Elevators

# ASHRAE 90.1-2019
## Section G3.1.16 Elevators
Where the proposed design includes elevators, the baseline building design shall be modeled to include the elevator cab motor, ventilation fans, and lighting power. The elevator motor use shall be modeled with the same schedule as the proposed design. When included in the proposed design, the baseline elevator cab ventilation fan shall be 0.33 W/cfm and the lighting power density shall be 3.14 W/ft2; both operate continuously.

# Code Requirement Interpretation
The code requirement is straightforward, so are the exception.

# Implementation
The characteristics of the proposed model elevator(s) are provided by the user using the user data CSV file which includes the each elevator car weight, rated load, counter weight of the car, speed of the car, number of stories served by the elevator, the number of similar elevators, the floor area occupied the elevator, and the ventilation flow rate. The BHP and elevator power are calculated according to Section G3.1.16, the baseline elevator power is used in place of the proposed one (which can be through an electric equipment object or an exterior equipment fuel object). Process loads such as ventilation and lighting are modeled separately and as they are supposed to be modeled as operating continuously.

# Key Ruby Methods
- `model_add_prm_elevators`: Add baseline elevators based on user data