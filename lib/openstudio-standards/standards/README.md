# OpenStudio-Standards Framework

## Overview

The `standards/` directory contains the complete implementation of the OpenStudio-Standards framework for building energy code compliance and analysis. This framework provides a comprehensive, extensible architecture for implementing multiple building energy standards with shared base functionality and standard-specific customizations.

## Architecture Overview

The standards framework uses object-oriented inheritance to provide code reuse while allowing standard-specific customizations:

```
Standard (abstract base class)
├── ASHRAE901 (abstract class)  
│   ├── ASHRAE9012004, ASHRAE9012007, ASHRAE9012010, ASHRAE9012013, ASHRAE9012016, ASHRAE9012019
│   ├── DOERefPre1980, DOERef19802004 (DOE reference buildings)
│   └── NRELZNEReady2017, ZEAEDGMultifamily (zero energy standards)
├── ASHRAE901PRM2019 (Performance Rating Method)
├── NECB2011, NECB2015, NECB2017, NECB2020 (Canadian standards)
├── ICCIECC2015 (International Energy Conservation Code)  
├── CBES (California Building Energy Standards - Title 24)
├── DEER (Database for Energy Efficiency Resources)
└── OEESC2014 (Ontario Energy Efficiency Standards)
```

## Directory Structure

### Base Framework

#### `standard.rb` - Abstract Base Class
**The foundation of all building energy standards**

**Key Features:**
- Standard registration and discovery system
- Data loading and validation framework
- Model lookup name resolution
- Template and standards data management

**Key Methods:**
- `register_standard`: Dynamic standard registration
- `build`: Factory method for standard instantiation
- `load_standards_database`: JSON data loading with validation
- `model_get_lookup_name`: Consistent model identification

#### Component Extensions (`Standards.*.rb` files)
**Base class extensions for OpenStudio components - 44+ files**

**Major Component Categories:**
- **HVAC Equipment**: AirLoopHVAC, ChillerElectricEIR, BoilerHotWater, Fans, Pumps, etc.
- **Building Envelope**: Surface, SubSurface, PlanarSurface
- **Building Systems**: ThermalZone, Space, SpaceType, Model
- **Schedules and Controls**: ScheduleRuleset, ZoneHVACComponent
- **Service Systems**: ServiceWaterHeating, WaterHeaterMixed

**Design Pattern:**
Each component extension provides:
- Information methods (efficiency lookup, sizing calculations)
- Modification methods (apply standards, set efficiencies)  
- Validation methods (compliance checking)
- Standard-agnostic base implementations

### Standard Families

### ASHRAE 90.1 Family (`ashrae_90_1/`)

#### Base Implementation: `ashrae_90_1.rb`
**Abstract base class for all ASHRAE 90.1 standards**

#### Version Implementations
**Six complete ASHRAE 90.1 versions (2004-2019):**
- `ashrae_90_1_2004/` through `ashrae_90_1_2019/`
- Each version includes 15-20 component-specific override files
- Progressive improvements in efficiency requirements and modeling approaches

#### DOE Reference Buildings
- **`doe_ref_pre_1980/`**: Pre-1980 reference building standards
- **`doe_ref_1980_2004/`**: 1980-2004 reference building standards  
- Integration with DOE Commercial Reference Building models

#### Zero Energy Standards  
- **`nrel_zne_ready_2017/`**: NREL Zero Energy Ready commercial buildings
- **`ze_aedg_multifamily/`**: Zero Energy AEDG for multifamily buildings

#### Data Resources (`data/`)
- Comprehensive JSON databases for efficiency requirements
- Climate zone definitions and mappings
- Equipment performance curves and sizing data

### ASHRAE 90.1 PRM (`ashrae_90_1_prm/`)

#### Performance Rating Method Implementation
**Complete Appendix G modeling framework**

**Core Features:**
- **`ashrae_90_1_prm_2019/`**: Full 2019 PRM implementation
- Baseline building automatic generation
- Performance cost index calculations
- User data integration (CSV and JSON formats)

**Components:**
- 25+ component-specific PRM override files
- Comprehensive user data processing framework
- Documentation and examples (`docs/`)

### NECB - Canadian Standards (`necb/`)
**Most comprehensive national building code implementation**

[See detailed NECB README for complete documentation]

**Four NECB Versions**: 2011, 2015, 2017, 2020
**BTAP Integration**: Pre-1980 and 1980-2010 vintages  
**ECMs Framework**: Energy conservation measures
**Shared Resources**: Common data and utilities

