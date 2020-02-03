require_relative '../../../helpers/minitest_helper'


# This class will perform tests that are HDD driven, A Test model will be created
# that will have all of OpenStudios surface types with different contructions. All
# components are created from scratch to ensure model are up to date and we will
# not run into version issues with the test. 
## to specifically test aspects of the NECB2011 code that are HDD dependant. 
class NECB_Constructions_FDWR_Tests < Minitest::Test
  #set global weather files sample
  NECB_epw_files_for_cdn_climate_zones = [
      'CAN_BC_Vancouver.Intl.AP.718920_CWEC2016.epw', #  CZ 4 HDD = 2932
      'CAN_BC_Kamloops.AP.718870_CWEC2016.epw', #    CZ 5 HDD = 3567
      'CAN_ON_Ottawa-Macdonald-Cartier.Intl.AP.716280_CWEC2016.epw', #CZ 6 HDD = 4563
      'CAN_AB_Banff.CS.711220_CWEC2016.epw', #CZ 7aHDD = 5501
      'CAN_ON_Armstrong.AP.718410_CWEC2016.epw', #CZ 7b HDD = 6572
      'CAN_NU_Resolute.AP.719240_CWEC2016.epw' # CZ 8HDD = 12570
  ]
  #Set Compliance vintage
  Templates = ['NECB2011','NECB2015','NECB2017', 'BTAPPRE1980', 'BTAP1980TO2010']

  # Create scaffolding to create a model with windows, then reset to appropriate values.
  # Will require large windows and constructions that have high U-values.    
  def setup()

    @file_folder = __dir__
    @test_folder = File.join(@file_folder, '..')
    @root_folder = File.join(@test_folder, '..')
    @resources_folder = File.join(@test_folder, 'resources')
    @expected_results_folder = File.join(@test_folder, 'expected_results')
    @test_results_folder = @expected_results_folder
    @top_output_folder = "#{@test_folder}/output/"

    #Create new model for testing. 
    @model = OpenStudio::Model::Model.new
    #Create Geometry that will be used for all tests.  

    #Below ground story to tests all ground surfaces including roof.
    length = 100.0; width = 100.0; num_above_ground_floors = 0; num_under_ground_floors = 1; floor_to_floor_height = 3.8; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = -10.0
    @below_ground_floors = BTAP::Geometry::Wizards::create_shape_rectangle(@model, length, width, num_above_ground_floors, num_under_ground_floors, floor_to_floor_height, plenum_height, perimeter_zone_depth, initial_height)

    #Above ground story to test all above outdoors surfaces including floor.
    length = 100.0; width = 100.0; num_above_ground_floors = 3; num_under_ground_floors = 0; floor_to_floor_height = 3.8; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = 10.0
    @above_ground_floors = BTAP::Geometry::Wizards::create_shape_rectangle(@model, length, width, num_above_ground_floors, num_under_ground_floors, floor_to_floor_height, plenum_height, perimeter_zone_depth, initial_height)

    #Find all outdoor surfaces. 
    outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Outdoors")
    @outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
    @outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")

    #Set all FWDR to a ratio of 0.60
    subsurfaces = []
    counter = 0
    @outdoor_walls.each {|wall| subsurfaces << wall.setWindowToWallRatio(0.60)}
    #ensure all wall subsurface types are represented. 
    subsurfaces.each do |subsurface|
      counter = counter + 1

      case counter
      when 1
        subsurface.get.setSubSurfaceType('FixedWindow')
      when 2
        subsurface.get.setSubSurfaceType('OperableWindow')
      when 3
        subsurface.get.setSubSurfaceType('Door')
      when 4
        subsurface.get.setSubSurfaceType('GlassDoor')
        counter = 0
      end
    end


    #Create skylights that are 10% of area with a 4x4m size.
    pattern = OpenStudio::Model::generateSkylightPattern(@model.getSpaces, @model.getSpaces[0].directionofRelativeNorth, 0.10, 4.0, 4.0) # ratio, x value, y value
    subsurfaces = OpenStudio::Model::applySkylightPattern(pattern, @model.getSpaces, OpenStudio::Model::OptionalConstructionBase.new)

    #ensure all roof subsurface types are represented. 
    subsurfaces.each do |subsurface|
      counter = counter + 1
      case counter
      when 1
        subsurface.setSubSurfaceType('Skylight')
      when 2
        subsurface.setSubSurfaceType('TubularDaylightDome')
      when 3
        subsurface.setSubSurfaceType('TubularDaylightDiffuser')
      when 4
        subsurface.setSubSurfaceType('OverheadDoor')
        counter = 0
      end
    end

    standard = Standard.build("NECB2011")
    standard.model_clear_and_set_example_constructions(@model)
    #Ensure that building is Conditioned add spacetype to each space. 

  end

  #setup()


  # Tests to ensure that the U-Values of the construction are set correctly. This 
  # test will set up  
  # for all HDDs 
  # NECB2011 8.4.4.1
  # @return [Bool] true if successful. 
  def test_necb_hdd_envelope_rules()
    # Todo - Define a construction directly to a surface. 
    # Todo - Define a construction set to a space directly.
    # Todo - Define a construction set to a floor directly. 
    # Todo - Define an adiabatic surface (See if it handle the bug)
    # Todo - Roughly 1 day of work (phylroy) 

    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    #Create report string. 

    @json_test_output = {}
    #Iterate through the vintage templates 'NECB2011', etc..
    Templates.each do |template|
      @json_test_output[template] = {}
    #Iterate through the weather files.
    NECB_epw_files_for_cdn_climate_zones.each do |weather_file|



        #Create a space type and assign to all spaces.. This is done because the FWDR is only applied to conditions spaces.. So we need conditioning data.

        building_type = "Office"
        space_type = "WholeBuilding"
        climate_zone = 'NECB HDD Method'
        standard = Standard.build(template)

        table = standard.standards_data['tables']['space_types']['table']
        space_type_properties = table.detect {|st| st["building_type"] == building_type && st["space_type"] == space_type }
        st = OpenStudio::Model::SpaceType.new(@model)
        st.setStandardsBuildingType(space_type_properties['building_type'])
        st.setStandardsSpaceType(space_type_properties['space_type'])
        st.setName("#{template}-#{space_type_properties['building_type']}-#{space_type_properties['space_type']}")
        standard.space_type_apply_rendering_color(st)
        standard.model_add_loads(@model)
        #Now loop through each space and assign the spacetype.
        @model.getSpaces.each do |space|
          space.setSpaceType(st)
        end

        #Create Zones.
        standard.model_create_thermal_zones(@model)


        #Add weather file, HDD.
        standard.model_add_design_days_and_weather_file(@model, 'NECB HDD Method', File.basename(weather_file))
        standard.model_add_ground_temperatures(@model, 'HighriseApartment', 'NECB HDD Method')
        @hdd = standard.get_necb_hdd18(@model)

        standard.apply_building_default_constructionset(@model) # add necb default construction set
        standard.apply_standard_construction_properties(model: @model) # standards candidate
        if template == 'BTAPPRE1980'
          standard.apply_standard_window_to_wall_ratio(model: @model, fdwr_set: 1.1)
        else
          standard.apply_standard_window_to_wall_ratio(model: @model)
        end
        standard.apply_standard_window_to_wall_ratio(model: @model) # standards candidate
        standard.apply_standard_skylight_to_roof_ratio(model: @model) # standards candidate


        #Add Infiltration rates to the space objects themselves. 
        standard.model_apply_infiltration_standard(@model)


        #Get Surfaces by type.
        outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Outdoors")
        outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
        outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")
        outdoor_floors = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Floor")
        outdoor_subsurfaces = BTAP::Geometry::Surfaces::get_subsurfaces_from_surfaces(outdoor_surfaces)
        windows = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["FixedWindow", "OperableWindow"])
        skylights = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Skylight", "TubularDaylightDiffuser", "TubularDaylightDome"])
        doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Door", "GlassDoor"])
        overhead_doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["OverheadDoor"])
        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Ground")
        ground_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Wall")
        ground_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "RoofCeiling")
        ground_floors = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Floor")

        #Determine the weighted average conductances by surface type. 
        ## exterior surfaces
        outdoor_walls_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_walls)
        outdoor_roofs_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_roofs)
        outdoor_floors_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_floors)
        ## Ground surfaces
        ground_walls_average_conductances = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(ground_walls)
        ground_roofs_average_conductances = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(ground_roofs)
        ground_floors_average_conductances = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(ground_floors)
        ## Sub surfaces
        windows_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(windows)
        skylights_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(skylights)
        doors_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(doors)
        overhead_doors_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(overhead_doors)


        srr_info = standard.find_exposed_conditioned_roof_surfaces(@model)
        fdwr_info = standard.find_exposed_conditioned_vertical_surfaces(@model)

        #Output conductances
        def roundOrNA(data, figs=4)
			if data == 'NA'
				return data
			end
			return data.round(figs)
		end
        @json_test_output[template][@hdd] = {}
        @json_test_output[template][@hdd]['fdwr'] = roundOrNA(fdwr_info["fdwr"])
        @json_test_output[template][@hdd]['srr'] = roundOrNA(srr_info["srr"])
        @json_test_output[template][@hdd]['outdoor_roofs_average_conductances'] = roundOrNA(outdoor_roofs_average_conductance)
        @json_test_output[template][@hdd]['outdoor_walls_average_conductances'] = roundOrNA(outdoor_walls_average_conductance)
        @json_test_output[template][@hdd]['outdoor_floors_average_conductances'] = roundOrNA(outdoor_floors_average_conductance)
        @json_test_output[template][@hdd]['ground_roofs_average_conductances'] = roundOrNA(ground_roofs_average_conductances)
        @json_test_output[template][@hdd]['ground_walls_average_conductances'] = roundOrNA(ground_walls_average_conductances)
        @json_test_output[template][@hdd]['ground_floors_average_conductances'] = roundOrNA(ground_floors_average_conductances)
        @json_test_output[template][@hdd]['windows_average_conductance'] = roundOrNA(windows_average_conductance)
        @json_test_output[template][@hdd]['skylights_average_conductance'] = roundOrNA(skylights_average_conductance)
        @json_test_output[template][@hdd]['doors_average_conductance'] = roundOrNA(doors_average_conductance)

        
        #infiltration test
        # Get the effective infiltration rate through the walls and roof only.
        sorted_spaces = BTAP::Geometry::Spaces::get_spaces_from_storeys(@model, @above_ground_floors).sort_by {|space| space.name.get}
        #Need to sort spaces otherwise the output order is random.
        @json_test_output[template][@hdd]['Wall/Roof infil rate (L/s/m2)'] = {}
        sorted_spaces.each do |space|
          assert(space.spaceInfiltrationDesignFlowRates.size <= 1, "There should be no more than one infiltration object per space in the reference/budget building#{space.spaceInfiltrationDesignFlowRates}")
          #If space rightfully does not have an infiltration rate (no exterior surfaces) output an NA. 
          if space.spaceInfiltrationDesignFlowRates.size == 0
            @json_test_output[template][@hdd]['Wall/Roof infil rate (L/s/m2)'][space.name] = "NA,"
          else
            #Do some math to determine the effective infiltration rate of the walls and roof only as per NECB. 
            wall_roof_infiltration_rate = space.spaceInfiltrationDesignFlowRates[0].flowperExteriorSurfaceArea.get * space.exteriorArea / standard.space_exterior_wall_and_roof_and_subsurface_area(space)
            #Output effective infiltration rate
            @json_test_output[template][@hdd]['Wall/Roof infil rate (L/s/m2)'][space.name] = "#{(wall_roof_infiltration_rate * 1000).round(3)},"

          end
        end

        BTAP::FileIO::save_osm(@model, File.join(File.dirname(__FILE__), "output", "#{template}-hdd#{@hdd}-envelope_test.osm"))
      end #Weather file loop.
    end # Template vintage loop

    #Write test report file.
    test_result_file = File.join(@test_results_folder, 'compliance_envelope_test_results.json')
    File.open(test_result_file, 'w') {|f| f.write(JSON.pretty_generate(@json_test_output))}




    #Test that the values are correct by doing a file compare.
    expected_result_file = File.join(@expected_results_folder, 'compliance_envelope_expected_results.json')
    b_result = FileUtils.compare_file(expected_result_file, test_result_file)
    BTAP::FileIO::save_osm(@model, File.join(output_folder, 'envelope_test.osm'))
    assert(b_result,
           "Envelope test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}"
    )

  end # test_envelope()

end #Class NECBHDDTests
