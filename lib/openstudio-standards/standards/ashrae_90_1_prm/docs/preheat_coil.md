Preheat coil requirements

# ASHRAE 90.1-2019

G3.1.3.7 Preheat Coils (System 5 through 8)
The baseline system shall be modeled with a preheat coil controlled to a fixed set point of 20F less than the design room heating temperature set point.

# PRM-Reference Manual:
For baseline system 5 through 8, the baseline will be modeled with preheat coil controlled to a fixed setpoint 20 F less than the design zone heating temperature setpoint. If there are multiple zone heating setpoints, the preheat setpoint will be determined by the zone with the highest heating temperature setpoint.

The preheat coil capacity will be oversized by 25%. Sizing calculation shall be based on the heating design day and cooling design day conditions, as defined in Section 3.1.5 of this document. Oversizing would be carried out at zone level where the sizing parameters would be applied to the zone design's heating coil loads.

The heating source for baseline system 5 and 7 will be hydronic. Buildings with baseline system 6 and 8 will be modeled with electric resistance preheat coils.

The coil efficiency is not applicable to electric coils

# Requirement change:
## ASHRAE 90.1-2013 Appendix G:
G3.1.2.4 Preheat Coils: If the HVAC system in the proposed design has a preheat coil and a preheat coil can be modeled in the baseline system, the baseline system shall be modeled with a preheat coil controlled in the same manner as the proposed design.

## ASHRAE 90.1-2016, 2019 Appendix G:
G3.1.3.19: System 5 through 8, The baseline system shall be modeled with a preheat coil controlled to a fixed setpoint 20F less than the design room heating temperature set point.

# Key Ruby Methods

*Standards.Model.rb*
```ruby
# Template method for adding a setpoint manager for a coil control logic to a heating coil.
# ASHRAE 90.1-2019 Appendix G.
def model_set_central_preheat_coil_spm(model, thermal_zones, coil)
	return true
end
```
This implementation is overriden in the subclass *ashrae_90_1_prm.Model.rb*

```ruby
def model_set_central_preheat_coil_spm(model, thermal_zones, coil)
	# below is the sudo code
	coil_name = coil.name.get.to_s

	max_heat_setpoint = 0.0
	thermalZone.each do |zone|
		# Get the thermalstat heating setpoint of each zone
		# Reset the max_heat_setpoint if a zone has a higher heating setpoint value
	end

	max_heat_setpoint_f = convert(max_heat_setpoint, 'C', 'F')
	preheat_setpoint_f = max_heat_setpoint_f - 20 # required to be 20F lower than the max heat setpoint
	preheat_setpoint_c = convert(preheat_setpoint_f, 'F', 'C')

	schedule = add_constant_schedule(preheat_setpoint_c)

	# add a new_setpointManager_scheduled
	# add the schedule to the new setpoint manager scheduled.
	# add the new setpoint manager to the coil.
end
```

Currently, the method is only being called when executing system type 5, 6, 7, and 8 generation routines.