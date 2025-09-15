Config = {}

-- General Settings
Config.Debug = false
Config.UseTarget = true -- Use rsg-target for interactions
Config.Locale = 'en'

-- Taxi Job Settings (DEPRECATED - Anyone can be a taxi driver now)
Config.TaxiJob = 'taxi' -- Not used anymore - kept for compatibility
Config.MinimumTaxiDrivers = 0 -- Minimum online taxi drivers before NPCs spawn
Config.MaxTaxiDrivers = 50 -- Maximum taxi drivers allowed online (increased since anyone can drive)

-- Vehicle Settings
Config.TaxiVehicles = {
    'buggy01', -- Horse-drawn buggy
    'cart01',  -- Simple cart
    'wagon02', -- Covered wagon
    'coach2',  -- Stagecoach
}

-- Taxi Depot Locations (where players get vehicles)
Config.TaxiDepots = {
    {
        name = 'Valentine Taxi Depot',
        coords = vector3(-1807.15, -433.42, 158.83),
        heading = 90.0,
        blip = {
            sprite = 'blip_stable',
            color = 'YELLOW'
        }
    },
    {
        name = 'Annesburg Taxi Depot',
        coords = vector3(2930.95, 1348.75, 44.1),
        heading = 180.0,
        blip = {
            sprite = 'blip_stable',
            color = 'YELLOW'
        }
    },
    {
        name = 'Blackwater Taxi Depot',
        coords = vector3(-3664.0, -2628.0, -14.0),
        heading = 270.0,
        blip = {
            sprite = 'blip_stable',
            color = 'YELLOW'
        }
    },
    {
        name = 'Rhodes Taxi Depot',
        coords = vector3(1346.0, -1312.0, 77.0),
        heading = 0.0,
        blip = {
            sprite = 'blip_stable',
            color = 'YELLOW'
        }
    },
    {
        name = 'Strawberry Taxi Depot',
        coords = vector3(-802.0, -1324.0, 43.0),
        heading = 45.0,
        blip = {
            sprite = 'blip_stable',
            color = 'YELLOW'
        }
    }
}

-- Legacy vehicle spawn locations (kept for compatibility)
Config.VehicleSpawnLocations = {
    {coords = vector3(-1807.15, -433.42, 158.83), heading = 90.0}, -- Valentine
    {coords = vector3(2930.95, 1348.75, 44.1), heading = 180.0},   -- Annesburg
    {coords = vector3(-3664.0, -2628.0, -14.0), heading = 270.0},  -- Blackwater
    {coords = vector3(1346.0, -1312.0, 77.0), heading = 0.0},      -- Rhodes
    {coords = vector3(-802.0, -1324.0, 43.0), heading = 45.0},     -- Strawberry
}

-- Fare System
Config.FareSystem = {
    BaseFare = 2.0,           -- Base fare in dollars
    PerMeterRate = 0.05,      -- Rate per meter traveled
    WaitingRate = 0.10,       -- Rate per second while waiting
    NightMultiplier = 1.5,    -- Multiplier for night time (8PM - 6AM)
    WeatherMultiplier = 1.25, -- Multiplier for bad weather
    MinimumFare = 1.0,        -- Minimum fare amount
    MaximumFare = 50.0,       -- Maximum fare amount
}

-- NPC Taxi Settings
Config.NPCTaxis = {
    Enabled = true,
    SpawnChance = 0.3,        -- Chance to spawn NPC taxi when needed
    MaxNPCTaxis = 5,          -- Maximum NPC taxis at once
    DespawnTime = 300000,     -- Time in ms before NPC taxi despawns (5 minutes)
    ResponseTime = {15, 45},  -- Random response time in seconds [min, max]
}

