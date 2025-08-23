# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

OpenStudio-Standards is a Ruby Gem library extending the OpenStudio SDK for building energy modeling. It creates typical building models, applies building standards (ASHRAE 90.1, NECB), generates code baseline models, and checks model compliance against standards.

## Common Development Commands

### Setup and Dependencies
- `bundle install` - Install Ruby gem dependencies (run this first)
- `gem install bundler` - Install the bundler gem (one-time setup)

### Build and Package
- `bundle exec rake build` - Build the openstudio-standards gem into pkg/ directory
- `bundle exec rake install` - Build and install gem into system gems
- `bundle exec rake install:local` - Build and install gem without network access

### Testing
- `bundle exec rake test:circleci` - Run CircleCI tests (CI environment only)
- `bundle exec rake test:parallel_run_all_tests_locally` - Run all tests in parallel locally
- `ruby test/subdirectory/test_XX.rb` - Run a specific test file
- Test files are organized by category: 90_1_general/, 90_1_prm/, doe_prototype/, deer_prototype/, necb/, etc.

### Code Quality
- `bundle exec rake rubocop` - Check code style consistency
- `bundle exec rake rubocop:auto_correct` - Auto-correct RuboCop style issues
- `bundle exec rake rubocop:show` - Show RuboCop results in browser

### Documentation
- `bundle exec rake doc` - Generate YARD documentation
- `bundle exec rake doc:show` - Generate and display documentation in browser

### Data Management
- `bundle exec rake data:update` - Generate JSONs from OpenStudio_Standards spreadsheets
- `bundle exec rake data:export:jsons` - Export JSONs to data library
- `bundle exec rake data:update:costing` - Update RS-Means database

### Task Discovery
- `bundle exec rake -T` - List all available Rake commands

## Code Architecture

### Standards Class Hierarchy
The library uses inheritance for code reuse across different building standards:
- `Standard` (abstract base class in `standards/standard.rb`)
  - `ASHRAE901` (abstract class in `standards/ashrae_90_1/ashrae_90_1.rb`)
    - `ASHRAE9012004`, `ASHRAE9012007`, `ASHRAE9012010`, `ASHRAE9012013`, `ASHRAE9012016`, `ASHRAE9012019` (concrete classes)
    - `DOERefPre1980`, `DOERef19802004` (DOE reference building standards)
    - `NRELZNEReady2017`, `ZEAEDGMultifamily` (zero energy standards)
  - `ASHRAE901PRM2019` (Performance Rating Method for ASHRAE 90.1-2019)
  - `NECB2011`, `NECB2015`, `NECB2017`, `NECB2020` (Canadian National Energy Code for Buildings)
  - `ICCIECC2015` (International Code Council International Energy Conservation Code)
  - `CBES` (California Building Energy Standards - Title 24 versions from pre-1978 to 2008)
  - `DEER` (Database for Energy Efficiency Resources - multiple vintage years from pre-1975 to 2075)
  - `OEESC2014` (Ontario Energy Efficiency Standards for Commercial buildings)

Methods in base classes are inherited by child classes, but can be overridden for specific standard requirements.

### Standards Folder Structure
The `standards/` directory is organized as follows:

**Base Classes and Component Extensions:**
- `standard.rb` - Abstract base `Standard` class with core functionality
- `Standards.*.rb` files - Extensions for specific OpenStudio component types (e.g., `Standards.AirLoopHVAC.rb`, `Standards.ChillerElectricEIR.rb`, etc.)

**Standard-Specific Implementations:**
- `ashrae_90_1/` - ASHRAE 90.1 family of standards
  - Individual version folders: `ashrae_90_1_2004/`, `ashrae_90_1_2007/`, etc. through `ashrae_90_1_2019/`
  - DOE reference building standards: `doe_ref_pre_1980/`, `doe_ref_1980_2004/`  
  - Zero energy standards: `nrel_zne_ready_2017/`, `ze_aedg_multifamily/`
  - `data/` - JSON data files with standard-specific values
- `ashrae_90_1_prm/` - ASHRAE 90.1 Performance Rating Method (Appendix G modeling)
  - `ashrae_90_1_prm_2019/` - 2019 PRM implementation
  - `data/`, `docs/`, `userdata_csv/`, `userdata_json/` - Supporting data and documentation
