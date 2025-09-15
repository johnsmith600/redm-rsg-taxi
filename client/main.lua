local RSGCore = exports['rsg-core']:GetCoreObject()

-- Local Variables
local PlayerData = {}
local isTaxiDriver = false
local isOnDuty = false
local currentVehicle = nil
local currentRide = nil
local taxiMeter = {
    active = false,
    startTime = 0,
    startCoords = nil,
    fare = 0.0,
    distance = 0.0
}
local taxiBlips = {}
local driverBlips = {}
local rideBlip = nil

-- Initialize
CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            PlayerData = RSGCore.Functions.GetPlayerData()
            break
        end
        Wait(10)
    end
    
    -- Initialize taxi system
    InitializeTaxiSystem()
end)

-- Player Data Events
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    PlayerData = RSGCore.Functions.GetPlayerData()
    InitializeTaxiSystem()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    CleanupTaxiSystem()
end)

RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
    CheckTaxiJob()
end)

-- Initialize Taxi System
function InitializeTaxiSystem()
    CreateTaxiStandBlips()
    CheckTaxiJob()
    
    -- Start main thread
    CreateThread(TaxiMainThread)
    
    -- Start meter thread
    CreateThread(TaxiMeterThread)
end

-- Cleanup Taxi System
function CleanupTaxiSystem()
    RemoveAllBlips()
    if isOnDuty then
        StopTaxiWork()
    end
end

-- Check if player has taxi job
function CheckTaxiJob()
    if PlayerData.job and PlayerData.job.name == Config.TaxiJob then
        isTaxiDriver = true
    else
        isTaxiDriver = false
        if isOnDuty then
            StopTaxiWork()
        end
    end
end

-- Main taxi thread
function TaxiMainThread()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        if isTaxiDriver and isOnDuty then
            sleep = 500
            
            -- Check if in taxi vehicle
            if IsPedInAnyVehicle(playerPed, false) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                if IsVehicleModel(vehicle, GetHashKey(Config.TaxiVehicles[1])) or 
                   IsVehicleModel(vehicle, GetHashKey(Config.TaxiVehicles[2])) or
                   IsVehicleModel(vehicle, GetHashKey(Config.TaxiVehicles[3])) or
                   IsVehicleModel(vehicle, GetHashKey(Config.TaxiVehicles[4])) then
                    currentVehicle = vehicle
                    
                    -- Update meter if active
                    if taxiMeter.active then
                        UpdateTaxiMeter(playerCoords)
                    end
                end
            else
                currentVehicle = nil
            end
        end
        
        -- Check taxi stand proximity
        for _, stand in ipairs(Config.TaxiStands) do
            local distance = #(playerCoords - stand.coords)
            if distance <= stand.radius then
                sleep = 0
                
                -- Show help text
                if not isTaxiDriver or (isTaxiDriver and not isOnDuty) then
                    RSGCore.Functions.DrawText3D(stand.coords.x, stand.coords.y, stand.coords.z + 1.0, Lang:t('help.taxi_stand'))
                end
                
                -- Handle interaction
                if IsControlJustReleased(0, 0x760A9C6F) then -- G key
                    if isTaxiDriver then
                        OpenTaxiDriverMenu()
                    else
                        OpenPassengerMenu()
                    end
                end
                break
            end
        end
        
        Wait(sleep)
    end
end

-- Taxi meter thread
function TaxiMeterThread()
    while true do
        if taxiMeter.active and currentVehicle then
            local playerCoords = GetEntityCoords(PlayerPedId())
            UpdateTaxiMeter(playerCoords)
        end
        Wait(1000) -- Update every second
    end
end

-- Start taxi work
function StartTaxiWork()
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:canBecomeTaxiDriver', function(canStart, reason)
        if canStart then
            TriggerServerEvent('rsg-taxi:server:startWork')
        else
            RSGCore.Functions.Notify(reason, 'error')
        end
    end)
end

-- Stop taxi work
function StopTaxiWork()
    TriggerServerEvent('rsg-taxi:server:stopWork')
end

