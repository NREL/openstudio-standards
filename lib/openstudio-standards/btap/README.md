# BTAP (Building Technology Assessment Platform)

## Overview

BTAP is a comprehensive building analysis and costing framework developed by Natural Resources Canada (NRCan) for large-scale building energy modeling, cost analysis, and energy conservation measure (ECM) evaluation. It provides advanced capabilities for building portfolio analysis, lifecycle cost assessment, and Canadian building code compliance.

## Architecture

BTAP is organized into three main components:

### Core BTAP Framework
High-level building modeling and analysis tools located in the root `btap/` directory.

### Utilities Submodule  
Specialized tools and helper functions in `btap/utilities/`.

### Costing Framework
Comprehensive building component costing system in `btap/costing/`.

## Core Modules

### Primary Framework Files

#### `btap.rb` - Main BTAP Module
- **Purpose**: Core BTAP functionality and common utilities
- **Key Features**:
  - Simulation settings management
  - Output variable configuration and management  
  - Ruby class extensions (String, Integer, Boolean conversions)
  - OpenStudio library integration
  - Common validation utilities
- **Key Classes**: `BTAP`, `BTAP::SimulationSettings`, `BTAP::Reports`, `BTAP::Common`

#### `envelope.rb` - Building Envelope Analysis  
- **Purpose**: Advanced building envelope analysis and modification
- **Key Features**:
  - Construction customization and thermal property adjustments
  - Thermal conductance calculations and modifications
  - Adiabatic surface handling and assignment
  - Construction set management and customization
  - Cost integration for envelope modifications
- **Key Classes**: `BTAP::Resources::Envelope`, `BTAP::Resources::Envelope::Constructions`

#### `geometry.rb` - Advanced Geometry Operations
- **Purpose**: Comprehensive 3D building geometry manipulation
- **Key Features**:
  - Space enumeration and management
  - Surface matching and intersection operations
  - Building and model scaling operations
  - Fenestration-to-wall ratio (FWDR) and skylight-to-roof ratio (SRR) calculations
  - Building rotation and orientation changes
  - Perimeter vs core space identification
  - Surface filtering by boundary conditions, types, and orientations
- **Key Classes**: `BTAP::Geometry`, `BTAP::Geometry::Surfaces`, `BTAP::Geometry::Spaces`

#### `fileio.rb` - File I/O Operations
- **Purpose**: Comprehensive file handling for building energy models
- **Key Features**:
  - OSM/IDF file loading, saving, and conversion
  - Model comparison and validation
  - CSV processing and data extraction
  - EnergyPlus simulation result processing
  - Time series data extraction and analysis
  - Model cleaning and optimization utilities
- **Key Classes**: `BTAP::FileIO`

#### `schedules.rb` - Schedule Management
- **Purpose**: Building schedule creation and manipulation
- **Dependencies**: Core BTAP utilities

#### `bridging.rb` - Thermal Bridging Analysis
- **Purpose**: Advanced thermal bridging calculations for envelope performance
- **Dependencies**: Envelope module

#### `vintagizer.rb` - Building Vintage Analysis
- **Purpose**: Building performance assessment based on construction vintage
- **Key Features**:
  - Envelope performance analysis by building age
  - Infiltration rate adjustments for vintage buildings
  - Equipment efficiency assessment (fans, pumps, HVAC)
  - Building upgrade recommendations
- **Key Classes**: `Vintagizer`

#### `visualization.rb` - Model Visualization
- **Purpose**: Building model visualization and reporting tools
- **Dependencies**: Geometry, FileIO modules

#### `btap_result.rb` - Results Processing  
- **Purpose**: Comprehensive analysis and processing of simulation results
- **Dependencies**: FileIO, SQL processing utilities

## Utilities Submodule (`utilities/`)

### Space and Building Management
- **`generate_space_types.rb`**: Automated space type generation and management
- **`space_type.rb`**: Space type utilities and operations
- **`rename_surfaces.rb`**: Surface naming and organization utilities

### Geometric Operations  
- **`round_surf_coords.rb`**: Surface coordinate rounding for geometric precision
- **`convert_surfaces_to_adiabatic_necb_8426.rb`**: Adiabatic surface conversion utilities
- **`set_mult_to_adiabatic.rb`**: Surface multiplier handling for adiabatic surfaces

### Data Processing
- **`os_sim_extract.rb`**: EnergyPlus simulation result extraction tools
- **`weatherData1_xlsx_to_json.rb`**: Weather data format conversion utilities
- **`necb_to_epw_map.rb`**: Canadian climate zone to weather file mapping
- **`sched_create.rb`**: Advanced schedule creation utilities

## Costing Framework (`costing/`)

The BTAP costing framework is one of the most comprehensive building cost analysis systems available, providing detailed lifecycle cost analysis for all building systems.

### Main Costing Engine

#### `btap_costing.rb` - Core Costing System
- **Purpose**: Main costing engine with regional cost factor integration
- **Key Features**:
  - Regional cost factor calculations and interpolation
  - Construction cost database generation for Canadian cities
  - Distance-based cost interpolation between locations
  - Comprehensive cost auditing capabilities
  - Integration with mechanical sizing data
- **Key Classes**: `BTAPCosting`, `SimpleLinearRegression`

### Component-Specific Costing Modules

#### Building Systems Costing
- **`envelope_costing.rb`**: Building envelope component costs (walls, roofs, foundations, windows)
- **`lighting_costing.rb`**: Traditional lighting system costs
- **`led_lighting_costing.rb`**: LED lighting upgrade costs and payback analysis
- **`heating_cooling_costing.rb`**: HVAC equipment costing (boilers, chillers, heat pumps, etc.)
- **`ventilation_costing.rb`**: Ventilation system costs (fans, ductwork, air handling units)
- **`shw_costing.rb`**: Service hot water system costs (water heaters, piping, controls)

