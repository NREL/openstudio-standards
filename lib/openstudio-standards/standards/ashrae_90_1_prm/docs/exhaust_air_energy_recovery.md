Exhaust Air Energy Recovery

# ASHRAE 90.1-2019
## Section G3.1.2.10 Exhaust Air Energy Recovery

Individual fan systems that have both a design supply air capacity of 5000 cfm or greater and have a minimum design outdoor air supply of 70% or greater shall have an energy recovery system with at least 50% enthalpy recovery ratio. Fifty percent enthalpy recovery ratio shall mean a change in the enthalpy of the outdoor air supply equal to 50% of the difference between the outdoor air and return air at design conditions. Provision shall be made to bypass or control the heat recovery system to permit air economizer operation, where applicable.

If any of these exceptions apply, exhaust air energy recovery shall not be included in the baseline
building design:
1. Systems serving spaces that are not cooled and that are heated to less than 60°F.
2. Systems exhausting toxic, flammable, or corrosive fumes or paint or dust. This exception
shall only be used if exhaust air energy recovery is not used in the proposed design.
3. Commercial kitchen hoods (grease) classified as Type 1 by NFPA 96. This exception shall
only be used if exhaust air energy recovery is not used in the proposed design.
4. Heating systems in Climate Zones 0 through 3.
5. Cooling systems in Climate Zones 3C, 4C, 5B, 5C, 6B, 7, and 8.
6. Where the largest exhaust source is less than 75% of the design outdoor airflow. This exception
shall only be used if exhaust air energy recovery is not used in the proposed design.
7. Systems requiring dehumidification that employ energy recovery in series with the cooling
coil. This exception shall only be used if exhaust air energy recovery and series-style
energy recovery coils are not used in the proposed design.

# Code Requirement Interpretation
The code requirement is straightforward, so are the exception.

# Implementation
The requirement poses one main challenge: EnergyPlus/OpenStudio doesn't support enthalpy recovery ratio (ERR) as a modeling input, so the effectiveness associated with a specific enthalpy recovery ratio have to be determined. There is no direct conversion from ERR to effectiveness as the ERR depends on specific design conditions which are not prescribed either by the rating standard or 90.1. PNNL did some preliminary research using data from one manufacturer to derive reasonable effectiveness values from the code required 50% ERR. The findings were implemented in OpenStudio-Standards through this [pull request](https://github.com/NREL/openstudio-standards/pull/1165) when adding 90.1-2019 version of the prototype building models. The same regressions were used to make generated baseline model comply with this requirement.

Exception 1 is automatically handled by checking the thermostats of all zones served by an air loop, if at least one of them is heated to less than 60F, an ERV is not modeled in the baseline model. Exception 2, 3, 6, and 7 are handled through user data inputs. Exception 5 is ignored since all baseline models in Appendix G are modeled as cooled. Exception 4 is automatically handled by code and relates to heating and ventilation only systems in hot climate zones.

# Key Ruby Methods
- `air_loop_hvac_apply_energy_recovery_ventilator_efficiency`: Set effectiveness value of an ERV's heat exchanger
- `air_loop_hvac_energy_recovery_ventilator_flow_limit`: Determine the airflow limits that govern whether or not an ERV is required (this is where the exceptions are evaluated, if none apply the limit is set to 5000 cfm)
- `heat_exchanger_air_to_air_sensible_and_latent_minimum_effectiveness`: Defines the minimum sensible and latent effectiveness of the heat exchanger
- `heat_exchanger_air_to_air_sensible_and_latent_design_conditions`: Determine the heat exchanger design conditions for a specific climate zones
- `heat_exchanger_air_to_air_sensible_and_latent_enthalpy_recovery_ratio`: Determine the required enthalpy recovery ratio (currently defaulted to 0.5)