-- Spawn taxi vehicle
function SpawnTaxiVehicle()
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:getVehicleSpawnLocations', function(locations)
        if #locations == 0 then
            RSGCore.Functions.Notify(Lang:t('error.no_spawn_locations'), 'error')
            return
        end
        
        -- Use closest location
        local playerCoords = GetEntityCoords(PlayerPedId())
        local closestLocation = nil
        local closestDistance = math.huge
        
        for _, location in ipairs(locations) do
            local distance = #(playerCoords - location.coords)
            if distance < closestDistance then
                closestDistance = distance
                closestLocation = location
            end
        end
        
        if closestLocation then
            -- Show vehicle selection menu
            ShowVehicleSelectionMenu(closestLocation)
        end
    end)
end

-- Show vehicle selection menu
function ShowVehicleSelectionMenu(spawnLocation)
    local vehicleMenu = {
        {
            header = Lang:t('menu.spawn_vehicle'),
            isMenuHeader = true
        }
    }
    
    for _, vehicle in ipairs(Config.TaxiVehicles) do
        table.insert(vehicleMenu, {
            header = GetDisplayNameFromVehicleModel(vehicle),
            txt = Lang:t('ui.vehicle_model') .. ': ' .. vehicle,
            params = {
                event = 'rsg-taxi:client:spawnSelectedVehicle',
                args = {
                    model = vehicle,
                    coords = spawnLocation.coords,
                    heading = spawnLocation.heading
                }
            }
        })
    end
    
    table.insert(vehicleMenu, {
        header = Lang:t('menu.close'),
        params = {
            event = 'rsg-menu:closeMenu'
        }
    })
    
    exports['rsg-menu']:openMenu(vehicleMenu)
end

-- Return taxi vehicle
function ReturnTaxiVehicle()
    if currentVehicle then
        TriggerServerEvent('rsg-taxi:server:returnVehicle', currentVehicle)
        currentVehicle = nil
    else
        RSGCore.Functions.Notify(Lang:t('error.no_vehicle'), 'error')
    end
end

-- Toggle taxi meter
function ToggleTaxiMeter()
    if not currentVehicle then
        RSGCore.Functions.Notify(Lang:t('error.no_vehicle'), 'error')
        return
    end
    
    if not currentRide then
        RSGCore.Functions.Notify(Lang:t('error.no_passengers'), 'error')
        return
    end
    
    if taxiMeter.active then
        StopTaxiMeter()
    else
        StartTaxiMeter()
    end
end

-- Start taxi meter
function StartTaxiMeter()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    taxiMeter.active = true
    taxiMeter.startTime = GetGameTimer()
    taxiMeter.startCoords = playerCoords
    taxiMeter.fare = Config.FareSystem.BaseFare
    taxiMeter.distance = 0.0
    
    TriggerServerEvent('rsg-taxi:server:startMeter', currentRide.passenger)
    RSGCore.Functions.Notify(Lang:t('info.taxi_meter_started'), 'primary')
end

-- Stop taxi meter
function StopTaxiMeter()
    if not taxiMeter.active then return end
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    taxiMeter.active = false
    TriggerServerEvent('rsg-taxi:server:stopMeter', currentRide.passenger, playerCoords)
    RSGCore.Functions.Notify(Lang:t('info.taxi_meter_stopped'), 'primary')
end

-- Update taxi meter
function UpdateTaxiMeter(currentCoords)
    if not taxiMeter.active or not taxiMeter.startCoords then return end
    
    local distance = #(taxiMeter.startCoords - currentCoords)
    local timePassed = (GetGameTimer() - taxiMeter.startTime) / 1000
    
    taxiMeter.distance = distance
    taxiMeter.fare = Config.FareSystem.BaseFare + 
                    (distance * Config.FareSystem.PerMeterRate) + 
                    (timePassed * Config.FareSystem.WaitingRate)
    
    -- Apply multipliers
    local hour = GetClockHours()
    if hour >= 20 or hour <= 6 then
        taxiMeter.fare = taxiMeter.fare * Config.FareSystem.NightMultiplier
    end
    
    -- Clamp fare
    taxiMeter.fare = math.max(Config.FareSystem.MinimumFare, 
                             math.min(Config.FareSystem.MaximumFare, taxiMeter.fare))
    
    -- Update UI
    SendNUIMessage({
        type = 'updateMeter',
        fare = taxiMeter.fare,
        distance = taxiMeter.distance,
        time = timePassed
    })
