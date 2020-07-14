# Demand Controlled Ventilation Measure
This measure enables or disables demand controlled ventilation (DCV) in air-based HVAC systems of a model. 
Enabling DCV can be based on occupancy or CO<sub>2</sub> concentration in spaces.
<br> Some parts of this measure used the existing measure, called "enable_demand_controlled_ventilation", in OpenStudio's BCL with some modifications. 

# Description
The workflow of this measure is as follows:
1. Create indoor CO<sub>2</sub> availability and setpoint and outdoor CO<sub>2</sub> schedules. 
(This is required for CO<sub>2</sub>-based DCV)
2. Set outdoor airflow rate per person for each zone. (This is required for occupancy-based DCV)
3. Set a contaminant controller in each zone to control the zone to the specified CO<sub>2</sub> 
level based on the indoor CO<sub>2</sub> availability and setpoint schedules.
(This is required for CO<sub>2</sub>-based DCV)
4. Loop through all air loops to:
    1. Find the outdoor air system for each air loop.
    2. Get the outdoor air controller from the outdoor air system.
    3. Get the mechanical ventilation controller from the outdoor air controller.
    4. Set DCV of the the mechanical ventilation controller to Yes or No based on whether DCV is enabled or not.
    5. Set the system outdoor air method based on the DCV type (i.e. occupancy/CO<sub>2</sub>-based DCV)

# Approach
This measure has defined simple schedules for indoor CO<sub>2</sub> availability and setpoint and outdoor CO<sub>2</sub> schedules.
However, more detailed schedules can be defined in the future.

# Testing Plan
* This measure has been called in the **apply_systems** function (in autozone.rb).
* This measure was tested for NECB 2011 full service restaurant archetype.
Note that since setting the outdoor airflow rate per person is upon another BTAP task, 
the outdoor airflow rate per person values were set manually for each space that was served by an air-based HVAC system using OpenStudio.

# Waiting On
Two parts of this measure are upon other BTAP tasks as follows:
1. Regarding setting the outdoor airflow rate per person, the associated values for each space type should be entered for 
"ventilation_per_person" in "lib/openstudio-standards/standards/necb/NECB2011/data/space_types.json"
    * Note #1: NBC-2010, Division B, Article 6.2.2.1. refers to ANSI/ASHRAE 62 “Ventilation for Acceptable Indoor Air Quality” for the required ventilation, 
except for storage garages.
    * Note #2: Regaridng ventilation of storage garages, see NBC-2010, Division B, Article 6.2.2.3. which says "provide, during operating hours, a continuous supply of outdoor air at a rate of not less than 3.9 L/s for each square metre of floor area."
2. This measure created a function called **get_any_number_ppm** as a ScheduleTypeLimits to input CO<sub>2</sub> concentration levels.
This function can be added to "btap/schedules.rb > module StandardScheduleTypeLimits".

# Files Added/Modified
* Files have been modified:
  * **necb_2011.rb**
  * **autozone.rb**
* Files have been added: 
  * **demand_controlled_ventilation.md**