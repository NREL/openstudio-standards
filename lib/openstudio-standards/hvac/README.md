# HVAC Module

## Overview

The HVAC module provides comprehensive tools for creating, modifying, and analyzing HVAC systems in building energy models. This module handles air distribution systems, exhaust fans, setpoint management, and HVAC component creation and modification.

## Module Structure

### Air Loop Operations (`air_loop/`)
- **`information.rb`**: Air loop system analysis and information extraction

### Exhaust Systems (`exhaust/`)  
- **`create_exhaust_fan.rb`**: Exhaust fan creation and sizing

### Setpoint Management (`setpoint_managers/`)
- **`information.rb`**: Setpoint manager analysis and information

### System Creation and Analysis
- **`cbecs_hvac.rb`**: CBECS (Commercial Buildings Energy Consumption Survey) HVAC system implementations
- **`components/create.rb`**: HVAC component creation utilities
- **`components/modify.rb`**: HVAC component modification and optimization

## Key Capabilities

### Air Loop Systems
- Air handling unit configuration and sizing
- Supply and return fan sizing and control
- Heating and cooling coil integration
- Economizer control strategies
- Ventilation requirement calculations

### Exhaust Systems
- Kitchen exhaust fan sizing and control
- General exhaust fan implementation
- Exhaust heat recovery integration

### Component Management
- HVAC component creation with proper sizing
- Equipment efficiency optimization
- Control system integration
- Performance curve applications

### CBECS Integration
- Commercial building HVAC system archetypes
- Statistical building system implementations
- Survey-based system selection and sizing

## Dependencies

### Internal Dependencies
- **Schedules Module**: For system operation schedules
- **Thermal Zone Module**: For zone-level HVAC requirements  
- **Standards Module**: For equipment efficiency and sizing requirements
- **Utilities Module**: For logging and simulation utilities

### External Dependencies
- **OpenStudio SDK**: HVAC system modeling capabilities
- **EnergyPlus**: HVAC simulation engine

## Usage Patterns

### Typical HVAC System Creation
1. **Zone Analysis**: Determine heating/cooling loads and ventilation requirements
2. **System Selection**: Choose appropriate HVAC system type based on building characteristics
3. **Component Sizing**: Size equipment based on loads and standards requirements
4. **Control Integration**: Apply appropriate control strategies
5. **Performance Optimization**: Optimize system efficiency and operation

### Integration with Standards
The HVAC module works closely with the standards framework to:
- Apply equipment efficiency requirements
- Size systems according to code requirements
- Implement required control strategies
- Validate system compliance