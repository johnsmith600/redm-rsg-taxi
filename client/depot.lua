local RSGCore = exports['rsg-core']:GetCoreObject()

-- Local Variables
local depotBlips = {}
local requestBlips = {}
local nearbyDepot = nil
local nearbyRequest = nil

-- Initialize depot system
CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            CreateDepotBlips()
            CreateRequestBlips()
            break
        end
        Wait(1000)
    end
end)

-- Create blips for taxi depots
function CreateDepotBlips()
    for i, depot in ipairs(Config.TaxiDepots) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, depot.coords.x, depot.coords.y, depot.coords.z)
        SetBlipSprite(blip, GetHashKey(Config.Blips.TaxiDepot.sprite), true)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, depot.name)
        depotBlips[i] = blip
    end
end

-- Create blips for taxi request locations
function CreateRequestBlips()
    for i, location in ipairs(Config.TaxiRequestLocations) do
        if location.blip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, location.coords.x, location.coords.y, location.coords.z)
            SetBlipSprite(blip, GetHashKey(Config.Blips.TaxiRequest.sprite), true)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, location.name)
            requestBlips[i] = blip
        end
    end
end

-- Main depot interaction loop
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- Check for nearby depot
        nearbyDepot = nil
        for _, depot in ipairs(Config.TaxiDepots) do
            local distance = #(playerCoords - depot.coords)
            if distance < 3.0 then
                nearbyDepot = depot
                sleep = 0
                break
            end
        end
        
        -- Check for nearby taxi request location
        nearbyRequest = nil
        for _, location in ipairs(Config.TaxiRequestLocations) do
            local distance = #(playerCoords - location.coords)
            if distance < 3.0 then
                nearbyRequest = location
                sleep = 0
                break
            end
        end
        
        Wait(sleep)
    end
end)

-- Draw text and handle interactions
CreateThread(function()
    while true do
        local sleep = 1000
        
        if nearbyDepot then
            sleep = 0
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            if vehicle == 0 then
                -- Player is on foot - show get vehicle option
                RSGCore.Functions.DrawText3D(nearbyDepot.coords.x, nearbyDepot.coords.y, nearbyDepot.coords.z + 1.0, 
                    '[E] ' .. Lang:t('ui.get_taxi_vehicle'))
                
                if IsControlJustPressed(0, 0x760A9C6F) then -- E key
                    OpenDepotMenu(nearbyDepot)
                end
            else
                -- Player is in vehicle - check if it's a taxi
                local vehicleModel = GetEntityModel(vehicle)
                local isTaxiVehicle = false
                
                for _, taxiModel in ipairs(Config.TaxiVehicles) do
                    if GetHashKey(taxiModel) == vehicleModel then
                        isTaxiVehicle = true
                        break
                    end
                end
                
                if isTaxiVehicle then
                    RSGCore.Functions.DrawText3D(nearbyDepot.coords.x, nearbyDepot.coords.y, nearbyDepot.coords.z + 1.0, 
                        '[E] ' .. Lang:t('ui.return_taxi_vehicle'))
                    
                    if IsControlJustPressed(0, 0x760A9C6F) then -- E key
                        ReturnTaxiVehicleToDepot(vehicle)
                    end
                end
            end
        end
        
        if nearbyRequest then
            sleep = 0
            RSGCore.Functions.DrawText3D(nearbyRequest.coords.x, nearbyRequest.coords.y, nearbyRequest.coords.z + 1.0, 
                '[E] ' .. Lang:t('ui.call_taxi'))
            
            if IsControlJustPressed(0, 0x760A9C6F) then -- E key
                OpenTaxiRequestMenu(nearbyRequest)
            end
        end
        
        Wait(sleep)
    end
end)

-- Open depot menu for getting vehicles
function OpenDepotMenu(depot)
    local vehicleMenu = {
        {
            header = depot.name,
            isMenuHeader = true
        },
        {
            header = Lang:t('ui.available_vehicles'),
            txt = Lang:t('ui.select_taxi_vehicle'),
            isMenuHeader = true
        }
    }
    
    -- Add vehicle options
    for _, vehicle in ipairs(Config.TaxiVehicles) do
        table.insert(vehicleMenu, {
            header = GetVehicleDisplayName(vehicle),
            txt = Lang:t('ui.vehicle_model') .. ': ' .. vehicle,
            params = {
                event = 'rsg-taxi:client:spawnDepotVehicle',
                args = {
                    model = vehicle,
                    depot = depot
                }
            }
        })
    end
    
    -- Add close option
    table.insert(vehicleMenu, {
        header = Lang:t('ui.close'),
        params = {
            event = 'rsg-menu:closeMenu'
        }
    })
    
    exports['rsg-menu']:openMenu(vehicleMenu)
end

