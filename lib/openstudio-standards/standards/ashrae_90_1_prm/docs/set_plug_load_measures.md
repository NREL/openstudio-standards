Handle plug-load credits

# ASHRAE 90.1-2019
- G3.1 (12) Proposed: Receptacle and *process loads*, such as those for office and other equipment, shall be estimated based on the building area type or space type category and shall be assumed to be identical in the *proposed design* and *baseline building design*, except as specifically approved by the *rating authority* only when quantifying performance that exceeds the requirements of Standard 90.1 but not when the *Performance Rating Method* is used as an alternative path for minimum standard compliance in accordance with Section 4.2.1.1
- G3.1 (12) Proposed: When receptacle controls installed in *spaces* where not required by Section 8.4.2 are included in the *proposed building design*, the hourly receptacle shall be reduced as follows:

  ![RPC= RC * 10%](https://latex.codecogs.com/svg.latex?RPC=&space;RC&space;*&space;10%)
    
    where:
    - *RPC* = receptacle power credit 
    - *EPS<sub>pro</sub>* = EPS<sub>bas</sub> x (1-RPC)
    - *RC* = percentage of all controlled receptacles
    - *EPS<sub>bas</sub>* = baseline equipment power hourly schedule (fraction)
    - *EPS<sub>pro</sub>* = proposed equipment power hourly schedule (fraction)
- G3.1 (12) Baseline: Motors shall be modeled as having the *efficiency* ratings found in Table G3.9.1 Other systems covered by Section 10 and miscellaneous loads shall be modeled as identical to those in the *proposed design*, including schedules of operation and *control of the equipment*.

# Code Requirement Interpretation
For each space in the proposed building indicate which receptacle control strategies from the control list are included and the percentage of receptacles that are controlled.

When receptacle controls are installed in spaces not required by 90.1-2019 Section 8.4.2, credit for receptacle controls in the proposed design can be taken by decreasing the receptacle schedule in the proposed building design according to the following:

![RPC= RC * 10%](https://latex.codecogs.com/svg.latex?RPC=&space;RC&space;*&space;10%)

# Implementation Methodology
- **Step 1:** Check the required room types in Section 8.4.2, if matched, then skip the plug-load credits.
The matching rule is based on closest space functions as described in Section 8.4.2. The Table below shows the mapping. It subjects to changes.

| Rooms                                                     | Space type category 1                  | Space type category 2                          |
|-----------------------------------------------------------|----------------------------------------|------------------------------------------------|
| Private Offices                                           | office - enclosed <= 250 sf            |                                                |
 | Conference Rooms                                          | conference/meeting/multipurpose        |                                                |
| Room used primarily for printing and/or copying functions | copy/print                             |                                                |
| Break rooms                                               | lounge/breakroom - all other           | lounge/breakroom - healthcare facility         |
| Classrooms                                                | classroom/lecture/training - all other | classroom/lecture/training - preschool to 12th |
| Individual workstation                                    | office - open                          |                                                |

- **Step 2:** Check *userdata_electric_equipment* to verify user data
  - **Step 2.1:** Check *userdata_electric_equipment* to identify if the the electric equipment is a motor / refrigeration / elevator.
    - **Step 2.1.1:** If motor, retrieve data and save in the electric equipment object.
    - **Step 2.1.2:** If refrigeration or elevator, skip the processing.
  - **Step 2.2:** Else if *fraction_of_controlled_receptacle* (RC) data is available. If yes, get the user data (RC) and calculate the RPC
  - **Step 2.3:** Else: check *receptacle_power_savings* (RPC) data is available. If yes, get the user data (RPC) and apply the credit.
- **Step 3:** If apply credit, apply the credit at every hour of the existing electric equipment schedule with the equation:
  - ![hr_{new} = {hr_{ex}}/{1.0-RPC}](https://latex.codecogs.com/svg.image?hr_{new}&space;=&space;{hr_{ex}}&space;/&space;(1.0-RPC))
  - hr<sub>new</sub>: the adjusted hourly value
  - hr<sub>ex</sub>: the original hourly value
- **Step 4:** Repeat the similar process for *userdata_gas_equipment* user data.

## Key Ruby Methods
The above logic is implemented in the `space_type_apply_internal_loads` in the ashrae_90_1_prm.SpaceType class.
Sub-logics are implemented in the `update_power_equipment_credits` function, which is called by `space_type_apply_internal_loads`

## Test Case Documentation
### Test case 1:
- Prototype: Small Office
- User data folder: */userdata_pe_01*
- Summary:
This case will test whether *fraction_of_controlled_receptacles* is read correctly for an electric equipment (*Office WholeBuilding - Sm Office Elec Equip*).
Expected output: the baseline schedule is 5% higher than proposed schedule for the electric equipment: *Office WholeBuilding - Sm Office Elec Equip*.

### Test case 2:
- Prototype: Small Office
- User data folder: */userdata_pe_02*
- Summary:
This case will test whether *receptacle_power_savings*  is read correctly for an electric equipment (*Office WholeBuilding - Sm Office Elec Equip*).
Expected output: the baseline schedule is 15% higher than proposed schedule for the electric equipment: *Office WholeBuilding - Sm Office Elec Equip*.

### Test case 3
- Prototype: Small Office
- User data folder: */userdata_pe_03*
- Summary:
This case will test whether *motor_horsepower*, *motor_efficiency* and *motor_is_exempt* are read correctly for an electric equipment (*Office WholeBuilding - Sm Office Elec Equip*).
Expected output: the electric equipment in the baseline shall have three additional properties *motor_horsepower = 10.0*, *motor_efficiency = 0.72* and *motor_is_exempt = False* 


### Test case 4
- Prototype: Small Office
- User data folder: */userdata_pe_04*
- Summary:
This case added space and space type to the user data. For equipment **Office WholeBuilding - Sm Office Elec Equip 4**, the receptacle credit was set to 0.05 however, it is then adjusted to 0.025 because one of the space type (conference/meeting/multipurpose) is on the exception list.