- `necb/` - Canadian National Energy Code for Buildings (extensive Canadian building energy standards)
  - **NECB Standard Versions:**
    - `NECB2011/` - Full implementation with comprehensive systems (HVAC systems 1-8, building envelope, lighting, service water heating, electrical systems)
    - `NECB2015/` - Updated version with enhanced lighting and HVAC systems
    - `NECB2017/` - Newer version with HVAC system updates
    - `NECB2020/` - Latest version with building envelope and service water heating improvements
  - **BTAP (Building Technology Assessment Platform) Vintages:**
    - `BTAPPRE1980/` - Pre-1980 building standards with legacy HVAC systems and envelope specifications
    - `BTAP1980TO2010/` - Building standards covering 1980-2010 period
  - **Energy Conservation Measures:**
    - `ECMS/` - Energy Conservation Measures implementation including ERV, natural ventilation, ground-mounted PV systems, and HVAC ECMs
  - **Shared Resources:**
    - `common/` - Common data files including:
      - Carbon pricing schedules and utility pricing data
      - Electric and gas grid intensity data for emissions calculations
      - Reference runs data and space type upgrade mappings
      - System type definitions and construction defaults
      - BTAP datapoint handling utilities
    - `docs/` - Technical documentation including air system naming conventions
  
  **NECB Implementation Features:**
  - Climate zone-based requirements (Canadian climate zones)
  - Province-specific fuel type mappings and utility pricing
  - Comprehensive HVAC system types (1-8) with single-speed and multi-speed options
  - LED lighting compliance and occupancy sensor controls
  - Thermal bridging calculations and building envelope performance
  - BEPS (Building Energy Performance Standards) compliance pathways
  - Quality assurance and quality control (QAQC) reporting
  - Foundation modeling with Kiva integration
  - Demand controlled ventilation and energy recovery ventilation
  - Regional fuel use analysis and carbon pricing integration
- `icc_iecc/` - International Energy Conservation Code
  - `icc_iecc_2015/` - 2015 version implementation
- `cbes/` - California Building Energy Standards (Title 24)
  - Vintage folders from `cbes_pre_1978/` through `cbes_t24_2008/`
  - `data/` - California-specific standards data
- `deer/` - Database for Energy Efficiency Resources (California utility standards)
  - Extensive vintage coverage from `deer_pre_1975/` through `deer_2075/`
  - `data/` - DEER-specific efficiency data
- `oeesc/` - Ontario Energy Efficiency Standards for Commercial buildings
  - `oeesc_2014/` - 2014 version implementation

Each standard implementation typically includes component-specific override files (e.g., `*.AirLoopHVAC.rb`, `*.ChillerElectricEIR.rb`) that customize base class behavior for that particular standard's requirements.

### Module Organization
Core functionality is organized into modules within `lib/openstudio-standards/`:

#### Core Building Systems
- **`geometry/`** - Create, modify, and analyze building geometry
  - Bar building creation, custom shape creation, geometric transformations
  - Building form optimization, fenestration ratios, aspect ratio optimization
  - Climate-responsive design, parametric modeling, complex geometries
  - Integration with standards compliance and HVAC system requirements
- **`constructions/`** - Create, modify, and analyze building envelope constructions and materials
  - Opaque constructions (walls, roofs, floors), fenestration constructions (windows, doors)
  - Material management with thermal, optical, and physical property management
  - Climate optimization, standards integration, cost integration with BTAP framework
  - Construction validation and material compatibility verification
- **`hvac/`** - Create, modify, and analyze HVAC systems
  - Air loop systems, exhaust systems, setpoint management
  - CBECS integration, component management, control system integration
  - Integration with schedules, thermal zones, and standards requirements
- `create_typical/` - Create entire typical building energy models
- `daylighting/` - Daylighting controls and calculations
- `exterior_lighting/` - Create and manage exterior lighting systems and properties
- `infiltration/` - Handle building infiltration calculations and adjustments for different pressure conditions

