Set number and types of boilers, chillers, and towers in baseline.

# ASHRAE 90.1-2019

G3.1.3.13
Minimum volume set points for VAV reheat boxes shall be 30% of zone peak airflow, the minimum outdoor airflow rate, or the airflow rate required to comply with applicable codes or accreditation standards, whichever is larger.

G3.1.3.14
Minimum volume set points for fan-powered boxes shall be equal to 30% of peak design primary airflow rate or the rate required to meet the minimum outdoor air ventilation requirement, whichever is larger.

# Key Ruby Methods

## Existing
* `air_loop_hvac_apply_minimum_vav_damper_positions`: Set the minimum VAV damper positions.
* `air_terminal_single_duct_vav_reheat_apply_minimum_damper_position`: Set the minimum damper position based on OA rate of the space and the template.
* `air_terminal_single_duct_vav_reheat_minimum_damper_position`: Specifies the minimum damper position for VAV dampers.
* `air_terminal_single_duct_parallel_piu_reheat_apply_prm_baseline_fan_power`: Sets the fan power of a PIU fan based on the W/cfm specified in the standard.

## New
* `air_terminal_single_duct_parallel_reheat_piu_minimum_primary_airflow_fraction`: Specifies the minimum primary air flow fraction for PFB boxes.
* `air_terminal_single_duct_parallel_piu_reheat_apply_minimum_primary_airflow_fraction`: Set the minimum primary air flow fraction based on OA rate of the space and the template.
