Set window to wall ratio in the baseline model

# ASHRAE 90.1-2019
- G3.1 (5) Baseline c: Vertical Fenestration Areas: For building area types included in the Table G3.1.1-1, vertical fenestration areas for new buildings and additions shall equal that in Table G3.1.1-1 based on the area of gross above-grade walls that separate conditioned spaces and semiheated spaces from the exterior. 
- G3.1 (5) Baseline c: Where a building has multiple building area types, each type shall use the values in the table. 
- G3.1 (5) Baseline c: The vertical fenestration shall be distributed on each face of the building in the same proportion as in the proposed design. 
- G3.1 (5) Baseline c: For building areas not shown in Table G3.1.1-1, vertical fenestration areas for new building and additions shall equal that in the proposed design or 40% of gross above-grade wall area, whichever is smaller, and shall be distributed on each face of the building in the same proportions in the proposed design.
- G3.1 (5) Baseline c: ([addendum_l](https://www.ashrae.org/file%20library/technical%20resources/standards%20and%20guidelines/standards%20addenda/90_1_2019_l_20201030.pdf)): If this would cause the combined vertical fenestration and opaque door area on a given face to exceed the gross above-grade wall area on that face, then the vertical fenestration area on other faces shall be increased in proportion to the gross above-grade wall area of these faces such that the total baseline building vertical fenestration area is equal to that calculated following Table G3.1.1.-1.
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
The function `get_wwr_reduction_ratio` implements the logic for calculating the reduction ratio `reduction_ratio` and `surface_adjust_fenestration_in_a_surface` implements the logics to adjust the window to wall ratio for a surface

The implementation of both functions can be found in the `ashrae_90_1_prm.Model.rb`

## Notes:
The function works well with cases where WWR reduction is needed. For WWR increase to meet Table G3.1.1-1 values, the function's limitation is listed below:
1. The function will remove all windows in the surface then add a new window to meet the required WWR.
2. The function will keep the existing doors but there could be cases the location of door overlaps with the new window.

In addition, when increasing the WWR requires adding windows to surfaces with no windows, the function will not adding any windows to spaces tagged as plenum and/or used as a AirLoopSupplyPlenum or AirLoopReturnPlenum. 

## Test Case Documentation

### Test case 1:
- Prototype: Small Office
- User data folder: */userdata_default_test*
- Summary:

The target WWR is 19% and the test prototype has WWR of 21.20%. 

A regular WWR reduction shall be applied in this case to set the WWR in the baseline model to 19%.

### Test case 2:
- Prototype: Small Office - WWR adjusted.
- User data folder: */userdata_default_test*
- Summary:
- 
  Test prototype:

|                       | Total  | North | East  | South | West  |
|-----------------------|--------|-------|-------|-------|-------|
| Wall Area (m2)        | 281.51 | 84.45 | 56.30 | 84.45 | 56.30 |
| Window Area (m2)      | 28.15  | 8.44  | 5.63  | 8.44  | 5.63  |
| Window-Wall Ratio (%) | 10%    | 10%   | 10%   | 10%   | 10%   |  

The target WWR is 19%. The test prototype has WWR of 10% (10% for every surface).

A regular WWR increase shall be applied in this case to set the WWR in the baseline model to 19% for every surface.

Baseline:

|                       | Total  | North | East  | South | West  |
|-----------------------|--------|-------|-------|-------|-------|
| Wall Area (m2)        | 281.51 | 84.45 | 56.30 | 84.45 | 56.30 |
| Window Area (m2)      | 53.49  | 16.05 | 10.70 | 16.05 | 10.70 |
| Window-Wall Ratio (%) | 19%    | 19%   | 19%   | 19%   | 19%   |  

### Test case 3:
- Prototype: Small Office - WWR adjusted.
- User data folder: */userdata_default_test*
- Summary:

Test prototype:

|                       | Total  | North | East  | South | West  |
|-----------------------|--------|-------|-------|-------|-------|
| Wall Area (m2)        | 281.51 | 84.45 | 56.30 | 84.45 | 56.30 |
| Window Area (m2)      | 5.63   | 0.0   | 0.0   | 0.0   | 5.63  |
| Window-Wall Ratio (%) | 2%     | 0%    | 0%    | 0%    | 10%   |  

In this case, the WWR shall be increased to 19% however, the maximum WWR by expanding windows in West facade only is 17.7%, about 1.3% smaller than the required by the code.
The function shall increase the rest facades proportionally to meet the overall 19% WWR target.

Baseline:

|                       | Total  | North | East  | South | West  |
|-----------------------|--------|-------|-------|-------|-------|
| Wall Area (m2)        | 281.51 | 84.45 | 56.30 | 84.45 | 56.30 |
| Window Area (m2)      | 53.49  | 1.06  | 0.7   | 1.06  | 50.67 |
| Window-Wall Ratio (%) | 19%    | 1.25% | 1.25% | 1.25% | 90%   |  

### Test Case 4
- Prototype: Mid Apartment
- User data folder: */userdata_default_test*
- Summary:

Test prototype:

|                       | Total   | North  | East   | South  | West   |
|-----------------------|---------|--------|--------|--------|--------|
| Wall Area (m2)        | 1542.06 | 564.80 | 206.23 | 564.80 | 206.23 |
| Window Area (m2)      | 306.92  | 112.97 | 43.82  | 112.97 | 37.16  |
| Window-Wall Ratio (%) | 19.9%   | 20%    | 21.25% | 20%    | 18.02% |  

The test prototype WWR is 19.9%. Based on code, Mid-apartment shall be `Other` building window to wall ratio type so in the baseline, it should have 40% WWR or its proposed design whichever is smaller.

Baseline:

|                       | Total   | North  | East   | South  | West   |
|-----------------------|---------|--------|--------|--------|--------|
| Wall Area (m2)        | 1542.06 | 564.80 | 206.23 | 564.80 | 206.23 |
| Window Area (m2)      | 308.41  | 112.97 | 44.74  | 113.54 | 37.16  |
| Window-Wall Ratio (%) | 20%     | 20%    | 21.7%  | 20.1%  | 18.02% |  

In this case, a 0.1% tolerance is applied.

### Test Case 5
- Prototype: Mid Apartment - WWR adjusted
- User data folder: */userdata_default_test*
- Summary:

Test prototype:

|                       | Total   | North  | East   | South  | West   |
|-----------------------|---------|--------|--------|--------|--------|
| Wall Area (m2)        | 1542.06 | 564.80 | 206.23 | 564.80 | 206.23 |
| Window Area (m2)      | 750.59  | 282.40 | 92.90  | 282.40 | 92.90  |
| Window-Wall Ratio (%) | 50%     | 50%    | 50%    | 50%    | 50%    |  

The test prototype WWR is 50%. Based on code, Mid-apartment shall be `Other` building window to wall ratio type so in the baseline, it should have 40% WWR or its proposed design whichever is smaller.

Baseline:

|                       | Total   | North  | East   | South  | West   |
|-----------------------|---------|--------|--------|--------|--------|
| Wall Area (m2)        | 1542.06 | 564.80 | 206.23 | 564.80 | 206.23 |
| Window Area (m2)      | 616.84  | 225.92 | 87.02  | 229.58 | 74.32  |
| Window-Wall Ratio (%) | 40%     | 40%    | 42.20% | 40.65% | 36.04% |  


### Test Case 6
- Prototype: Medium Office - WWR adjusted
- User data folder: */userdata_default_test*
- Summary:

Test prototype:

|                       | Total   | North  | East   | South  | West   |
|-----------------------|---------|--------|--------|--------|--------|
| Wall Area (m2)        | 1977.67 | 593.30 | 395.53 | 593.30 | 395.53 |
| Window Area (m2)      | 27.38   | 0.0    | 27.38  | 0.0    | 0.0    |
| Window-Wall Ratio (%) | 1.38%   | 0%     | 6.92%  | 0%     | 0%     |  

The test prototype has WWR of 1.38%. The target WWR is 31%. The building has plenums so this test case shall increase the window to wall ratio to 31% by adding more windows to the rest facades and in the meantime, avoids adding new windows to the plenum surfaces

Baseline:

|                       | Total   | North  | East   | South  | West   |
|-----------------------|---------|--------|--------|--------|--------|
| Wall Area (m2)        | 1977.67 | 593.30 | 395.53 | 593.30 | 395.53 |
| Window Area (m2)      | 613.08  | 137.48 | 246.45 | 137.49 | 91.66  |
| Window-Wall Ratio (%) | 31%     | 23.17% | 62.31% | 23.17% | 23.17% | 