### California Standards

#### CBES - California Building Energy Standards (`cbes/`)
**Title 24 Building Energy Efficiency Standards**

**Vintage Coverage**: 7 versions from pre-1978 through 2008
- `cbes_pre_1978/` through `cbes_t24_2008/`
- California-specific climate zones and requirements
- Integration with California utility rate structures

#### DEER - California Utility Standards (`deer/`)  
**Database for Energy Efficiency Resources**

**Extensive Vintage Coverage**: 22 versions from pre-1975 through 2075
- Historical analysis: `deer_pre_1975/` through `deer_2020/`
- Future projections: `deer_2025/` through `deer_2075/`
- Each vintage includes Comstock integration variants
- California investor-owned utility integration

### Other Standards

#### ICC IECC (`icc_iecc/`)
**International Energy Conservation Code**
- `icc_iecc_2015/`: 2015 version implementation
- Residential and commercial building requirements

#### OEESC (`oeesc/`)  
**Ontario Energy Efficiency Standards for Commercial Buildings**
- `oeesc_2014/`: 2014 version implementation
- Ontario-specific requirements and climate integration

## Key Design Patterns

### Inheritance and Override Pattern

#### Base Class Methods
```ruby
# Standard.rb - base implementation
def equipment_get_efficiency(equipment)
  # Generic efficiency lookup
end

# Component-specific base class  
# Standards.ChillerElectricEIR.rb
def chiller_electric_eir_find_cop(chiller)
  # Base chiller efficiency lookup
end
```

#### Standard-Specific Overrides
```ruby
# ashrae_90_1_2019.ChillerElectricEIR.rb  
def chiller_electric_eir_find_cop(chiller)
  # 2019-specific efficiency requirements
end

# necb_2011.ChillerElectricEIR.rb
def chiller_electric_eir_find_cop(chiller) 
  # NECB 2011-specific requirements
end
```

### Data-Driven Standards

#### JSON Data Structure
Each standard maintains JSON databases with:
- **Equipment Efficiency Tables**: Performance requirements by equipment type and size
- **Construction Assemblies**: Envelope performance requirements  
- **Climate Zone Data**: Geographic and climatic information
- **Space Type Data**: Building use type definitions and requirements
- **System Selection Data**: HVAC system selection criteria

#### Data Loading Pattern
```ruby
def load_standards_database
  # Load base standard data
  super
  
  # Load standard-specific data  
  load_standard_data('standard_specific_data.json')
end
```

### Template-Based Identification

#### Naming Convention
Standards use consistent template naming:
- ASHRAE 90.1: `'90.1-2019'`, `'90.1-2016'`, etc.
- NECB: `'NECB2011'`, `'NECB2015'`, etc.  
- DEER: `'DEER 2020'`, `'DEER 2025'`, etc.

#### Model Lookup Integration
```ruby
def model_get_lookup_name(model)
  # Determine appropriate standard based on model characteristics
  # Return standard template name for data lookup
end
```

## Component Integration Patterns

### HVAC Equipment Standards

#### Equipment Efficiency Requirements
- **Size-based efficiency**: Different requirements by equipment capacity
- **Climate-based adjustments**: Efficiency variations by climate zone
- **Fuel type variations**: Different requirements by energy source
- **Control integration**: Minimum control requirements

#### Sizing and Selection
- **Autosizing integration**: Work with OpenStudio autosizing
- **Performance curves**: Detailed equipment performance modeling
- **System integration**: Equipment coordination within systems

### Building Envelope Standards

#### Construction Requirements
- **Climate zone based**: Different requirements by geographic location
- **Assembly performance**: Complete wall, roof, floor assemblies
- **Fenestration requirements**: Window and door performance standards
- **Air barrier requirements**: Envelope airtightness standards

### Lighting Standards

#### Power Density Requirements
- **Space type based**: Different allowances by building use
- **Control requirements**: Occupancy sensors, daylight dimming
- **Exterior lighting**: Site and facade lighting requirements

## Data Management

### Standards Database Structure

#### Hierarchical Data Organization
```
data/
├── {standard_name}/
│   ├── equipment_efficiency_tables.json
│   ├── envelope_requirements.json  
│   ├── lighting_power_densities.json
│   ├── climate_zone_data.json
│   └── space_type_definitions.json
```