-- Open taxi request menu
function OpenTaxiRequestMenu(location)
    -- Check if there are any active taxi drivers
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:getActiveTaxiDrivers', function(drivers)
        local requestMenu = {
            {
                header = Lang:t('ui.taxi_service'),
                isMenuHeader = true
            },
            {
                header = location.name,
                txt = Lang:t('ui.request_taxi_from_location'),
                isMenuHeader = true
            }
        }
        
        if #drivers > 0 then
            -- Player drivers available
            table.insert(requestMenu, {
                header = Lang:t('ui.request_player_taxi'),
                txt = Lang:t('ui.player_drivers_available', {count = #drivers}),
                params = {
                    event = 'rsg-taxi:client:requestPlayerTaxi',
                    args = {
                        pickup = location
                    }
                }
            })
        end
        
        -- Always show NPC taxi option
        table.insert(requestMenu, {
            header = Lang:t('ui.request_npc_taxi'),
            txt = Lang:t('ui.npc_taxi_description'),
            params = {
                event = 'rsg-taxi:client:requestNPCTaxi',
                args = {
                    pickup = location
                }
            }
        })
        
        -- Add close option
        table.insert(requestMenu, {
            header = Lang:t('ui.close'),
            params = {
                event = 'rsg-menu:closeMenu'
            }
        })
        
        exports['rsg-menu']:openMenu(requestMenu)
    end)
end

-- Spawn vehicle from depot
RegisterNetEvent('rsg-taxi:client:spawnDepotVehicle', function(data)
    local model = data.model
    local depot = data.depot
    
    -- Check if player already has a taxi vehicle
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:hasActiveTaxiVehicle', function(hasVehicle)
        if hasVehicle then
            TriggerEvent('RSGCore:Notify', Lang:t('error.already_have_taxi_vehicle'), 'error')
            return
        end
        
        -- Find a clear spawn location near the depot
        local spawnCoords = GetClearSpawnLocation(depot.coords, depot.heading)
        if not spawnCoords then
            TriggerEvent('RSGCore:Notify', Lang:t('error.no_clear_spawn_location'), 'error')
            return
        end
        
        -- Request vehicle spawn
        TriggerServerEvent('rsg-taxi:server:spawnDepotVehicle', model, spawnCoords, depot.heading)
    end)
end)

-- Return vehicle to depot
function ReturnTaxiVehicleToDepot(vehicle)
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:canReturnVehicle', function(canReturn, reason)
        if not canReturn then
            TriggerEvent('RSGCore:Notify', reason, 'error')
            return
        end
        
        -- Return the vehicle
        TriggerServerEvent('rsg-taxi:server:returnVehicleToDepot', VehToNet(vehicle))
        
        -- Delete the vehicle locally
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
        
        TriggerEvent('RSGCore:Notify', Lang:t('success.vehicle_returned_to_depot'), 'success')
    end, VehToNet(vehicle))
end

-- Find clear spawn location near depot
function GetClearSpawnLocation(coords, heading)
    local attempts = 0
    local maxAttempts = 10
    local spawnRadius = 5.0
    
    while attempts < maxAttempts do
        local offsetX = math.random(-spawnRadius, spawnRadius)
        local offsetY = math.random(-spawnRadius, spawnRadius)
        local testCoords = vector3(coords.x + offsetX, coords.y + offsetY, coords.z)
        
        -- Check if location is clear
        if IsAreaClear(testCoords, 3.0, true, false, false, false, false) then
            return testCoords
        end
        
        attempts = attempts + 1
    end
    
    return nil
end

-- Request player taxi
RegisterNetEvent('rsg-taxi:client:requestPlayerTaxi', function(data)
    local pickup = data.pickup
    
    -- Show destination selection
    local destinationMenu = {
        {
            header = Lang:t('ui.select_destination'),
            isMenuHeader = true
        }
    }
    
    -- Add destination options
    for _, location in ipairs(Config.TaxiRequestLocations) do
        if location.coords ~= pickup.coords then
            table.insert(destinationMenu, {
                header = location.name,
                txt = Lang:t('ui.travel_to_location'),
                params = {
                    event = 'rsg-taxi:client:confirmPlayerTaxiRequest',
                    args = {
                        pickup = pickup,
                        destination = location
                    }
                }
            })
        end
    end
    
    exports['rsg-menu']:openMenu(destinationMenu)
end)

-- Confirm player taxi request
RegisterNetEvent('rsg-taxi:client:confirmPlayerTaxiRequest', function(data)
    TriggerServerEvent('rsg-taxi:server:requestPlayerTaxi', data.pickup, data.destination)
    TriggerEvent('RSGCore:Notify', Lang:t('info.taxi_request_sent'), 'primary')
end)

-- Request NPC taxi
RegisterNetEvent('rsg-taxi:client:requestNPCTaxi', function(data)
    local pickup = data.pickup
    
    -- Show destination selection for NPC taxi
    local destinationMenu = {
        {
            header = Lang:t('ui.select_destination'),
            isMenuHeader = true
        }
    }
    
    -- Add destination options
    for _, location in ipairs(Config.TaxiRequestLocations) do
        if location.coords ~= pickup.coords then
            table.insert(destinationMenu, {
                header = location.name,
                txt = Lang:t('ui.travel_to_location'),
                params = {
                    event = 'rsg-taxi:client:confirmNPCTaxiRequest',
                    args = {
                        pickup = pickup,
                        destination = location
                    }
                }
            })
        end
    end
    
    exports['rsg-menu']:openMenu(destinationMenu)
end)

-- Confirm NPC taxi request
RegisterNetEvent('rsg-taxi:client:confirmNPCTaxiRequest', function(data)
    TriggerServerEvent('rsg-taxi:server:requestNPCTaxi', data.pickup, data.destination)
    TriggerEvent('RSGCore:Notify', Lang:t('info.npc_taxi_called'), 'primary')
end)

-- Vehicle spawned from depot
RegisterNetEvent('rsg-taxi:client:vehicleSpawnedFromDepot', function(netId)
    local vehicle = NetToVeh(netId)
    if DoesEntityExist(vehicle) then
        -- Set player as driver
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        TriggerEvent('RSGCore:Notify', Lang:t('success.taxi_vehicle_ready'), 'success')
        
        -- Show instructions
        TriggerEvent('RSGCore:Notify', Lang:t('info.taxi_driver_instructions'), 'primary')
    end
end)