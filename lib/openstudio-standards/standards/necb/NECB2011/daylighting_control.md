# Daylighting Sensor Controls Measure
This measure adds daylighting sensor controls to a building's spaces where they are daylighted by sidelighting and/or toplighting based on NECB-2011. <br> Some parts of this measure used the existing measure, called "assign_ashrae_9012010_daylighting_controls", in OpenStudio's BCL with some modifications.

## Description
The workflow of this measure is as follows:
1. Find all spaces in a building that have the fenestration types of "fixed window", "operable window", and "skylight" on exterior surfaces.
2. Calculate "Primary Sidelighted Areas" and "Sidelighting Effective Aperture" for the spaces that have fixed and/or operable window(s), as per NECB-2011's Article 4.2.2.9. and Article 4.2.2.10. See Notes #1 and 2 below.
3. Calculate "Daylighted Area Under Skylights" and "Skylight Effective Aperture" for the spaces that have skylight(s), as per NECB-2011's Article 4.2.2.5. and 4.2.2.7. See Notes #3 and 4 below.
4. Exclude the daylighted spaces where the NECB-2011's required conditions are not met for either "Primary Sidelighted Areas", "Sidelighting Effective Aperture", "Daylighted Area Under Skylights", or "Skylight Effective Aperture". See Note #5 below for the NECB-2011's required conditions.
5. However, include all daylighted office spaces larger than 25 m<sup>2</sup> even if they do not meet NECB-2011's required conditions for either "Primary Sidelighted Areas", "Sidelighting Effective Aperture", "Daylighted Area Under Skylights", or "Skylight Effective Aperture". This approach is based on NECB-2011's Article 4.2.2.2. 
6. Create daylighting sensor(s) (one or two) for the daylighted spaces that should have daylighting sensors controls. See Note #6 below for number of sensors.

##### Note #1:
* The Primary Sidelighted Area is calculated as follows: (See NECB-2011 Figure A-4.2.2.9.)
  * Primary Sidelighted Area’s width = window width + min(0.6 m, distance to any vertical obstruction that is 1.5 m or more in height) on each side of the window.
  * Primary Sidelighted Area’s depth = min(window head height, perpendicular distance of any vertical obstruction that is 1.5 m or more in height from the window).
  * Primary Sidelighted Area = its width x its depth
  
##### Note #2:
* The Sidelighting Effective Aperture is calculated as follows:
  * Sidelighting Effective Aperture = sum(glazing area of window) x area-weighted visible transmittance of glazing / Primary Sidelighted Area

##### Note #3:
* The Daylighted Area Under Skylight is calculated as follows: (See NECB-2011 Figure A-4.2.2.5.(2))
  * Daylighted Area Under Skylight = Area of the skylight’s projection onto the floor + the horizontal distances extending from the projection in each direction to min(0.7 * ceiling height, distance to any primary daylighted area, distance to any vertical obstruction where the obstruction is farther than 70% of the distance between the top of the obstruction and the ceiling).

##### Note #4:
* The Skylight Effective Aperture is calculated as follows:
  * Skylight Effective Aperture = 0.85 x (total glazing area of skylights) x (area-weighted VT of skylight glazing) x (WF) / Daylighted Area Under Skylight
  * WF is the area-weighted average well factor (see NECB-2011: 4.2.2.7.).
  
##### Note #5:
* Which daylighted spaces should have daylighting sensor controls as per NECB-2011:
  * Primary Sidelighted Areas > 100 m<sup>2</sup>
  * Sidelighting Effective Aperture > 0.1 (10%)
  * Daylighted Area Under Skylights > 400 m<sup>2</sup>
  * Skylight Effective Aperture > 0.006 (0.6%)
  
##### Note #6:
* Energyplus allows for maximum two daylighting sensor controls in each thermal zone.
* Considering the above limitation in EnergyPlus and NECB-2011's Article 4.2.2.2., this measure determines whether one or two daylighting sensors are needed for a daylighted space as below:
  * If the daylighted space area <= 250 m<sup>2</sup>: put one sensor at the center of the space at the height of 0.8 m above the floor.
  * Otherwise, divide the space into two equal parts and put one sensor at the center of each of them at the height of 0.8 m above the floor.

## Approach
This measure has some assumptions and limitations:
1. It does not consider rooftop monitors regarding toplighting.
2. It does not exclude overlapped daylighted areas regarding wide windows in spaces daylighted by sidelighting.
3. It assumes that skylight(s) are in parallel to roof(s) edges.
4. It assumes that skylight(s) are flush with ceiling(s).
5. It assumes that skylight(s) is(are) rectangular in shape.
6. In the calculation of extension of skylight(s)' projection onto the floor, the window head height is subtracted from the associated vertical distance of skylight projection to the exterior wall once (even if the exterior wall has multiple windows).
7. It does not consider space types (see NECB-2011's 4.2.2.8.) regarding whether they should or should not have daylighting sensor controls.
8. It does not consider this clause from NECB-2011: 4.2.2.4.: "enclosed space > 800 m<sup>2</sup> in buildings located above the 55˚N latitude" regarding toplighting.
  
## Testing Plan
* This measure has been called in the **model_apply_standard** function after the **apply_loop_pump_power** function (in necb_2011.rb).
  * Note that since the **apply_auto_zoning** function removes any assigned thermal zones (hence, removes daylighting sensors), 
the **model_add_daylighting_controls** function was removed from the **apply_fdwr_srr_daylighting** function.
* This measure was tested for two NECB 2011 archetypes: (1) full service restaurant, (2) warehouse. <br> 
The full service restaurant archetype has sidelighting. Since none of spaces of this archetype met the NECB-2011's requirements to have daylighting sensor control(s), daylighting sensor controls were created for none of the spaces of this archetype. <br>
The warehouse archetype has both sidelighting and skylights. One space out of three daylighted spaces met the NECB-2011's requirements to have daylighting sensor control(s). One of the two other daylighted spaces is an office space larger than 25 m<sup>2</sup>; hence, a daylighting sensor control was created for this space although it did not meet the NECB-2011's requirements.
![Warehouse](/home/osdev/openstudio-standards/lib/openstudio-standards/standards/necb/NECB2011/Warehouse_daylightingSensor.png)

## Files Added/Modified
 * Files have been modified:
   * **necb_2011.rb**
 * Files have been added:
   * **daylighting_control.md**
   * **Warehouse_daylightingSensor.png**