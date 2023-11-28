Apply the service water heating loops to the baseline model

# ASHRAE 90.1 - 2019
- G3.1 (11) Baseline: The service water-heating system in the baseline building design shall be as specified in Table G3.1.1-2.
- G3.1 (11) Baseline a: Where a complete service water-heating system exists or a new service water-heating system has been specified, one service water-heating system shall be modeled for each building area type in the proposed building. Each system shall be sized according to the provisions of Section 7.4.1, and the equipment shall match the minimum efficiency requirements in Section 7.4.2.

# Code Requirement Interpretation
1. The quantity of the swh building area type should be identified based on the user compliance data or user selection. The building area types should be from Table G3.1.1-2.
2. The water heater efficiency and surface loss UA should be calculated based on Table 7.8.
3. If multiple swh building area types are assigned by the user, one swh loop shall be modeled for each building area type.
4. The water heater parameters other than the efficiency and surface loss UA should be the same to those in the user model.

# Implementation Methodology
## Proposed Model:
if (`swh_system`):
- Keep the current swh loop.

elseif (`!swh_system & swh_loads`):
- Use `model_apply_swh_loops`.

elseif (`!swh_system & !swh_loads`):
- No need to change.

elseif (`combined system`):
- No need to change.

## Baseline Model:
if (`swh_system`):
- Use `model_apply_swh_loops`.

elseif (`!swh_system & swh_loads`):
- Use `model_apply_swh_loops`.

elseif (`!swh_system & !swh_loads`):
- No need to change.

elseif (`combined system`):
- No need to change.

### `model_apply_swh_loop`
- For `wateruse_equipment` in `model`
    - Get the wsh building area type from the additional property of each wateruse_equipment.
    - Store all the swh building area types in `building_type_swh`.
- If `building_type_swh` is nil or `building_type_swh` contains only 1 unique item:
    - Use the method input building area type or the unique building area type as the swh building area type.
    - Keep the existing swh loop and assign the basline water heater parameters.
- Else(`building_type_swh` contains multiple unique item):
    - Store the parameters of the current swh system
    - Remove the old swh loop.
    - Add multiple new swh loops based on the building area types.
    - Calculate the parameters and assign them to the new swh loops.

## Key Ruby Methods
The method `model_apply_baseline_swh_loops` implements the logic for applying the baseline swh loops. This method can be found in `ashrae_90_1_prm_2019.Model.rb`. The method `model_apply_baseline_water_heater` implements the fuel type and parameters of the water heater. The method `model_add_swh_loop` adds the new swh loop. These two methods can be found in `ashrae_90_1_prm_2019_WaterHeaterMixed.rb`.

## Test Case Documentation

### Test case 1:
- Prototype: Medium Office
- User data folder: */userdata_default_test*
- Summary:
No user data, read building area type by input.
User model: 
One swh loop.
Baseline model:
One swh loop with changed fuel type and parameters.

### Test case 2:
- Prototype: Medium Office
- User data folder: */userdata_swh*
- Summary:
Read building area types from user data.
User model: 
Two swh loop.
Baseline model:
Two swh loop with changed fuel type and parameters.

### Test case 3:
- Prototype: Medium Office
- User data folder: */userdata_swh*
- Summary:
Read building area types from user data.
User model: 
One swh loop but two building area types are assigned.
Baseline model:
Two swh loop with changed fuel type and parameters.