#### Analysis and Quality Assurance
- `prototypes/` - Apply typical assumptions not governed by standards
- `qaqc/` - Quality assurance and quality control methods
- `sql_file/` - Handle EnergyPlus SQL output files for data extraction, including energy use and unmet hours

#### Support Systems
- `refrigeration/` - Create and manage refrigeration systems, cases, walk-ins, compressors, and compressor racks
- `refs/` - Contains reference classes for all building standards (ASHRAE 90.1 versions, NECB, DOE prototypes, etc.)
- `schedules/` - Create, modify, and get information about schedules
- `service_water_heating/` - Service water heating systems
- `space/` - Space-level operations including occupancy detection, load calculations, and hours of operation
- `thermal_zone/` - Thermal zone modifications
- `utilities/` - Common utility functions
- `weather/` - Weather file handling

#### Standards Framework
- `standards/` - Modify model inputs to meet specific standards (uses data/ directory)
- `btap/` - Building Technology Assessment Platform (BTAP) - Comprehensive building analysis and costing framework
  - **Core BTAP Modules:**
    - `btap.rb` - Main BTAP module with simulation settings, output variable management, and common utilities
    - `envelope.rb` - Building envelope analysis including construction customization, thermal conductance adjustments, and adiabatic surface handling
    - `geometry.rb` - Advanced geometry operations including space enumeration, surface matching, model scaling, fenestration ratios, and building rotation
    - `fileio.rb` - File I/O operations for OSM/IDF conversion, model loading/saving, CSV processing, and simulation result extraction
    - `schedules.rb` - Schedule management and manipulation utilities
    - `bridging.rb` - Thermal bridging calculations and analysis
    - `vintagizer.rb` - Building vintage analysis for envelope, infiltration, and equipment efficiency assessments
    - `visualization.rb` - Model visualization and reporting tools
    - `btap_result.rb` - Results processing and analysis framework
  - **Utilities Submodule (`utilities/`):**
    - Space type generation and management utilities
    - EnergyPlus simulation result extraction tools
    - Surface coordinate rounding and geometric operations
    - Surface renaming and adiabatic conversion utilities
    - Weather data processing (EPW mapping and JSON conversion)
    - Schedule creation utilities
  - **Comprehensive Costing Framework (`costing/`):**
    - **Main Costing Engine (`btap_costing.rb`):**
      - BTAPCosting class with regional cost interpolation using distance-based weighting
      - CostingDatabase class with thread-safe database management and validation
      - Regional cost factors for all Canadian provinces/territories with great-circle distance calculations
      - Integration with mechanical system sizing and NECB standards compliance analysis
    - **Component-Specific Costing Modules (9 major modules):**
      - `envelope_costing.rb` - Exterior walls, roofs, foundations, windows, doors, and air sealing costs
      - `lighting_costing.rb` & `led_lighting_costing.rb` - Traditional and LED lighting with payback analysis
      - `heating_cooling_costing.rb` - Complete HVAC equipment including capacity-based costing and regional labor rates
      - `ventilation_costing.rb` - Air handling units, ductwork, filtration, and ventilation controls  
      - `shw_costing.rb` - Service water heating systems including heat recovery and high-efficiency equipment
      - `dcv_costing.rb` - Demand controlled ventilation with CO2 sensors and building automation integration
      - `daylighting_sensor_control_costing.rb` - Daylight sensors with continuous and stepped dimming systems
      - `nv_costing.rb` - Natural ventilation with operable windows and mixed-mode integration
      - `pv_ground_costing.rb` - Ground-mounted solar PV with various mounting systems and grid integration
    - **Cost Database System (`common_resources/` - 15 CSV files):**
      - Core cost data: `costs.csv`, `costs_local_factors.csv`, `locations.csv`
      - Material databases: `materials_opaque.csv`, `materials_glazing.csv`, `materials_lighting.csv`, `materials_hvac.csv`
      - Construction data: `constructions_opaque.csv`, `constructions_glazing.csv`, `construction_sets.csv`
      - Equipment data: `hvac_vent_ahu.csv`, `lighting_sets.csv`, `lighting.csv`
      - Validation data: `ConstructionProperties.csv`, `Constructions.csv`
    - **Regional Cost Analysis:**
      - Distance-based interpolation between Canadian reference cities with inverse distance weighting
      - Provincial cost factors capturing labor costs, material costs, market conditions, and climate adjustments
      - Integration with National Energy Board utility rates and time-of-use pricing structures
    - **Testing and Validation Framework:**
      - Automated test execution with `test_run_costing_tests.rb` and parallel testing capabilities
      - NECB reference building validation using comprehensive Canadian building types and climate zones
      - Mechanical system validation with `mech_sizing.json` for HVAC capacity ranges and installation factors
      - Regression testing with baseline cost result comparison and performance validation
  - **BTAP Data Resources:**
    - Weather data mapping and climate zone information
    - NECB space type information and building templates
    - Mechanical system sizing databases
    - Canadian utility pricing and end-use energy costs
    - Regional construction cost factors and material pricing
  
  **BTAP Core Capabilities:**
  - Large-scale building portfolio analysis and energy modeling
  - Comprehensive building lifecycle cost analysis with regional variations
  - Building vintage assessment and retrofit analysis
  - Advanced geometry manipulation and parametric modeling
  - Canadian building code compliance and costing (NECB integration)
  - Energy conservation measure (ECM) cost-benefit analysis
  - Automated model processing and results aggregation

