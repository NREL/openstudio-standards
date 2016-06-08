require_relative 'minitest_helper'
#class WeatherTests < Minitest::Test
#  # Tests to ensure that the NECB default schedules are being defined correctly.
#  # This is not for compliance, but for archetype development. This will compare
#  # to values in an excel/csv file stored in the weather folder.
#  # NECB 2011 8.4.2.3 
#  # @return [Bool] true if successful. 
#  def test_weather_reading()
#    BTAP::Environment::create_climate_index_file(
#      File.join(File.dirname(__FILE__),'..','data','weather'), 
#      File.join(File.dirname(__FILE__),'weather_test.csv') 
#    )
#    assert ( 
#      FileUtils.compare_file(File.join(File.dirname(__FILE__),'..','data','weather','weather_info.csv'), 
#        File.join(File.dirname(__FILE__),'weather_test.csv'))
#    )
#  end
#end

# This class will perform tests that are HDD dependant, Test model will be created
# to specifically test aspects of the NECB2011 code that are HDD dependant. 
class NECBHDDTests < Minitest::Test
  #set global variables
  NECB_epw_files_for_cdn_climate_zones = [
    'CAN_BC_Vancouver.718920_CWEC.epw',#  CZ 5 - Gas HDD = 3019 
    'CAN_ON_Toronto.716240_CWEC.epw', #CZ 6 - Gas HDD = 4088
    'CAN_PQ_Sherbrooke.716100_CWEC.epw', #CZ 7a - Electric HDD = 5068
    'CAN_YT_Whitehorse.719640_CWEC.epw', #CZ 7b - FuelOil1 HDD = 6946
    'CAN_NU_Resolute.719240_CWEC.epw' # CZ 8  -FuelOil2 HDD = 12570
  ] 
  NECB_climate_zone = ['NECB HDD Method']
  NECB_templates = [ 'NECB 2011']
  CREATE_MODELS = true
  RUN_MODELS = false
  COMPARE_RESULTS = false
  DEBUG = false
  
  # Create scaffolding to create a model with windows, then reset to appropriate values.
  # Will require large windows and constructions that have high U-values.    
  def setup()
    
    @weather_files = [
      
    ]
    #Create Geometry that will be used for all tests.  
    length = 100.0
    width = 100.0
    num_floors = 1
    floor_to_floor_height = 3.8
    plenum_height = 1
    perimeter_zone_depth = 4.57
    @model = OpenStudio::Model::Model.new
    BTAP::Geometry::Wizards::create_shape_rectangle(@model,
      length,
      width,
      num_floors,
      floor_to_floor_height,
      plenum_height,
      perimeter_zone_depth
    )
    
    #Add very large FDWR and SSR. 
    
    #find all outdoor surfaces. 
    outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Outdoors")
    outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
    outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")
    #Set all walls to a ratio of 0.60
    outdoor_walls.each {|wall| wall.setWindowToWallRatio(0.60) }
    
    #Set all roofs to a ratio of 0.60
    outdoor_roofs.each {|wall| wall.setWindowToWallRatio(0.60) }
    
  end
  
  # Tests to ensure that the FDWR ratio is set correctly for all HDDs
  # This is not for compliance, but for archetype development.
  # NECB 2011 8.4.4 
  # @return [Bool] true if successful. 
  def test_fdwr_max()
    assert( BTAP::Geometry::get_fwdr(@model), 0.60 ) 
    
    
  end
  
  # Tests to ensure that the SRR ratio is set correctly for all HDDs
  # This is not for compliance, but for archetype development.
  # NECB 2011 8.4.4.1
  # @return [Bool] true if successful. 
  def test_srr_max()
    assert( BTAP::Geometry::get_srr(@model), 0.60 ) 
    
  end
  
  # Tests to ensure that the U-Values of the construction are set correctly 
  # for all HDDs 
  # NECB 2011 8.4.4.1
  # @return [Bool] true if successful. 
  def test_envelope()
    #Test worst case scenario.. User is using the same constructions set for the Exterior, Ground and Interior sets. 
    #
    #Create a crappy default opaque constructions. 
    name = "opaque material" ; thickness = 0.1 ; conductivity = 0.1
    opaque_mat = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material( @model,name, thickness, conductivity) 
    name = "insulation material" ; thickness = 0.1 ; conductivity = 0.1
    insulation_mat = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material( @model,name, thickness, conductivity) 
    wall = roof = floor = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstruction", [opaque_mat,insulation_mat], insulation_mat)
    
    #Create Constructions
    exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions(@model,"ExteriorSet",wall,roof,floor)
    interior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions(@model,"InteriorSet",wall,roof,floor)
    ground_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions(@model,"GroundSet",wall,roof,floor)
      
    #Create Simple Glazing
    name = "simple glazing test";shgc  = 0.10 ; ufactor = 0.10; thickness = 0.005; visible_transmittance = 0.8
    glazing_mat = BTAP::Resources::Envelope::Materials::Fenestration::create_simple_glazing(@model,name,shgc,ufactor,thickness,visible_transmittance)
    #Create Subsurface Constructions
    fixedWindowConstruction =             BTAP::Resources::Envelope::Constructions::create_construction(@model, "Fenestration", [glazing_mat])
    operableWindowConstruction =          BTAP::Resources::Envelope::Constructions::create_construction(@model, "Fenestration", [glazing_mat])
    setDoorConstruction =                 BTAP::Resources::Envelope::Constructions::create_construction(@model, "Fenestration", [glazing_mat])
    setGlassDoorConstruction =            BTAP::Resources::Envelope::Constructions::create_construction(@model, "Fenestration", [glazing_mat])
    overheadDoorConstruction =            BTAP::Resources::Envelope::Constructions::create_construction(@model, "Fenestration", [glazing_mat])
    skylightConstruction =                BTAP::Resources::Envelope::Constructions::create_construction(@model, "Fenestration", [glazing_mat])
    tubularDaylightDomeConstruction =     BTAP::Resources::Envelope::Constructions::create_construction(@model, "Fenestration", [glazing_mat])
    tubularDaylightDiffuserConstruction = BTAP::Resources::Envelope::Constructions::create_construction(@model, "Fenestration", [glazing_mat])
    
    #Create Subsurface Constructions sets. 
    subsurface_exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_subsurface_construction_set(
      @model,
      fixedWindowConstruction,
      operableWindowConstruction,
      setDoorConstruction,
      setGlassDoorConstruction,
      overheadDoorConstruction,
      skylightConstruction,
      tubularDaylightDomeConstruction,
      tubularDaylightDiffuserConstruction)
    
    subsurface_interior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_subsurface_construction_set(
      @model,
      fixedWindowConstruction,
      operableWindowConstruction,
      setDoorConstruction,
      setGlassDoorConstruction,
      overheadDoorConstruction,
      skylightConstruction,
      tubularDaylightDomeConstruction,
      tubularDaylightDiffuserConstruction)
    
    #Create the default construction set. 
    default_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_construction_set(@model, 
      name, 
      exterior_construction_set, 
      interior_construction_set, 
      ground_construction_set, 
      subsurface_exterior_construction_set, 
      subsurface_interior_construction_set)
    @model.building.get.setDefaultConstructionSet( default_construction_set )
  end
      
      
    
    
