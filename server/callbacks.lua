-- Server Callbacks for RSG Taxi System

local RSGCore = exports['rsg-core']:GetCoreObject()

-- Wait for RSGCore to be ready
CreateThread(function()
    while not RSGCore do
        Wait(10)
        RSGCore = exports['rsg-core']:GetCoreObject()
    end
end)

-- Get available taxi drivers
RSGCore.Functions.CreateCallback('rsg-taxi:server:getAvailableDrivers', function(source, cb, coords)
    local availableDrivers = {}
    
    for driverId, driver in pairs(TaxiDrivers) do
        if driver.status == 'available' then
            local driverCoords = GetEntityCoords(GetPlayerPed(driverId))
            local distance = coords and #(coords - driverCoords) or 0
            
            table.insert(availableDrivers, {
                id = driverId,
                name = driver.playerName,
                rating = driver.rating,
                totalRides = driver.totalRides,
                distance = distance,
                coords = driverCoords
            })
        end
    end
    
    -- Sort by distance if coords provided
    if coords then
        table.sort(availableDrivers, function(a, b)
            return a.distance < b.distance
        end)
    end
    
    cb(availableDrivers)
end)

-- Get taxi stands
RSGCore.Functions.CreateCallback('rsg-taxi:server:getTaxiStands', function(source, cb)
    cb(Config.TaxiStands)
end)

-- Get pickup locations
RSGCore.Functions.CreateCallback('rsg-taxi:server:getPickupLocations', function(source, cb)
    cb(Config.PickupLocations)
end)

-- Check if player can become taxi driver
RSGCore.Functions.CreateCallback('rsg-taxi:server:canBecomeTaxiDriver', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player not found')
        return
    end
    
    -- Check if player has taxi job
    if Player.PlayerData.job.name ~= Config.TaxiJob then
        cb(false, Lang:t('error.not_taxi_driver'))
        return
    end
    
    -- Check if already working
    if TaxiDrivers[source] then
        cb(false, Lang:t('error.already_taxi_driver'))
        return
    end
    
    -- Check maximum drivers
    local driverCount = 0
    for _ in pairs(TaxiDrivers) do
        driverCount = driverCount + 1
    end
    
    if driverCount >= Config.MaxTaxiDrivers then
        cb(false, Lang:t('error.max_drivers_reached'))
        return
    end
    
    cb(true, 'Can become taxi driver')
end)

-- Get vehicle spawn locations
RSGCore.Functions.CreateCallback('rsg-taxi:server:getVehicleSpawnLocations', function(source, cb)
    local availableLocations = {}
    
    for _, location in ipairs(Config.VehicleSpawnLocations) do
        local occupied = false
        
        -- Check if location is occupied
        local vehicles = GetAllVehicles()
        for _, vehicle in ipairs(vehicles) do
            local vehicleCoords = GetEntityCoords(vehicle)
            if #(location.coords - vehicleCoords) < 5.0 then
                occupied = true
                break
            end
        end
        
        if not occupied then
            table.insert(availableLocations, location)
        end
    end
    
    cb(availableLocations)
end)

-- Calculate fare estimate
RSGCore.Functions.CreateCallback('rsg-taxi:server:calculateFareEstimate', function(source, cb, pickup, destination)
    local distance = #(pickup - destination)
    local baseFare = Config.FareSystem.BaseFare
    local distanceFare = distance * Config.FareSystem.PerMeterRate
    local estimatedTime = distance / 10 -- Rough estimate: 10 units per second
    local timeFare = estimatedTime * Config.FareSystem.WaitingRate
    
    local totalFare = baseFare + distanceFare + timeFare
    
    -- Apply night multiplier if applicable
    local hour = tonumber(os.date('%H'))
    if hour >= 20 or hour <= 6 then
        totalFare = totalFare * Config.FareSystem.NightMultiplier
    end
    
    -- Apply weather multiplier (simplified random check)
    if math.random() < 0.3 then
        totalFare = totalFare * Config.FareSystem.WeatherMultiplier
    end
    
    totalFare = math.max(Config.FareSystem.MinimumFare, math.min(Config.FareSystem.MaximumFare, totalFare))
    
    cb({
        baseFare = baseFare,
        distanceFare = distanceFare,
        timeFare = timeFare,
        totalFare = totalFare,
        distance = distance,
        estimatedTime = estimatedTime
    })
end)

-- Get player's current ride
RSGCore.Functions.CreateCallback('rsg-taxi:server:getCurrentRide', function(source, cb)
    if ActiveRides[source] then
        cb(ActiveRides[source])
    else
        -- Check if player is a driver with an active ride
        for passengerId, ride in pairs(ActiveRides) do
            if ride.driver == source then
                cb(ride)
                return
            end
        end
        cb(nil)
    end
end)