### Data Structure
- `/data/standards/` - JSON files containing standards data (efficiency values, constructions, etc.)
- `/data/geometry/` - 3D building geometry templates and HVAC system descriptions
- `/data/weather/` - Weather files (.epw, .ddy, .stat) for representative locations
- Data should not contain code - edit Google spreadsheets or building-energy-standards-data repo instead

### Test Organization
- Tests are located in `/test/` with subdirectories by category
- Use `minitest` framework
- Test files follow naming pattern `test_XX.rb`
- Create tests for new functionality in appropriate subdirectory

## Development Workflow

1. Install OpenStudio SDK (minimum version 3.7.0) and matching Ruby version
2. Connect Ruby to OpenStudio (platform-specific steps in DeveloperInformation.md)
3. Run `bundle install` to install dependencies
4. Create new branch for changes
5. Modify code following existing patterns and conventions
6. Create/update tests in appropriate `/test/` subdirectory
7. Run tests: `ruby test/subdirectory/test_XX.rb`
8. Generate documentation: `bundle exec rake doc`
9. Check code style: `bundle exec rake rubocop`
10. Run broader test suite before committing

## Architecture Documentation

### Module Dependencies and Load Order

**Dependency Analysis**: See [MODULE_DEPENDENCIES.md](MODULE_DEPENDENCIES.md) for comprehensive dependency mapping.

**Loading Hierarchy** (from `lib/openstudio-standards.rb`):
1. **Foundation Layer**: Version, JSON, Singleton (3 items)
2. **Core Modules**: Geometry, Constructions, Infiltration, Utilities (21 files)
3. **Functional Modules**: Daylighting, Exterior Lighting, Refrigeration, Schedules, Service Water Heating, Space, Thermal Zone (16 files)
4. **Complex Modules**: HVAC, CreateTypical, QAQC, SQL File, Weather (29 files)
5. **Standards Framework**: Standards.Model, BTAP (12 files)
6. **Standards Implementations**: NECB, ASHRAE 90.1, DEER, CBES, ICC IECC, OEESC (300+ files)
7. **Component Extensions**: Standards.{Component} files (50+ files)
8. **Prototypes**: Building types and standard-specific implementations (150+ files)

### Architectural Patterns

#### Inheritance Pattern (Standards Framework)
```
Standard (abstract) → ASHRAE901 (abstract) → ASHRAE9012019 (concrete)
```
- **Base Classes**: Provide common functionality and data loading
- **Abstract Classes**: Define family-specific behavior (ASHRAE901, NECB)
- **Concrete Classes**: Implement specific standard versions with overrides

#### Component Extension Pattern  
```
Standards.ChillerElectricEIR.rb → ashrae_90_1_2019.ChillerElectricEIR.rb
```
- **Base Extensions**: Generic component behavior for all standards
- **Standard Overrides**: Standard-specific efficiency requirements and sizing

