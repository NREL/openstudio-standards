# Building Technology Assessment Platform ( BTAP )


## Contents
----------
1) [Introduction](#introduction)
2) [Objective](#objective)
3) [Scope](#scope) 
4) [Commercial Building Archetypes](#commercial-building_archetypes) 
	1) [Creating New Building Archetypes](#creating-new-building-archetypes)
    	1) [3D Geometry and Space-type Method](#3d-geometry-and-spacetype-method)
        1) [Building Story Method](#building-story-method)
    1) [Ruleset Development](#ruleset-development)
    1) [Regional Data-Sources](#regional-data-sources)
    	1) [Fuel Use by System Type](#fuel-use-by-system-type)
        1) [Utility Rates](#utility-rates)
1) [Energy Conservation Measure Libraries](#energy-conservation-measure-libraries)
1) [Generating Data Results](#generating-data-results)
    1) [OpenStudio Spreadsheet Method](#openstudio-spreadsheet-method)
    1) [OpenStudio PAT Method](#openstudio-pat-method)
1) [Outputs](#output)
	1) [3D HTML Viewer](#3d-html-viewer)
    1) [OSM File](#osm-file)
    1) [EnergyPlus HTML Output](#energyplus-html-output)
    1) [OpenStudio HTML Output](#openstudio-html-output)
    1) [QAQC JSON Output](#btap-qaqc-json-output)


## Introduction 

NRCan is developing a framework to assist in the analysis of the energy performance of technologies used in commercial buildings. The framework is based upon the U.S National Renewable Energy Laboratory's [Openstudio](https://www.openstudio.net/) software development kit. The software and data are opensource and available for download, inspection and modification.  It consists of four distinct components. 

* The [Standards project](https://github.com/NREL/openstudio-standards) which is a rules based engine that automates the creation of 'archetypes' for specific vintages.
* The Costing Project: Automatcially cost the baseline archetypes as well as some upgrade through an expert system. 
* The Energy Conservation Measures Project: A library of scripts that will apply canadian energy conservation measures to a building if applicable.
* The Solutions Database: This will be a database of optimized runs using the archetypes, costing and measures components.    
* Data- Visualization: Creation of visualizations of the simulation data like [this](https://canmet-energy.github.io/parallel-coordinates/) to better support designers and researchers. 

## Objective

NRCan is developing the Building Technology Assesment Platform (BTAP) to allow researchers, energy consultants, governments and utiltiies 
* to analyze different new construction design scenarios across building types and locations in Canada in a fast and efficient manner.
* to determine what technologies and designs are most cost effective.
* to help define realistic code and design targets.    

## Scope
This work is predominately focused on new construction for the time being. However older vintages can be developed. The vintages are mapped to the [National Energy Code for Buildings](http://www.nrcan.gc.ca/energy/efficiency/buildings/eenb/codes/4037), and uses this as the sole input for building generation. 

## Commercial Building Archetypes

The commercial btap archetypes are created in two steps, the development of a spacetype geometric model, and then a ruleset that is applied to the model that populates the model with correct envelope and HVAC charecteristics for various geographic locations in Canada and the US. 

BTAP comes with 16 built-in commercial building spacetype geometric models. The are based on the U.S. DOE reference building archetypes, but gutted of everything except the geometry and space type information.  

The 16 building types are: 

|BUILDING TYPE NAME|FLOOR AREA (FT2)|NUMBER OF FLOORS|
|-----------------|----------------|----------------|
|Large Office|	498,588 |	12|
|Medium Office|	53,628|	3|
|Small Office	|5,500|	1|
|Warehouse|	52,045|	1|
|Stand-alone Retail|	24,962|	1|
|Strip Mall|	22,500|	1|
|Primary School|	73,960|	1|
|Secondary School|	210,887|	2|
|Supermarket|	45,000|	1|
|Quick Service Restaurant|	2,500|	1|
|Full Service Restaurant|	5,500|	1|
|Hospital|	241,351|	5|
|Outpatient Health Care|	40,946|	3|
|Small Hotel|	43,200|	4|
|Large Hotel|	122,120|	6|
|Midrise Apartment|	33,740|	4|

A ruleset is then applied to these skeleton geometric models to add the correct envelope and HVAC systems depending on the ruleset vintage and the model's city being considered.  

The standards project supports these vintage building codes: 
* ASHRAE90.1-2004
* ASHRAE90.1-2007
* ASHRAE90.1-2010
* ASHRAE90.1-2013
* DOEReference 1980to2004
* DOEReference Pre1980
* NECB 2011
* NECB 2015* 
* NECB 2017*


NRCan is repsonsible for the development of the Canadian rulesets. The NECB 2015 and 2017 are under development. 

### Creating New Building Archetypes

The standards project was developed to quickly generate new archetype buildings quickly based on NECB rulesets. To create a new archetype you need define the shape of the building and provide information on what activities are going on in the building.

#### 3D Geometry and Spacetype Method

The geometry and spaces can be created using the Sketchup plug-in for OpenStudio as well as the Openstudio App. The spaces must be assigned to an NECB space-type standard name. The space type contains information on schedules, lighting, outdoor air, plug loads, and heating and cooling as well as what typical HVAC systems are installed to support the space use activities.  The space-types are clearly defined in the NECB standard. This is the basis of how the building in generated by the standards engine. 

A complete listing of the NECB 2011 spacetypes can be found in section A-8.4.3.3 in the NECB 2011. You can programmatically access the space types in json format in the [NECB 2011 data folder](https://github.com/NREL/openstudio-standards/tree/master/lib/openstudio-standards/standards/necb/necb_2011/data) You can also request a Openstudio library file that contains all the NECB spacetypes to populate your model. 

#### Building Story Method
(This is under development.) 

Another non-geometry method that NRCan is developing is to simply give: 
* the floor area 
* the number of floors 
* the weighted percentage of spacetypes used in the building.
* the aspect ratio

This will create a rectangular model with all the space types represented.  This is currently under development, but may be useful in data-driven analysis.  With this information, BTAP can fill in all the other information to create the HVAC, envelope, and schedule for the building model. 


### Ruleset Development

NRCan is responsible for the development of the NECB vintage ruleset. These NECB rulesets can be modified through programming and changing data inputs. The ruleset was developed using an object oriented design and simple inheritance. For example, the main ruleset code for the NECB 2011 code logic, written in Ruby, is contained [here](https://github.com/NREL/openstudio-standards/tree/nrcan/lib/openstudio-standards/standards/necb/necb_2011) in the NECB2011 class.   

The raw data is also directly derived from the NECB 2011 standard. This includes tables, efficiencies, etc. The data is stored in JSON files [here](https://github.com/NREL/openstudio-standards/tree/nrcan/lib/openstudio-standards/standards/necb/necb_2011/data)

The data and code are used as inputs to create NECB reference archetypes. 

Subsequent versions of the NECB standard are simply sub-classes of the NECB 2011 ruleset. This allows us to create new rulesets for other vintages based on the NECB very quickly as we simply code what has changed in the data and the logic, and reuse the code from the previous vintages.  The same design we developed with NREL is used for the A90.1 rulesets. 

### Regional Datasources
BTAP uses the climate file used in the simulation to determine the Heating Degree-Day (HDD) to set the correct envelope charecteristics for the climate, the utilty rates, and the costing information. 

#### Fuel Use by System Type 
The standards used the climate file to decide what fuel types to assign to the building. Currenlty the resolution is at the provincial level. You can see the fuel types that are used by system and plant equipment defined in this JSON file [here](https://github.com/NREL/openstudio-standards/blob/nrcan/lib/openstudio-standards/standards/necb/necb_2011/data/regional_fuel_use.json)

This is rather coarse, but this can be improved easily as more data becomes available at the city level. 

#### Utility Rates
The archetypes use two methods to determine the utility energy costs. BTAP will output the National Energy Board Rates automatically with each run. It will also calculate time of use and block charge rates separately. These block charges rates were obtained from a survey of utilities across the country. A list of the utility rates can be found [here](https://github.com/canmet-energy/btap/blob/master/measures/BTAPUtilityTariffs/resources/Energy%20rates_2015.xls)

## Energy Conservation Measure Libraries
The Openstudio framework supports a scripted Ruby language environment to develop ECMs. This ECMs take in a set of arguments and modify the base building model. ECMs can change envelope conductivity, replace hvac systems, modify schedules, introduce control strategies and more. BTAP utilizes this feature of OpenStudio to modify the building model in an automated fashion. This is use in our parametric analysis of design scenarios.  The benefit of these measure is that they can be applied to ANY OpenStudio model. So the measures that we are developing for the archetypes can also be used by modellers on their projects. We are currently in the process of developing measures specifically for BTAP users in a consistent manner.

NREL has developed a [Measures Writing Guide](http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/) to help uses develop their own measures. 

There is also a on-line database of measures that have been developed by NREL and crowd sourced by users on the [Building Component Library Website](https://bcl.nrel.gov/)



## Generating Data 
There are many ways to generate the NECB models and run them to run the simulation and produce results. The preferred ways are using NREL's OpenStudio Spreadsheet, and to use The Openstudio PAT 2.0 tool. Both methods can use Amazon to create the runs and output the data. Both methods allow for parametric and optimization numerical methods. 

The CreateNECBPrototype measure contained in the projects require as input:
* building type
* epw_file

Subsequent measures can be added to the analysis as needed. 


### OpenStudio Spreadsheet Method
This method required you to install the ruby language interpreter on your system as well as git. It uses a spreadsheet to input data to run the archetype generator measure as well as any other measures. Full instructions on how to invoke the spreadsheet method on contained [here](https://github.com/canmet-energy/necb-analysis-spreadsheet). This methodology will be deprecated soon in favor of using PAT 2.0. 

### OpenStudio PAT Method
This method simply requires you to install a recent version of OpenStudio on your Mac or PC and a git client and run the load the BTAP project contained in this repository. Instructions on how to run the analysis will be contained here soon. Detailed instruction on PAT 2.0 itself can be found [here](http://nrel.github.io/OpenStudio-user-documentation/reference/parametric_analysis_tool_2/)


## Outputs

The btap simulation analysis produces various outputs. You can find a sample of a full national run of 16 building types over ~70 cities in this [git repository](https://github.com/canmet-energy/necb_2011_reference_buildings) 

### 3D HTML Viewer
The analysis produces a 3D HTML model of the geometry that can be reviewed to ensure geometry is correct. 

### OSM File 
The OpenStudio model files are created and available in the database result. This is to allow users to inspect the model and alter it and run it manually if they wish. 

### EnergyPlus HTML Output
This is the EnergyPlus HTML file

### OpenStudio HTML Output
This is the more detailed OpenStudio HTML report, which includes graphs. 

### QAQC JSON Output

The BTAP JSON format is a custom output format that contains high level information about the simulation. JSON format is a popular web and database standards with support built in for all modern languages and is supported by database engines like MongoDB and SQLite. It is supported also by recent versions of Excel and Tableau. It is extremely fast to parse and easy to read by humans as it follows a tree hierarchy structure. 

The output of this is a subset of the output available by EnergyPlus. Data is being added to the BTAP JSON file on a regular basis as needed.  For a full list of outputs available from EnergyPlus,  please refer to the [EnergyPlus Input/Output Documentation](https://bigladdersoftware.com/epx/docs/8-8/input-output-reference/) 

Below is an example of the output of a single Full Service Restaurant model in JSON. Multiple JSON files can be concatenated together for analysis in big data software analytic tools like tableau.  


```json
{
  "os_standards_revision": "0d4548f",
  "os_standards_version": "0.1.15",
  "openstudio_version": "2.2.1.92a7ed37f1",
  "energyplus_version": "8.7.0",
  "date": "2018-01-16 21:58:07 +0000",
  "building": {
    "name": "-FullServiceRestaurant-NECB HDD Method-CAN_AB_Banff.CS.711220_CWEC2016.epw created: 2018-01-16 21:56:33 +0000",
    "conditioned_floor_area_m2": 511.15331569,
    "exterior_area_m2": 845.223329175342,
    "volume": 2384.1066906608494,
    "number_of_stories": 2
  },
  "geography": {
    "hdd": 5496.0,
    "cdd": 11.0,
    "climate_zone": "7a",
    "city": "Banff CS",
    "state_province_region": "AB",
    "country": "CAN",
    "latitude": 51.193,
    "longitude": -115.552
  },
  "spacetype_area_breakdown": {
    "space_function_-_undefined_-": 0,
    "space_function_dining_-_family_space": 371.74807149,
    "space_function_food_preparation": 139.4052442
  },
  "economics": {
    "electricity_cost": 7395.51,
    "electricity_cost_per_m2": 14.46828138054213,
    "natural_gas_cost": 2591.04,
    "natural_gas_cost_per_m2": 5.069007517837158,
    "total_cost": 9986.54,
    "total_cost_per_m2": 19.537269334777346,
    "additional_cost": 0.0,
    "additional_cost_per_m2": 0.0
  },
  "end_uses": {
    "heating_gj": 562.22,
    "cooling_gj": 4.94,
    "interior_lighting_gj": 98.39,
    "exterior_lighting_gj": 0,
    "interior_equipment_gj": 34.33,
    "exterior_equipment_gj": 0,
    "fans_gj": 59.35,
    "pumps_gj": 0.22,
    "heat_rejection_gj": 0,
    "humidification_gj": 0,
    "heat_recovery_gj": 0,
    "water_systems_gj": 138.06,
    "water_systems_water_m3": 379.87,
    "refrigeration_gj": 0,
    "generators_gj": 0,
    "total_end_uses_gj": 897.51,
    "total_end_uses_water_m3": 379.87
  },
  "end_uses_eui": {
    "heating_gj_per_m2": 1.0999048284389308,
    "cooling_gj_per_m2": 0.00966441935983835,
    "interior_lighting_gj_per_m2": 0.19248627951710431,
    "exterior_lighting_gj_per_m2": 0,
    "interior_equipment_gj_per_m2": 0.06716184547029364,
    "exterior_equipment_gj_per_m2": 0,
    "fans_gj_per_m2": 0.11610997753166115,
    "pumps_gj_per_m2": 0.00043039924274583747,
    "heat_rejection_gj_per_m2": 0,
    "humidification_gj_per_m2": 0,
    "heat_recovery_gj_per_m2": 0,
    "water_systems_gj_per_m2": 0.270095088424956,
    "water_systems_water_m3_per_m2": 0.7431625470084604,
    "refrigeration_gj_per_m2": 0,
    "generators_gj_per_m2": 0,
    "total_end_uses_gj_per_m2": 1.7558528379855298,
    "total_end_uses_water_m3_per_m2": 0.7431625470084604
  },
  "meter_peaks": {
    "electric_w": 15550.46,
    "natural_gas_w": 115955.78
  },
  "unmet_hours": {
    "cooling": 1.5,
    "heating": 0.0
  },
  "service_water_heating": {
    "total_nominal_occupancy": 44.152477477477476,
    "electricity_per_year": 0.0,
    "electricity_per_day": 0.0,
    "electricity_per_day_per_occupant": 0.0,
    "natural_gas_per_year": 138.06,
    "additional_fuel_per_year": 0.0,
    "water_m3_per_year": 379.87,
    "water_m3_per_day": 1.0393160054719561,
    "water_m3_per_day_per_occupant": 0.02353924547047489
  },
  "envelope": {
    "outdoor_walls_average_conductance_w_per_m2_k": 0.21,
    "outdoor_roofs_average_conductance_w_per_m2_k": 0.162,
    "ground_floors_average_conductance_w_per_m2_k": 0.757,
    "windows_average_conductance_w_per_m2_k": 2.2,
    "fdwr": 17.1,
    "srr": 0.0,
    "constructions": {
      "exterior_fenestration": [
        {
          "name": "Customized Fenestration: cond=0.220 tvis=0.220 tsol=0.232",
          "net_area_m2": 47.17,
          "thermal_conductance_m2_w_per_k": 2.2,
          "solar_transmittance": 0.6,
          "visible_tranmittance": 0.21
        }
      ],
      "exterior_opaque": [
        {
          "name": "Customized opaque construction Typical Insulated Exterior Mass Wall R-12.5 to conductance of 0.21",
          "net_area_m2": 228.55,
          "thermal_conductance_m2_w_per_k": 0.21,
          "solar_absorptance": 0.92
        },
        {
          "name": "Customized opaque construction Typical Insulated Metal Building Roof R-20.41 to conductance of 0.162",
          "net_area_m2": 569.51,
          "thermal_conductance_m2_w_per_k": 0.162,
          "solar_absorptance": 0.7
        }
      ],
      "ground": [
        {
          "name": "Customized opaque construction Typical Insulated Carpeted 6in Slab Floor to conductance of 0.757",
          "net_area_m2": 511.15,
          "thermal_conductance_m2_w_per_k": 0.757,
          "solar_absorptance": 0.7
        }
      ]
    }
  },
  "spaces": [
    {
      "name": "Kitchen",
      "multiplier": 1,
      "volume": 425.01870851696,
      "exterior_wall_area": 106.52720615999999,
      "space_type_name": "Space Function Food preparation",
      "thermal_zone": "Sp-Kitchen Sys-3 Flr-1 Sch-B HPlcmt-north ZN",
      "breathing_zone_outdoor_airflow_vbz": 0.1912,
      "infiltration_method": "Flow/ExteriorArea",
      "infiltration_flow_per_m2": 0.00025,
      "occupancy_schedule": "NECB-B-Occupancy",
      "occ_per_m2": 0.05,
      "lighting_w_per_m2": 10.7,
      "electric_w_per_m2": 10.0,
      "shw_m3_per_s": 0.0,
      "waterUseEquipment": [
        {
          "peak_flow_rate": 4.49574007408925e-06,
          "peak_flow_rate_per_area": 3.224943293840053e-08,
          "shw_watts_per_person": 119.86600971356044
        }
      ]
    },
    {
      "name": "attic",
      "multiplier": 1,
      "volume": 825.7024617851778,
      "exterior_wall_area": 0.0,
      "space_type_name": "Space Function - undefined -",
      "thermal_zone": "Sp-attic Sys-0 Flr-2 Sch-- undefined - HPlcmt-core ZN",
      "breathing_zone_outdoor_airflow_vbz": -1,
      "infiltration_method": "Flow/ExteriorArea",
      "infiltration_flow_per_m2": 0.00025,
      "occupancy_schedule": null,
      "waterUseEquipment": [

      ]
    },
    {
      "name": "Dining",
      "multiplier": 1,
      "volume": 1133.3855203587118,
      "exterior_wall_area": 169.19041208,
      "space_type_name": "Space Function Dining - family space",
      "thermal_zone": "Sp-Dining Sys-3 Flr-1 Sch-B HPlcmt-south ZN",
      "breathing_zone_outdoor_airflow_vbz": 1.3314,
      "infiltration_method": "Flow/ExteriorArea",
      "infiltration_flow_per_m2": 0.00025,
      "occupancy_schedule": "NECB-B-Occupancy",
      "occ_per_m2": 0.1,
      "lighting_w_per_m2": 9.6,
      "electric_w_per_m2": 1.0,
      "shw_m3_per_s": 0.0,
      "waterUseEquipment": [
        {
          "peak_flow_rate": 2.39515451281452e-05,
          "peak_flow_rate_per_area": 6.442950741383873e-08,
          "shw_watts_per_person": 119.86600070216548
        }
      ]
    }
  ],
  "thermal_zones": [
    {
      "name": "Sp-Dining Sys-3 Flr-1 Sch-B HPlcmt-south ZN",
      "floor_area": 371.74807149,
      "multiplier": 1,
      "is_conditioned": "Yes",
      "is_ideal_air_loads": false,
      "heating_sizing_factor": 1.3,
      "cooling_sizing_factor": 1.1,
      "zone_heating_design_supply_air_temperature": 43.0,
      "zone_cooling_design_supply_air_temperature": 13.0,
      "spaces": [
        {
          "name": "Dining",
          "type": "Space Function Dining - family space"
        }
      ],
      "equipment": [
        {
          "name": "Air Terminal Single Duct Uncontrolled 2",
          "type": "StraightComponent"
        },
        {
          "name": "Zone HVAC Baseboard Convective Water 2",
          "type": "ZoneHVACComponent"
        }
      ]
    },
    {
      "name": "Sp-attic Sys-0 Flr-2 Sch-- undefined - HPlcmt-core ZN",
      "floor_area": 511.15331569,
      "multiplier": 1,
      "is_conditioned": "No",
      "is_ideal_air_loads": false,
      "heating_sizing_factor": -1.0,
      "cooling_sizing_factor": -1.0,
      "zone_heating_design_supply_air_temperature": 40.0,
      "zone_cooling_design_supply_air_temperature": 14.0,
      "spaces": [
        {
          "name": "attic",
          "type": "Space Function - undefined -"
        }
      ],
      "equipment": [

      ]
    },
    {
      "name": "Sp-Kitchen Sys-3 Flr-1 Sch-B HPlcmt-north ZN",
      "floor_area": 139.4052442,
      "multiplier": 1,
      "is_conditioned": "Yes",
      "is_ideal_air_loads": false,
      "heating_sizing_factor": 1.3,
      "cooling_sizing_factor": 1.1,
      "zone_heating_design_supply_air_temperature": 43.0,
      "zone_cooling_design_supply_air_temperature": 13.0,
      "spaces": [
        {
          "name": "Kitchen",
          "type": "Space Function Food preparation"
        }
      ],
      "equipment": [
        {
          "name": "Air Terminal Single Duct Uncontrolled 1",
          "type": "StraightComponent"
        },
        {
          "name": "Zone HVAC Baseboard Convective Water 1",
          "type": "ZoneHVACComponent"
        }
      ]
    }
  ],
  "air_loops": [
    {
      "name": "Sp-Kitchen Sys-3 Flr-1 Sch-B HPlcmt-north ZN NECB System 3 PSZ",
      "thermal_zones": [
        "Sp-Kitchen Sys-3 Flr-1 Sch-B HPlcmt-north ZN"
      ],
      "total_floor_area_served": 139.4052442,
      "supply_fan": {
        "type": "CV",
        "name": "Fan Constant Volume 1",
        "fan_efficiency": 0.39975,
        "motor_efficiency": 0.615,
        "pressure_rise": 640.0,
        "max_air_flow_rate": -1.0
      },
      "economizer": {
        "name": "Controller Outdoor Air 1",
        "control_type": "NoEconomizer"
      },
      "cooling_coils": {
        "dx_single_speed": [
          {
            "name": "Coil Cooling DX Single Speed 1 17kBtu/hr 14.0SEER",
            "cop": 3.8248,
            "nominal_total_capacity_w": 5000.03
          }
        ],
        "dx_two_speed": [

        ]
      },
      "heating_coils": {
        "coil_heating_gas": [
          {
            "name": "Coil Heating Gas 1",
            "type": "Gas",
            "efficency": 0.8
          }
        ],
        "coil_heating_electric": [

        ],
        "coil_heating_water": [

        ]
      }
    },
    {
      "name": "Sp-Dining Sys-3 Flr-1 Sch-B HPlcmt-south ZN NECB System 3 PSZ",
      "thermal_zones": [
        "Sp-Dining Sys-3 Flr-1 Sch-B HPlcmt-south ZN"
      ],
      "total_floor_area_served": 371.74807149,
      "supply_fan": {
        "type": "CV",
        "name": "Fan Constant Volume 2",
        "fan_efficiency": 0.39975,
        "motor_efficiency": 0.615,
        "pressure_rise": 640.0,
        "max_air_flow_rate": -1.0
      },
      "economizer": {
        "name": "Controller Outdoor Air 2",
        "control_type": "DifferentialEnthalpy"
      },
      "cooling_coils": {
        "dx_single_speed": [
          {
            "name": "Coil Cooling DX Single Speed 2 75kBtu/hr 9.7EER",
            "cop": 3.33578834974707,
            "nominal_total_capacity_w": 22039.04
          }
        ],
        "dx_two_speed": [

        ]
      },
      "heating_coils": {
        "coil_heating_gas": [
          {
            "name": "Coil Heating Gas 2",
            "type": "Gas",
            "efficency": 0.8
          }
        ],
        "coil_heating_electric": [

        ],
        "coil_heating_water": [

        ]
      }
    }
  ],
  "plant_loops": [
    {
      "name": "Hot Water Loop",
      "design_loop_exit_temperature": 82.0,
      "loop_design_temperature_difference": 16.0,
      "pumps": [
        {
          "name": "Pump Variable Speed 1",
          "type": "Pump:VariableSpeed",
          "head_pa": 179352.0,
          "water_flow_m3_per_s": 0.000255,
          "electric_power_w": 83.65,
          "motor_efficency": 0.7
        }
      ],
      "boilers": [
        {
          "name": "Primary Boiler 58kBtu/hr 0.85 AFUE",
          "type": "Boiler:HotWater",
          "fueltype": "NaturalGas",
          "nominal_capacity": 16999.5988238892
        },
        {
          "name": "Secondary Boiler 0kBtu/hr 0.85 AFUE",
          "type": "Boiler:HotWater",
          "fueltype": "NaturalGas",
          "nominal_capacity": 0.001
        }
      ],
      "chiller_electric_eir": [

      ],
      "cooling_tower_single_speed": [

      ],
      "water_heater_mixed": [

      ]
    },
    {
      "name": "Main Service Water Loop",
      "design_loop_exit_temperature": 60.0000000000001,
      "loop_design_temperature_difference": 5.0,
      "pumps": [
        {
          "name": "Service Water Loop Pump",
          "type": "Pump:ConstantSpeed",
          "head_pa": 29891.0,
          "water_flow_m3_per_s": 2.8e-05,
          "electric_power_w": 1.56,
          "motor_efficency": 0.7
        }
      ],
      "boilers": [

      ],
      "chiller_electric_eir": [

      ],
      "cooling_tower_single_speed": [

      ],
      "water_heater_mixed": [
        {
          "name": "200gal NaturalGas Water Heater - 200kBtu/hr 0.807 Therm Eff",
          "type": "WaterHeater:Mixed",
          "heater_thermal_efficiency": 0.807222539674442,
          "heater_fuel_type": "NaturalGas"
        }
      ]
    }
  ],
  "eplusout_err": {
    "warnings": [
      " ** Warning ** IP: IDF line~6 Alpha Argument length exceeds maximum, will be truncated=  -FullServiceRestaurant-NECB HDD Method-CAN_AB_Banff.CS.711220_CWEC2016.epw created: 2018-01-16 21:56:33 +000   **   ~~~   ** Will be processed as Alpha=-FULLSERVICERESTAURANT-NECB HDD METHOD-CAN_AB_BANFF.CS.711220_CWEC2016.EPW CREATED: 2018-01-16 21:56:33 +0000",
      "ProcessScheduleInput: Schedule:Day:Interval=\"ECONOMIZER MAX OA FRACTION 100 PCT DEFAULT\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Day:Interval=\"SCHEDULE DAY 1\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Day:Interval=\"SCHEDULE DAY 10\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Day:Interval=\"SCHEDULE DAY 11\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Day:Interval=\"SCHEDULE DAY 12\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Day:Interval=\"SCHEDULE DAY 2\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Day:Interval=\"SCHEDULE DAY 5\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Day:Interval=\"SCHEDULE DAY 6\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Day:Interval=\"SCHEDULE DAY 7\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Day:Interval=\"SCHEDULE DAY 8\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Day:Interval=\"SCHEDULE DAY 9\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Year=\"ECONOMIZER MAX OA FRACTION 100 PCT\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Year=\"SCHEDULE RULESET 3\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Year=\"SCHEDULE RULESET 4\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Year=\"SCHEDULE RULESET 5\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Year=\"SCHEDULE RULESET 6\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Year=\"SCHEDULE RULESET 7\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Year=\"SCHEDULE RULESET 8\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Constant=\"ALWAYS OFF DISCRETE\", Blank Schedule Type Limits Name input -- will not be validated.",
      "ProcessScheduleInput: Schedule:Constant=\"ALWAYS ON CONTINUOUS\", Blank Schedule Type Limits Name input -- will not be validated.",
      "CheckUsedConstructions: There are 24 nominally unused constructions in input.  For explicit details on each unused construction, use Output:Diagnostics,DisplayExtraWarnings;",
      "GetDXCoils: Coil:Cooling:DX:SingleSpeed=\"COIL COOLING DX SINGLE SPEED 2 75KBTU/HR 9.7EER\", invalid  ...Part Load Fraction Correlation Curve Name = DXCOOL-NECB2011-REF-COOLPLFFPLR 1 has out of range value.  ...Curve maximum must be <= 1.0, curve max at PLR = 0.99 is 1.015  ...Setting curve maximum to 1.0 and simulation continues.",
      "GetDXCoils: Coil:Cooling:DX:SingleSpeed=\"COIL COOLING DX SINGLE SPEED 1 17KBTU/HR 14.0SEER\", invalid  ...Part Load Fraction Correlation Curve Name = DXCOOL-NECB2011-REF-COOLPLFFPLR has out of range value.  ...Curve maximum must be <= 1.0, curve max at PLR = 0.99 is 1.015  ...Setting curve maximum to 1.0 and simulation continues.",
      "The Standard Ratings is calculated for Coil:Cooling:DX:SingleSpeed = COIL COOLING DX SINGLE SPEED 2 75KBTU/HR 9.7EER but not at the AHRI test condition due to curve out of bound.   Review the Standard Ratings calculations in the Engineering Reference for this coil type. Also, use Output:Diagnostics, DisplayExtraWarnings for further guidance.",
      "The Standard Ratings is calculated for Coil:Cooling:DX:SingleSpeed = COIL COOLING DX SINGLE SPEED 1 17KBTU/HR 14.0SEER but not at the AHRI test condition due to curve out of bound.   Review the Standard Ratings calculations in the Engineering Reference for this coil type. Also, use Output:Diagnostics, DisplayExtraWarnings for further guidance.",
      "Output:Meter: invalid Name=\"DISTRICTCOOLING:FACILITY\" - not found.",
      "Output:Meter: invalid Name=\"DISTRICTHEATING:FACILITY\" - not found.",
      "Output:Meter:MeterFileOnly requested for \"Electricity:Facility\" (TimeStep), already on \"Output:Meter\". Will report to both eplusout.eso and eplusout.mtr",
      "CalcDoe2DXCoil: Coil:Cooling:DX:SingleSpeed \"COIL COOLING DX SINGLE SPEED 1 17KBTU/HR 14.0SEER\" - Full load outlet air dry-bulb temperature < 2C. This indicates the possibility of coil frost/freeze. Outlet temperature = -2.80 C.   ...Occurrence info = RUN PERIOD 1, 02/02 08:02 - 08:05  ... Possible reasons for low outlet air dry-bulb temperatures are: This DX coil     1) may have a low inlet air dry-bulb temperature. Inlet air temperature = 12.008 C.     2) may have a low air flow rate per watt of cooling capacity. Check inputs.     3) is used as part of a HX assisted cooling coil which uses a high sensible effectiveness. Check inputs.",
      "The following Report Variables were requested but not generated  because IDF did not contain these elements or misspelled variable name -- check .rdd file",
      "Plant loop falling below lower temperature limit, PlantLoop=\"MAIN SERVICE WATER LOOP\"",
      "CalcDoe2DXCoil: Coil:Cooling:DX:SingleSpeed=\"COIL COOLING DX SINGLE SPEED 1 17KBTU/HR 14.0SEER\" - Full load outlet temperature indicates a possibility of frost/freeze error continues. Outlet air temperature statistics follow:"
    ],
    "fatal": [

    ],
    "severe": [

    ]
  },
  "ruby_warnings": [
    "space.spaceType.get.defaultScheduleSet.get.numberofPeopleSchedule is empty for attic",
    "zone.sizingZone.zoneHeatingSizingFactor is empty for Sp-attic Sys-0 Flr-2 Sch-- undefined - HPlcmt-core ZN",
    "zone.sizingZone.zoneCoolingSizingFactor is empty for Sp-attic Sys-0 Flr-2 Sch-- undefined - HPlcmt-core ZN",
    "Fan Constant Volume 1 does not exist in sql file WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Fans' AND ColumnName='Max Air Flow Rate' AND Units='m3/s'",
    "Fan Constant Volume 2 does not exist in sql file WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Fans' AND ColumnName='Max Air Flow Rate' AND Units='m3/s'"
  ],
  "sanity_check": {
    "fail": [
      "[ERROR][SANITY_CHECK-FAIL] for [SPACE][attic] and [THERMAL ZONE] [Sp-attic Sys-0 Flr-2 Sch-- undefined - HPlcmt-core ZN] where isConditioned is supposed to be [Yes] but found as No"
    ],
    "pass": [
      "[TEST-PASS][SANITY_CHECK-PASS] for [SPACE][Dining] and [THERMAL ZONE] [Sp-Dining Sys-3 Flr-1 Sch-B HPlcmt-south ZN] where isConditioned is supposed to be [Yes] and found as Yes",
      "[TEST-PASS][SANITY_CHECK-PASS] for [SPACE][Kitchen] and [THERMAL ZONE] [Sp-Kitchen Sys-3 Flr-1 Sch-B HPlcmt-north ZN] where isConditioned is supposed to be [Yes] and found as Yes"
    ]
  },
  "is_baseline": "false",
  "measures": [
    {
      "name": "create_prototype_building",
      "arguments": {
        "__SKIP__": false,
        "building_type": "FullServiceRestaurant",
        "climate_zone": "NECB HDD Method",
        "epw_file": "CAN_AB_Banff.CS.711220_CWEC2016.epw",
        "template": "NECB 2011"
      },
      "display_name": "Create Prototype Building",
      "measure_class_name": "CreatePrototypeBuilding",
      "index": 0,
      "is_ecm": false
    },
    {
      "name": "view_model",
      "arguments": {
        "__SKIP__": false
      },
      "display_name": "ViewModel",
      "measure_class_name": "ViewModel",
      "index": 1,
      "is_ecm": false
    },
    {
      "name": "btaputilitytariffs",
      "arguments": {
        "__SKIP__": false
      },
      "display_name": "Utility Tariffs Model Setup",
      "measure_class_name": "UtilityTariffsModelSetup",
      "index": 2,
      "is_ecm": false
    },
    {
      "name": "btapreportvariables",
      "arguments": {
        "__SKIP__": false,
        "reporting_frequency": "hourly"
      },
      "display_name": "BTAP Zone Report Variables",
      "measure_class_name": "BTAPReportVariables",
      "index": 3,
      "is_ecm": false
    },
    {
      "name": "btapresults",
      "arguments": {
        "__SKIP__": false,
        "generate_hourly_report": "false"
      },
      "display_name": "BTAP Results",
      "measure_class_name": "BTAPResults",
      "index": 4,
      "is_ecm": false
    },
    {
      "name": "openstudioresults",
      "arguments": {
        "__SKIP__": false
      },
      "display_name": "OpenStudio Results",
      "measure_class_name": "OpenStudioResults",
      "index": 5,
      "is_ecm": false
    }
  ]
}
```
### simulations.json
This file is downloadable from the OpenStudio NRCan server. It is a single file that contains all the the qaqc.json for each simulation. This file is rather large and editors may have a problem opening it. Tableau can has a limit to the file size of json it can process.  You can use MS PowerBI to analyis the data as a whole. You can use Mongodb to load and filter the data as well.

Run the Ideal loads on Amazon using PAT. 
Download the Simulations.json file from the run. 
Import the JSON data into MongoDB on Elmo. Where btap is the name of the database and simulations_runs is the name of the collection/table. 
```
	mongoimport -h 132.156.197.127:27018 --db btap --collection simulation_runs --file ~/windows-host/IdealAir/simulations.json --jsonArray
```
Query the database to get what you need and eliminate what you do not need. 
```
	mongo --host 132.156.197.127:27018 btap -eval "printjsononeline( db.simulation_runs.find( {},{ _id :0, information :0, warnings :0, errors :0, unique_errors :0, sanity_check :0, thermal_zones :0, spaces :0} ).toArray()) " > ~/windows-host/test1.json
```
For more information on creating MongoDB queries.. look [here](https://www.tutorialspoint.com/mongodb/mongodb_query_document.htm)

Note: You can use you own installation of MongoDB if you wish. Simply change the IP address accordingly. 



