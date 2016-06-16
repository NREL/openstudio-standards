require_relative 'minitest_helper'


# This class will perform tests that are HDD driven, A Test model will be created
# that will have all of OpenStudios surface types with different contructions. All
# components are created from scratch to ensure model are up to date and we will
# not run into version issues with the test. 
# to specifically test aspects of the NECB2011 code that are HDD dependant. 
class NECBHDDTests < Minitest::Test
  #set global weather files sample
  NECB_epw_files_for_cdn_climate_zones = [
    'CAN_BC_Vancouver.718920_CWEC.epw',#  CZ 4 HDD = 2932
    'CAN_BC_Kamloops.718870_CWEC.epw',#    CZ 5 HDD = 3567
    'CAN_ON_Ottawa.716280_CWEC.epw', #CZ 6 HDD = 4563
    'CAN_PQ_Ste.Agathe.des.Monts.717200_CWEC.epw', #CZ 7aHDD = 5501
    'CAN_MB_The.Pas.718670_CWEC.epw', #CZ 7b HDD = 6572
    'CAN_NU_Resolute.719240_CWEC.epw' # CZ 8HDD = 12570
  ] 
  #Set Compliance vintage
  Templates = ['NECB 2011']#,'90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013']
  
  # Create scaffolding to create a model with windows, then reset to appropriate values.
  # Will require large windows and constructions that have high U-values.    
  def setup()

    #Create new model for testing. 
    @model = OpenStudio::Model::Model.new
    #Create Geometry that will be used for all tests.  
    
    #Below ground story to tests all ground surfaces including roof.
    length = 100.0; width = 100.0 ; num_above_ground_floors = 0; num_under_ground_floors = 1; floor_to_floor_height = 3.8 ; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = -10.0
    @below_ground_floors = BTAP::Geometry::Wizards::create_shape_rectangle(@model,length, width, num_above_ground_floors,num_under_ground_floors, floor_to_floor_height, plenum_height,perimeter_zone_depth, initial_height )

    #Above ground story to test all above outdoors surfaces including floor.
    length = 100.0; width = 100.0 ; num_above_ground_floors = 3; num_under_ground_floors = 0; floor_to_floor_height = 3.8 ; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = 10.0
    @above_ground_floors = BTAP::Geometry::Wizards::create_shape_rectangle(@model,length, width, num_above_ground_floors,num_under_ground_floors, floor_to_floor_height, plenum_height,perimeter_zone_depth, initial_height )

    #Find all outdoor surfaces. 
    outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Outdoors")
    @outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
    @outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")
    
    #Set all FWDR to a ratio of 0.60
    subsurfaces = []
    counter = 0
    @outdoor_walls.each {|wall| subsurfaces << wall.setWindowToWallRatio(0.60) }
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
    pattern = OpenStudio::Model::generateSkylightPattern(@model.getSpaces,@model.getSpaces[0].directionofRelativeNorth,0.10, 4.0, 4.0) # ratio, x value, y value
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

  end #setup()
  

  
  # Tests to ensure that the U-Values of the construction are set correctly. This 
  # test will set up  
  # for all HDDs 
  # NECB 2011 8.4.4.1
  # @return [Bool] true if successful. 
  def test_necb_hdd_envelope_rules()
    # Todo - Define a construction directly to a surface. 
    # Todo - Define a construction set to a space directly.
    # Todo - Define a construction set to a floor directly. 
    # Todo - Define an adiabatic surface (See if it handle the bug)
    # Todo - Roughly 1 day of work (phylroy) 
     
    #Create report string. 
    
    @output = ""
     
    
    #Iterate through the weather files. 
    NECB_epw_files_for_cdn_climate_zones.each do |weather_file|
      @hdd = BTAP::Environment::WeatherFile.new(weather_file).hdd18
      #Iterate through the vintage templates 'NECB 2011', etc..
      Templates.each do |template|
      
        #Define Materials
        name = "opaque material";      thickness = 0.012700; conductivity = 0.160000
        opaque_mat     = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material( @model, name, thickness, conductivity)
    
        name = "insulation material";  thickness = 0.050000; conductivity = 0.043000
        insulation_mat = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material( @model,name, thickness, conductivity)
    
        name = "simple glazing test";shgc  = 0.250000 ; ufactor = 3.236460; thickness = 0.003000; visible_transmittance = 0.160000
        simple_glazing_mat = BTAP::Resources::Envelope::Materials::Fenestration::create_simple_glazing(@model,name,shgc,ufactor,thickness,visible_transmittance)
    
        name = "Standard Glazing Test"; thickness = 0.003; conductivity = 0.9; solarTransmittanceatNormalIncidence = 0.84; frontSideSolarReflectanceatNormalIncidence = 0.075; backSideSolarReflectanceatNormalIncidence = 0.075; visibleTransmittance = 0.9; frontSideVisibleReflectanceatNormalIncidence = 0.081; backSideVisibleReflectanceatNormalIncidence = 0.081; infraredTransmittanceatNormalIncidence = 0.0; frontSideInfraredHemisphericalEmissivity = 0.84; backSideInfraredHemisphericalEmissivity = 0.84; opticalDataType = "SpectralAverage"; dirt_correction_factor = 1.0; is_solar_diffusing = false
        standard_glazing_mat =BTAP::Resources::Envelope::Materials::Fenestration::create_standard_glazing( @model, name ,thickness, conductivity, solarTransmittanceatNormalIncidence, frontSideSolarReflectanceatNormalIncidence, backSideSolarReflectanceatNormalIncidence, visibleTransmittance, frontSideVisibleReflectanceatNormalIncidence, backSideVisibleReflectanceatNormalIncidence, infraredTransmittanceatNormalIncidence, frontSideInfraredHemisphericalEmissivity, backSideInfraredHemisphericalEmissivity,opticalDataType, dirt_correction_factor, is_solar_diffusing)
    
        #Define Constructions
        # # Surfaces 
        ext_wall                            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionExtWall",                    [opaque_mat,insulation_mat], insulation_mat)
        ext_roof                            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionExtRoof",                    [opaque_mat,insulation_mat], insulation_mat)
        ext_floor                           = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionExtFloor",                   [opaque_mat,insulation_mat], insulation_mat)
        grnd_wall                           = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionGrndWall",                   [opaque_mat,insulation_mat], insulation_mat)
        grnd_roof                           = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionGrndRoof",                   [opaque_mat,insulation_mat], insulation_mat)
        grnd_floor                          = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionGrndFloor",                  [opaque_mat,insulation_mat], insulation_mat)
        int_wall                            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionIntWall",                    [opaque_mat,insulation_mat], insulation_mat)
        int_roof                            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionIntRoof",                    [opaque_mat,insulation_mat], insulation_mat)
        int_floor                           = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionIntFloor",                   [opaque_mat,insulation_mat], insulation_mat)
        # # Subsurfaces
        fixedWindowConstruction             = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionFixed",                [simple_glazing_mat])
        operableWindowConstruction          = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionOperable",             [simple_glazing_mat])
        setGlassDoorConstruction            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionDoor",                 [standard_glazing_mat])
        setDoorConstruction                 = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionDoor",                       [opaque_mat,insulation_mat], insulation_mat)
        overheadDoorConstruction            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionOverheadDoor",               [opaque_mat,insulation_mat], insulation_mat)
        skylightConstruction                = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionSkylight",             [standard_glazing_mat])
        tubularDaylightDomeConstruction     = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionDomeConstruction",     [standard_glazing_mat])
        tubularDaylightDiffuserConstruction = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionDiffuserConstruction", [standard_glazing_mat])
    
        #Define Construction Sets
        # # Surface
        exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions( @model,"ExteriorSet",ext_wall,ext_roof,ext_floor)
        interior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions( @model,"InteriorSet",int_wall,int_roof,int_floor)
        ground_construction_set   = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions( @model,"GroundSet",  grnd_wall,grnd_roof,grnd_floor)
    
        # # Subsurface 
        subsurface_exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_subsurface_construction_set( @model, fixedWindowConstruction, operableWindowConstruction, setDoorConstruction, setGlassDoorConstruction, overheadDoorConstruction, skylightConstruction, tubularDaylightDomeConstruction, tubularDaylightDiffuserConstruction)
        subsurface_interior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_subsurface_construction_set( @model, fixedWindowConstruction, operableWindowConstruction, setDoorConstruction, setGlassDoorConstruction, overheadDoorConstruction, skylightConstruction, tubularDaylightDomeConstruction, tubularDaylightDiffuserConstruction)
    
        #Define default construction sets.
        name = "Construction Set 1"
        default_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_construction_set(@model, name, exterior_construction_set, interior_construction_set, ground_construction_set, subsurface_exterior_construction_set, subsurface_interior_construction_set)

    
        #Assign default to the model. 
        @model.getBuilding.setDefaultConstructionSet( default_construction_set )
      
        #Add weather file, HDD.
        @model.add_design_days_and_weather_file('HighriseApartment', template, 'NECB HDD Method', File.basename(weather_file))
      
        # Reduce the WWR and SRR, if necessary
        @model.apply_performance_rating_method_baseline_window_to_wall_ratio(template)
        @model.apply_performance_rating_method_baseline_skylight_to_roof_ratio(template)
        
        # Apply Construction
        @model.apply_performance_rating_method_construction_types(template)
        
        #Add Infiltration rates to the space objects themselves. 
        @model.apply_infiltration_standard(template)
        

      
        #Get Surfaces by type.
        outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Outdoors")
        outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
        outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")
        outdoor_floors = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Floor")
        outdoor_subsurfaces = BTAP::Geometry::Surfaces::get_subsurfaces_from_surfaces(outdoor_surfaces)
        windows = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["FixedWindow" , "OperableWindow" ])
        skylights = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Skylight", "TubularDaylightDiffuser","TubularDaylightDome" ])
        doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Door" , "GlassDoor" ])
        overhead_doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["OverheadDoor" ])
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
        
        
        
        #Create headers.
        
        @header_output  = ""
        @header_output  << "Vintage,WeatherFile,HDD,FDWR,SRR," 
        @header_output  << "outdoor_walls_average_conductance,outdoor_roofs_average_conductance,outdoor_floors_average_conductance,"
        @header_output  << "ground_walls_average_conductances, ground_roofs_average_conductances, ground_floors_average_conductances,"
        @header_output  << "windows_average_conductance,skylights_average_conductance,doors_average_conductance,overhead_doors_average_conductance,"
        
        
        #Output conductances 
        @output << "#{template},#{weather_file},#{@hdd.round(0)},#{BTAP::Geometry::get_fwdr(@model).round(4)},#{BTAP::Geometry::get_srr(@model).round(4)},"
        @output << "#{outdoor_walls_average_conductance.round(4)} ,#{outdoor_roofs_average_conductance.round(4)} , #{outdoor_floors_average_conductance.round(4)},"
        @output << "#{ground_walls_average_conductances.round(4)},#{ground_roofs_average_conductances.round(4)},#{ground_floors_average_conductances.round(4)},"
        @output << "#{windows_average_conductance.round(4)},#{skylights_average_conductance.round(4)},#{doors_average_conductance.round(4)},#{overhead_doors_average_conductance.round(4)},"
        
        #infiltration test
        # Get the effective infiltration rate through the walls and roof only.
        BTAP::Geometry::Spaces::get_spaces_from_storeys(@model,@above_ground_floors).each do |space|
          @header_output << "#{space.name} - Wall/Roof infil rate (L/s/m2),"
          assert( space.spaceInfiltrationDesignFlowRates.size <= 1, "There should be no more than one infiltration object per space in the reference/budget building#{space.spaceInfiltrationDesignFlowRates}" )
          #If space rightfully does not have an infiltration rate (no exterior surfaces) output an NA. 
          if space.spaceInfiltrationDesignFlowRates.size == 0
            @output << "NA,"
          else
            #Do some math to determine the effective infiltration rate of the walls and roof only as per NECB. 
            wall_roof_infiltration_rate  = space.spaceInfiltrationDesignFlowRates[0].flowperExteriorSurfaceArea.get *  space.exteriorArea / space.exterior_wall_and_roof_and_subsurface_area
            #Output effective infiltration rate
            @output << "#{wall_roof_infiltration_rate * 1000},"
          end
        end
        @header_output << "\n"
        @output << "\n"
        BTAP::FileIO::save_osm(@model, File.join(File.dirname(__FILE__),"output","#{template}-hdd#{@hdd}-envelope_test.osm"))
      end #Weather file loop.
    end # Template vintage loop
    
    #Write test report file. 
    test_result_file = File.join(File.dirname(__FILE__),'regression_files','compliance_envelope_test_results.csv')
    File.open(test_result_file, 'w') {|f| f.write( @header_output + @output) }
    
    #Test that the values are correct by doing a file compare.
    expected_result_file = File.join(File.dirname(__FILE__),'regression_files','compliance_envelope_expected_results.csv')
    b_result = FileUtils.compare_file(expected_result_file , test_result_file )
    BTAP::FileIO::save_osm(@model, File.join(File.dirname(__FILE__),'envelope_test.osm'))
    assert( b_result, 
      "Envelope test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}"
    )  
  end # test_envelope()
      
      
    
    