#### Data Validation
- **Schema validation**: JSON schema enforcement
- **Cross-reference validation**: Data consistency checking
- **Unit validation**: Consistent units across all data

### Geographic Integration

#### Climate Zone Implementation
- **ASHRAE Climate Zones**: Integration with ASHRAE Standard 169
- **Canadian Climate Zones**: NECB 8-zone system
- **California Climate Zones**: Title 24 16-zone system  
- **Custom Climate Zones**: Support for jurisdiction-specific zones

## Usage Patterns

### Standard Selection and Instantiation

#### Factory Pattern Usage
```ruby
# Automatic standard selection
standard = Standard.build('90.1-2019')

# Direct instantiation
standard = ASHRAE9012019.new

# Template-based selection  
template = model_get_lookup_name(model)
standard = Standard.build(template)
```

### Model Compliance Application

#### Typical Workflow
```ruby
# 1. Load or create model
model = load_osm_file(path)

# 2. Determine appropriate standard
standard = Standard.build(template)

# 3. Apply standard requirements
standard.model_apply_standard(model, climate_zone)

# 4. Validate compliance  
results = standard.model_check_compliance(model)
```

### Component-Level Standards Application

#### Equipment Efficiency Application
```ruby
# Apply efficiency standards to HVAC equipment
air_loop.supplyComponents.each do |component|
  if component.to_FanVariableVolume.is_initialized
    fan = component.to_FanVariableVolume.get
    standard.fan_apply_standard_minimum_motor_efficiency(fan)
  end
end
```

## Testing and Validation

### Regression Testing Framework
- **Reference Building Testing**: Complete building model validation
- **Component Testing**: Individual component performance validation  
- **Cross-Standard Testing**: Consistency across related standards

### Compliance Verification
- **Automated Compliance Checking**: Rule-based compliance validation
- **Performance Verification**: Energy simulation result validation
- **Documentation Generation**: Automated compliance reports

## Extension Guidelines

### Adding New Standards

#### Implementation Steps
1. **Inherit from Base Class**: Extend `Standard` or appropriate family base class
2. **Implement Required Methods**: Override abstract methods with standard-specific logic
3. **Create Data Files**: Develop JSON databases with standard requirements
4. **Component Overrides**: Create component-specific override files as needed
5. **Testing**: Develop comprehensive test suite with reference buildings

#### Best Practices
- **Follow Naming Conventions**: Consistent file and class naming
- **Data-Driven Approach**: Minimize hard-coded values, use JSON data
- **Incremental Override**: Only override methods that differ from base implementation
- **Comprehensive Testing**: Test all functionality with realistic building models

### Adding New Components

#### Component Extension Pattern
1. **Base Implementation**: Create `Standards.{Component}.rb` with base methods
2. **Standard Overrides**: Create standard-specific overrides as needed
3. **Data Integration**: Add component data to standards JSON files
4. **Testing**: Validate component behavior across all standards

## Dependencies

### Internal Dependencies
- **Core OpenStudio-Standards Modules**: Geometry, constructions, schedules, etc.
- **BTAP Integration**: Canadian standards integration with BTAP framework
- **Utilities**: Shared utility functions and data structures

### External Dependencies  
- **OpenStudio SDK**: Building energy modeling framework
- **EnergyPlus**: Energy simulation engine
- **Ruby Standard Libraries**: JSON, CSV processing

### Data Dependencies
- **Climate Data**: Weather files and climate zone definitions  
- **Standards Publications**: Official building energy code requirements
- **Equipment Data**: Manufacturer performance data and industry databases

## Development Notes

### Code Organization Principles
- **Separation of Concerns**: Clear boundaries between different standards families
- **DRY (Don't Repeat Yourself)**: Extensive code reuse through inheritance
- **Data-Driven**: Standards requirements stored in JSON, not hard-coded
- **Extensible**: Easy to add new standards or components

### Performance Considerations  
- **Lazy Loading**: Standards data loaded only when needed
- **Efficient Lookups**: Optimized data structures for frequent operations
- **Memory Management**: Careful management of large data sets

### Maintenance Considerations
- **Version Control**: Clear versioning for standards updates
- **Backward Compatibility**: Maintain compatibility with existing models
- **Documentation**: Comprehensive documentation for all public interfaces
- **Testing**: Extensive automated testing for all functionality

The OpenStudio-Standards framework represents one of the most comprehensive and well-architected building energy standards implementations available, providing robust support for multiple international building energy codes with a clean, extensible design.