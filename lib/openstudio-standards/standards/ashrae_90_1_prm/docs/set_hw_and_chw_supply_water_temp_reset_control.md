Apply water supply temperature reset control to hot water loop and chilled water loop.

# ASHRAE 90.1-2019

G3.1.3.4 Hot-Water Supply Temperature Reset (Sys 1, 5 ,7, 11, and 12)

Hot-water supply temperature shall be reset based on outdoor dry-bulb temperature using the following schedule: 180F at 20F and below, 150F at 50F and above and ramped linearly between 180F and 150F at temperature between 20F and 50F.

Exception G3.1.3.4: Systems served by purchased heat

G3.1.3.8: Chilled-Water Supply Temperature Reset (Sys 7, 8, 11, 12 and 13)

Chilled-water supply temperature shall be reset based on outdoor dry-bulb temperature using the following schedule: 44F at 80F and above, 54F at 60F and below, and ramped linearly between 44F and 54F at temperature between 80F and 60F.

Exception G3.1.3.9:
If the baseline chilled-water system serves a computer room HVAC system, the supply chilled-water temperature shall be reset higher based on the HVAC system requiring the most cooling; i.e., the chilled-water set point is reset higher until one cooling-coil valve is nearly wide open. The maximum reset chilled-water supply temperature shall be 54F
Systems served by purchased chilled water.


# Key Ruby Methods

## plant_loop_enable_supply_water_temperature_reset(plant_loop)
Search and identify the hot water loops and chilled water loops (exclude district systems).
Add SetpointManagerOutdoorAirReset to the loops.