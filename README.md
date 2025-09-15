# This Has Been Archived and is not functional #

# RSG Taxi System for RedM

An advanced taxi system for RedM servers using the RSG2 framework. This comprehensive system provides both player-driven and NPC taxi services with a modern web-based interface.

## Features

### 🚗 Core Taxi System
- **Player Taxi Drivers**: Players can work as taxi drivers with full job management
- **Passenger System**: Request rides to various locations across the map
- **NPC Taxi Service**: Automated NPC taxis when no players are available
- **Dynamic Fare Calculation**: Distance, time, and condition-based pricing
- **Real-time Taxi Meter**: Live fare tracking during rides

### 💰 Economy Integration
- **Multiple Payment Methods**: Cash and bank payments
- **Tip System**: Optional tipping for drivers
- **Driver Earnings**: Configurable driver/company revenue split
- **Society Integration**: Company earnings go to taxi society account

### 📊 Advanced Features
- **Rating System**: Passengers can rate drivers (1-5 stars)
- **Ride History**: Complete history of all rides
- **Driver Statistics**: Track rides, earnings, and ratings
- **Real-time Dashboard**: Modern web interface for drivers
- **GPS Integration**: Waypoint system for destinations

### 🎮 User Experience
- **Modern UI**: Responsive HTML/CSS/JS interface
- **Multiple Languages**: Localization support
- **Taxi Stands**: Designated pickup locations
- **Blip System**: Map markers for taxis and stands
- **Notifications**: In-game alerts and updates

### 🗄️ Data Management
- **MySQL Integration**: Persistent data storage
- **Automatic Cleanup**: Old data removal system
- **Statistics Tracking**: Comprehensive analytics
- **Backup System**: Data integrity protection

## Installation

### Prerequisites
- RedM server with RSG Core framework
- MySQL database
- oxmysql resource

### Setup Instructions

1. **Download and Extract**
   ```bash
   cd resources
   git clone https://github.com/yourusername/redm-rsg-taxi.git rsg-taxi
   ```

2. **Database Setup**
   - The resource will automatically create required tables on first run
   - Ensure your MySQL connection is properly configured

3. **Configuration**
   - Edit `config.lua` to customize settings
   - Adjust taxi stands, vehicles, and fare rates
   - Configure economy settings

4. **Add to Server Config**
   ```cfg
   ensure rsg-taxi
   ```

5. **Job Setup** (if using job system)
   - Add taxi job to your jobs configuration
   - Set appropriate permissions and grades

## Configuration

### Basic Settings
```lua
Config.TaxiJob = 'taxi'                    -- Job name for taxi drivers
Config.MaxTaxiDrivers = 10                 -- Maximum concurrent drivers
Config.MinimumTaxiDrivers = 0              -- Minimum before NPCs spawn
```

### Fare System
```lua
Config.FareSystem = {
    BaseFare = 2.0,                        -- Base fare amount
    PerMeterRate = 0.05,                   -- Rate per meter traveled
    WaitingRate = 0.10,                    -- Rate per second waiting
    NightMultiplier = 1.5,                 -- Night time multiplier
    WeatherMultiplier = 1.25,              -- Bad weather multiplier
    MinimumFare = 1.0,                     -- Minimum fare
    MaximumFare = 50.0,                    -- Maximum fare
}
```

### Vehicle Configuration
```lua
Config.TaxiVehicles = {
    'buggy01',                             -- Horse-drawn buggy
    'cart01',                              -- Simple cart
    'wagon02',                             -- Covered wagon
    'coach2',                              -- Stagecoach
}
```

## Usage

### For Taxi Drivers
1. **Start Working**: Go to any taxi stand and press `G`
2. **Spawn Vehicle**: Select from available taxi vehicles
3. **Accept Rides**: Respond to passenger requests
4. **Use Meter**: Toggle meter on/off during rides
5. **Collect Payment**: Receive fare and tips from passengers

### For Passengers
1. **Call Taxi**: Go to taxi stand or use `/calltaxi` command
2. **Select Destination**: Choose from available locations
3. **Wait for Pickup**: Driver will come to your location
4. **Pay Fare**: Complete payment at destination
5. **Rate Driver**: Optional rating system

### Commands
- `/taxi` - Open taxi menu
- `/calltaxi` - Request a taxi
- `/taximeter` - Toggle taxi meter (drivers only)
- `/taxistats` - View driver statistics

### Key Bindings
- `F6` - Open Taxi Menu
- `F7` - Toggle Taxi Meter
- `G` - Interact at taxi stands

## API & Exports

### Server Exports
```lua
-- Check if player is taxi driver
local isDriver = exports['rsg-taxi']:IsPlayerTaxiDriver(playerId)

-- Get all active taxi drivers
local drivers = exports['rsg-taxi']:GetTaxiDrivers()

-- Get active rides
local rides = exports['rsg-taxi']:GetActiveRides()
```

### Client Exports
```lua
-- Open taxi meter UI
exports['rsg-taxi']:OpenTaxiMeterUI()

-- Show notification
exports['rsg-taxi']:ShowUINotification(message, type, duration)

-- Check if UI is open
local isOpen = exports['rsg-taxi']:IsUIOpen()
```

## Database Schema

The system creates the following tables:
- `taxi_drivers` - Driver information and statistics
- `taxi_rides` - Complete ride history
- `taxi_ratings` - Driver ratings and comments
- `taxi_vehicles` - Vehicle tracking and status

## Customization

### Adding New Locations
Edit `Config.PickupLocations` in `config.lua`:
```lua
{coords = vector3(x, y, z), name = "Location Name"}
```

### Custom Vehicle Models
Add vehicle models to `Config.TaxiVehicles`:
```lua
Config.TaxiVehicles = {
    'your_custom_vehicle',
    'another_vehicle'
}
```

### Styling the UI
Modify `html/style.css` to customize the appearance:
- Colors and themes
- Layout and positioning
- Animations and effects

## Troubleshooting

### Common Issues
1. **Database Connection**: Ensure oxmysql is running and configured
2. **Job System**: Verify taxi job exists in your framework
3. **Permissions**: Check player job permissions
4. **Vehicle Spawning**: Ensure spawn locations are clear

### Debug Mode
Enable debug mode in `config.lua`:
```lua
Config.Debug = true
```

## Performance

### Optimization Features
- Efficient distance calculations
- Automatic cleanup systems
- Configurable update intervals
- Resource usage monitoring

### Recommended Settings
- Update interval: 1000ms
- Cleanup interval: 10 minutes
- Max render distance: 100 units

## Support

### Getting Help
1. Check the configuration file
2. Review server console for errors
3. Enable debug mode for detailed logging
4. Check database connections

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Credits

- **Framework**: RSG Core Team
- **Development**: RSG Community
- **UI Design**: Modern web standards
- **Testing**: RedM Community

## Changelog

### Version 1.0.0
- Initial release
- Complete taxi system implementation
- Modern web-based UI
- Database integration
- NPC taxi system
- Rating and statistics system

---

**Note**: This is an advanced system designed for experienced server administrators. Proper configuration and testing are recommended before deployment on production servers.
