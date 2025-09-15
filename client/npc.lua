-- NPC Taxi System for RSG Taxi

local NPCTaxis = {}
local NPCDrivers = {}

-- NPC Driver Names
local DriverNames = {
    "William Thompson", "Arthur Morgan", "John Marston", "Dutch van der Linde",
    "Hosea Matthews", "Micah Bell", "Charles Smith", "Javier Escuella",
    "Bill Williamson", "Sean MacGuire", "Lenny Summers", "Kieran Duffy",
    "Uncle", "Reverend Swanson", "Leopold Strauss", "Simon Pearson",
    "Susan Grimshaw", "Tilly Jackson", "Mary-Beth Gaskill", "Karen Jones",
    "Abigail Roberts", "Jack Marston", "Sadie Adler", "Molly O'Shea"
}

-- Initialize NPC system
CreateThread(function()
    Wait(5000) -- Wait for everything to load
    
    if Config.NPCTaxis.Enabled then
        print('^2[RSG-TAXI]^7 NPC Taxi system initialized')
        
        -- Start NPC management thread
        CreateThread(NPCManagementThread)
        
        -- Start NPC behavior thread
        CreateThread(NPCBehaviorThread)
    end
end)

-- NPC Management Thread
function NPCManagementThread()
    while Config.NPCTaxis.Enabled do
        Wait(30000) -- Check every 30 seconds
        
        -- Clean up inactive NPCs
        CleanupInactiveNPCs()
        
        -- Spawn NPCs if needed
        CheckAndSpawnNPCs()
    end
end

-- NPC Behavior Thread
function NPCBehaviorThread()
    while Config.NPCTaxis.Enabled do
        Wait(1000)
        
        for npcId, npcData in pairs(NPCTaxis) do
            if DoesEntityExist(npcData.ped) and DoesEntityExist(npcData.vehicle) then
                UpdateNPCBehavior(npcId, npcData)
            else
                -- Clean up missing NPC
                CleanupNPC(npcId)
            end
        end
    end
end

