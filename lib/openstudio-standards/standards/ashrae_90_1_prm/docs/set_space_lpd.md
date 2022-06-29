Set lighting power density for each space by standard space category.

# ASHRAE 90.1-2019
- G3.1 (6) Baseline: Interior lighting power in the baseline building design shall be determined using the values in Table G3.7
- G3.1 (6) Baseline: Lighting shall be modeled by having the automatic shutoff controls in buildings > 5000 ft2 (2500 m2) and occupancy sensors in employee lunch break rooms, conference/meeting rooms, and classrooms (not including shop classrooms, laboratory classrooms, and preschool through 12th-grade classrooms). These controls shall be reflected in the baseline building design lighting schedules. No additional automatic lighting controls, e.g., automatic controls for daylight utilization and occupancy sensors in space types not listed above, shall be modeled in the baseline building design.

# Code Requirement Interpretation
The requirement aim to determine the interior lighting power density according to the Table G3.7.
For spaces mixed multiple space types, weighted LPD is calculated and the occupancy sensor reduction is weighted by the lighting power density of the space.

# Implementation Methodology
The method of assigning interior lighting power density for a single-type space is straightforward. However, when the space is a mixed-type, the lighting power density and occupancy sensor reduction are calculated in the example below.

Example:

| Space               | num_std_ltg_types | std_ltg_type01            | std_ltg_type_frac01 | std_ltg_type02        | std_ltg_type_frac02 |
|---------------------|-------------------|---------------------------|---------------------|-----------------------|---------------------|
| Perimeter_ZN_2      | 2                 | retail - whole building   | 0.8                 | retail dressing room  | 0.2                 |

Where:

| Space Type                | lighting per area (W/ft2) | occupancy sensor reduction |
|---------------------------|---------------------------|----------------------------|
| retail - whole building   | 1.5                       | 0.1                        |
| retail dressing room      | 0.89                      | 0.1                        |

The lighting power density of Perimeter_ZN_2 shall be determined as:

**Weighted LPD** = 1.5 W/ft2 * 0.8 + 0.89 W/ft2 * 0.2 = 1.2 W/ft2 + 0.178 W/ft2 = 1.378 W/ft2

**Weighted occupancy sensor reduction** = (0.1 * 1.2 W/ft2 + 0.1 * 0.178 W/ft2) / 1.378 W/ft2 = 0.1

## Key Ruby Methods
The function `space_type_apply_internal_loads` is used to calculate the LPDs and occupancy sensor reduction for each `Space` or `Space Type`. The logic is implemented by overriding this method in the `ashrae_90_1_prm_2019.SpaceType` class.

## Test Case Documentation

### Test case 1:
- Prototype: Small Office
- User data folder: */userdata_lpd_01*
- Summary:

| Space            | num_std_ltg_types | std_ltg_type01           | std_ltg_type_frac01 | std_ltg_type02          | std_ltg_type_frac02 | std_ltg_type03       | std_ltg_type_frac03 | Target_LPD (W/m2) |
|------------------|-------------------|--------------------------|---------------------|-------------------------|---------------------|----------------------|---------------------|-------------------|
| `Perimeter_ZN_2` | 2                 | retail - whole building  | 0.8                 | retail dressing room    | 0.2                 |                      |                     | 14.83267494       |      
| `Perimeter_ZN_1` | 3                 | retail mall concourse    | 0.2                 | retail - whole building | 0.6                 | retail dressing room | 0.2                 | 15.26323154       |
| `Perimeter_ZN_4` | 1                 | kitchen                  | 1.0                 |                         |                     |                      |                     | 12.91669806       |
| `Perimeter_ZN_3` | 1                 | office                   | 1.0                 |                         |                     |                      |                     | 10.7639           |
| `Perimeter_ZN_5` | 1                 | office                   | 1.0                 |                         |                     |                      |                     | 10.7639           |
| `Attic`          | 2                 | warehouse - bulk storage | 0.5                 | workshop                | 0.5                 |                      |                     | 15.06948107       |


### Test case 2:
- Prototype: Small Office
- User data folder: */userdata_lpd_02*
- Summary:

| Space Type                         | num_std_ltg_types | std_ltg_type01          | std_ltg_type_frac01 | std_ltg_type02 | std_ltg_type_frac02 | Target_LPD (W/m2) |
|------------------------------------|-------------------|-------------------------|---------------------|----------------|---------------------|-------------------|
| `Office WholeBuilding - Sm Office` | 2                 | atrium <= 40 ft height  | 0.5                 | workshop       | 0.5                 | 12.2452724        |

The `Office WholeBuilding - Sm Office` is the space type used by `Perimeter_ZN_1` through `Perimeter_ZN_5`.

- Note: In this test case, we also expect `Attic` to have `0 W/m2` LPD.


### Test case 2:
- Prototype: Small Office
- User data folder: *N/A*
- Summary:

`Office` is used as the standard space type for all spaces except `Attic`. Therefore, in this test case, we are expecting LPD to be 10.7639 for spaces `Perimeter_ZN_1` through `Perimeter_ZN_5` except `Attic`.

