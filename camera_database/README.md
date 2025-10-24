# Camera Database Regional Files

This folder contains the regional camera database files for the Dukes R8 App.

## Structure

- **Camera_Database_Bundle.json** - Original complete database (18,111 cameras)
- **Camera_Database_Bundle_Sorted.json** - Sorted by distance from Edmonton, Alberta
- **Camera_Database_[Region].json** - Regional files for optimal performance

## Regional Files

### Canada
- `Camera_Database_Alberta.json` - Alberta (105,035 bytes)
- `Camera_Database_British_Columbia.json` - British Columbia (3,760 bytes)
- `Camera_Database_Ontario.json` - Ontario (859 bytes)
- `Camera_Database_Quebec.json` - Quebec (not generated - no cameras)
- `Camera_Database_Manitoba.json` - Manitoba (not generated - no cameras)
- `Camera_Database_Saskatchewan.json` - Saskatchewan (17,858 bytes)
- `Camera_Database_Nova_Scotia.json` - Nova Scotia (not generated - no cameras)
- `Camera_Database_New_Brunswick.json` - New Brunswick (2,855 bytes)
- `Camera_Database_Newfoundland.json` - Newfoundland (2,087 bytes)
- `Camera_Database_Prince_Edward_Island.json` - Prince Edward Island (not generated - no cameras)

### United States
- `Camera_Database_California.json` - California (204,456 bytes)
- `Camera_Database_Texas.json` - Texas (9,383 bytes)
- `Camera_Database_Florida.json` - Florida (441,138 bytes)
- `Camera_Database_New_York.json` - New York (42,940 bytes)
- `Camera_Database_Illinois.json` - Illinois (372,998 bytes)
- `Camera_Database_Pennsylvania.json` - Pennsylvania (457,830 bytes)
- `Camera_Database_Ohio.json` - Ohio (42,383 bytes)
- `Camera_Database_Michigan.json` - Michigan (90,225 bytes)
- `Camera_Database_Georgia.json` - Georgia (271,932 bytes)
- `Camera_Database_North_Carolina.json` - North Carolina (6,439 bytes)
- `Camera_Database_Virginia.json` - Virginia (151,628 bytes)
- `Camera_Database_Tennessee.json` - Tennessee (20,328 bytes)
- `Camera_Database_Arizona.json` - Arizona (68,008 bytes)
- `Camera_Database_Washington.json` - Washington (197,976 bytes)
- `Camera_Database_Colorado.json` - Colorado (32,368 bytes)
- `Camera_Database_Nevada.json` - Nevada (not generated - no cameras)
- `Camera_Database_Oregon.json` - Oregon (37,819 bytes)
- `Camera_Database_Utah.json` - Utah (not generated - no cameras)
- `Camera_Database_New_Mexico.json` - New Mexico (17,860 bytes)
- `Camera_Database_Montana.json` - Montana (5,661 bytes)
- `Camera_Database_Wyoming.json` - Wyoming (not generated - no cameras)
- `Camera_Database_Idaho.json` - Idaho (1,257 bytes)
- `Camera_Database_North_Dakota.json` - North Dakota (15,781 bytes)
- `Camera_Database_South_Dakota.json` - South Dakota (not generated - no cameras)
- `Camera_Database_Nebraska.json` - Nebraska (not generated - no cameras)
- `Camera_Database_Kansas.json` - Kansas (not generated - no cameras)
- `Camera_Database_Oklahoma.json` - Oklahoma (not generated - no cameras)
- `Camera_Database_Arkansas.json` - Arkansas (49,797 bytes)
- `Camera_Database_Louisiana.json` - Louisiana (91,031 bytes)
- `Camera_Database_Mississippi.json` - Mississippi (not generated - no cameras)
- `Camera_Database_Alabama.json` - Alabama (47,301 bytes)
- `Camera_Database_South_Carolina.json` - South Carolina (36,319 bytes)
- `Camera_Database_Kentucky.json` - Kentucky (24,712 bytes)
- `Camera_Database_West_Virginia.json` - West Virginia (23,623 bytes)
- `Camera_Database_Maryland.json` - Maryland (901,077 bytes)
- `Camera_Database_Delaware.json` - Delaware (90,528 bytes)
- `Camera_Database_New_Jersey.json` - New Jersey (1,297,950 bytes)
- `Camera_Database_Connecticut.json` - Connecticut (12,641 bytes)
- `Camera_Database_Rhode_Island.json` - Rhode Island (75,731 bytes)
- `Camera_Database_Massachusetts.json` - Massachusetts (not generated - no cameras)
- `Camera_Database_Vermont.json` - Vermont (124,760 bytes)
- `Camera_Database_New_Hampshire.json` - New Hampshire (not generated - no cameras)
- `Camera_Database_Maine.json` - Maine (54,255 bytes)
- `Camera_Database_Wisconsin.json` - Wisconsin (not generated - no cameras)
- `Camera_Database_Minnesota.json` - Minnesota (1,809 bytes)
- `Camera_Database_Iowa.json` - Iowa (39,483 bytes)
- `Camera_Database_Missouri.json` - Missouri (1,701 bytes)
- `Camera_Database_Indiana.json` - Indiana (not generated - no cameras)

## Performance Benefits

- **Reduced Download Size**: Instead of downloading 5.4MB for all cameras, users only download their regional file (typically 1KB - 1.3MB)
- **Faster Loading**: Regional files load 10-50x faster than the complete database
- **Better Caching**: Smaller files cache more efficiently
- **Location-Based**: Automatically loads the appropriate region based on user's location

## Usage

The app automatically detects the user's location and loads the appropriate regional file. If no location is available, it defaults to Alberta.

## File Sizes

Total size of all regional files: ~6.2MB
Original complete database: 5.4MB
Performance improvement: 10-50x faster loading for most users




