-- Taxi Stands/Stations
Config.TaxiStands = {
    {
        name = "Valentine Taxi Stand",
        coords = vector3(-1807.15, -433.42, 158.83),
        radius = 3.0,
        blip = true,
        jobs = {'taxi', 'unemployed'}
    },
    {
        name = "Saint Denis Taxi Stand",
        coords = vector3(2930.95, 1348.75, 44.1),
        radius = 3.0,
        blip = true,
        jobs = {'taxi', 'unemployed'}
    },
    {
        name = "Blackwater Taxi Stand",
        coords = vector3(-3664.0, -2628.0, -14.0),
        radius = 3.0,
        blip = true,
        jobs = {'taxi', 'unemployed'}
    },
    {
        name = "Rhodes Taxi Stand",
        coords = vector3(1346.0, -1312.0, 77.0),
        radius = 3.0,
        blip = true,
        jobs = {'taxi', 'unemployed'}
    },
    {
        name = "Strawberry Taxi Stand",
        coords = vector3(-802.0, -1324.0, 43.0),
        radius = 3.0,
        blip = true,
        jobs = {'taxi', 'unemployed'}
    }
}

-- Passenger Pickup Locations
Config.PickupLocations = {
    -- Valentine Area
    {coords = vector3(-1798.0, -374.0, 158.0), name = "Valentine General Store"},
    {coords = vector3(-1786.0, -387.0, 160.0), name = "Valentine Saloon"},
    {coords = vector3(-1823.0, -354.0, 164.0), name = "Valentine Bank"},
    
    -- Saint Denis Area
    {coords = vector3(2644.0, -1293.0, 52.0), name = "Saint Denis Market"},
    {coords = vector3(2632.0, -1226.0, 53.0), name = "Saint Denis Saloon"},
    {coords = vector3(2644.0, -1282.0, 52.0), name = "Saint Denis Bank"},
    
    -- Blackwater Area
    {coords = vector3(-3700.0, -2599.0, -13.0), name = "Blackwater General Store"},
    {coords = vector3(-3708.0, -2617.0, -13.0), name = "Blackwater Saloon"},
    {coords = vector3(-3664.0, -2628.0, -14.0), name = "Blackwater Bank"},
    
    -- Rhodes Area
    {coords = vector3(1329.0, -1293.0, 77.0), name = "Rhodes General Store"},
    {coords = vector3(1341.0, -1317.0, 77.0), name = "Rhodes Saloon"},
    {coords = vector3(1294.0, -1303.0, 77.0), name = "Rhodes Bank"},
    
    -- Strawberry Area
    {coords = vector3(-1792.0, -386.0, 160.0), name = "Strawberry General Store"},
    {coords = vector3(-1805.0, -364.0, 164.0), name = "Strawberry Hotel"},
}

-- Taxi Request Locations (where players can call taxis)
Config.TaxiRequestLocations = {
    -- Valentine Area
    {coords = vector3(-1798.0, -374.0, 158.0), name = "Valentine General Store", blip = true},
    {coords = vector3(-1786.0, -387.0, 160.0), name = "Valentine Saloon", blip = true},
    {coords = vector3(-1823.0, -354.0, 164.0), name = "Valentine Bank", blip = true},
    {coords = vector3(-1800.0, -430.0, 158.0), name = "Valentine Train Station", blip = true},
    
    -- Saint Denis Area  
    {coords = vector3(2644.0, -1293.0, 52.0), name = "Saint Denis Market", blip = true},
    {coords = vector3(2632.0, -1226.0, 53.0), name = "Saint Denis Saloon", blip = true},
    {coords = vector3(2644.0, -1282.0, 52.0), name = "Saint Denis Bank", blip = true},
    {coords = vector3(2750.0, -1230.0, 49.0), name = "Saint Denis Train Station", blip = true},
    
    -- Blackwater Area
    {coords = vector3(-3700.0, -2599.0, -13.0), name = "Blackwater General Store", blip = true},
    {coords = vector3(-3708.0, -2617.0, -13.0), name = "Blackwater Saloon", blip = true},
    {coords = vector3(-3664.0, -2628.0, -14.0), name = "Blackwater Bank", blip = true},
    {coords = vector3(-3760.0, -2650.0, -13.0), name = "Blackwater Train Station", blip = true},
    
    -- Rhodes Area
    {coords = vector3(1329.0, -1293.0, 77.0), name = "Rhodes General Store", blip = true},
    {coords = vector3(1341.0, -1317.0, 77.0), name = "Rhodes Saloon", blip = true},
    {coords = vector3(1294.0, -1303.0, 77.0), name = "Rhodes Bank", blip = true},
    {coords = vector3(1230.0, -1300.0, 76.0), name = "Rhodes Train Station", blip = true},
    
    -- Strawberry Area
    {coords = vector3(-1792.0, -386.0, 160.0), name = "Strawberry General Store", blip = true},
    {coords = vector3(-1805.0, -398.0, 158.0), name = "Strawberry Hotel", blip = true}
}