-- Spawn NPC Taxi
function SpawnNPCTaxi(passengerId, pickupCoords, destination)
    print("^2[RSG-Taxi Debug]^7 SpawnNPCTaxi called with:")
    print("^2[RSG-Taxi Debug]^7 passengerId:", passengerId)
    print("^2[RSG-Taxi Debug]^7 pickupCoords:", type(pickupCoords), pickupCoords)
    print("^2[RSG-Taxi Debug]^7 destination:", type(destination), destination)
    
    if #NPCTaxis >= Config.NPCTaxis.MaxNPCTaxis then
        return false
    end
    
    -- Find suitable spawn location
    local spawnLocation = FindNPCSpawnLocation(pickupCoords)
    if not spawnLocation then
        return false
    end
    
    -- Choose random vehicle
    local vehicleModel = Config.TaxiVehicles[math.random(#Config.TaxiVehicles)]
    local vehicleHash = GetHashKey(vehicleModel)
    
    -- Request model
    RequestModel(vehicleHash)
    while not HasModelLoaded(vehicleHash) do
        Wait(10)
    end
    
    -- Spawn vehicle
    local vehicle = CreateVehicle(vehicleHash, spawnLocation.x, spawnLocation.y, spawnLocation.z, spawnLocation.w, true, false)
    
    if not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(vehicleHash)
        return false
    end
    
    -- Configure vehicle
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, false)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleFuelLevel(vehicle, 100.0)
    
    -- Generate plate
    local plate = GenerateNPCPlate()
    SetVehicleNumberPlateText(vehicle, plate)
    
    -- Spawn driver
    local driverModel = GetHashKey('A_M_M_UNIDUSTRIAL_01') -- Generic male model
    RequestModel(driverModel)
    while not HasModelLoaded(driverModel) do
        Wait(10)
    end
    
    local driver = CreatePedInsideVehicle(vehicle, 26, driverModel, -1, true, false)
    
    if not DoesEntityExist(driver) then
        DeleteEntity(vehicle)
        SetModelAsNoLongerNeeded(vehicleHash)
        SetModelAsNoLongerNeeded(driverModel)
        return false
    end
    
    -- Configure driver
    SetEntityAsMissionEntity(driver, true, true)
    SetPedRandomComponentVariation(driver, false)
    SetPedCanBeDraggedOut(driver, false)
    SetPedCanBeTargetted(driver, false)
    SetPedFleeAttributes(driver, 0, false)
    SetPedCombatAttributes(driver, 17, true)
    
    -- Create NPC data
    local npcId = 'npc_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
    local driverName = DriverNames[math.random(#DriverNames)]
    
    NPCTaxis[npcId] = {
        id = npcId,
        ped = driver,
        vehicle = vehicle,
        plate = plate,
        driverName = driverName,
        passenger = passengerId,
        pickupCoords = pickupCoords,
        destination = destination,
        status = 'going_to_pickup',
        spawnTime = GetGameTimer(),
        lastUpdate = GetGameTimer(),
        taskSequence = nil,
        blip = nil
    }
    
    -- Create blip for NPC taxi
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, spawnLocation.x, spawnLocation.y, spawnLocation.z)
    SetBlipSprite(blip, GetHashKey(Config.Blips.TaxiDriver.sprite), true)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, 'NPC Taxi - ' .. driverName)
    NPCTaxis[npcId].blip = blip
    
    -- Start driving to pickup
    DriveToLocation(npcId, pickupCoords)
    
    -- Notify passenger
    TriggerServerEvent('rsg-taxi:server:npcTaxiDispatched', passengerId, {
        npcId = npcId,
        driverName = driverName,
        vehicle = vehicleModel,
        plate = plate,
        eta = CalculateETA(spawnLocation, pickupCoords)
    })
    
    -- Clean up models
    SetModelAsNoLongerNeeded(vehicleHash)
    SetModelAsNoLongerNeeded(driverModel)
    
    return true
end

-- Update NPC Behavior
function UpdateNPCBehavior(npcId, npcData)
    local currentTime = GetGameTimer()
    
    -- Check if NPC should be despawned
    if currentTime - npcData.spawnTime > Config.NPCTaxis.DespawnTime then
        CleanupNPC(npcId)
        return
    end
    
    -- Update based on status
    if npcData.status == 'going_to_pickup' then
        HandleGoingToPickup(npcId, npcData)
    elseif npcData.status == 'waiting_for_passenger' then
        HandleWaitingForPassenger(npcId, npcData)
    elseif npcData.status == 'driving_to_destination' then
        HandleDrivingToDestination(npcId, npcData)
    elseif npcData.status == 'completed' then
        HandleRideCompleted(npcId, npcData)
    end
    
    npcData.lastUpdate = currentTime
end

-- Handle going to pickup
function HandleGoingToPickup(npcId, npcData)
    local vehicleCoords = GetEntityCoords(npcData.vehicle)
    
    -- Ensure pickupCoords is a vector3
    local pickupVec = npcData.pickupCoords
    if type(npcData.pickupCoords) == 'table' then
        pickupVec = vector3(npcData.pickupCoords.x or npcData.pickupCoords[1], 
                           npcData.pickupCoords.y or npcData.pickupCoords[2], 
                           npcData.pickupCoords.z or npcData.pickupCoords[3])
    end
    
    local distanceToPickup = #(vehicleCoords - pickupVec)
    
    if distanceToPickup < 10.0 then
        -- Arrived at pickup
        npcData.status = 'waiting_for_passenger'
        ClearPedTasks(npcData.ped)
        
        -- Notify passenger
        TriggerServerEvent('rsg-taxi:server:npcTaxiArrived', npcData.passenger, npcId)
        
        -- Start waiting timer
        npcData.waitStartTime = GetGameTimer()
    elseif GetGameTimer() - npcData.lastUpdate > 5000 then
        -- Check if still driving, if not, restart task
        if not IsPedInVehicle(npcData.ped, npcData.vehicle, false) then
            TaskWarpPedIntoVehicle(npcData.ped, npcData.vehicle, -1)
        end
        
        if not GetIsTaskActive(npcData.ped, 151) then -- TASK_VEHICLE_DRIVE_TO_COORD
            DriveToLocation(npcId, npcData.pickupCoords)
        end
    end
end

-- Handle waiting for passenger
function HandleWaitingForPassenger(npcId, npcData)
    local waitTime = GetGameTimer() - (npcData.waitStartTime or 0)
    
    if waitTime > 60000 then -- Wait 1 minute max
        -- Timeout, leave
        npcData.status = 'completed'
        TriggerServerEvent('rsg-taxi:server:npcTaxiTimeout', npcData.passenger, npcId)
    end
    
    -- Check if passenger entered vehicle
    local passengerPed = GetPlayerPed(GetPlayerFromServerId(npcData.passenger))
    if DoesEntityExist(passengerPed) and IsPedInVehicle(passengerPed, npcData.vehicle, false) then
        npcData.status = 'driving_to_destination'
        DriveToLocation(npcId, npcData.destination.coords)
        
        -- Start meter
        TriggerServerEvent('rsg-taxi:server:npcStartMeter', npcData.passenger, npcId)
    end
end

-- Handle driving to destination
function HandleDrivingToDestination(npcId, npcData)
    local vehicleCoords = GetEntityCoords(npcData.vehicle)
    
    -- Ensure destination coords is a vector3
    local destVec = npcData.destination.coords
    if type(npcData.destination.coords) == 'table' then
        destVec = vector3(npcData.destination.coords.x or npcData.destination.coords[1], 
                         npcData.destination.coords.y or npcData.destination.coords[2], 
                         npcData.destination.coords.z or npcData.destination.coords[3])
    end
    
    local distanceToDestination = #(vehicleCoords - destVec)
    
    if distanceToDestination < 15.0 then
        -- Arrived at destination
        npcData.status = 'completed'
        ClearPedTasks(npcData.ped)
        
        -- Stop meter and request payment
        TriggerServerEvent('rsg-taxi:server:npcStopMeter', npcData.passenger, npcId, vehicleCoords)
    elseif GetGameTimer() - npcData.lastUpdate > 5000 then
        -- Check if still driving
        if not GetIsTaskActive(npcData.ped, 151) then
            DriveToLocation(npcId, npcData.destination.coords)
        end
    end
end

-- Handle ride completed
function HandleRideCompleted(npcId, npcData)
    -- Wait a bit then despawn
    if GetGameTimer() - npcData.lastUpdate > 10000 then
        CleanupNPC(npcId)
    end
end

-- Drive to location
function DriveToLocation(npcId, coords)
    local npcData = NPCTaxis[npcId]
    if not npcData or not DoesEntityExist(npcData.ped) or not DoesEntityExist(npcData.vehicle) then
        return
    end
    
    -- Clear existing tasks
    ClearPedTasks(npcData.ped)
    
    -- Set driving style
    local drivingStyle = 786603 -- Normal driving with some urgency
    
    -- Drive to coordinates
    TaskVehicleDriveToCoord(npcData.ped, npcData.vehicle, coords.x, coords.y, coords.z, 15.0, 0, GetEntityModel(npcData.vehicle), drivingStyle, 10.0, -1)
end

-- Find NPC spawn location
function FindNPCSpawnLocation(pickupCoords)
    local spawnLocations = {}
    
    -- Debug: Print pickupCoords structure
    print("^2[RSG-Taxi Debug]^7 pickupCoords type:", type(pickupCoords))
    if type(pickupCoords) == 'table' then
        print("^2[RSG-Taxi Debug]^7 pickupCoords content:", json.encode(pickupCoords))
    end
    
    -- Convert pickupCoords to vector3 if it's a table
    local pickup = pickupCoords
    if type(pickupCoords) == 'table' then
        local x = pickupCoords.x or pickupCoords[1] or 0.0
        local y = pickupCoords.y or pickupCoords[2] or 0.0
        local z = pickupCoords.z or pickupCoords[3] or 0.0
        
        print("^2[RSG-Taxi Debug]^7 Extracted coords - x:", x, "y:", y, "z:", z)
        
        -- Ensure we have valid numbers
        if type(x) == 'number' and type(y) == 'number' and type(z) == 'number' then
            pickup = vector3(x, y, z)
        else
            print("^1[RSG-Taxi Error]^7 Invalid coordinate values - x:", type(x), "y:", type(y), "z:", type(z))
            return nil
        end
    end
    
    -- Add configured spawn locations
    for _, location in ipairs(Config.VehicleSpawnLocations) do
        local distance = #(pickup - vector3(location.coords.x, location.coords.y, location.coords.z))
        if distance > 100.0 and distance < 1000.0 then -- Not too close, not too far
            table.insert(spawnLocations, {
                x = location.coords.x,
                y = location.coords.y,
                z = location.coords.z,
                w = location.heading,
                distance = distance
            })
        end
    end
    
    -- Sort by distance
    table.sort(spawnLocations, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Return closest suitable location
    return spawnLocations[1]
end

-- Calculate ETA
function CalculateETA(from, to)
    -- Convert coordinates to vector3 if they're tables
    local fromVec = from
    local toVec = to
    
    if type(from) == 'table' then
        fromVec = vector3(from.x or from[1], from.y or from[2], from.z or from[3])
    end
    
    if type(to) == 'table' then
        toVec = vector3(to.x or to[1], to.y or to[2], to.z or to[3])
    end
    
    local distance = #(fromVec - toVec)
    local estimatedSpeed = 20.0 -- Average speed in units per second
    return math.ceil(distance / estimatedSpeed / 60) -- Return in minutes
end

-- Generate NPC plate
function GenerateNPCPlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = 'NPC'
    for i = 1, 5 do
        local rand = math.random(#chars)
        plate = plate .. string.sub(chars, rand, rand)
    end
    return plate
end

-- Cleanup NPC
function CleanupNPC(npcId)
    local npcData = NPCTaxis[npcId]
    if not npcData then return end
    
    -- Remove blip
    if npcData.blip then
        RemoveBlip(npcData.blip)
    end
    
    -- Delete entities
    if DoesEntityExist(npcData.ped) then
        DeleteEntity(npcData.ped)
    end
    
    if DoesEntityExist(npcData.vehicle) then
        DeleteEntity(npcData.vehicle)
    end
    
    -- Remove from table
    NPCTaxis[npcId] = nil
end

-- Cleanup inactive NPCs
function CleanupInactiveNPCs()
    local currentTime = GetGameTimer()
    local toRemove = {}
    
    for npcId, npcData in pairs(NPCTaxis) do
        -- Check if entities still exist
        if not DoesEntityExist(npcData.ped) or not DoesEntityExist(npcData.vehicle) then
            table.insert(toRemove, npcId)
        -- Check timeout
        elseif currentTime - npcData.spawnTime > Config.NPCTaxis.DespawnTime then
            table.insert(toRemove, npcId)
        end
    end
    
    for _, npcId in ipairs(toRemove) do
        CleanupNPC(npcId)
    end
end

-- Check and spawn NPCs if needed
function CheckAndSpawnNPCs()
    -- This would be called by server when needed
    -- For now, just maintain existing NPCs
end

-- Server Events
RegisterNetEvent('rsg-taxi:client:spawnNPCTaxi', function(passengerId, pickupCoords, destination)
    SpawnNPCTaxi(passengerId, pickupCoords, destination)
end)

RegisterNetEvent('rsg-taxi:client:despawnNPCTaxi', function(npcId)
    CleanupNPC(npcId)
end)

-- Exports
exports('SpawnNPCTaxi', SpawnNPCTaxi)
exports('CleanupNPC', CleanupNPC)
exports('GetNPCTaxis', function()
    return NPCTaxis
end)