end

-- Call taxi (passenger)
function CallTaxi()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    -- Show destination selection
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:getPickupLocations', function(locations)
        ShowDestinationMenu(locations, playerCoords)
    end)
end

-- Show destination menu
function ShowDestinationMenu(locations, pickupCoords)
    local destinationMenu = {
        {
            header = Lang:t('ui.destination'),
            isMenuHeader = true
        }
    }
    
    for _, location in ipairs(locations) do
        local distance = #(pickupCoords - location.coords)
        table.insert(destinationMenu, {
            header = location.name,
            txt = Lang:t('ui.trip_distance') .. ': ' .. math.floor(distance) .. 'm',
            params = {
                event = 'rsg-taxi:client:requestRide',
                args = {
                    pickup = pickupCoords,
                    destination = location
                }
            }
        })
    end
    
    table.insert(destinationMenu, {
        header = Lang:t('menu.close'),
        params = {
            event = 'rsg-menu:closeMenu'
        }
    })
    
    exports['rsg-menu']:openMenu(destinationMenu)
end

-- Open taxi driver menu
function OpenTaxiDriverMenu()
    print("^2[RSG-Taxi]^7 OpenTaxiDriverMenu called")
    local driverMenu = {
        {
            header = Lang:t('menu.taxi_menu'),
            isMenuHeader = true
        }
    }
    
    if not isOnDuty then
        table.insert(driverMenu, {
            header = Lang:t('menu.start_work'),
            txt = Lang:t('info.start_taxi_shift'),
            params = {
                event = 'rsg-taxi:client:startWork'
            }
        })
    else
        table.insert(driverMenu, {
            header = Lang:t('menu.stop_work'),
            txt = Lang:t('info.stop_taxi_shift'),
            params = {
                event = 'rsg-taxi:client:stopWork'
            }
        })
        
        if not currentVehicle then
            table.insert(driverMenu, {
                header = Lang:t('menu.spawn_vehicle'),
                txt = Lang:t('info.spawn_taxi_vehicle'),
                params = {
                    event = 'rsg-taxi:client:spawnVehicle'
                }
            })
        else
            table.insert(driverMenu, {
                header = Lang:t('menu.return_vehicle'),
                txt = Lang:t('info.return_taxi_vehicle'),
                params = {
                    event = 'rsg-taxi:client:returnVehicle'
                }
            })
        end
        
        table.insert(driverMenu, {
            header = Lang:t('menu.toggle_meter'),
            txt = Lang:t('info.toggle_taxi_meter'),
            params = {
                event = 'rsg-taxi:client:toggleMeter'
            }
        })
        
        table.insert(driverMenu, {
            header = Lang:t('menu.driver_stats'),
            txt = Lang:t('info.view_driver_stats'),
            params = {
                event = 'rsg-taxi:client:showStats'
            }
        })
    end
    
    table.insert(driverMenu, {
        header = Lang:t('menu.close'),
        params = {
            event = 'rsg-menu:closeMenu'
        }
    })
    
    exports['rsg-menu']:openMenu(driverMenu)
end

-- Open passenger menu
function OpenPassengerMenu()
    print("^2[RSG-Taxi]^7 OpenPassengerMenu called")
    local passengerMenu = {
        {
            header = Lang:t('menu.passenger_menu'),
            isMenuHeader = true
        },
        {
            header = Lang:t('menu.call_taxi'),
            txt = Lang:t('info.request_taxi_ride'),
            params = {
                event = 'rsg-taxi:client:callTaxi'
            }
        }
    }
    
    if currentRide then
        table.insert(passengerMenu, {
            header = Lang:t('menu.cancel_ride'),
            txt = Lang:t('info.cancel_current_ride'),
            params = {
                event = 'rsg-taxi:client:cancelRide'
            }
        })
    end
    
    table.insert(passengerMenu, {
        header = Lang:t('menu.ride_history'),
        txt = Lang:t('info.view_ride_history'),
        params = {
            event = 'rsg-taxi:client:showRideHistory'
        }
    })
    
    table.insert(passengerMenu, {
        header = Lang:t('menu.close'),
        params = {
            event = 'rsg-menu:closeMenu'
        }
    })
    
    exports['rsg-menu']:openMenu(passengerMenu)
