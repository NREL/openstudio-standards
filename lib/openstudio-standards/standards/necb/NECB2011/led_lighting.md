# High Performance LED Lighting Measure
This measure adds a new lighting definition regarding LED lighting in each space of the model, 
and replace the existing lighting definition with the LED lighting definition in each space.

# Description
The workflow of this measure is as follows:
1. Define a new LED lighting definition for each space.
2. Use the new LED lighting definition instead of the existing lighting definition in each space.

# Approach
This measure follows the functions already existed in the BTAP environment with respect to setting lights in spaces.<br>
However, a new function called **set_lighting_per_area_led_lighting** has been created in necb_2011.rb to set lighting power density (LPD) for LED lighting.<br>
Moreover, the **apply_standard_lights** function (in lighting.rb) has been modified to set the three fields of 
fraction radiant, fraction visible, and return air fraction for LED lighting.<br> 
Furthermore, two variables have been added to the **apply_standard_lights** function:
(1) **lights_type** to specify which lighting type to be used in the model. The lighting types that a user can choose are: CFL, LED.
(2) **scale** to specify whether LPD default values are used or a fraction of LPD default values are used in the model.

# Testing Plan
* This measure has been called in the **apply_loads** function (in necb_2011.rb) -> **model_add_loads** function (in necb_2011.rb) 
-> **space_type_apply_internal_loads** function (in beps_compliance_path.rb) -> **apply_standard_lights** function (in lighting.rb).
* This measure was tested for NECB 2011 full service restaurant archetype.
* Note that regarding atriums' heights, since none of the archetypes has atriums, 
the testing procedure was performed for the space type including the "Dining" term and with some tweaks in the LPD equations.

# Waiting On
* There are four fields in the OS:Lights:Definition object that need to be updated in standards/lib/openstudio-standards/standards/necb/NECB2011/**data/led_lighting_data.json**, as follows:
  1. LPD (W/m<sup>2</sup>)
  2. Fraction Radiant
  3. Fraction Visible
  4. Return Air Fraction

* Note that three xlsx files (**led_lighting_data_necb2011.xlsx**, **led_lighting_data_necb2015.xlsx**, **led_lighting_data_necb2017.xlsx**) 
should be updated as per Mike Lubun's xlsx files for lighting sets.
* To this end, openstudio-standards/lib/openstudio-standards/utilities/**LEDLightingData_xlsx_to_json.rb** can be used to convert the xlsx files to json format.
* Once the openstudio-standards/lib/openstudio-standards/**btap/led_lighting_data.json** file is generated using LEDLightingData_xlsx_to_json.rb, 
openstudio-standards/lib/openstudio-standards/standards/necb/NECB2011/**data/led_lighting_data.json** should be updated manually (copy and paste from **btap/led_lighting_data.json**). 
 
# Files Added/Modified
* Files have been modified: 
  * **necb_2011.rb**
  * **beps_compliance_path.rb**
  * **lighting.rb**
* Files have been added: 
  * **led_lighting.md**
  * openstudio-standards/lib/openstudio-standards/utilities/**LEDLightingData_xlsx_to_json.rb**
  * openstudio-standards/lib/openstudio-standards/btap/**led_lighting_data_necb2011.xlsx**
  * openstudio-standards/lib/openstudio-standards/btap/**led_lighting_data_necb2015.xlsx**
  * openstudio-standards/lib/openstudio-standards/btap/**led_lighting_data_necb2017.xlsx**
  * openstudio-standards/lib/openstudio-standards/**btap/led_lighting_data.json**
  * openstudio-standards/lib/openstudio-standards/standards/necb/NECB2011/**data/led_lighting_data.json**