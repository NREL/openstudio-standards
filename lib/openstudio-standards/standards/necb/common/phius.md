# PHIUS performance indicators
The **phius_performance_indicators** method in btap_data.rb (see /lib/openstudio-standards/standards/necb/common/btap_data.rb) 
calculates energy demands and peak loads as per PHIUS and NECB.
Refer to below references for the parameters definitions and equations have used for this calculation:
* PHIUS 2021 Passive Building Standard Standard-Setting Documentation. 
Available at https://www.phius.org/phius-certification-for-buildings-products/project-certification/phius-2021-emissions-down-scale-up.
* Wright, L. (2019). Setting the Heating/Cooling Performance Criteria for the PHIUS 2018 Passive Building Standard. 
In ASHRAE Topical Conference Proceedings, pp. 399-409.
  
# Assumptions
For the calculation of energy demands and peak loads, the below assumptions have been made regarding the PHIUS-related parameters:
* **Unit density** is calculated using either of the below cases:
    * The unit density is the inverse of the floor area per unit if a building model is comprised of mainly spaces for staying over night, 
    such as dwelling suits in apartments, guest rooms in hotels, patient and recovery rooms in hospitals. 
    The list of space type names has been considered under this category is: 
    {"Dormitory - living quarters", "Dwelling Unit(s)", "Hotel/Motel - rooms", "Hway lodging - rooms", 
    "Guest room", "Dormitory living quarters", "Dwelling units general", "Dwelling units long-term", 
    "Fire station sleeping quarters", "Health care facility patient room", "Health care facility recovery room"}. 
    It has been assumed that if the percentage of the above spaces' total area of a building model's conditioned floor area is larger than 40%, the building model falls into this category. 
    For instance, ~41% of the LargeHotel archetype is rooms. Hence, the unit density of the LargeHotel archetype is the inverse of the floor area per the average area of its rooms.
    * The unit density is the inverse of a building model's conditioned floor area if the building model is comprised of mainly commercial spaces. 
    In other words, if the percentage of the above spaces' total area of a building model's conditioned floor area is below 40%, the building model falls into this category.
* The base humidity ratio for the calculation of **dehumidification degree-days** has been set as 0.010 based on Wright's (2019) article.