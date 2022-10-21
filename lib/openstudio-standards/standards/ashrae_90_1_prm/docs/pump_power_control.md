Pump power and control requirements

# ASHRAE 90.1-2019

## G3.1.3.5 Hot-Water Pumps
The baseline building design hot-water pump power shall be 19 W/gpm. The pumping system shall be modeled as primary-only with continuous variable flow and a minimum of 25% of the design flow rate. Hot-water systems serving 120,000 ft2or more shall be modeled with variable-speed drives, and systems serving less than 120,000 ft2 shall be modeled as riding the pump curve. 

### Exception to G3.1.3.5
The pump power for systems using purchased heat shall be 14 W/gpm.

## G3.1.3.10 Chilled-Water Pumps (Systems 7, 8, 11, 12, and 13)
Chilled-water systems shall be modeled as primary/secondary systems with constantflow primary loop and variable-flow secondary loop. For systems with cooling capacity of 300 tons or more, the secondary pump shall be modeled with variable-speed drives and a minimum flow of 25% of the design flow rate. For systems with less than 300 tons cooling capacity, the secondary pump shall be modeled as riding the pump curve. The baseline building constant-volume primary pump power shall be modeled as 9 W/gpm, and the variable-flow secondary pump power shall be modeled as 13 W/gpm at design conditions. For computer room systems using System 11 with an integrated fluid economizer, the baseline building design primary chilled-water pump power shall be increased by 3 W/gpm for flow associated with the fluid economizer.

### Exception to G3.1.3.10
For systems using purchased chilled water, the building distribution pump shall be modeled with variable-speed drive, a minimum flow of 25% of the design flow rate, and a pump power of 16 W/gpm.

## G3.1.3.11 Heat Rejection (Systems 7, 8, 11, 12, and 13)
The baseline building design condenser-water pump power shall be 19W/gpm and modeled as constant volume. For computer room systems using System 11 with an integrated fluid economizer, the baseline building design condenser water-pump power shall be increased by 3W/gpm for flow associated with the fluid economizer.
Each chiller shall be modeled with separate condenser-water and chilled-water pumps interlocked to operate with the associated chiller.

# Requirement change:
## ASHRAE 90.1-2013 Appendix G:
### G3.1.3.5 Hot-Water Pumps:
The baseline building design hot-water pump power shall be 19 W/gpm. The pumping system shall be modeled as primary-only with continuous variable flow. Hot-water systems serving 120,000 ft2 or more shall be modeled with variable-speed drives, and systems serving less than 120,000 ft2 shall be modeled as riding the pump curve.

Exceptions: The pump power for systems using purchased heat shall be 14 W/gpm.

### G3.1.3.10 Chilled-Water Pumps (System 7, 8 and 11)
The baseline building design pump power shall be 22 W/gpm. Chilled-water systems with a cooling capacity of 300 tons or more shall be modeled as primary/secondary systems with variable-speed drives on the secondary pumping loop. Chilled-water pumps in systems serving less than 300 tons cooling capacity shall be modeled as a primary/secondary systems with secondary pump riding the pump curve. For computer room systems using System 11 with an integrated water-side economizer, the baseline building design primary chilled-water pump power shall be increased 5 W/gpm for flow associated with the water-side economizer.

Exceptions: The pump power for systems using purchased chilled water shall be 16 W/gpm.

### G3.1.3.11 Heat Reject (System 7, 8, 9, 12, and 13)
The baseline building design condenser-water pump power shall be 19 W/gpm. For computer room systems using System 11 with an integrated water-side economizer, the baseline building design condenser water-pump power shall be increased 5 W/gpm for flow associated with the water-side economizer. Each chiller shall be modeled with separate condenser water and chilled-water pumps interlocked to operate with the associated chiller.

## ASHRAE 90.1-2016, 2019 Appendix G:
G3.1.3.19: System 5 through 8, The baseline system shall be modeled with a preheat coil controlled to a fixed setpoint 20F less than the design room heating temperature set point.

# Key Ruby Methods

*Standards.Model.rb*
```ruby
plant_loop_apply_prm_baseline_pump_power()
plant_loop_apply_prm_baseline_pumping_type()
```
```