Set number and types of boilers, chillers, and towers in baseline.

# ASHRAE 90.1-2019

G3.1.3.7 Type and Number of Chillers (Systems 7, 8, 11, 12, and 13)
Electric chillers shall be used in the baseline building design regardless of the cooling
energy source, e.g. direct-fired absorption or absorption from purchased steam. The
baseline building design’s chiller plant shall be modeled with chillers having the number
and type as indicated in Table G3.1.3.7 as a function of building peak cooling load.
Exception to G3.1.3.7
Systems using purchased chilled water shall be modeled in accordance with Section G3.1.1.3.

Table G3.1.3.7 Type and Number of Chillers

Building Peak Cooling Load Number and Type of Chillers  
<=300 tons: 1 water-cooled screw chiller  
\>300 tons, <600 tons: 2 water-cooled screw chillers sized equally  
\>=600 tons: 2 water-cooled centrifugal chillers minimum with chillers added so that no chiller is larger than 800 tons, all sized equally

G3.1.3.2 Type and Number of Boilers (Systems 1, 5, 7, 11, and 12)
The boiler plant shall be natural draft, except as noted in Section G3.1.1.1. The baseline
building design boiler plant shall be modeled as having a single boiler if the baseline
building design plant serves a conditioned floor area of 15,000 ft2 or less, and as having
two equally sized boilers for plants serving more than 15,000 ft2. Boilers shall be
staged as required by the load.

G3.1.3.11 Heat Rejection (Systems 7, 8, 11, 12, and 13)
The heat-rejection device shall be an axial-fan open-circuit cooling tower with variablespeed
fan control and shall have an efficiency of 38.2 gpm/hp at the conditions specified
in Table 6.8.1-7.


# Key Ruby Methods

## plant_loop_apply_prm_number_of_boilers(plant_loop)

Set boiler type and number of boilers based on floor area served by the boiler plant loop.
Set staging to sequential.

## plant_loop_apply_prm_number_of_chillers(plant_loop, sizing_run_dir)

Set chiller type and number of chillers based on total cooling capacity
Set staging to sequential.

## plant_loop_apply_prm_number_of_cooling_towers(plant_loop)

An alternate version of this method is located in ashrae_90_1_prm.PlantLoop.rb.
This version keeps a single cooling tower, but adds a headered pump bank with one pump per chiller.