end
  

  


# This class will perform tests that are Spacetype dependant, Test model will be created
# to specifically test aspects of the NECB2011 code that are Spacetype dependant. 
class NECB2011SpaceTypeTests < Minitest::Test
  
  # Tests to ensure that the NECB default schedules are being defined correctly.
  # This is not for compliance, but for archetype development. 
  # @return [Bool] true if successful. 
  def schedule_type_defaults_test()
    
  end
  # This test will ensure that the wildcard spacetypes are being assigned the 
  # appropriate schedule.
  # This is not for compliance, but for archetype development. 
  # @return [Bool] true if successful. 
  def wildcard_schedule_defaults_test()
    
  end
  
  # This test will ensure that the loads for each of the 133 spacetypes are 
  # being assigned the appropriate values for SHW, People and Equipment.
  # This is not for compliance, but for archetype development. 
  # @return [Bool] true if successful. 
  def internal_loads_test()
    
  end
  
  # This test will ensure that the loads for each of the 133 spacetypes are 
  # being assigned the appropriate values for LPD.
  # This is not for compliance, but for archetype development. 
  # @return [Bool] true if successful.
  def lighting_power_density_test()
    
  end
  
  
  # This test will ensure that the system selection for each of the 133 spacetypes are 
  # being assigned the appropriate values for LPD.
  # @return [Bool] true if successful.
  def system_selection_test()
    
  end
  
  
end




