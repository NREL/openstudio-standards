# Geometry Module

## Overview

The Geometry module provides comprehensive tools for creating, modifying, and analyzing building geometry in OpenStudio energy models. This module handles 3D building geometry creation, geometric transformations, space organization, and building form optimization.

## Module Structure

### Core Geometry Operations
- **`create.rb`**: Basic geometry creation utilities
- **`create_bar.rb`**: Bar building geometry creation
- **`create_shape.rb`**: Custom shape geometry creation
- **`group.rb`**: Geometry grouping and organization
- **`information.rb`**: Geometry analysis and information extraction
- **`modify.rb`**: Geometry modification and transformation

## Key Capabilities

### Geometry Creation

#### Bar Building Creation (`create_bar.rb`)
- **Rectangular Buildings**: Simple rectangular building footprints
- **L-Shaped Buildings**: L-shaped building configurations
- **Courtyard Buildings**: Buildings with central courtyards
- **Multi-Story Buildings**: Automatic floor replication and stacking
- **Parametric Sizing**: Width, depth, and height parameterization

#### Custom Shape Creation (`create_shape.rb`)  
- **Polygon Buildings**: Complex polygon footprint creation
- **Custom Vertices**: User-defined building shapes
- **Irregular Geometries**: Non-rectangular building forms
- **Site-Specific Shapes**: Geometry fitting to site constraints

#### Basic Geometry (`create.rb`)
- **Space Creation**: Individual space geometry creation
- **Surface Generation**: Wall, floor, ceiling, and roof surface creation
- **Fenestration**: Window and door placement and sizing
- **Shading Elements**: Overhangs, fins, and complex shading devices

### Geometry Modification (`modify.rb`)

#### Geometric Transformations
- **Translation**: Move building geometry in 3D space
- **Rotation**: Rotate buildings around vertical or custom axes  
- **Scaling**: Uniform and non-uniform scaling operations
- **Mirroring**: Mirror geometry across planes

#### Building Form Optimization
- **Aspect Ratio Optimization**: Optimize building proportions for energy performance
- **Orientation Analysis**: Test multiple building orientations
- **Massing Studies**: Explore different building massing options
- **Floor Plate Optimization**: Optimize floor plate size and shape

#### Surface Modifications
- **Fenestration Ratios**: Adjust window-to-wall ratios
- **Skylight Ratios**: Modify skylight-to-roof ratios
- **Surface Subdivision**: Divide large surfaces for detailed modeling
- **Surface Merging**: Combine adjacent surfaces

### Geometry Analysis (`information.rb`)

#### Building Metrics
- **Floor Areas**: Calculate conditioned and unconditioned floor areas
- **Surface Areas**: Calculate wall, roof, and floor areas by orientation
- **Volume Calculations**: Calculate building volumes and heights
- **Aspect Ratios**: Calculate building aspect ratios and compactness metrics

#### Fenestration Analysis
- **Window-to-Wall Ratios**: Calculate by orientation and overall
- **Skylight-to-Roof Ratios**: Calculate skylight percentages
- **Glazing Analysis**: Analyze glazing area and orientation distribution
- **Shading Analysis**: Calculate shading factors and solar exposure

#### Geometric Properties
- **Building Envelope**: Calculate envelope area and form factors
- **Thermal Zones**: Analyze zone geometry and relationships  
- **Space Relationships**: Identify adjacent spaces and surfaces
- **Solar Exposure**: Calculate solar exposure by surface and orientation

### Geometry Organization (`group.rb`)

#### Space Grouping
- **Thermal Zoning**: Group spaces into thermal zones
- **Building Stories**: Organize spaces by building level
- **Space Types**: Group spaces by functional use
- **Exposure Categories**: Group by perimeter vs core location

#### Surface Organization  
- **Orientation Grouping**: Group surfaces by cardinal orientation
- **Boundary Conditions**: Group by interior, exterior, ground contact
- **Construction Groups**: Group surfaces with similar constructions
- **Adjacency Analysis**: Identify and group adjacent surfaces

## Advanced Features

### Parametric Modeling
- **Design Variables**: Define parametric design variables for geometry
- **Constraint Handling**: Apply geometric constraints during modifications
- **Design Space Exploration**: Systematic exploration of geometric alternatives
- **Optimization Integration**: Interface with optimization algorithms