end

-- Event handler for opening taxi menu
RegisterNetEvent('rsg-taxi:client:openMenu', function()
    print("^2[RSG-Taxi]^7 Opening taxi menu - isTaxiDriver:", isTaxiDriver)
    if isTaxiDriver then
        print("^2[RSG-Taxi]^7 Opening driver menu")
        OpenTaxiDriverMenu()
    else
        print("^2[RSG-Taxi]^7 Opening passenger menu")
        OpenPassengerMenu()
    end
end)

-- Create taxi stand blips
function CreateTaxiStandBlips()
    for _, stand in ipairs(Config.TaxiStands) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, stand.coords.x, stand.coords.y, stand.coords.z)
        SetBlipSprite(blip, GetHashKey(Config.Blips.TaxiStand.sprite), true)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, Config.Blips.TaxiStand.name)
        table.insert(taxiBlips, blip)
    end
end

-- Remove all blips
function RemoveAllBlips()
    for _, blip in ipairs(taxiBlips) do
        RemoveBlip(blip)
    end
    taxiBlips = {}
    
    for _, blip in ipairs(driverBlips) do
        RemoveBlip(blip)
    end
    driverBlips = {}
    
    if rideBlip then
        RemoveBlip(rideBlip)
        rideBlip = nil
    end
end

-- Events
RegisterNetEvent('rsg-taxi:client:startWork', function()
    isOnDuty = true
    RSGCore.Functions.Notify(Lang:t('success.taxi_job_started'), 'success')
end)

RegisterNetEvent('rsg-taxi:client:stopWork', function()
    isOnDuty = false
    currentVehicle = nil
    currentRide = nil
    taxiMeter.active = false
    RSGCore.Functions.Notify(Lang:t('success.taxi_job_stopped'), 'success')
end)

RegisterNetEvent('rsg-taxi:client:spawnSelectedVehicle', function(data)
    TriggerServerEvent('rsg-taxi:server:spawnVehicle', data.model, data.coords, data.heading)
end)

RegisterNetEvent('rsg-taxi:client:setVehicleKeys', function(vehicle, plate)
    currentVehicle = vehicle
    -- Give keys to player (if using a key system)
    -- TriggerEvent('vehiclekeys:client:SetOwner', plate)
end)

RegisterNetEvent('rsg-taxi:client:requestRide', function(data)
    TriggerServerEvent('rsg-taxi:server:requestRide', data.pickup, data.destination)
end)

RegisterNetEvent('rsg-taxi:client:rideRequest', function(rideData)
    -- Show ride request notification
    RSGCore.Functions.Notify(Lang:t('notifications.new_ride_request', {location = rideData.destination.name}), 'primary', 10000)
    
    -- Show accept/decline menu
    local requestMenu = {
        {
            header = Lang:t('notifications.new_ride_request', {location = rideData.destination.name}),
            isMenuHeader = true
        },
        {
            header = Lang:t('ui.passenger_name') .. ': ' .. rideData.passengerName,
            txt = Lang:t('ui.estimated_fare') .. ': $' .. string.format('%.2f', rideData.estimatedFare),
            isMenuHeader = true
        },
        {
            header = Lang:t('menu.accept'),
            params = {
                event = 'rsg-taxi:client:acceptRide',
                args = {passenger = rideData.passenger}
            }
        },
        {
            header = Lang:t('menu.decline'),
            params = {
                event = 'rsg-taxi:client:declineRide',
                args = {passenger = rideData.passenger}
            }
        }
    }
    
    exports['rsg-menu']:openMenu(requestMenu)
end)

RegisterNetEvent('rsg-taxi:client:acceptRide', function(data)
    TriggerServerEvent('rsg-taxi:server:acceptRide', data.passenger)
end)

RegisterNetEvent('rsg-taxi:client:declineRide', function(data)
    TriggerServerEvent('rsg-taxi:server:declineRide', data.passenger)
end)

