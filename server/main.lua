local RSGCore = exports['rsg-core']:GetCoreObject()

-- Global Variables (accessible across server files)
TaxiDrivers = {}
ActiveRides = {}
TaxiVehicles = {}
NPCTaxis = {}
RideQueue = {}

-- Initialize the taxi system
CreateThread(function()
    Wait(1000)
    print('^2[RSG-TAXI]^7 Taxi system initialized')
    
    -- Create database tables if they don't exist
    if Config.Database.Enabled then
        TriggerEvent('rsg-taxi:server:createTables')
    end
    
    -- Start cleanup thread
    CreateThread(function()
        while true do
            Wait(Config.Performance.CleanupInterval)
            CleanupInactiveRides()
            CleanupAbandonedVehicles()
        end
    end)
end)

-- Player Management
RegisterNetEvent('RSGCore:Server:PlayerLoaded', function(Player)
    local src = source
    if Config.Database.Enabled then
        LoadPlayerTaxiData(src)
    end
end)

RegisterNetEvent('RSGCore:Server:OnPlayerUnload', function(src)
    if TaxiDrivers[src] then
        TaxiDrivers[src] = nil
        TriggerClientEvent('rsg-taxi:client:updateDrivers', -1, TaxiDrivers)
    end
    
    -- Cancel any active rides
    if ActiveRides[src] then
        CancelRide(src, 'driver_disconnect')
    end
end)

-- Taxi Driver Management
RegisterNetEvent('rsg-taxi:server:startWork', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player has taxi job
    if Player.PlayerData.job.name ~= Config.TaxiJob then
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.not_taxi_driver'), 'error')
        return
    end
    
    -- Check if already working
    if TaxiDrivers[src] then
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.already_taxi_driver'), 'error')
        return
    end
    
    -- Check maximum drivers
    local driverCount = 0
    for _ in pairs(TaxiDrivers) do
        driverCount = driverCount + 1
    end
    
    if driverCount >= Config.MaxTaxiDrivers then
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.max_drivers_reached'), 'error')
        return
    end
    
    -- Add driver to active list
    TaxiDrivers[src] = {
        playerId = src,
        playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        status = 'available',
        vehicle = nil,
        currentRide = nil,
        totalRides = 0,
        totalEarnings = 0,
        rating = 5.0,
        startTime = os.time()
    }
    
    TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.taxi_job_started'), 'success')
    TriggerClientEvent('rsg-taxi:client:startWork', src)
    TriggerClientEvent('rsg-taxi:client:updateDrivers', -1, TaxiDrivers)
    
    -- Save to database
    if Config.Database.Enabled then
        SaveDriverData(src)
    end
end)

RegisterNetEvent('rsg-taxi:server:stopWork', function()
    local src = source
    
    if not TaxiDrivers[src] then
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.not_taxi_driver'), 'error')
        return
    end
    
    -- Cancel any active rides
    if TaxiDrivers[src].currentRide then
        CancelRide(src, 'driver_stopped_work')
    end
    
    -- Remove driver from active list
    TaxiDrivers[src] = nil
    
    TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.taxi_job_stopped'), 'success')
    TriggerClientEvent('rsg-taxi:client:stopWork', src)
    TriggerClientEvent('rsg-taxi:client:updateDrivers', -1, TaxiDrivers)
end)