### Climate-Responsive Design
- **Solar Analysis**: Optimize geometry for solar exposure and shading
- **Daylighting Optimization**: Optimize for natural daylight access
- **Wind Analysis**: Consider prevailing wind patterns in geometry
- **Climate-Specific Recommendations**: Geometry guidance by climate zone

### Complex Geometries
- **Curved Surfaces**: Handle curved walls and complex roof forms
- **Sloped Surfaces**: Manage sloped roofs and irregular floor plates
- **Multi-Building Sites**: Handle campus and multi-building configurations
- **Site Integration**: Integrate building geometry with site context

## Integration Capabilities

### Standards Integration
- **Code Compliance**: Ensure geometry meets building code requirements
- **Accessibility**: Validate geometry for accessibility compliance
- **Fire Safety**: Consider fire safety requirements in geometry design

### HVAC Integration
- **Zone Creation**: Create thermal zones appropriate for HVAC systems
- **System Layout**: Consider HVAC system layout in geometry design
- **Equipment Placement**: Plan space for HVAC equipment and distribution

### Daylighting Integration
- **Window Placement**: Optimize window placement for daylighting
- **Shading Design**: Design appropriate exterior and interior shading
- **Light Shelf Integration**: Integrate daylighting enhancement strategies

## Usage Patterns

### Basic Building Creation Workflow
1. **Define Building Program**: Establish space requirements and relationships
2. **Create Building Footprint**: Define building shape and orientation
3. **Generate 3D Geometry**: Create floors, walls, and roof surfaces
4. **Add Fenestration**: Place windows, doors, and skylights
5. **Create Thermal Zones**: Group spaces into appropriate thermal zones
6. **Apply Constructions**: Assign appropriate constructions to surfaces

### Geometric Optimization Workflow  
1. **Define Design Variables**: Establish parameters to be optimized
2. **Set Performance Objectives**: Define energy, daylighting, or cost objectives
3. **Generate Alternatives**: Create multiple geometric alternatives
4. **Evaluate Performance**: Simulate and evaluate each alternative
5. **Select Optimal Design**: Choose best-performing geometry
6. **Refine Design**: Fine-tune selected geometry

### Complex Geometry Workflow
1. **Site Analysis**: Understand site constraints and opportunities
2. **Conceptual Design**: Develop initial building massing and organization
3. **Detailed Geometry**: Create detailed 3D geometry with all surfaces
4. **Validation**: Ensure geometry is valid and meets requirements
5. **Integration**: Integrate with building systems and components
6. **Documentation**: Generate geometry documentation and drawings

## Quality Assurance

### Geometry Validation
- **Surface Intersection**: Detect and resolve surface intersections
- **Geometric Consistency**: Ensure consistent coordinate systems and units
- **Topology Validation**: Validate space and surface connectivity
- **Model Completeness**: Ensure all necessary surfaces and spaces are present

### Performance Verification
- **Solar Exposure**: Validate solar calculations and shading analysis
- **Thermal Zone Logic**: Verify thermal zone creation and relationships
- **Area Calculations**: Validate floor area and envelope area calculations
- **Adjacency Verification**: Ensure proper surface adjacency matching

## Dependencies

### Internal Dependencies
- **Utilities Module**: For logging and mathematical operations
- **Standards Module**: For code compliance requirements
- **Constructions Module**: For surface construction assignment

### External Dependencies
- **OpenStudio SDK**: 3D geometry modeling capabilities
- **Ruby Geometric Libraries**: Advanced geometric calculations
- **Linear Algebra**: Matrix operations for geometric transformations

## Development Notes

### Design Principles
- **Robustness**: Handle edge cases and invalid geometry gracefully
- **Flexibility**: Support wide range of building types and forms
- **Performance**: Efficient algorithms for large and complex geometries
- **Interoperability**: Work seamlessly with other OpenStudio-Standards modules

### Performance Considerations
- **Memory Efficiency**: Efficient handling of large geometric models
- **Computational Speed**: Fast geometric calculations and transformations
- **Scalability**: Handle projects from single buildings to large campuses
- **Precision**: Maintain geometric precision throughout operations