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
      - calculate total OA by occupants in model: occupant_oa_p = zone_total_occupants * airflow_per_occupant_u
      - calculate total OA by occupants in user data: occupant_oa_u = zone_total_occupants * airflow_per_occupant_u
      - calculate total OA by floor area in model: floor_area_oa_p = zone_floor_area * airflow_per_floor_area_p
      - calculate total OA by floor area in user data: floor_area_oa_u = zone_floor_area * airflow_per_floor_area_u
      - calculate total OA by zone in model: zone_oa_p = airflow_per_zone_p
      - calculate total OA by zone in user data: zone_oa_u = airflow_per_zone_u
      - calculate total OA by ACH in model: ach_oa_p = ach_p * height(m) / 3.6 / 1000
      - calculate total OA by ACH in user data: ach_oa_u = ach_u * height(m) / 3.6 / 1000
      - calculate sum OA: sum_oa = occupant_oa_p + floor_area_oa_p + zone_oa_p + ach_oa_p
      - calculate sum user data oa: user_data_oa = occupant_oa_u + floor_area_oa_u + zone_oa_u + ach_oa_u
      - if sum_oa > user_data_oa:
        - Modify the ventilation methods in the object.
      - else:
        - Issue a warning in the log
NOTE: 
1. There are some details relate to Zone-Space relationship needs to be explored in the above logic
2. When assigning user specified ventilation methods, it will likely require to create a new space type and override the ventilation object in the new space type - this could cause multiple space types in the baseline model (similar case is in ligthing)

# Key Ruby Methods

## New

 
