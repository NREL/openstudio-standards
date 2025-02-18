require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

# This class will perform tests that are HDD driven, A Test model will be created
# that will have all of OpenStudios surface types with different contructions. All
# components are created from scratch to ensure model are up to date and we will
# not run into version issues with the test.
## to specifically test aspects of the NECB2011 code that are HDD dependant.
class NECB_Constructions_FDWR_Tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Set global weather files sample.
  NECB_epw_files_for_cdn_climate_zones = [
      'CAN_BC_Vancouver.Intl.AP.718920_CWEC2020.epw', #  CZ 4 HDD = 2932
      'CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw', #    CZ 5 HDD = 3567
      'CAN_QC_Montreal.Intl.AP.716270_CWEC2020.epw', #CZ 6 HDD = 4563
      'CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw', #CZ 7aHDD = 5501
      'CAN_AB_Fort.Mcmurray.AP.716890_CWEC2020.epw', #CZ 7b HDD = 6572
      'CAN_NT_Yellowknife.AP.719360_CWEC2020.epw' # CZ 8HDD = 12570
  ]

  # Create scaffolding to create a model with windows, then reset to appropriate values.
  # Will require large windows and constructions that have high U-values.
  def create_base_model()

    #Create new model for testing.
    @model = OpenStudio::Model::Model.new
    #Create Geometry that will be used for all tests.

    #Below ground story to tests all ground surfaces including roof.
    length = 100.0; width = 100.0; num_above_ground_floors = 0; num_under_ground_floors = 1; floor_to_floor_height = 3.8; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = -10.0

    OpenstudioStandards::Geometry.create_shape_rectangle(@model, length, width, num_above_ground_floors, num_under_ground_floors, floor_to_floor_height, plenum_height, perimeter_zone_depth, initial_height)
    @below_ground_floors = OpenstudioStandards::Geometry.model_get_building_stories_below_ground(@model)

    #Above ground story to test all above outdoors surfaces including floor.
    length = 100.0; width = 100.0; num_above_ground_floors = 3; num_under_ground_floors = 0; floor_to_floor_height = 3.8; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = 10.0
    OpenstudioStandards::Geometry.create_shape_rectangle(@model, length, width, num_above_ground_floors, num_under_ground_floors, floor_to_floor_height, plenum_height, perimeter_zone_depth, initial_height)
    @above_ground_floors = OpenstudioStandards::Geometry.model_get_building_stories_above_ground(@model)

    #Find all outdoor surfaces.
    outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Outdoors")
    @outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
    @outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")

    @model.getBuilding.setStandardsNumberOfStories(4)
    @model.getBuilding.setStandardsNumberOfAboveGroundStories(3)

    #Set all FWDR to a ratio of 0.60
    subsurfaces = []
    counter = 0
    @outdoor_walls.each { |wall| subsurfaces << wall.setWindowToWallRatio(0.60) }
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

    standard = get_standard("NECB2011")
    standard.model_clear_and_set_example_constructions(@model)
    #Ensure that building is Conditioned add spacetype to each space.

  end

  # Tests to ensure that the U-Values of the construction are set correctly. This
  # test will set up
  # for all HDDs
  # NECB2011 8.4.4.1
  # @return [Boolean] true if successful.
  def test_necb_hdd_envelope_rules()

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)

    # Create report string.
    @json_test_output = {}

    # Iterate through the vintage templates 'NECB2011', etc..
    @AllTemplates.each do |template|
      @json_test_output[template] = {}

      # Iterate through the weather files.
      NECB_epw_files_for_cdn_climate_zones.each do |weather_file|
        create_base_model()

        # Create a space type and assign to all spaces.. This is done because the FWDR is only applied to conditioned spaces.. So we need conditioning data.
        building_type = "Office"
        space_type = "WholeBuilding"
        standard = get_standard(template)

        table = standard.standards_data['tables']['space_types']['table']
        space_type_properties = table.detect { |st| st["building_type"] == building_type && st["space_type"] == space_type }
        st = OpenStudio::Model::SpaceType.new(@model)
        st.setStandardsBuildingType(space_type_properties['building_type'])
        st.setStandardsSpaceType(space_type_properties['space_type'])
        st.setName("#{template}-#{space_type_properties['building_type']}-#{space_type_properties['space_type']}")
        standard.space_type_apply_rendering_color(st)
        standard.model_add_loads(@model, 'NECB_Default', 1.0)

        # Now loop through each space and assign the spacetype.
        @model.getSpaces.each do |space|
          space.setSpaceType(st)
        end

        # Create Zones.
        standard.model_create_thermal_zones(@model)

        # Worflow should mirror BTAP workflow up to fdwr. Note envelope includes infiltration.
        # Not validating spacetypes as not needed for this simplified test.
        standard.apply_weather_data(model: @model, epw_file: File.basename(weather_file))
        standard.apply_loads(model: @model)
        standard.apply_envelope(model: @model)
        standard.apply_fdwr_srr_daylighting(model: @model)

        # Store hdd for classifing results.
        @hdd = standard.get_necb_hdd18(model: @model, necb_hdd: true)

        # Set the infiltration rate at each space.
        @model.getSpaces.sort.each do |space|
          standard.space_apply_infiltration_rate(space)
        end

        # Get Surfaces by type.
        outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Outdoors")
        outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
        outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")
        outdoor_floors = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Floor")
        outdoor_subsurfaces = outdoor_surfaces.flat_map(&:subSurfaces)
        windows = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["FixedWindow", "OperableWindow"])
        skylights = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Skylight", "TubularDaylightDiffuser", "TubularDaylightDome"])
        doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Door", "GlassDoor"])
        overhead_doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["OverheadDoor"])
        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Ground")
        ground_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Wall")
        ground_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "RoofCeiling")
        ground_floors = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Floor")

        # Determine the weighted average conductances by surface type.
        ## exterior surfaces.
        outdoor_walls_average_conductance = OpenstudioStandards::Constructions.surfaces_get_conductance(outdoor_walls)
        outdoor_roofs_average_conductance = OpenstudioStandards::Constructions.surfaces_get_conductance(outdoor_roofs)
        outdoor_floors_average_conductance = OpenstudioStandards::Constructions.surfaces_get_conductance(outdoor_floors)
        ## Ground surfaces.
        ground_walls_average_conductances = OpenstudioStandards::Constructions.surfaces_get_conductance(ground_walls)
        ground_roofs_average_conductances = OpenstudioStandards::Constructions.surfaces_get_conductance(ground_roofs)
        ground_floors_average_conductances = OpenstudioStandards::Constructions.surfaces_get_conductance(ground_floors)
        ## Sub surfaces.
        windows_average_conductance = OpenstudioStandards::Constructions.surfaces_get_conductance(windows)
        windows_average_shgc = OpenstudioStandards::Constructions.surfaces_get_solar_transmittance(windows)
        skylights_average_conductance = OpenstudioStandards::Constructions.surfaces_get_conductance(skylights)
        doors_average_conductance = OpenstudioStandards::Constructions.surfaces_get_conductance(doors)
        #overhead_doors_average_conductance = OpenstudioStandards::Constructions.surfaces_get_conductance(overhead_doors)

        # SRR and FDWR.
        srr_info = standard.find_exposed_conditioned_roof_surfaces(@model)
        fdwr_info = standard.find_exposed_conditioned_vertical_surfaces(@model)

        # Output conductances.
        def roundOrNA(data, figs = 4)
          if data.nil? || data == 'NA'
            return 'NA'
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
        @json_test_output[template][@hdd]['windows_average_shgc'] = roundOrNA(windows_average_shgc)
        @json_test_output[template][@hdd]['skylights_average_conductance'] = roundOrNA(skylights_average_conductance)
        @json_test_output[template][@hdd]['doors_average_conductance'] = roundOrNA(doors_average_conductance)


        # Infiltration test.
        # Get the effective infiltration rate through the walls and roof only.
        sorted_spaces = @above_ground_floors.flat_map(&:spaces).sort_by { |space| space.name.get }

        # Need to sort spaces otherwise the output order is random.
        @json_test_output[template][@hdd]['Wall/Roof infil rate (L/s/m2)'] = {}
        sorted_spaces.each do |space|
          assert(space.spaceInfiltrationDesignFlowRates.size <= 1, "There should be no more than one infiltration object per space in the reference/budget building#{space.spaceInfiltrationDesignFlowRates}")

          # If space rightfully does not have an infiltration rate (no exterior surfaces) output an NA.
          if space.spaceInfiltrationDesignFlowRates.size == 0
            @json_test_output[template][@hdd]['Wall/Roof infil rate (L/s/m2)'][space.name] = "NA,"
          else
            # Do some math to determine the effective infiltration rate of the walls and roof only as per NECB.
            wall_roof_infiltration_rate = space.spaceInfiltrationDesignFlowRates[0].flowperExteriorSurfaceArea.get * space.exteriorArea / OpenstudioStandards::Geometry.space_get_exterior_wall_and_subsurface_and_roof_area(space)
            # Output effective infiltration rate
            @json_test_output[template][@hdd]['Wall/Roof infil rate (L/s/m2)'][space.name] = "#{(wall_roof_infiltration_rate * 1000).round(3)},"

          end
        end

        BTAP::FileIO::save_osm(@model, File.join(output_folder, '#{template}-hdd#{@hdd}-envelope_test.osm'))
      end # Weather file loop.
    end # Template vintage loop

    # Write test report and osm files.
    test_result_file = File.join(@test_results_folder, 'compliance_envelope_test_results.json')
    File.open(test_result_file, 'w') { |f| f.write(JSON.pretty_generate(@json_test_output)) }

    # Test that the values are correct by doing a file compare.
    expected_result_file = File.join(@expected_results_folder, 'compliance_envelope_expected_results.json')

    # Check if test results match expected.
    msg = "Envelope test results do not match what is expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end # test_envelope()

end # Class NECBHDDTests
