-- UI Management for RSG Taxi System

local uiOpen = false
local currentUIType = nil

-- Initialize UI
CreateThread(function()
    Wait(1000)
    
    -- Send config to UI
    SendNUIMessage({
        type = 'init',
        config = {
            locale = Config.Locale,
            currency = '$',
            paymentMethods = {'cash', 'bank'},
            ratingSystem = Config.RatingSystem
        }
    })
end)

-- Open taxi meter UI
function OpenTaxiMeterUI()
    if uiOpen then return end
    
    uiOpen = true
    currentUIType = 'meter'
    
    SendNUIMessage({
        type = 'showMeter',
        data = {
            fare = taxiMeter.fare or 0,
            distance = taxiMeter.distance or 0,
            time = taxiMeter.active and (GetGameTimer() - taxiMeter.startTime) / 1000 or 0,
            active = taxiMeter.active or false
        }
    })
    
    SetNuiFocus(false, false) -- Meter doesn't need focus
end

-- Close taxi meter UI
function CloseTaxiMeterUI()
    if currentUIType ~= 'meter' then return end
    
    uiOpen = false
    currentUIType = nil
    
    SendNUIMessage({
        type = 'hideMeter'
    })
end

-- Open payment UI
function OpenPaymentUI(paymentData)
    if uiOpen then return end
    
    uiOpen = true
    currentUIType = 'payment'
    
    SendNUIMessage({
        type = 'showPayment',
        data = paymentData
    })
    
    SetNuiFocus(true, true)
end

-- Close payment UI
function ClosePaymentUI()
    if currentUIType ~= 'payment' then return end
    
    uiOpen = false
    currentUIType = nil
    
    SendNUIMessage({
        type = 'hidePayment'
    })
    
    SetNuiFocus(false, false)
end

-- Open rating UI
function OpenRatingUI(driverId)
    if uiOpen then return end
    
    uiOpen = true
    currentUIType = 'rating'
    
    SendNUIMessage({
        type = 'showRating',
        data = {
            driverId = driverId,
            timeout = Config.RatingSystem.RatingTimeout
        }
    })
    
    SetNuiFocus(true, true)
end

-- Close rating UI
function CloseRatingUI()
    if currentUIType ~= 'rating' then return end
    
    uiOpen = false
    currentUIType = nil
    
    SendNUIMessage({
        type = 'hideRating'
    })
    
    SetNuiFocus(false, false)
end

-- Open driver dashboard
function OpenDriverDashboard()
    if uiOpen then return end
    
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:getDriverStats', function(stats)
        RSGCore.Functions.TriggerCallback('rsg-taxi:server:getTodayEarnings', function(todayEarnings)
            RSGCore.Functions.TriggerCallback('rsg-taxi:server:getWeeklyStats', function(weeklyStats)
                uiOpen = true
                currentUIType = 'dashboard'
                
                SendNUIMessage({
                    type = 'showDashboard',
                    data = {
                        stats = stats,
                        todayEarnings = todayEarnings,
                        weeklyStats = weeklyStats,
                        currentRide = currentRide,
                        meterActive = taxiMeter.active
                    }
                })
                
                SetNuiFocus(true, true)
            end)
        end)
    end)
end

-- Close driver dashboard
function CloseDriverDashboard()
    if currentUIType ~= 'dashboard' then return end
    
    uiOpen = false
    currentUIType = nil
    
    SendNUIMessage({
        type = 'hideDashboard'
    })
    
    SetNuiFocus(false, false)
end

-- Open ride history UI
function OpenRideHistoryUI()
    if uiOpen then return end
    
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:getRideHistory', function(rideHistory)
        uiOpen = true
        currentUIType = 'history'
        
        SendNUIMessage({
            type = 'showHistory',
            data = {
                rides = rideHistory
            }
        })
        
        SetNuiFocus(true, true)
    end)
end

-- Close ride history UI
function CloseRideHistoryUI()
    if currentUIType ~= 'history' then return end
    
    uiOpen = false
    currentUIType = nil
    
    SendNUIMessage({
        type = 'hideHistory'
    })
    
    SetNuiFocus(false, false)
end

-- Open taxi request UI
function OpenTaxiRequestUI()
    if uiOpen then return end
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:getPickupLocations', function(locations)
        RSGCore.Functions.TriggerCallback('rsg-taxi:server:getAvailableDrivers', function(drivers, coords)
            uiOpen = true
            currentUIType = 'request'
            
            SendNUIMessage({
                type = 'showRequest',
                data = {
                    locations = locations,
                    drivers = drivers,
                    playerCoords = playerCoords
                }
            })
            
            SetNuiFocus(true, true)
        end, playerCoords)
    end)
end

-- Close taxi request UI
function CloseTaxiRequestUI()
    if currentUIType ~= 'request' then return end
    
    uiOpen = false
    currentUIType = nil
    
    SendNUIMessage({
        type = 'hideRequest'
    })
    
    SetNuiFocus(false, false)
end

-- Update meter display
function UpdateMeterDisplay(fare, distance, time)
    if currentUIType == 'meter' or currentUIType == 'dashboard' then
        SendNUIMessage({
            type = 'updateMeter',
            data = {
                fare = fare,
                distance = distance,
                time = time,
                active = taxiMeter.active
            }
        })
    end
end

-- Show notification in UI
function ShowUINotification(message, type, duration)
    SendNUIMessage({
        type = 'showNotification',
        data = {
            message = message,
            type = type or 'info',
            duration = duration or 5000
        }
    })