-- Get driver earnings for today
RSGCore.Functions.CreateCallback('rsg-taxi:server:getTodayEarnings', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        cb(0)
        return
    end
    
    if not Config.Database.Enabled then
        -- Return current session earnings if no database
        if TaxiDrivers[source] then
            cb(TaxiDrivers[source].totalEarnings or 0)
        else
            cb(0)
        end
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.query([[
        SELECT SUM(fare + tip) as today_earnings
        FROM taxi_rides
        WHERE driver_citizenid = ? AND DATE(created_at) = CURDATE() AND status = 'completed'
    ]], {citizenid}, function(result)
        if result and result[1] and result[1].today_earnings then
            cb(result[1].today_earnings)
        else
            cb(0)
        end
    end)
end)

-- Get driver's weekly stats
RSGCore.Functions.CreateCallback('rsg-taxi:server:getWeeklyStats', function(source, cb)
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
    
    MySQL.query([[
        SELECT 
            DATE(created_at) as ride_date,
            COUNT(*) as rides_count,
            SUM(fare + tip) as daily_earnings,
            AVG(rating) as avg_rating
        FROM taxi_rides r
        LEFT JOIN taxi_ratings rt ON r.ride_id = rt.ride_id
        WHERE r.driver_citizenid = ? 
        AND r.created_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
        AND r.status = 'completed'
        GROUP BY DATE(r.created_at)
        ORDER BY ride_date DESC
    ]], {citizenid}, function(result)
        cb(result or {})
    end)
end)

-- Get nearby passengers waiting for taxi
RSGCore.Functions.CreateCallback('rsg-taxi:server:getNearbyPassengers', function(source, cb, coords, radius)
    local nearbyPassengers = {}
    radius = radius or 500.0
    
    for passengerId, ride in pairs(ActiveRides) do
        if ride.status == 'requested' and #(coords - ride.pickupCoords) <= radius then
            local Player = RSGCore.Functions.GetPlayer(passengerId)
            if Player then
                table.insert(nearbyPassengers, {
                    id = passengerId,
                    name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                    pickupCoords = ride.pickupCoords,
                    destination = ride.destination,
                    distance = #(coords - ride.pickupCoords),
                    waitTime = os.time() - ride.startTime,
                    estimatedFare = CalculateEstimatedFare(ride.pickupCoords, ride.destination)
                })
            end
        end
    end
    
    -- Sort by distance
    table.sort(nearbyPassengers, function(a, b)
        return a.distance < b.distance
    end)
    
    cb(nearbyPassengers)
end)

-- Check if location is a taxi stand
RSGCore.Functions.CreateCallback('rsg-taxi:server:isAtTaxiStand', function(source, cb, coords)
    for _, stand in ipairs(Config.TaxiStands) do
        if #(coords - stand.coords) <= stand.radius then
            cb(true, stand)
            return
        end
    end
    cb(false, nil)
end)

-- Get taxi vehicle models
RSGCore.Functions.CreateCallback('rsg-taxi:server:getTaxiVehicles', function(source, cb)
    cb(Config.TaxiVehicles)
end)

-- Validate destination
RSGCore.Functions.CreateCallback('rsg-taxi:server:validateDestination', function(source, cb, coords)
    -- Check if destination is valid (not in water, not too far, etc.)
    local valid = true
    local reason = ''
    
    -- Check if coordinates are reasonable
    if not coords or not coords.x or not coords.y or not coords.z then
        valid = false
        reason = 'Invalid coordinates'
    end
    
    -- Check if destination is too far (example: max 10km)
    if valid then
        local playerCoords = GetEntityCoords(GetPlayerPed(source))
        local distance = #(playerCoords - coords)
        if distance > 10000 then
            valid = false
            reason = 'Destination too far'
        end
    end
    
    cb(valid, reason)
end)

-- Get active rides count
RSGCore.Functions.CreateCallback('rsg-taxi:server:getActiveRidesCount', function(source, cb)
    local count = 0
    for _ in pairs(ActiveRides) do
        count = count + 1
    end
    cb(count)
end)

-- Get server statistics
RSGCore.Functions.CreateCallback('rsg-taxi:server:getServerStats', function(source, cb)
    local stats = {
        totalDrivers = 0,
        availableDrivers = 0,
        busyDrivers = 0,
        activeRides = 0,
        totalVehicles = 0
    }
    
    for _, driver in pairs(TaxiDrivers) do
        stats.totalDrivers = stats.totalDrivers + 1
        if driver.status == 'available' then
            stats.availableDrivers = stats.availableDrivers + 1
        elseif driver.status == 'busy' then
            stats.busyDrivers = stats.busyDrivers + 1
        end
    end
    
    for _ in pairs(ActiveRides) do
        stats.activeRides = stats.activeRides + 1
    end
    
    for _ in pairs(TaxiVehicles) do
        stats.totalVehicles = stats.totalVehicles + 1
    end
    
    cb(stats)
end)