# Ground-Mounted PV Measure
This measure is to add ground-mounted PV to a model. 
Renewable energy should be the last item added to a model. 

## Description
* The users' inputs for the measure are PV module type, and total area and azimuth and tilt angles of PV panels. 
* A json file has been created that includes a variety of PV modules options.
* It has been assumed that PV panel's size is 5 ft x 2 ft as it seems to fit the racking system used for ground mounts as per Mike Lubun's comment.
* Default PV panels' tilt angle has been set as the latitude of the location.
* Default PV panels' azimuth angle has been set as south-facing arrays.
* Default PV module type has been set as "HES-160-36PV 26.6  x 58.3 x 1.38" as assuming a typical panel is 5 ft x 2 ft, 
the closest standard type PV panel in the costing spreadsheet would be the 160W HES based on Mike Lubun's comment.
* Only one PVWatts generator is created using the measure for simplification, 
  however exact number of PVWatts generators (and inverters) are calculated for costing as per Mike Lubun's comment.

## Approach
* A new file in https://github.com/NREL/openstudio-standards/tree/nrcan/lib/openstudio-standards/standards/necb/ECMS folder called pv_ground.rb has been created.
* A method called apply_pv_ground has been added to the ECMS class. This is where the PV method logic has been writen.
* Since the PV modules has many options (i.e. type and capacity) a library in json format has been created in https://github.com/NREL/openstudio-standards/blob/nrcan/lib/openstudio-standards/standards/necb/ECMS/data. 
These properties align with the costing spreadsheet.
* The apply_pv_ground method has been added to the end of the 'apply_systems_and_efficiencies' method in necb2011.rb.
* The inputs have been set to 'nil' for the do nothing option, similar to what is done in the erv measure.
* The required arguments have been threaded up to the 'model_create_prototype_model' method in necb_2011.rb.

## Testing Plan
* The tests were run in OpenStudio to ensure electricity is being generated and scales with changes in the PV panels area.
* In OpenStudio, it has been checked that net site/source energy is less than total site/source energy due to the installation of PV panels.
* Another output variable that can be checked in OpenStudio at different timesteps is **Inverter AC Output Electric Power [W]**.
* A unit test has been developed.
##### Notes:
* "Total site energy is the "gross" energy consumed by the building site and Net Site Energy is the final energy consumed by the building site after accounting for any on-site energy generation (photovoltaics, generators, etc.)."
(Ref: https://unmethours.com/question/25416/what-is-the-difference-between-site-energy-and-source-energy/)
* "Total Source Energy (="represents the total amount of raw fuel that is required to operate the building. 
It incorporates all transmission, delivery, and production losses" Source: EPA). In contrast, the Net Source Energy is the energy that you get after the losses of delivery and transportation."
(Ref: https://unmethours.com/question/19090/what-is-the-difference-between-total-source-energy-and-net-source-energy/)
## Files Added/Modified
 * Files have been modified:
   * **necb_2011.rb**
   * **btap_pre1980.rb**
 * Files have been added:
   * **pv_ground.rb**
   * **pv.json**
   * **test_pv_ground.rb** 
   * **pv_ground.md**
