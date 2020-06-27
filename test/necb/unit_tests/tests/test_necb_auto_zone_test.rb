require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'

class NECB_Autozone_Tests < MiniTest::Test
  BUILDINGS = [
      "FullServiceRestaurant",
      "LargeHotel",
      "LargeOffice",
      "MediumOffice",
      "HighriseApartment",
      "MidriseApartment",
      "Outpatient",
      "PrimarySchool",
      "QuickServiceRestaurant",
      "RetailStandalone",
      "RetailStripmall",
      "SmallHotel",
      "SmallOffice",
      "Warehouse",
      "Hospital"
  ]


  #metacode to create tests dynamically for each archetype.
  BUILDINGS.each do |attribute|
    define_method(:"test_#{attribute}") {
      model = autozone("#{attribute}")
    }
  end

  def setup()
    @output_folder = "#{File.dirname(__FILE__)}/output/autozoner"
    @relative_geometry_path = "/../../lib/openstudio-standards/standards/necb/NECB2011/data/geometry/"
    @epw_file = 'CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw'
    @template = 'NECB2011'
    @climate_zone = 'NECB HDD Method'
    FileUtils.mkdir_p(@output_folder) unless File.directory?(@output_folder)
  end

  # Test to validate the heat pump performance curves
  def autozone(building_type)
    outfile = @output_folder + "/#{building_type}_autozoned.osm"
    File.delete(outfile) if File.exist?(outfile)
    outfile_json = @output_folder + "/#{building_type}_autozoned.json"
    File.delete(outfile_json) if File.exist?(outfile_json)
    standard = Standard.build("#{@template}")
    model = standard.model_create_prototype_model(epw_file: @epw_file,
                                                  sizing_run_dir: File.join(@output_folder, building_type, 'sizing'),
                                                  template: @template,
                                                  building_type: building_type)


    puts "Writing Output #{outfile}"
    BTAP::FileIO::save_osm(model, outfile)
    air_loops = []
    model.getAirLoopHVACs.each do |airloop|
      debug = {}
      debug[:airloop_name] = airloop.name.to_s
      debug[:control_zone] = standard.determine_control_zone(airloop.thermalZones).name.to_s
      debug[:thermal_zones] = []
      airloop.thermalZones.sort.each do |tz|
        zone_data = {}
        zone_data[:name] = tz.name.to_s
        zone_data[:heating_load_per_area] = standard.stored_zone_heating_load(tz)
        zone_data[:cooling_load_per_area] = standard.stored_zone_cooling_load(tz)
        zone_data[:spaces] = []
        tz.spaces.sort.each do |space|
          space_data = {}
          space_data[:name] = space.name.get.to_s
          space_data[:space_type] = space.spaceType.get.standardsBuildingType.get.to_s + '-' + space.spaceType.get.standardsSpaceType.get.to_s
          space_data[:schedule] = standard.determine_necb_schedule_type(space).to_s
          space_data[:heating_load_per_area] = standard.stored_space_heating_load(space)
          space_data[:cooling_load_per_area] = standard.stored_space_cooling_load(space)
          space_data[:surface_report] = standard.space_surface_report(space)
          zone_data[:spaces] << space_data
        end
        zone_data[:spaces].sort! {|a, b| [a[:name]] <=> [b[:name]]}
        debug[:thermal_zones] << zone_data
      end
      debug[:thermal_zones].sort! {|a, b| [a[:thermal_zone_name]] <=> [b[:thermal_zone_name]]}
      air_loops << debug
    end
    outfile_json = @output_folder + "/#{building_type}_autozoned.json"
    puts "Writing Output #{outfile_json}"
    air_loops.sort! {|a, b| [a[:airloop_name]] <=> [b[:airloop_name]]}
    File.write(outfile_json, JSON.pretty_generate(air_loops))
    #assert(standard.model_run_simulation_and_log_errors(model, File.join(@output_folder, building_type)), "#{building_type} Failed to run.")
  end
end