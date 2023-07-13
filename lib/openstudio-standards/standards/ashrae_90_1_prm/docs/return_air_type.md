Return Air Type

# ASHRAE 90.1-2019 PRM Reference Manual
For baseline building systems 1 and 2, the return air path shall be direct-to-unit. For baseline building systems 3 through 8 and 11 through 13 and when the proposed design is direct-to-unit, the baseline building shall be ducted return, otherwise the baseline building return air path shall be the same as proposed design.

# Implementation
For each zone:

* Retrieve the type of return used by the HVAC system serving the zone
  * If the zone is served by air loops
    * ignore air loop-based DOAS
    * if air loop uses a return plenum -> return_plenum
    * if air loop uses a return path -> ducted_return
  * If the zone is served by zonal systems
    * direct-to-unit since zonal systems cannot be connected to return plenum objects
* Using additional properties, set the type of return as one of the following: return_plenum, ducted_return, direct-to-unit
* Using additional properties, set the name of the plenum zone used when return_plenum is specified

Once the systems have been created:

* Using the zone design air flow rate and previously added additional properties determine the dominant return air configuration (the most dominant ones being the one with the most air flow)
* All system are by default assumed to be ducted_return/direct-to-unit (using the zone mixer object) but if return_plenum ends up being the dominant one, pass the appropriate argument to the method creating the systems

To simplify reporting at that point, use `ducted_return_or_direct_to_unit` and `return_plenum` as the additional property field.

# Key Ruby Methods 
## New
* `model_determine_baseline_return_air_type`: determine the baseline return air type associated with each zone
* `model_identify_return_air_type`: identify the return air type associated with each thermal zone
* `air_loop_hvac_return_air_plenum`: determine if the air loop has a return air plenum 
 