#### Module Composition Pattern
```
Geometry → Space → ThermalZone → HVAC → QAQC
```
- **Low Coupling**: Modules depend only on lower-level modules
- **High Cohesion**: Each module has focused responsibilities
- **Clear Data Flow**: Information flows from foundation to complex modules

### Key Design Decisions

#### Data-Driven Architecture
- **JSON Standards Data**: All standards requirements stored in JSON files
- **Template-Based Lookup**: Consistent naming for standards identification
- **Separation of Code and Data**: Updates to requirements don't require code changes

#### Factory Pattern Implementation
```ruby
standard = Standard.build('90.1-2019')  # Factory method
standard = ASHRAE9012019.new            # Direct instantiation
```

#### Canadian Integration Strategy  
- **NECB-BTAP Integration**: Canadian standards integrated with costing framework
- **Climate Zone Mapping**: Canadian 8-zone system fully implemented
- **Regional Data**: Provincial utility rates, cost factors, and climate data

### Module Interaction Documentation

#### Well-Designed Interactions ✅
- **Geometry → Constructions**: Clean assignment of constructions to surfaces
- **Standards → Components**: Clear override pattern for efficiency requirements
- **QAQC → All Modules**: Appropriate cross-cutting validation concerns

#### Complex Interactions ⚠️
- **BTAP ↔ NECB**: Tight integration between Canadian-specific modules
- **Standards Component Overrides**: 200+ override files with complex method resolution
- **Prototype Dependencies**: Deep dependency chains in building type implementations

### Development Guidelines

#### Adding New Standards
1. **Choose Base Class**: Inherit from `Standard` or appropriate family base class
2. **Implement Template**: Define template name for model lookup
3. **Create Data Files**: Develop comprehensive JSON requirement databases
4. **Component Overrides**: Create component-specific files only as needed
5. **Test Thoroughly**: Develop complete test suite with reference buildings

#### Module Development Principles
- **Single Responsibility**: Each module should have one primary purpose
- **Minimal Dependencies**: Depend only on necessary lower-level modules
- **Standards Agnostic**: Core modules should work with all standards
- **Comprehensive Testing**: Test integration with multiple standards

#### Code Organization Rules
- **File Naming**: Use consistent naming patterns across modules
- **Directory Structure**: Follow established hierarchy and grouping
- **Documentation**: Provide README.md for all major modules
- **Interface Design**: Design clear, minimal public interfaces

#### LLM Development Benefits
Key aspects that make this codebase LLM-friendly:
- **Clear Module Boundaries**: Well-defined interfaces between geometry, constructions, HVAC, and standards
- **Established Patterns**: Component extension pattern, factory pattern, inheritance hierarchy
- **Comprehensive Documentation**: Technical README files in major modules with usage patterns
- **Database Schema Understanding**: Clear CSV structure and validation requirements
- **Safety Guidelines**: Testing frameworks and validation requirements prevent data corruption
- **API Boundaries**: Clear separation between costing modules, standards implementations, and core functionality

## Key Conventions

- Follow Ruby style guidelines enforced by RuboCop
- Custom RuboCop configuration allows higher method complexity for engineering code
- Use YARD documentation format for method documentation
- Methods that modify models should follow existing naming patterns
- Standards-specific methods should be placed in appropriate standards subdirectory
- Use existing utilities in `utilities/` for common tasks like simulation and logging
- Always prefer editing existing files in the codebase over creating new ones
- Check if libraries already exist before adding new dependencies

### Architectural Guidelines
- **Respect Module Boundaries**: Don't create dependencies between peer-level modules
- **Follow Load Order**: New modules should fit into established dependency hierarchy
- **Use Factory Patterns**: Follow established patterns for standards instantiation
- **Data-Driven Design**: Store requirements in JSON, not hard-coded values
- **Component Override Pattern**: Use established pattern for standards-specific behavior

## Ruby Version Requirements
- Ruby 2.7.2 for OpenStudio 3.2.0 through 3.7.0
- Ruby 3.2.2 for OpenStudio 3.8.0 and above
- Check OpenStudio SDK Version Compatibility Matrix for specific versions