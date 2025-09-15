-- Database Management for RSG Taxi System

-- Create database tables
RegisterNetEvent('rsg-taxi:server:createTables', function()
    -- Taxi drivers table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `taxi_drivers` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `player_name` varchar(100) NOT NULL,
            `total_rides` int(11) DEFAULT 0,
            `total_earnings` decimal(10,2) DEFAULT 0.00,
            `rating` decimal(3,2) DEFAULT 5.00,
            `total_rating_count` int(11) DEFAULT 0,
            `status` varchar(20) DEFAULT 'offline',
            `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    -- Taxi rides table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `taxi_rides` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `ride_id` varchar(50) NOT NULL,
            `driver_citizenid` varchar(50) NOT NULL,
            `passenger_citizenid` varchar(50) NOT NULL,
            `pickup_coords` text NOT NULL,
            `destination_coords` text NOT NULL,
            `destination_name` varchar(100) DEFAULT NULL,
            `distance` decimal(10,2) DEFAULT 0.00,
            `duration` int(11) DEFAULT 0,
            `fare` decimal(10,2) DEFAULT 0.00,
            `tip` decimal(10,2) DEFAULT 0.00,
            `payment_method` varchar(20) DEFAULT 'cash',
            `status` varchar(20) DEFAULT 'completed',
            `start_time` timestamp NULL DEFAULT NULL,
            `end_time` timestamp NULL DEFAULT NULL,
            `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `ride_id` (`ride_id`),
            KEY `driver_citizenid` (`driver_citizenid`),
            KEY `passenger_citizenid` (`passenger_citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    -- Taxi ratings table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `taxi_ratings` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `ride_id` varchar(50) NOT NULL,
            `driver_citizenid` varchar(50) NOT NULL,
            `passenger_citizenid` varchar(50) NOT NULL,
            `rating` int(1) NOT NULL,
            `comment` text DEFAULT NULL,
            `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `ride_id` (`ride_id`),
            KEY `driver_citizenid` (`driver_citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    -- Taxi vehicles table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `taxi_vehicles` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `plate` varchar(10) NOT NULL,
            `model` varchar(50) NOT NULL,
            `driver_citizenid` varchar(50) NOT NULL,
            `spawn_coords` text NOT NULL,
            `status` varchar(20) DEFAULT 'active',
            `fuel` decimal(5,2) DEFAULT 100.00,
            `engine_health` decimal(8,2) DEFAULT 1000.00,
            `body_health` decimal(8,2) DEFAULT 1000.00,
            `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `plate` (`plate`),
            KEY `driver_citizenid` (`driver_citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    print('^2[RSG-TAXI]^7 Database tables created successfully')
end)

-- Load player taxi data
function LoadPlayerTaxiData(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.query('SELECT * FROM taxi_drivers WHERE citizenid = ?', {citizenid}, function(result)
        if result and result[1] then
            local data = result[1]
            TriggerClientEvent('rsg-taxi:client:loadPlayerData', src, {
                totalRides = data.total_rides,
                totalEarnings = data.total_earnings,
                rating = data.rating,
                ratingCount = data.total_rating_count
            })
        else
            -- Create new driver record
            MySQL.insert('INSERT INTO taxi_drivers (citizenid, player_name) VALUES (?, ?)', {
                citizenid,
                Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
            })
        end
    end)
end

-- Save driver data
function SaveDriverData(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not TaxiDrivers[src] then return end
    
    local citizenid = Player.PlayerData.citizenid
    local driver = TaxiDrivers[src]
    
    MySQL.update([[
        UPDATE taxi_drivers 
        SET player_name = ?, total_rides = ?, total_earnings = ?, rating = ?, status = ?, updated_at = NOW()
        WHERE citizenid = ?
    ]], {
        driver.playerName,
        driver.totalRides,
        driver.totalEarnings,
        driver.rating,
        driver.status,
        citizenid
    })
end

-- Save ride data
function SaveRideData(ride)
    local Driver = RSGCore.Functions.GetPlayer(ride.driver)
    local Passenger = RSGCore.Functions.GetPlayer(ride.passenger)
    
    if not Driver or not Passenger then return end
    
    MySQL.insert([[
        INSERT INTO taxi_rides 
        (ride_id, driver_citizenid, passenger_citizenid, pickup_coords, destination_coords, 
         destination_name, distance, duration, fare, tip, payment_method, status, start_time, end_time)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?))
    ]], {
        ride.id,
        Driver.PlayerData.citizenid,
        Passenger.PlayerData.citizenid,
        json.encode(ride.pickupCoords),
        json.encode(ride.destination.coords),
        ride.destination.name,
        ride.distance,
        ride.duration,
        ride.fare,
        ride.tip or 0,
        ride.paymentMethod,
        ride.status,
        ride.startTime,
        ride.endTime
    })
end

-- Save rating data
function SaveRatingData(passengerId, driverId, rating, comment)
    local Driver = RSGCore.Functions.GetPlayer(driverId)
    local Passenger = RSGCore.Functions.GetPlayer(passengerId)
    
    if not Driver or not Passenger then return end
    
    -- Find the most recent ride between these players
    MySQL.query([[
        SELECT ride_id FROM taxi_rides 
        WHERE driver_citizenid = ? AND passenger_citizenid = ? 
        ORDER BY created_at DESC LIMIT 1
    ]], {
        Driver.PlayerData.citizenid,
        Passenger.PlayerData.citizenid
    }, function(result)
        if result and result[1] then
            MySQL.insert([[
                INSERT INTO taxi_ratings (ride_id, driver_citizenid, passenger_citizenid, rating, comment)
                VALUES (?, ?, ?, ?, ?)
            ]], {
                result[1].ride_id,
                Driver.PlayerData.citizenid,
                Passenger.PlayerData.citizenid,
                rating,
                comment
            })
            
            -- Update driver's average rating
            UpdateDriverRating(Driver.PlayerData.citizenid)
        end
    end)
end

-- Update driver rating
function UpdateDriverRating(citizenid)
    MySQL.query([[
        SELECT AVG(rating) as avg_rating, COUNT(*) as rating_count 
        FROM taxi_ratings 
        WHERE driver_citizenid = ?
    ]], {citizenid}, function(result)
        if result and result[1] then
            MySQL.update([[
                UPDATE taxi_drivers 
                SET rating = ?, total_rating_count = ?, updated_at = NOW()
                WHERE citizenid = ?
            ]], {
                result[1].avg_rating or 5.0,
                result[1].rating_count or 0,
                citizenid
            })
        end
    end)
end

-- Save vehicle data
function SaveVehicleData(plate, model, driverCitizenid, coords)
    MySQL.insert([[
        INSERT INTO taxi_vehicles (plate, model, driver_citizenid, spawn_coords)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        driver_citizenid = VALUES(driver_citizenid),
        spawn_coords = VALUES(spawn_coords),
        updated_at = NOW()
    ]], {
        plate,
        model,
        driverCitizenid,
        json.encode(coords)
    })
end

-- Get driver statistics
RSGCore.Functions.CreateCallback('rsg-taxi:server:getDriverStats', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
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

-- Clean up old data
CreateThread(function()
    while true do
        Wait(86400000) -- 24 hours
        
        -- Clean up old rides (older than 30 days)
        MySQL.query([[
            DELETE FROM taxi_rides 
            WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
        ]])
        
        -- Clean up old ratings (older than 30 days)
        MySQL.query([[
            DELETE FROM taxi_ratings 
            WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
        ]])
        
        -- Clean up inactive vehicles (older than 7 days)
        MySQL.query([[
            DELETE FROM taxi_vehicles 
            WHERE updated_at < DATE_SUB(NOW(), INTERVAL 7 DAY) AND status = 'inactive'
        ]])
        
        print('^2[RSG-TAXI]^7 Database cleanup completed')
    end
end)

-- Export functions
exports('LoadPlayerTaxiData', LoadPlayerTaxiData)
exports('SaveDriverData', SaveDriverData)
exports('SaveRideData', SaveRideData)
exports('SaveRatingData', SaveRatingData)
exports('SaveVehicleData', SaveVehicleData)