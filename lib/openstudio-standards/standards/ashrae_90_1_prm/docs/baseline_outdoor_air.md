Baseline Outdoor Air

# ASHRAE 90.1-2019 PRM Reference Manual
For all HVAC zones, the minimum ventilation system outdoor air intake flow shall be the same for the proposed and baseline building designs. Except in the following conditions:
- If the minimum outdoor air intake flow in the proposed design is provided in excess of the amount required by the rating authority or building official, then the baseline building design shall be modeled to reflect the greater of that required by the rating authority or building official and will be less than the proposed design.

# Implementation
- Reads in userdata_design_specification_outdoor_air
- Before the HVAC sizing run, evaluate the user data
  - Loop through Sizing:Zones
    - Get the DesignSpecification:OutdoorAir, if matches to the user_data_oa then check the current ventilation settings.
    - Split into four sub-routines:
      - calculate total OA by occupants: occupant_oa = zone_total_occupants * airflow_per_occupant
      - calculate total OA by floor area: floor_area_oa = zone_floor_area * airflow_per_floor_area
      - calculate total OA by zone: zone_oa = airflow_per_zone
      - calculate total OA by ACH: ach_oa = ach * height(m) / 3.6 / 1000
      - calculate sum OA: sum_oa = occupant_oa + floor_area_oa + zone_oa + ach_oa
      - if sum_oa > user_data_oa:
        - duplicate a DesignSpecifcation:OutdoorAir object
        - Enter the ventilation methods to the object
        - Reassign the object to the Sizing:Zones

NOTE: 
1. There are some details relate to Zone-Space relationship needs to be explored in the above logic
2. When assigning user specified ventilation methods, it will likely require to create a new space type and override the ventilation object in the new space type - this could cause multiple space types in the baseline model (similar case is in ligthing)

# Key Ruby Methods

## New

 
