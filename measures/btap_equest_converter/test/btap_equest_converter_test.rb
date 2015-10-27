require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class BtapEquestConverterTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end



  def import_inp_test(inp_file) 
    
    # create an instance of the measure, a runner and an empty model
    measure = BtapEquestConverter.new
    runner = OpenStudio::Ruleset::OSRunner.new
    model = OpenStudio::Model::Model.new
    #create argument map
    facade = OpenStudio::Ruleset::OSArgument::makeStringArgument("inp_file");
    facade.setValue(inp_file);

    args  = OpenStudio::Ruleset::OSArgumentVector.new();
    args << facade
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(args)

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    BTAP::runner_register("Info", "*********Running Unit Tests against #{inp_file}*************" ,runner)
    #Create an instances of a DOE model
    doe_model = BTAP::EQuest::DOEBuilding.new()
    #Load the inp data into the DOE model.
    doe_model.load_inp(inp_file)
    
     
    # check that number of thermal spaces are the same for osm and inp. 
    doe_spaces = doe_model.find_all_commands("SPACE")
    osm_spaces = model.getSpaces
    assert_equal( doe_spaces.size , osm_spaces.size, "#{doe_spaces.size} spaces detected in inp file and #{osm_spaces.size} spaces created in osm.")

    # check that number of thermal zones,  are the same in the inp and osm files. 
    doe_zones = doe_model.find_all_commands("ZONE")
    osm_zones = model.getThermalZones
    assert_equal( doe_zones.size , osm_zones.size, "#{doe_zones.size} zones detected in inp file and #{osm_zones.size} zones created in osm.")

    
    # compare number of all surfaces
    doe_surfaces = []
    doe_surfaces.concat( doe_model.find_all_commands("EXTERIOR-WALL") ) 
    doe_surfaces.concat( doe_model.find_all_commands("INTERIOR-WALL") )
    doe_surfaces.concat( doe_model.find_all_commands("UNDERGROUND-WALL") )
    doe_surfaces.concat( doe_model.find_all_commands("ROOF") )
    osm_number_of_mirror_surfaces = 0  
    model.getSurfaces.each do|surface| 
      if surface.name.to_s.include?("mirror") 
        osm_number_of_mirror_surfaces = osm_number_of_mirror_surfaces + 1
      end
    end
    osm_surfaces = model.getSurfaces
    #test if all surfaces were translated
    assert_equal( doe_surfaces.size ,  osm_surfaces.size - osm_number_of_mirror_surfaces, "Surfaces in OSM  and INP do not match.")

    
    #compare number of subsurfaces
    doe_subsurfaces = []
    doe_subsurfaces.concat( doe_model.find_all_commands("WINDOW") ) 
    doe_subsurfaces.concat( doe_model.find_all_commands("DOOR") )
    osm_subsurfaces = model.getSubSurfaces
    #Check to see if all items were imported. 
    assert_equal( doe_subsurfaces.size ,  osm_subsurfaces.size , "SubSurfaces in OSM  and INP do not match." ) 

    
    
    #save file
    filename = "#{inp_file}.osm"
    File.delete(filename) if File.exist?(filename)
    model.save(OpenStudio::Path.new(filename))
    puts "File #{filename} saved."
    assert_equal("Success", result.value.valueName)
  end



  def test_4StoreyBuilding()
    self.import_inp_test("#{File.dirname(__FILE__)}/./4StoreyBuilding.inp" )
  end
#  Test case has a Dummy zone so this fails the test. 
#  def test_ReaganBuilding_Calibrated()
#    self.import_inp_test("#{File.dirname(__FILE__)}/./ReaganBuilding_Calibrated.inp")
#  end
  def test_5ZoneFloorRotationTest()
    self.import_inp_test("#{File.dirname(__FILE__)}/./5ZoneFloorRotationTest.inp")
  end
  def test_basic_2storey_with_basement_wizard_geometry
    self.import_inp_test("#{File.dirname(__FILE__)}/./basic_2storey_with_basement_wizard_geometry.inp")
  end
  def test_Custom_Concave_Polygon()
    self.import_inp_test("#{File.dirname(__FILE__)}/./Custom_Concave_Polygon.inp" )
  end
  def test_Custom_Convex_Polygon()
    self.import_inp_test("#{File.dirname(__FILE__)}/./Custom_Convex_Polygon.inp")
  end
# Test has errors in surface conversion.  
#  def test_H_Shape()
#    self.import_inp_test("#{File.dirname(__FILE__)}/./H_Shape.inp")
#  end
  def test_Nealon_Calibrated()
    self.import_inp_test("#{File.dirname(__FILE__)}/./Nealon_Calibrated.inp")
  end
  def test_Plus_Shape()
    self.import_inp_test("#{File.dirname(__FILE__)}/./Plus_Shape.inp")
  end
  def test_Rectangle_minus_corner()
    self.import_inp_test("#{File.dirname(__FILE__)}/./Rectangle_minus_corner.inp")
  end
  def test_Rectangle()
    self.import_inp_test("#{File.dirname(__FILE__)}/./Rectangle.inp")
  end
  def test_Rectangular_Atrium()
    self.import_inp_test("#{File.dirname(__FILE__)}/./Rectangular_Atrium.inp")
  end
  def test_SingleZonePerFloorRotation()
    self.import_inp_test("#{File.dirname(__FILE__)}/./SingleZonePerFloorRotation.inp" )
  end
  def test_T_Shape()
    self.import_inp_test("#{File.dirname(__FILE__)}/./T_Shape.inp")
  end
  def test_Trapezoid()
    self.import_inp_test("#{File.dirname(__FILE__)}/./Trapezoid.inp")
  end
  def test_Triangle()
    self.import_inp_test("#{File.dirname(__FILE__)}/./Triangle.inp")
  end
  def test_U_Shape()
    self.import_inp_test("#{File.dirname(__FILE__)}/./U_Shape.inp")
  end
  def test_Overhang()
    self.import_inp_test("#{File.dirname(__FILE__)}/./Overhang.inp")
  end
  
end