#### Advanced Systems Costing  
- **`dcv_costing.rb`**: Demand controlled ventilation system costs
- **`daylighting_sensor_control_costing.rb`**: Daylighting control system costs
- **`nv_costing.rb`**: Natural ventilation system costs
- **`pv_ground_costing.rb`**: Ground-mounted photovoltaic system costs

### Costing Database and Resources (`common_resources/`)

#### Cost Databases (CSV format)
- **`costs.csv`**: Base construction and material costs
- **`costs_local_factors.csv`**: Regional cost adjustment factors
- **`locations.csv`**: Geographic location data for cost interpolation

#### Material Databases  
- **`materials_opaque.csv`**: Opaque construction materials (insulation, concrete, etc.)
- **`materials_glazing.csv`**: Window and glazing materials
- **`materials_lighting.csv`**: Lighting equipment and components  
- **`materials_hvac.csv`**: HVAC equipment and components

#### Construction and Assembly Data
- **`constructions_opaque.csv`**: Wall, roof, and floor constructions
- **`constructions_glazing.csv`**: Window and glazing assemblies  
- **`construction_sets.csv`**: Complete construction set definitions
- **`ConstructionProperties.csv`**: Thermal and physical properties
- **`Constructions.csv`**: Construction assembly definitions

#### HVAC and Equipment Data
- **`hvac_vent_ahu.csv`**: Air handling unit specifications and costs
- **`lighting_sets.csv`**: Complete lighting system definitions
- **`lighting.csv`**: Individual lighting fixture data

### Testing and Validation Framework

#### Automated Testing
- **`test_run_costing_tests.rb`**: Main test runner for costing calculations
- **`test_run_all_test_locally.rb`**: Local test execution framework  
- **`parallel_tests.rb`**: Parallel test execution for large-scale validation
- **`copy_test_results_files_to_expected_results.rb`**: Test result management

#### Reference Data
- **`necb_reference_runs.csv`**: NECB reference building cost validation data
- **`neb_end_use_prices.csv`**: Canadian utility pricing for end-use analysis
- **`mech_sizing.json`**: Mechanical system sizing reference data

#### Workflow Integration
- **`btap_workflow.rb`**: Integration with larger BTAP analysis workflows
- **`btap_measure_helper.rb`**: OpenStudio measure integration utilities
- **`cost_building_from_file.rb`**: Automated costing from building definition files

## Data Resources

### Weather and Climate Data
- **`WeatherData1.json`**: Canadian weather station data and climate information  
- **`necb_2011_spacetype_info.csv`**: NECB space type definitions and characteristics

### Canadian-Specific Data
BTAP includes extensive Canadian building code integration:
- NECB space type mappings and building templates
- Provincial utility pricing and end-use energy costs  
- Regional construction cost factors across all Canadian provinces
- Climate zone mappings and weather data correlations

## Key Capabilities

### Large-Scale Analysis
- **Building Portfolio Analysis**: Process hundreds of building models efficiently
- **Parametric Studies**: Automated parameter sweeps for optimization
- **Regional Analysis**: Cost and performance analysis across different Canadian climates

### Cost Analysis  
- **Lifecycle Cost Analysis**: Complete building lifecycle cost assessment
- **Regional Cost Variations**: Accurate costing for all Canadian markets
- **ECM Cost-Benefit Analysis**: Economic analysis of energy conservation measures
- **Payback Calculations**: Simple and complex payback analysis for upgrades

### Canadian Building Code Integration
- **NECB Compliance**: Full integration with Canadian National Energy Code for Buildings
- **Provincial Variations**: Handle provincial differences in building codes and costs
- **Utility Integration**: Integration with Canadian utility rate structures

### Advanced Modeling Features
- **Building Vintage Assessment**: Analyze existing building performance by construction era
- **Retrofit Analysis**: Compare pre- and post-retrofit building performance
- **Thermal Bridging**: Advanced thermal bridging analysis for envelope performance
- **Automated QAQC**: Quality assurance and quality control for large model sets

## Usage Patterns

### Typical Workflow
1. **Model Import**: Load building model using FileIO utilities
2. **Geometry Processing**: Use Geometry module for spatial analysis
3. **Envelope Analysis**: Apply Envelope module for construction assessment  
4. **Costing Analysis**: Use comprehensive costing framework for economic analysis
5. **Results Processing**: Extract and analyze results using BTAPResult framework

### Integration Points  
- **OpenStudio SDK**: Full integration with OpenStudio building modeling
- **EnergyPlus**: Process EnergyPlus simulation results
- **NECB Standards**: Direct integration with Canadian building standards
- **Regional Data**: Canadian weather, utility, and cost databases

## Dependencies

### Core Dependencies
- OpenStudio SDK (building energy modeling)
- JSON (data processing)
- CSV (database operations)  
- Ruby standard libraries (file operations, mathematics)

### Internal Dependencies  
- All core OpenStudio-Standards modules (geometry, constructions, schedules, etc.)
- NECB standards integration
- Utilities module for common operations

## Development Notes

### Code Organization
- Modular design allows use of individual components or complete framework
- Consistent naming conventions across all modules
- Comprehensive test coverage for all costing calculations
- Extensive documentation and example usage

### Canadian Focus
BTAP was developed specifically for Canadian building analysis and includes:
- Canadian climate zone integration
- Provincial building code variations
- Canadian utility rate structures
- Regional construction cost databases
- Canadian-specific building archetypes and space types

This makes BTAP the most comprehensive tool available for Canadian building energy and cost analysis.