end #Class NECBHDDTests


# This class will perform tests that are Spacetype dependant, Test model will be created
# to specifically test aspects of the NECB2011 code that are Spacetype dependant. 
class NECB2011DefaultSpaceTypeTests < Minitest::Test
  #Standards
  Templates = ['NECB 2011']#,'90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013']
  #NECB Building Spacetype definition names. 
  BuildingTypeNames = [
    "Automotive facility",
    "Convention centre",
    "Courthouse",
    "Dining - bar/lounge",
    "Dining - cafeteria",
    "Dining - family",
    "Dormitory",
    "Exercise centre",
    "Fire station",
    "Gymnasium",
    "Health-care clinic",
    "Hospital",
    "Hotel",
    "Library",
    "Manufacturing facility",
    "Motel",
    "Motion picture theatre",
    "Multi-unit residential",
    "Museum",
    "Office",
    "Parking garage",
    "Penitentiary",
    "Performing arts theatre",
    "Police station",
    "Post office",
    "Religious",
    "Retail",
    "School/university",
    "Sports arena",
    "Town hall",
    "Transportation",
    "Warehouse",
    "Workshop",
  ]

  #NECB Spacetype definition names. 
  SpaceTypeNames = [
    "- undefined -",
    "Dwelling Unit(s)",
    "Atrium - H < 13m",
    "Atrium - H > 13m",
    "Audience - auditorium",
    "Audience - performance arts",
    "Audience - motion picture",
    "Classroom/lecture/training",
    "Conf./meet./multi-purpose",
    "Corr. >= 2.4m wide",
    "Corr. < 2.4m wide",
    "Dining - bar lounge/leisure",
    "Dining - family space",
    "Dining - other",
    "Dress./fitt. - performance arts",
    "Electrical/Mechanical",
    "Food preparation",
    "Lab - classrooms",
    "Lab - research",
    "Lobby - elevator",
    "Lobby - performance arts",
    "Lobby - motion picture",
    "Lobby - other",
    "Locker room",
    "Lounge/recreation",
    "Office - enclosed",
    "Office - open plan",
    "Sales area",
    "Stairway",
    "Storage area",
    "Washroom",
    "Workshop space",
    "Automotive - repair",
    "Bank - banking and offices",
    "Convention centre - audience",
    "Convention centre - exhibit",
    "Courthouse - courtroom",
    "Courthouse - cell",
    "Courthouse - chambers",
    "Penitentiary - audience",
    "Penitentiary - classroom",
    "Penitentiary - dining",
    "Dormitory - living quarters",
    "Fire station - engine room",
    "Fire station - quarters",
    "Gym - fitness",
    "Gym - audience",
    "Gym - play",
    "Hospital corr. >= 2.4m",
    "Hospital corr. < 2.4m",
    "Hospital - emergency",
    "Hospital - exam",
    "Hospital - laundry/washing",
    "Hospital - lounge/recreation",
    "Hospital - medical supply",
    "Hospital - nursery",
    "Hospital - nurses' station",
    "Hospital - operating room",
    "Hospital - patient room",
    "Hospital - pharmacy",
    "Hospital - physical therapy",
    "Hospital - radiology/imaging",
    "Hospital - recovery",
    "Hotel/Motel - dining",
    "Hotel/Motel - rooms",
    "Hotel/Motel - lobby",
    "Hway lodging - dining",
    "Hway lodging - rooms",
    "Library - cataloging",
    "Library - reading",
    "Library - stacks",
    "Mfg - corr. >= 2.4m",
    "Mfg - corr. < 2.4m",
    "Mfg - detailed",
    "Mfg - equipment",
    "Mfg - bay H > 15m",
    "Mfg - 7.5 <= bay H <= 15m",
    "Mfg - bay H < 7.5m",
    "Museum - exhibition",
    "Museum - restoration",
    "Parking garage space",
    "Post office sorting",
    "Religious - audience",
    "Religious - fellowship hall",
    "Religious - pulpit/choir",
    "Retail - dressing/fitting",
    "Retail - mall concourse",
    "Retail - sales",
    "Sports arena - audience",
    "Sports arena - court c4",
    "Sports arena - court c3",
    "Sports arena - court c2",
    "Sports arena - court c1",
    "Sports arena - ring",
    "Transp. baggage",
    "Transp. seating",
    "Transp. concourse",
    "Transp. counter",
    "Warehouse - fine",
    "Warehouse - med/blk",
    "Warehouse - med/blk2",
  ]
  def setup()
    #Create new model for testing. 
    @model = OpenStudio::Model::Model.new
    #    #Create Geometry that will be used for all tests.  
    #    
    #Create only above ground geometry (Used for infiltration tests) 
    length = 100.0; width = 100.0 ; num_above_ground_floors = 1; num_under_ground_floors = 0; floor_to_floor_height = 3.8 ; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = 10.0
    BTAP::Geometry::Wizards::create_shape_rectangle(@model,length, width, num_above_ground_floors,num_under_ground_floors, floor_to_floor_height, plenum_height,perimeter_zone_depth, initial_height )

  end
  
  # Tests to ensure that the NECB default schedules are being defined correctly.
  # This is not for compliance, but for archetype development. 
  # @return [Bool] true if successful. 
  def test_schedule_type_defaults()
    header_output = ""
    output = ""
    #Iterate through all spacetypes/buildingtypes. 
    Templates.each do |template|
      SpaceTypeNames.each do |name|
        header_output = ""
        # Create a space type
        st = OpenStudio::Model::SpaceType.new(@model)
        st.setStandardsBuildingType('Space Function')
        st.setStandardsSpaceType(name)
        st.setName(name)
        st.set_rendering_color(template)

        @model.add_loads(template)

        #Set all spaces to spacetype
        @model.getSpaces.each do |space|
          space.setSpaceType(st)
        end
        
        #Add Infiltration rates to the space objects themselves. 
        @model.apply_infiltration_standard(template)
        
        #Get handle for space. 
        space = @model.getSpaces[0]
        space_area = space.floorArea #m2
        

        #Lights
        total_lpd = []
        lpd_sched = []
        st.lights.each {|light| total_lpd << light.powerPerFloorArea.get ; lpd_sched << light.schedule.get.name}
        assert(total_lpd.size <= 1 , "#{total_lpd.size} light definitions given. Expecting <= 1.")
      
        #People / Occupancy
        total_occ_dens = []
        occ_sched = []
        st.people.each {|people_def| total_occ_dens << people_def.spaceFloorAreaPerPerson.get ; occ_sched << people_def.numberofPeopleSchedule.get.name}
        assert(total_lpd.size <= 1 , "#{total_occ_dens.size} people definitions given. Expecting <= 1.")   
      
        #Equipment -Gas
        gas_equip_power = []
        gas_equip_sched = []
        st.gasEquipment.each {|gas_equip| gas_equip_power << gas_equip.powerPerFloorArea.get ; gas_equip_sched << gas_equip.schedule.get.name}
        assert( gas_equip_power.size <= 1 , "#{gas_equip_power.size} gas definitions given. Expecting <= 1." ) 
      
        #Equipment -Electric
        elec_equip_power = []
        elec_equip_sched = []
        st.electricEquipment.each {|elec_equip| elec_equip_power << elec_equip.powerPerFloorArea.get ; elec_equip_sched << elec_equip.schedule.get.name}
        assert( elec_equip_power.size <= 1 , "#{elec_equip_power.size} electric definitions given. Expecting <= 1." ) 
      
        #Equipment - Steam
        steam_equip_power = []
        steam_equip_sched = []
        st.steamEquipment.each {|steam_equip| steam_equip_power << steam_equip.powerPerFloorArea.get ; steam_equip_sched << steam_equip.schedule.get.name}
        assert( steam_equip_power.size <= 1 , "#{steam_equip_power.size} steam definitions given. Expecting <= 1." ) 
      
        #Hot Water Equipment
        hw_equip_power = []
        hw_equip_sched = []
        st.hotWaterEquipment.each {|equip| hw_equip_power << equip.powerPerFloorArea.get ; hw_equip_sched << equip.schedule.get.name}
        assert( hw_equip_power.size <= 1 , "#{hw_equip_power.size} hw definitions given. Expecting <= 1." ) 
      
        #Other Equipment
        other_equip_power = []
        other_equip_sched = []
        st.otherEquipment.each {|equip| other_equip_power << equip.powerPerFloorArea.get ; other_equip_sched << equip.schedule.get.name}
        assert( other_equip_power.size <= 1 , "#{other_equip_power.size} other equipment definitions given. Expecting <= 1." ) 
          
        #SHW
        shw_loop = OpenStudio::Model::PlantLoop.new(@model)
        shw_peak_flow_per_area = []
        shw_heating_target_temperature = []
        shw__schedule = ""
        area_per_occ = 0.0
        area_per_occ = total_occ_dens[0] unless total_occ_dens[0].nil?
        water_fixture = @model.add_swh_end_uses_by_space('Space Function', template, 'NECB HDD Method', shw_loop, st.name.get, space.name.get)
        shw__fraction_schedule = water_fixture.flowRateFractionSchedule.get.name
        shw_peak_flow = water_fixture.waterUseEquipmentDefinition.getPeakFlowRate.value # m3/s
        shw_peak_flow_per_area = shw_peak_flow / space_area #m3/s/m2
        # # Watt per person =             m3/s/m3        * 1000W/kW * (specific heat * dT) * m2/person
        shw_watts_per_person = shw_peak_flow_per_area * 1000 * (4.19 * 44.4) * 1000 * area_per_occ
        shw_target_temperature_schedule = water_fixture.waterUseEquipmentDefinition.targetTemperatureSchedule.get.to_ScheduleRuleset.get.defaultDaySchedule.values
   


        header_output << "SpaceType,"
        output << "#{st.name},"
        #lights
        if total_lpd[0].nil?
          total_lpd[0] = 0.0
          lpd_sched[0] = "NA"
        end
        header_output << "Lighting Power Density (W/m2),"
        output << "#{total_lpd[0].round(4)},"
        header_output << "Lighting Schedule,"
        output << "#{lpd_sched[0]},"
      
        #people
        if total_occ_dens[0].nil?
          total_occ_dens[0] = 0.0
          occ_sched[0] = "NA"
        end
        header_output << "Occupancy Density (m2/person),"
        output << "#{total_occ_dens[0].round(4)},"
        header_output << "Occupancy Schedule Name,"
        output << "#{occ_sched[0]},"

        #equipment - Elec
        if elec_equip_power[0].nil?
          elec_equip_power[0] = 0.0
          elec_equip_sched[0] = "NA"
        end
        header_output << "Elec Equip Power Density (W/m2),"
        output << "#{elec_equip_power[0].round(4)},"
        header_output << "Elec Equip Schedule,"
        output << "#{elec_equip_sched[0]}," 
      
        #equipment - Gas
        if gas_equip_power[0].nil?
          gas_equip_power[0] = 0.0
          gas_equip_sched[0] = "NA"
        end
        header_output << "Gas Equip Power Density (W/m2),"
        output << "#{gas_equip_power[0].round(4)},"
        header_output << "Gas Equip Schedule Name,"
        output << "#{gas_equip_sched[0]}," 
      
        #equipment - steam
        if steam_equip_power[0].nil?
          steam_equip_power[0] = 0.0
          steam_equip_sched[0] = "NA"
        end
        header_output << "Steam Equip Power Density (W/m2),"
        output << "#{steam_equip_power[0].round(4)},"
        header_output << "Steam Equip Schedule,"
        output << "#{steam_equip_sched[0]},"
      
        #equipment - hot water
        if hw_equip_power[0].nil?
          hw_equip_power[0] = 0.0
          hw_equip_sched[0] = "NA"
        end
        header_output << "HW Equip Power Density (W/m2),"
        output << "#{hw_equip_power[0].round(4)},"
        header_output << "HW Equip Schedule,"
        output << "#{hw_equip_sched[0]},"
          
        #SHW
        header_output << "SHW Watt/Person (W/person),"
        output << "#{shw_watts_per_person},"
        header_output << "SHW Fraction Schedule,"
        output << "#{shw__fraction_schedule},"
        header_output << "SHW Temperature Setpoint Schedule Values (C),"
        output << "#{shw_target_temperature_schedule},"

        #End line
        header_output << "\n"
        output << "\n"
          
        #remove space_type (This speeds things up a bit. 
        st.remove
        shw_loop.remove
        water_fixture.remove
          
      end #loop spacetypes
    end #loop Template
    #Write test report file. 
    test_result_file = File.join(File.dirname(__FILE__),'regression_files','space_type_test_results.csv')
    File.open(test_result_file, 'w') {|f| f.write(header_output + output) }
    
    #Test that the values are correct by doing a file compare.
    expected_result_file = File.join(File.dirname(__FILE__),'regression_files','space_type_expected_results.csv')
    b_result = FileUtils.compare_file(expected_result_file , test_result_file )
    assert( b_result, 
      "Envelope test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}"
    )  
  end 

  #  # This test will ensure that the system selection for each of the 133 spacetypes are 
  #  # being assigned the appropriate values for LPD.
  #  # @return [Bool] true if successful.
  def system_selection()
  
    space_type_catagories = {}
    BTAP::Compliance::NECB2011::Data::SpaceTypeData.each do |space_type_data|
      if space_type_catagories[space_type_data[11]].nil? 
        space_type_catagories[space_type_data[11]] = Array.new
      end
      space_type_catagories[space_type_data[11]] << space_type_data[0]
    end
    
    floors = 1
    space_type_catagories.each do |name,values|      
      values.sort.each do |value|
        case name
        when "Assembly Area" #Assembly Area.
          #Test different floor numbers
          [4,5].each do |floor_number|
            #BTAP::Compliance::NECB2011::necb_autozone_and_autosystem(@model,nil)
          end
        when "Automotive Area"
          

        end
       
      end
    end
  end
  #  end
  
  
end




