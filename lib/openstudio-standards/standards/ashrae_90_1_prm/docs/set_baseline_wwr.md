Set window to wall ratio in the baseline model

# ASHRAE 90.1-2019
- G3.1 (5) Baseline c: Vertical Fenestration Areas: For building area types included in the Table G3.1.1-1, vertical fenestration areas for new buildings and additions shall equal that in Table G3.1.1-1 based on the area of gross above-grade walls that separate conditioned spaces and semiheated spaces from the exterior. 
- G3.1 (5) Baseline c: Where a building has multiple building area types, each type shall use the values in the table. 
- G3.1 (5) Baseline c: The vertical fenestration shall be distributed on each face of the building in the same proportion as in the proposed design. 
- G3.1 (5) Baseline c: For building areas not shown in Table G3.1.1-1, vertical fenestration areas for new building and additions shall equal that in the proposed design or 40% of gross above-grade wall area, whichever is smaller, and shall be distributed on each face of the building in the same proportions in the proposed design.
- G3.1 (5) Baseline c ([addendum_l](https://www.ashrae.org/file%20library/technical%20resources/standards%20and%20guidelines/standards%20addenda/90_1_2019_l_20201030.pdf)): If this would cause the combined vertical fenestration and opaque door area on a given face to exceed the gross above-grade wall area on that face, then the vertical fenestration area on other faces shall be increased in proportion to the gross above-grade wall area of these faces such that the total baseline building vertical fenestration area is equal to that calculated following Table G3.1.1.-1.
- G3.1 (5) Baseline c: The fenestration area for an existing building shall equal the existing fenestration area prior to the proposed work and shall be distributed on each face of the building in the same proportions as the existing building.

# Code Requirement Interpretation
1. Fenestration area shall be calculated based on the area of gross above-grade walls that separate conditioned spaces and semiheated spaces from the exterior
2. If the window to wall ratio building type (wwr_building_type) can be found in Table G3.1.1-1, then the baseline window to wall ratio shall equal to the values specified in the table by proportionally decrease or increase the fenestration area.
3. If the wwr_building_type cannot be found in the Table or it is other type, the baseline window to wall ratio shall equal to 40% or proposed window to wall ratio, whichever is smaller.
4. Multiple wwr_building_types in a building shall use the values in the table correspondingly.
5. If the fenestration area increase exceeds the host wall surfaces, then the residual shall be distributed to the other wall surfaces proportionally to its wall surface area
6. Existing building shall remain the fenestration area the same as the existing fenestration area prior to the proposed work

# Implementation Methodology
- For `space_group` in `wwr_building_type`
    - calculate total wall area `wall_m2 = calculate_wall_area(space_group)`
    - calculate total wall area of walls has fenestration subsurfaces `fene_only_wall_m2 = calculate_fene_only_wall_area(space_group)`
    - calculate total window area `wind_m2 = calculate_total_wind_area(space_group)`
    - get the window to wall ratio (wwr) limit from Table 3.1.1-1 `wwr_lim = table_3.1.1-1(wwr_building_type)`
    - calculate multiplier `multiplier = wwr_lim / (wind_m2 / wall_m2)`
    - For `space` in `space_group`:
      - For `surface` in `space.surfaces` where `surface_boundary_condition == 'Outdoor' && surfaceType=='Wall'`:
        - set reduction ratio `reduction_ratio = 1.0` 
        - calculate the window to wall ratio of the surface `surface_wwr = get_wwr_of_a_surface`
        - if reduction is requested `multiplier < 1.0`
          - reduction ratio is set to `1.0 - multiplier`
          - call function to shrink the fenestration towards centroid `sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid`
        - elsif `wwr_building_type == 'all others'`
          - reduction ratio set to `1.0`
          - do nothing
        - else
          - calculate maximum fenestration area that wall surfaces with fenestration can reach `max_wwr = fene_only_wall_m2 * 0.9 / wall_m2` (Note: 90% wwr is the upper limit for each surface in OpenStudio standard)
          - if the wwr limit is greater than max wwr `max_wwr < wwr_lim`
            - if the surface has no fenestration `if surface_wwr == 0` (Note: In this case, it is required to add new fenestration to the surface)
              - Add window to the surface by a calculated ratio `surface.setWindowToWallRatio(1.0 + (wwr_lim*wall_m2 - max_wwr*wall_m2)/(wall_m2-fene_only_wall_m2))`
            - else: (Note: In this case, it is required to maximize the fenestration area in this surface to 90% wwr)
              - Set window to wall ratio to 90% `surface.setWindowToWallRatio(0.9)`
          else
            - if the surface has no fenestration `if surface_wwr == 0`
              - Do nothing
            - else:
              - Set a new window to wall ratio to the surface `surface.setWindowToWallRatio(surface_wwr * multiplier)`

## Key Ruby Methods
The function `get_wwr_reduction_ratio` implements the logic for calculating the reduction ratio `reduction_ratio` and `model_adjust_fenestration_in_a_surface` implements the logics to adjust the window to wall ratio for a surface

The implementation of both functions can be found in the `ashrae_90_1_prm.Model.rb`

## Test Case Documentation

### Test case 1:
- Prototype: Small Office
- User data folder: */userdata_lpd_01*
- Summary:


        