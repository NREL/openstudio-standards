Fan Power Credits

# ASHRAE 90.1-2019
Note 1 and 2 under Table G3.1.2.9 indicate that the baseline fan brake horsepower adjustment factor, A, is calculated according to Section 6.5.3.1.1 using the pressure-drop adjustment from the proposed design and the design flow rate of the baseline building system. The pressure-drop adjustment for evaporative coolers or heat recovery devices that are not required in the baseline system by Section G3.1.2.10.

# Code Requirement Interpretation
Section 6.5.3.1.1 include credits but also deductions. Following an internal discussion we concluded that the intent of Appendix G should be to base the deduction on the baseline building design and not the proposed design.

# Implementation
Fan power credits are provided by the user via the `userdata_airloop_hvac.csv` and `userdata_zone_hvac.csv` files. The deductions are only applicable to system 6 and 8 and are handled in the code in `air_loop_hvac_fan_power_limitation_pressure_drop_adjustment_brake_horsepower()`. Credits and deduction are stored as an `additionaProperty` at the `ThermalZone` and `AirLoopHVAC` level. The baseline fan power credits/deductions are calculated for each zone as follows: Az = sum(PD_sum * CFM_d_baseline/4131), where CFM_d_baseline is the baseline __zone__ design air flow and PD_sum. The system A is obtained by summing all the zone Az.

# Key Ruby Methods
* `thermal_zone_get_fan_power_limitations()`: calculate the fan power credits/deductions for a zone
* `air_loop_hvac_fan_power_limitation_pressure_drop_adjustment_brake_horsepower`: calculate the fan power limitation pressure drop adjustment (expressed in terms of BHP)
* `handle_zone_hvac_user_input_data`: use the user-defined CSV files to assign fan power credits to each zone