-- Blip Settings
Config.Blips = {
    TaxiDepot = {
        sprite = 'blip_stable',
        color = 'YELLOW',
        scale = 0.8,
        name = 'Taxi Depot'
    },
    TaxiRequest = {
        sprite = 'blip_taxi',
        color = 'BLIP_MODIFIER_MP_COLOR_32', 
        scale = 0.6,
        name = 'Call Taxi'
    },
    TaxiStand = {
        sprite = 'blip_taxi',
        color = 'BLIP_MODIFIER_MP_COLOR_32',
        scale = 0.8,
        name = 'Taxi Stand'
    },
    TaxiDriver = {
        sprite = 'blip_player',
        color = 'BLIP_MODIFIER_MP_COLOR_32',
        scale = 0.6,
        name = 'Taxi Driver'
    },
    ActiveRide = {
        sprite = 'blip_objective',
        color = 'BLIP_MODIFIER_MP_COLOR_2',
        scale = 0.7,
        name = 'Taxi Destination'
    }
}

-- Notification Settings
Config.Notifications = {
    Type = 'rsg-core', -- 'rsg-core', 'chat', 'custom'
    Position = 'top-right',
    Duration = 5000
}

-- Database Settings
Config.Database = {
    Enabled = true,
    SaveInterval = 300000, -- Save data every 5 minutes
    Tables = {
        drivers = 'taxi_drivers',
        rides = 'taxi_rides',
        ratings = 'taxi_ratings'
    }
}

-- Rating System
Config.RatingSystem = {
    Enabled = true,
    MinRating = 1,
    MaxRating = 5,
    DefaultRating = 5,
    RatingTimeout = 30000, -- Time in ms to rate after ride
}

-- Economy Integration
Config.Economy = {
    PaymentMethod = 'cash', -- 'cash', 'bank', 'both'
    TaxiDriverCut = 0.8,    -- Percentage driver keeps (80%)
    CompanyCut = 0.2,       -- Percentage company keeps (20%)
    SocietyAccount = 'society_taxi'
}

-- Sounds
Config.Sounds = {
    Enabled = true,
    Volume = 0.5,
    HornSound = 'CHECKPOINT_PERFECT',
    NotificationSound = 'CHECKPOINT_NORMAL'
}

-- Advanced Features
Config.Features = {
    GPS = true,              -- Enable GPS routing
    Meter = true,            -- Enable taxi meter
    Radio = true,            -- Enable taxi radio system
    Dispatch = true,         -- Enable dispatch system
    Queue = true,            -- Enable passenger queue system
    Tips = true,             -- Enable tipping system
    Receipts = true,         -- Enable ride receipts
    History = true,          -- Enable ride history
    Analytics = true,        -- Enable driver analytics
}

-- Performance Settings
Config.Performance = {
    UpdateInterval = 1000,   -- Update interval in ms
    MaxRenderDistance = 100.0, -- Maximum render distance for objects
    CleanupInterval = 600000,  -- Cleanup interval in ms (10 minutes)
}