# Natural Ventilation Measure
This measure adds natural ventilation (NV) to a building model.

## Description
The workflow of this measure is as follows:
* Ask for users' inputs for below arguments:
    * nv_type: whether to add NV to a building model or not
    * nv_opening_fraction: what is the opening fraction of windows (this value is used to calculate the opening area of windows for NV)
    * nv_Tout_min: As per E+ I/O Reference, "minimum outdoor temperature is the outdoor temperature (in Celsius) below which ventilation is shut off. This lower temperature limit is intended to avoid overcooling a space, which could result in a heating load."
    * nv_Delta_Tin_Tout: As per E+ I/O Reference, "Delta temperature is the temperature difference (in Celsius) between the indoor and outdoor air dry-bulb temperatures below which ventilation is shutoff."
* Loop through **ZoneHVACEquipmentLists**.
    * Get which thermal zone is served by each of the "ZoneHVACEquipmentLists" objects.
    * Get heating/cooling setpoint temperature schedules for the thermal zone from the osm file. 
    * Create an adjustment of heating/cooling setpoint temperature schedules. 
    (Note that these schedules are used in the "ZoneVentilation:DesignFlowRate" and "ZoneVentilation:WindandStackOpenArea" objects)
    * Loop through spaces in the thermal zone.
    * Gather outdoor air flow rate per person and per floor area of the space from the osm file.
    (Note that these values are used in the "ZoneVentilation:DesignFlowRate" objects)
    * Find how many external windows each space has.
    * Loop through external windows of the space.
    * Add **ZoneVentilation:DesignFlowRate** objects to each space if has at least one external window. 
        * The number of "ZoneVentilation:DesignFlowRate" is twice the number of external windows the space has. 
        This is because for each external window, two "ZoneVentilation:DesignFlowRate" objects are added: (1) for air flow rate per person, and (2) for air flow rate per floor area. 
    * Add one **ZoneVentilation:WindandStackOpenArea** objects to each space if has at least one external window. 
        * The number of "ZoneVentilation:WindandStackOpenArea" equals the number of external windows the space has.
    * Add "ZoneVentilation:DesignFlowRate" and "ZoneVentilation:WindandStackOpenArea" objects to the "ZoneHVAC:EquipmentList" object of the thermal zone.
* Loop through **AirLoopHVACs**.
    * Add **AvailabilityManagerHybridVentilation** to each air loop.

## Approach
This measure has some assumptions/limitations, as follows:
* It models NV using a simplified airflow method (rather than airflow network).
* It assumes that all floors are sealed, and mid points of windows are on neutral pressure level (NPL) of each floor 
to avoid complexity of finding the NPL of a building. 
Hence, this measure excludes stack-driven NV.
* It uses a built-in object called **AvailabilityManager:HybridVentilation** in EnergyPlus to avoid simultaneous NV and HVAC system operation.
    * Note that **Ventilation Control Mode Schedule Name** was set by default.
    Hence, the integer value in the schedule is set to 1 (i.e. temperature control).
    * Note that users' input for nv_Tout_min is used for the fields of "Minimum Outdoor Temperature".
        * As per E+ I/O Reference, "Minimum Outdoor Temperature is the outdoor temperature (in Celsius) below which hybrid ventilation is shut off when the ventilation control mode = 1 (Temperature). This lower temperature limit is intended to avoid overcooling a space, which could result in a heating load."
    * Note that the "Maximum Outdoor Temperature" has been set to 30C. (there is no temperature schedule unlike the ZoneVentilation:DesignFlowRate and ZoneVentilation:WindandStackOpenArea objects)    
        * As per E+ I/O Reference, "Maximum Outdoor Temperature is the outdoor temperature (in Celsius) above which hybrid ventilation is shut off when the ventilation control mode = 1 (Temperature). This upper temperature limit is intended to avoid overheating a space, which could result in a cooling load."
* It considers the Fanger thermal comfort model (rather than the ASHRAE 55's adaptive thermal comfort model). 
In other words, this measure sets min/max indoor air temperature as fixed values (on the basis of heating/cooling setpoint temperature) regardless of outdoor conditions.
* It uses heating/cooling setpoint schedules +/- 2C as the min/max indoor air temperature for controlling NV. 
    * Note that min/max indoor air temperature are the fields defined under the objects of **ZoneVentilation:DesignFlowRate** and **ZoneVentilation:WindandStackOpenArea**. 
    * As per E+ I/O Reference, "Minimum indoor temperature is the indoor temperature (in Celsius) below which ventilation is shutoff. This lower temperature limit is intended to avoid overcooling a space and thus result in a heating load."
    * As per E+ I/O Reference, "Maximum indoor temperature is the indoor temperature (in Celsius) above which ventilation is shutoff. This upper temperature limit is intended to avoid overheating a space and thus result in a cooling load."
* It uses the required outdoor airflow rate per person and floor area for each space as the airflow rate when there is NV in the space.
    * As a space may have multiple windows, to avoid outdoor airflow rate more than what is required for a space, the required outdoor airflow rate per person and floor area for the space are divided by the number of windows.
    * Note that this measure uses the E+'s defaults for the coefficients of A,B,C,D (i.e. 1,0,0,0) in Equation 1.41 in E+ I/O Reference. 
    These default values gives a constant air flow regardless of the wind speed and the difference between the indoor and outdoor temperature.
* It adds NV to any space with external windows (window types of either 'OperableWindow' or 'FixedWindow').
* It uses same opening fraction for all windows of spaces. So, depending on a window area, the opening area of the window is calculated.  

## Testing Plan
* Tests were run to ensure cooling loads reduce depending on the inputs for min outdoor air temperature, Delta T between indoor and outdoor, and windows opening fraction.
* Timestep-based results for NECB2011 Full Service Restaurant in Vancouver were checked to see if NV and HVAC were not working simultaneously, and if NV was working properly regarding using setpoints for NV.
The timestep-based results' excel file has been attached to the task (see https://github.com/canmet-energy/btap_tasks/issues/310).
* A unit test and expected results file were developed.
* The output variable that can be used to check whether NV and HVAC system is working at each timestep is **Availability Manager Hybrid Ventilation Control Status []**.
  It returns three values: 0 (no hybrid ventilation control), 1 (NV is allowed), and 2 (NV is not allowed).

## Files Added/Modified
 * Files have been modified:
   * **necb_2011.rb**
 * Files have been added:
   * **nv.rb**
   * **test_nv.rb**
   * **nv.md**
   * **nv_expected_results.rb**
   
## Reference
* E+ I/O Reference (2020), EnergyPlus Vesion 9.3.0 Documentation: Input Output Reference.