-- Vehicle Management
RegisterNetEvent('rsg-taxi:server:spawnVehicle', function(vehicleModel, coords, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player or not TaxiDrivers[src] then
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.not_taxi_driver'), 'error')
        return
    end
    
    if TaxiDrivers[src].vehicle then
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.vehicle_occupied'), 'error')
        return
    end
    
    -- Spawn vehicle
    local vehicle = CreateVehicle(vehicleModel, coords.x, coords.y, coords.z, heading, true, true)
    
    if vehicle then
        local plate = GeneratePlate()
        SetVehicleNumberPlateText(vehicle, plate)
        
        TaxiVehicles[vehicle] = {
            driver = src,
            plate = plate,
            model = vehicleModel,
            spawnTime = os.time()
        }
        
        TaxiDrivers[src].vehicle = vehicle
        
        TriggerClientEvent('rsg-taxi:client:setVehicleKeys', src, vehicle, plate)
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.vehicle_spawned'), 'success')
    end
end)

RegisterNetEvent('rsg-taxi:server:returnVehicle', function(vehicle)
    local src = source
    
    if not TaxiDrivers[src] or TaxiDrivers[src].vehicle ~= vehicle then
        return
    end
    
    -- Remove vehicle
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end
    
    TaxiVehicles[vehicle] = nil
    TaxiDrivers[src].vehicle = nil
    
    TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.vehicle_returned'), 'success')
end)

-- Ride Management
RegisterNetEvent('rsg-taxi:server:requestRide', function(pickupCoords, destination)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player already has an active ride
    if ActiveRides[src] then
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.ride_in_progress'), 'error')
        return
    end
    
    -- Find available driver
    local availableDriver = FindAvailableDriver(pickupCoords)
    
    if not availableDriver then
        -- Add to queue or spawn NPC taxi
        if Config.NPCTaxis.Enabled then
            SpawnNPCTaxi(src, pickupCoords, destination)
        else
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.no_nearby_taxis'), 'error')
        end
        return
    end
    
    -- Create ride
    local rideId = GenerateRideId()
    ActiveRides[src] = {
        id = rideId,
        passenger = src,
        driver = availableDriver,
        pickupCoords = pickupCoords,
        destination = destination,
        status = 'requested',
        startTime = os.time(),
        fare = 0,
        distance = 0
    }
    
    TaxiDrivers[availableDriver].status = 'busy'
    TaxiDrivers[availableDriver].currentRide = rideId
    
    -- Notify driver
    TriggerClientEvent('rsg-taxi:client:rideRequest', availableDriver, {
        passenger = src,
        passengerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        pickupCoords = pickupCoords,
        destination = destination,
        estimatedFare = CalculateEstimatedFare(pickupCoords, destination)
    })
    
    TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.taxi_called'), 'success')
end)

RegisterNetEvent('rsg-taxi:server:acceptRide', function(passengerId)
    local src = source
    
    if not TaxiDrivers[src] or not ActiveRides[passengerId] then
        return
    end
    
    local ride = ActiveRides[passengerId]
    if ride.driver ~= src then
        return
    end
    
    ride.status = 'accepted'
    
    TriggerClientEvent('rsg-taxi:client:rideAccepted', passengerId, src)
    TriggerClientEvent('rsg-taxi:client:startRide', src, ride)
    
    TriggerClientEvent('RSGCore:Notify', passengerId, Lang:t('notifications.ride_accepted'), 'success')
    TriggerClientEvent('RSGCore:Notify', src, Lang:t('notifications.ride_accepted'), 'success')
end)

RegisterNetEvent('rsg-taxi:server:declineRide', function(passengerId)
    local src = source
    
    if not ActiveRides[passengerId] then
        return
    end
    
    local ride = ActiveRides[passengerId]
    if ride.driver ~= src then
        return
    end
    
    -- Find another driver or cancel
    local newDriver = FindAvailableDriver(ride.pickupCoords, src)
    
    if newDriver then
        ride.driver = newDriver
        TaxiDrivers[newDriver].status = 'busy'
        TaxiDrivers[newDriver].currentRide = ride.id
        
        TriggerClientEvent('rsg-taxi:client:rideRequest', newDriver, {
            passenger = passengerId,
            pickupCoords = ride.pickupCoords,
            destination = ride.destination,
            estimatedFare = CalculateEstimatedFare(ride.pickupCoords, ride.destination)
        })
    else
        CancelRide(passengerId, 'no_available_drivers')
    end
    
    TaxiDrivers[src].status = 'available'
    TaxiDrivers[src].currentRide = nil
end)

RegisterNetEvent('rsg-taxi:server:startMeter', function(passengerId)
    local src = source
    
    if not TaxiDrivers[src] or not ActiveRides[passengerId] then
        return
    end
    
    local ride = ActiveRides[passengerId]
    if ride.driver ~= src then
        return
    end
    
    ride.status = 'in_progress'
    ride.meterStartTime = os.time()
    
    TriggerClientEvent('rsg-taxi:client:meterStarted', src)
    TriggerClientEvent('rsg-taxi:client:meterStarted', passengerId)
    
    TriggerClientEvent('RSGCore:Notify', src, Lang:t('info.taxi_meter_started'), 'primary')
    TriggerClientEvent('RSGCore:Notify', passengerId, Lang:t('info.ride_started', {destination = ride.destination.name}), 'primary')
end)

RegisterNetEvent('rsg-taxi:server:stopMeter', function(passengerId, finalCoords)
    local src = source
    
    if not TaxiDrivers[src] or not ActiveRides[passengerId] then
        return
    end
    
    local ride = ActiveRides[passengerId]
    if ride.driver ~= src then
        return
    end
    
    -- Calculate final fare
    local distance = #(ride.pickupCoords - finalCoords)
    local duration = os.time() - ride.meterStartTime
    local fare = CalculateFare(distance, duration)
    
    ride.status = 'completed'
    ride.endTime = os.time()
    ride.fare = fare
    ride.distance = distance
    ride.duration = duration
    
    TriggerClientEvent('rsg-taxi:client:meterStopped', src, fare)
    TriggerClientEvent('rsg-taxi:client:paymentRequest', passengerId, {
        fare = fare,
        distance = distance,
        duration = duration,
        driver = TaxiDrivers[src].playerName
    })
    
    TriggerClientEvent('RSGCore:Notify', src, Lang:t('info.taxi_meter_stopped'), 'primary')
end)

RegisterNetEvent('rsg-taxi:server:payFare', function(driverId, amount, tip, paymentMethod)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Driver = RSGCore.Functions.GetPlayer(driverId)
    
    if not Player or not Driver or not ActiveRides[src] then
        return
    end
    
    local totalAmount = amount + (tip or 0)
    
    -- Check if player has enough money
    if paymentMethod == 'cash' then
        if Player.PlayerData.money.cash < totalAmount then
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.insufficient_funds'), 'error')
            return
        end
        Player.Functions.RemoveMoney('cash', totalAmount)
    else
        if Player.PlayerData.money.bank < totalAmount then
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.insufficient_funds'), 'error')
            return
        end
        Player.Functions.RemoveMoney('bank', totalAmount)
    end
    
    -- Pay driver
    local driverCut = math.floor(amount * Config.Economy.TaxiDriverCut)
    local companyCut = amount - driverCut
    
    Driver.Functions.AddMoney('cash', driverCut + (tip or 0))
    
    -- Add to society account if configured
    if Config.Economy.SocietyAccount then
        exports['rsg-management']:AddMoney(Config.Economy.SocietyAccount, companyCut)
    end
    
    -- Update driver stats
    TaxiDrivers[driverId].totalRides = TaxiDrivers[driverId].totalRides + 1
    TaxiDrivers[driverId].totalEarnings = TaxiDrivers[driverId].totalEarnings + driverCut + (tip or 0)
    TaxiDrivers[driverId].status = 'available'
    TaxiDrivers[driverId].currentRide = nil
    
    -- Complete ride
    local ride = ActiveRides[src]
    ride.paid = true
    ride.tip = tip or 0
    ride.paymentMethod = paymentMethod
    
    TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.ride_completed'), 'success')
    TriggerClientEvent('RSGCore:Notify', driverId, Lang:t('success.fare_collected', {amount = driverCut + (tip or 0)}), 'success')
    
    if tip and tip > 0 then
        TriggerClientEvent('RSGCore:Notify', driverId, Lang:t('success.tip_received', {amount = tip}), 'success')
    end
    
    -- Save to database
    if Config.Database.Enabled then
        SaveRideData(ride)
        SaveDriverData(driverId)
    end
    
    -- Clean up
    ActiveRides[src] = nil
    
    -- Request rating
    if Config.RatingSystem.Enabled then
        TriggerClientEvent('rsg-taxi:client:requestRating', src, driverId)
    end
end)

RegisterNetEvent('rsg-taxi:server:submitRating', function(driverId, rating, comment)
    local src = source
    
    if not TaxiDrivers[driverId] then
        return
    end
    
    -- Update driver rating
    local currentRating = TaxiDrivers[driverId].rating or Config.RatingSystem.DefaultRating
    local newRating = (currentRating + rating) / 2
    TaxiDrivers[driverId].rating = math.max(Config.RatingSystem.MinRating, math.min(Config.RatingSystem.MaxRating, newRating))
    
    -- Save rating to database
    if Config.Database.Enabled then
        SaveRatingData(src, driverId, rating, comment)
    end
    
    TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.rating_submitted'), 'success')
end)

-- Utility Functions
function FindAvailableDriver(coords, excludeDriver)
    local closestDriver = nil
    local closestDistance = math.huge
    
    for driverId, driver in pairs(TaxiDrivers) do
        if driver.status == 'available' and driverId ~= excludeDriver then
            local driverCoords = GetEntityCoords(GetPlayerPed(driverId))
            local distance = #(coords - driverCoords)
            
            if distance < closestDistance then
                closestDistance = distance
                closestDriver = driverId
            end
        end
    end
    
    return closestDriver
end

function CalculateEstimatedFare(pickup, destination)
    local distance = #(pickup - destination.coords)
    local baseFare = Config.FareSystem.BaseFare
    local distanceFare = distance * Config.FareSystem.PerMeterRate
    
    return math.max(Config.FareSystem.MinimumFare, baseFare + distanceFare)
end

function CalculateFare(distance, duration)
    local baseFare = Config.FareSystem.BaseFare
    local distanceFare = distance * Config.FareSystem.PerMeterRate
    local timeFare = duration * Config.FareSystem.WaitingRate
    
    local totalFare = baseFare + distanceFare + timeFare
    
    -- Apply multipliers
    local hour = tonumber(os.date('%H'))
    if hour >= 20 or hour <= 6 then
        totalFare = totalFare * Config.FareSystem.NightMultiplier
    end
    
    -- Weather multiplier (simplified)
    if math.random() < 0.3 then -- 30% chance of bad weather
        totalFare = totalFare * Config.FareSystem.WeatherMultiplier
    end
    
    return math.max(Config.FareSystem.MinimumFare, math.min(Config.FareSystem.MaximumFare, totalFare))
end

function CancelRide(passengerId, reason)
    if not ActiveRides[passengerId] then
        return
    end
    
    local ride = ActiveRides[passengerId]
    local driverId = ride.driver
    
    if TaxiDrivers[driverId] then
        TaxiDrivers[driverId].status = 'available'
        TaxiDrivers[driverId].currentRide = nil
        TriggerClientEvent('rsg-taxi:client:rideCancelled', driverId, reason)
    end
    
    TriggerClientEvent('rsg-taxi:client:rideCancelled', passengerId, reason)
    ActiveRides[passengerId] = nil
end

function GenerateRideId()
    return 'ride_' .. os.time() .. '_' .. math.random(1000, 9999)
end

function GeneratePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local rand = math.random(#chars)
        plate = plate .. string.sub(chars, rand, rand)
    end
    return plate
end

function CleanupInactiveRides()
    local currentTime = os.time()
    for passengerId, ride in pairs(ActiveRides) do
        if currentTime - ride.startTime > 1800 then -- 30 minutes
            CancelRide(passengerId, 'timeout')
        end
    end
end

function CleanupAbandonedVehicles()
    local currentTime = os.time()
    for vehicle, data in pairs(TaxiVehicles) do
        if not TaxiDrivers[data.driver] or currentTime - data.spawnTime > 3600 then -- 1 hour
            if DoesEntityExist(vehicle) then
                DeleteEntity(vehicle)
            end
            TaxiVehicles[vehicle] = nil
        end
    end
end

-- Callbacks
RSGCore.Functions.CreateCallback('rsg-taxi:server:getTaxiDrivers', function(source, cb)
    cb(TaxiDrivers)
end)

RSGCore.Functions.CreateCallback('rsg-taxi:server:getDriverStats', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
        return
    end
    
    if not Config.Database.Enabled then
        -- Return current session stats if no database
        local src = source
        if TaxiDrivers[src] then
            cb(TaxiDrivers[src])
        else
            cb(nil)
        end
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.query([[
        SELECT 
            d.*,
            COUNT(r.id) as completed_rides,
            SUM(r.fare + r.tip) as total_earned,
            AVG(rt.rating) as avg_rating
        FROM taxi_drivers d
        LEFT JOIN taxi_rides r ON d.citizenid = r.driver_citizenid AND r.status = 'completed'
        LEFT JOIN taxi_ratings rt ON d.citizenid = rt.driver_citizenid
        WHERE d.citizenid = ?
        GROUP BY d.id
    ]], {citizenid}, function(result)
        if result and result[1] then
            cb(result[1])
        else
            cb(nil)
        end
    end)
end)

-- Get ride history
RSGCore.Functions.CreateCallback('rsg-taxi:server:getRideHistory', function(source, cb, limit)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end
    
    if not Config.Database.Enabled then
        cb({})
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    limit = limit or 50
    
    MySQL.query([[
        SELECT 
            r.*,
            rt.rating,
            rt.comment
        FROM taxi_rides r
        LEFT JOIN taxi_ratings rt ON r.ride_id = rt.ride_id
        WHERE r.driver_citizenid = ? OR r.passenger_citizenid = ?
        ORDER BY r.created_at DESC
        LIMIT ?
    ]], {citizenid, citizenid, limit}, function(result)
        cb(result or {})
    end)
end)

-- Get top drivers
RSGCore.Functions.CreateCallback('rsg-taxi:server:getTopDrivers', function(source, cb, limit)
    if not Config.Database.Enabled then
        cb({})
        return
    end
    
    limit = limit or 10
    
    MySQL.query([[
        SELECT 
            player_name,
            total_rides,
            total_earnings,
            rating,
            total_rating_count
        FROM taxi_drivers
        WHERE total_rides > 0
        ORDER BY rating DESC, total_rides DESC
        LIMIT ?
    ]], {limit}, function(result)
        cb(result or {})
    end)
end)

-- Commands
RSGCore.Commands.Add('taxi', Lang:t('commands.taxi'), {}, false, function(source, args)
    TriggerClientEvent('rsg-taxi:client:openMenu', source)
end)

RSGCore.Commands.Add('calltaxi', Lang:t('commands.calltaxi'), {}, false, function(source, args)
    TriggerClientEvent('rsg-taxi:client:callTaxi', source)
end)

-- Exports
exports('GetTaxiDrivers', function()
    return TaxiDrivers
end)

exports('GetActiveRides', function()
    return ActiveRides
end)

exports('IsPlayerTaxiDriver', function(playerId)
    return TaxiDrivers[playerId] ~= nil
end)