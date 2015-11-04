# Architecture

This library is being developed with 3 main use-cases in mind:

1. Create the DOE Prototype Buildings in OpenStudio format
2. Create a code baseline model from a proposed model
3. Check a model against a code/standard

These three things are all highly related, and share many common subtasks.  For example, since the DOE Prototype Buildings are supposed to be minimally code-compliant buildings, you need to set DX coil efficiencies.  When you are creating a code baseline model, you also need to set DX coil efficiencies.  When you are checking against a code/standard, you need to look up these same DX coil efficiencies. Additionally, all of these methods require access to the information about  the minimum efficiencies, u-values, etc. that are defined in the `/data/standards` directory.

The code has been structured such that several higher level methods may all call the same lower level method. For example, both of the methods below eventually call `SpaceType.add_loads`.  Rather than having two copies of this code inside of the two top level methods, there is one method.

	Model.create_prototype_building('Small Office, '90.1-2010', 'ASHRAE 169-2006-5A')
		Model.add_schedules
			SpaceType.add_schedules
		Model.apply_standard
			SpaceType.add_loads(people = true, lights = true, plug_loads = true)
	
	Model.create_baseline_building('90.1-2010', 'Appendix G')
		Model.add_baseline_hvac_systems
		Model.apply_standard
			SpaceType.add_loads(people = true, lights = true, plug_loads = false)

Where a method needs to operate **slightly differently** in two different situations, instead of duplicating the code, we make an input argument to tell that method what to do.  In the example above, `SpaceType.add_loads` is called with `plug_loads = true` when creating the prototype building, but `plug_loads = false` when creating the baseline model, since plug loads stay the same as the proposed model in Appendix G.

Where a method needs to operate **very differently** in two different situations, it should be broken out into a separate method. Less code often makes 

People using the library may also call lower-level methods directly, but this is not the main purpose of the library.

## TODO Describe the method hierarchy of the three top level methods


### `Model.create_prototype_building`
inputs: building type, template (standard), climate zone
  
- Model.load_geometry # Loads a typical building geometry
- Model.assign_space_type_stubs # Assigns each space a Standards Building Type and Standards Space Type, which are defined on the Space Types tab of the OpenStudio_Standards Google Spreadsheet.
- TODO Model.assign_construction_type_stubs # Assigns each surface in the model a Standards Construction Type (e.g. Mass Wall)
- Model.modify_infiltration_coefficients
- Model.modify_surface_convection_algorithm
- Model.create_thermal_zones # Creates one thermal zone for each space
- Model.add_schedules
	- Space Type.add_schedules(people = true, lights = true, occ = true, etc.)

### `Model.create_baseline_building`

- Model.apply_standard
	- Space Type.add_loads(people = true, lights = true, occ = true, etc.)
- Model.add_loads
	- For each space type:
- Model.

### `Model.check_against_standard`