RegisterNetEvent('rsg-taxi:client:rideAccepted', function(driverId)
    currentRide = {driver = driverId}
    RSGCore.Functions.Notify(Lang:t('notifications.ride_accepted'), 'success')
end)

RegisterNetEvent('rsg-taxi:client:startRide', function(rideData)
    currentRide = rideData
    
    -- Create blip for destination
    if rideBlip then
        RemoveBlip(rideBlip)
    end
    
    rideBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, rideData.destination.coords.x, rideData.destination.coords.y, rideData.destination.coords.z)
    SetBlipSprite(rideBlip, GetHashKey(Config.Blips.ActiveRide.sprite), true)
    Citizen.InvokeNative(0x9CB1A1623062F402, rideBlip, Config.Blips.ActiveRide.name)
end)

RegisterNetEvent('rsg-taxi:client:meterStarted', function()
    -- Update UI or show notification
end)

RegisterNetEvent('rsg-taxi:client:meterStopped', function(fare)
    -- Show fare to driver
    RSGCore.Functions.Notify(Lang:t('info.current_fare', {amount = string.format('%.2f', fare)}), 'primary')
end)

RegisterNetEvent('rsg-taxi:client:paymentRequest', function(paymentData)
    -- Show payment UI
    SendNUIMessage({
        type = 'showPayment',
        data = paymentData
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('rsg-taxi:client:rideCancelled', function(reason)
    currentRide = nil
    taxiMeter.active = false
    
    if rideBlip then
        RemoveBlip(rideBlip)
        rideBlip = nil
    end
    
    RSGCore.Functions.Notify(Lang:t('notifications.ride_cancelled'), 'error')
end)

RegisterNetEvent('rsg-taxi:client:requestRating', function(driverId)
    -- Show rating UI
    SendNUIMessage({
        type = 'showRating',
        driverId = driverId
    })
    SetNuiFocus(true, true)
end)

-- Menu Events
RegisterNetEvent('rsg-taxi:client:startWork', function()
    StartTaxiWork()
end)

RegisterNetEvent('rsg-taxi:client:stopWork', function()
    StopTaxiWork()
end)

RegisterNetEvent('rsg-taxi:client:spawnVehicle', function()
    SpawnTaxiVehicle()
end)

RegisterNetEvent('rsg-taxi:client:returnVehicle', function()
    ReturnTaxiVehicle()
end)

RegisterNetEvent('rsg-taxi:client:toggleMeter', function()
    ToggleTaxiMeter()
end)

RegisterNetEvent('rsg-taxi:client:callTaxi', function()
    CallTaxi()
end)

RegisterNetEvent('rsg-taxi:client:showStats', function()
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:getDriverStats', function(stats)
        if stats then
            local statsMenu = {
                {
                    header = Lang:t('menu.driver_stats'),
                    isMenuHeader = true
                },
                {
                    header = Lang:t('info.total_rides', {count = stats.totalRides}),
                    isMenuHeader = true
                },
                {
                    header = Lang:t('info.total_earnings', {amount = string.format('%.2f', stats.totalEarnings)}),
                    isMenuHeader = true
                },
                {
                    header = Lang:t('info.driver_rating', {rating = string.format('%.1f', stats.rating)}),
                    isMenuHeader = true
                },
                {
                    header = Lang:t('menu.close'),
                    params = {
                        event = 'rsg-menu:closeMenu'
                    }
                }
            }
            
            exports['rsg-menu']:openMenu(statsMenu)
        end
    end)
end)

-- NUI Callbacks
RegisterNUICallback('payFare', function(data, cb)
    TriggerServerEvent('rsg-taxi:server:payFare', data.driverId, data.amount, data.tip, data.paymentMethod)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('submitRating', function(data, cb)
    TriggerServerEvent('rsg-taxi:server:submitRating', data.driverId, data.rating, data.comment)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Commands
RegisterCommand('taxi', function()
    if isTaxiDriver then
        OpenTaxiDriverMenu()
    else
        OpenPassengerMenu()
    end
end)

RegisterCommand('calltaxi', function()
    CallTaxi()
end)

RegisterCommand('taximeter', function()
    ToggleTaxiMeter()
end)