end

-- Update ride status in UI
function UpdateRideStatus(status, data)
    SendNUIMessage({
        type = 'updateRideStatus',
        data = {
            status = status,
            rideData = data
        }
    })
end

-- NUI Callbacks
RegisterNUICallback('payFare', function(data, cb)
    TriggerServerEvent('rsg-taxi:server:payFare', data.driverId, data.amount, data.tip, data.paymentMethod)
    ClosePaymentUI()
    cb('ok')
end)

RegisterNUICallback('submitRating', function(data, cb)
    TriggerServerEvent('rsg-taxi:server:submitRating', data.driverId, data.rating, data.comment)
    CloseRatingUI()
    cb('ok')
end)

RegisterNUICallback('requestTaxi', function(data, cb)
    TriggerServerEvent('rsg-taxi:server:requestRide', data.pickup, data.destination)
    CloseTaxiRequestUI()
    cb('ok')
end)

RegisterNUICallback('cancelRide', function(data, cb)
    TriggerServerEvent('rsg-taxi:server:cancelRide')
    cb('ok')
end)

RegisterNUICallback('toggleMeter', function(data, cb)
    ToggleTaxiMeter()
    cb('ok')
end)

RegisterNUICallback('startWork', function(data, cb)
    StartTaxiWork()
    cb('ok')
end)

RegisterNUICallback('stopWork', function(data, cb)
    StopTaxiWork()
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    SpawnTaxiVehicle()
    cb('ok')
end)

RegisterNUICallback('returnVehicle', function(data, cb)
    ReturnTaxiVehicle()
    cb('ok')
end)

RegisterNUICallback('closeUI', function(data, cb)
    if currentUIType == 'payment' then
        ClosePaymentUI()
    elseif currentUIType == 'rating' then
        CloseRatingUI()
    elseif currentUIType == 'dashboard' then
        CloseDriverDashboard()
    elseif currentUIType == 'history' then
        CloseRideHistoryUI()
    elseif currentUIType == 'request' then
        CloseTaxiRequestUI()
    end
    cb('ok')
end)

RegisterNUICallback('calculateFare', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:calculateFareEstimate', function(fareData)
        cb(fareData)
    end, data.pickup, data.destination)
end)

RegisterNUICallback('getDriverStats', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:getDriverStats', function(stats)
        cb(stats)
    end)
end)

RegisterNUICallback('getRideHistory', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:getRideHistory', function(history)
        cb(history)
    end, data.limit)
end)

RegisterNUICallback('getAvailableDrivers', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-taxi:server:getAvailableDrivers', function(drivers)
        cb(drivers)
    end, data.coords)
end)

-- Events
RegisterNetEvent('rsg-taxi:client:openMeter', function()
    OpenTaxiMeterUI()
end)

RegisterNetEvent('rsg-taxi:client:closeMeter', function()
    CloseTaxiMeterUI()
end)

RegisterNetEvent('rsg-taxi:client:openPayment', function(paymentData)
    OpenPaymentUI(paymentData)
end)

RegisterNetEvent('rsg-taxi:client:openRating', function(driverId)
    OpenRatingUI(driverId)
end)

RegisterNetEvent('rsg-taxi:client:openDashboard', function()
    OpenDriverDashboard()
end)

RegisterNetEvent('rsg-taxi:client:openHistory', function()
    OpenRideHistoryUI()
end)

RegisterNetEvent('rsg-taxi:client:openRequest', function()
    OpenTaxiRequestUI()
end)

RegisterNetEvent('rsg-taxi:client:updateMeter', function(fare, distance, time)
    UpdateMeterDisplay(fare, distance, time)
end)

RegisterNetEvent('rsg-taxi:client:showUINotification', function(message, type, duration)
    ShowUINotification(message, type, duration)
end)

RegisterNetEvent('rsg-taxi:client:updateRideStatus', function(status, data)
    UpdateRideStatus(status, data)
end)

-- Key bindings (RedM compatible)
-- Use /taxi command to open taxi menu
-- Use /taximeter command to toggle taxi meter

-- Commands
RegisterCommand('taxi', function()
    TriggerEvent('rsg-taxi:client:openMenu')
end, false)

RegisterCommand('taximeter', function()
    if isTaxiDriver and isOnDuty then
        TriggerEvent('rsg-taxi:client:toggleMeter')
    end
end, false)

RegisterCommand('taxidashboard', function()
    if isTaxiDriver and isOnDuty then
        OpenDriverDashboard()
    end
end)

RegisterCommand('taxihistory', function()
    OpenRideHistoryUI()
end)

-- Exports
exports('OpenTaxiMeterUI', OpenTaxiMeterUI)
exports('CloseTaxiMeterUI', CloseTaxiMeterUI)
exports('OpenPaymentUI', OpenPaymentUI)
exports('ClosePaymentUI', ClosePaymentUI)
exports('OpenRatingUI', OpenRatingUI)
exports('CloseRatingUI', CloseRatingUI)
exports('OpenDriverDashboard', OpenDriverDashboard)
exports('CloseDriverDashboard', CloseDriverDashboard)
exports('UpdateMeterDisplay', UpdateMeterDisplay)
exports('ShowUINotification', ShowUINotification)
exports('IsUIOpen', function() return uiOpen end)
exports('GetCurrentUIType', function() return currentUIType end)