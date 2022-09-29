# Pump power and control

## Code requirements
G3.1.3.5: Hot-water pumps
The baseline building design hot-water pump power shall be **19 W/gpm**. The pumping
system shall be modeled as primary-only with continuous variable flow and a minimum
of 25% of the design flow rate. Hot-water systems serving **120,000 ft2** or more shall be
modeled with variable-speed drives, and systems serving less than **120,000 ft2** shall be
modeled as riding the pump curve.

Exception to G3.1.3.5:
The pump power for systems using purchased heat shall be **14 W/gpm**.

G3.1.3.10 Chilled-Water Pumps (System 7, 8, 11, 12 and 13)
Chilled-water systems shall be modeled as primary/secondary systems with constant-flow
primary loop and variable-flow secondary loop. For systems with cooling capacity
of **300 tons or more**, the secondary pump shall be modeled with variable-speed drives
and a minimum flow of 25% of the design flow rate. For systems with **less than 300 tons**
cooling capacity, the secondary pump shall be modeled as riding the pump curve. The baseline building constant-volume primary pump power shall be modeled as **9 W/gpm**,
and the variable-flow secondary pump power shall be modeled as **13 W/gpm** at design
conditions. For computer room systems using System 11 with an integrated fluid economizer,
the baseline building design primary chilled-water pump power shall be increased
by **3 W/gpm** for flow associated with the fluid economizer.

Exception to G3.1.3.10
For systems using purchased chilled water, the building distribution pump shall be modeled
with variable-speed drive, a minimum flow of 25% of the design flow rate, and a pump power
of **16 W/gpm**.

G3.1.3.11 Heat Rejection (Systems 7, 8, 11, 12 and 13)
The baseline building design condenser-water pump power shall be **19 W/gpm** and modeled as constant volume.
For computer room systems using System 11 with an integrated fluid economizer, the baseline building design condenser-water-pump power shall be increased by **3 W/gpm** for flow associated with the fluid economizer.
Each chiller shall be modeled with separate condenser-water and chilled-water pumps interlocked to operate with the associated chiller.

#### key functions
ashrae_90_1_prm.PlantLoop.rb: plant_loop_apply_prm_baseline_pump_power
Standards.PlantLoop.rb: plant_loop_apply_prm_baseline_pumping_type
    - Sub-function: plant_loop_apply_prm_baseline_hot_water_pumping_type
    - Sub-function: plant_loop_apply_prm_baseline_chilled_water_pumping_type
    - Sub-function: plant_loop_apply_prm_baseline_condenser_water_pumping_type

#### Parameters:
Pump power constants set in PlantLoop class:
```ruby
HOT_WATER_PUMP_POWER = 19 # W/gpm
HOT_WATER_DISTRICT_PUMP_POWER = 14 # W/gpm
CHILLED_WATER_PRIMARY_PUMP_POWER = 9 # W/gpm
CHILLED_WATER_SECONDARY_PUMP_POWER = 13 # W/gpm
CHILLED_WATER_DISTRICT_PUMP_POWER = 16 # W/gpm
CONDENSER_WATER_PUMP_POWER = 19 # W/gpm
```
Pump curve coefficients used to defining the pump type
```ruby
when 'Riding Curve'
  coeff_a = 0.0
  coeff_b = 3.2485
  coeff_c = -4.7443
  coeff_d = 2.5294
when 'VSD No Reset'
  coeff_a = 0.0
  coeff_b = 0.5726
  coeff_c = -0.301
  coeff_d = 0.7347
```

### Limitations

- The code implemented a primary and secondary loop configuration for chilled water loop. The primary loop has chiller at the supply side and a perfect heat exchanger at the demand side. The secondary loop has the heat exchanger at the supply side and coils at the demand side. In this configuration, each chiller will interlock with a pump. However, the pump operation strategy is not implemented yet.
- The integrated water economizer for system type 11 is not implemented.

### PRM-RM
