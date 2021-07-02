# This class holds methods that apply NECB2020 rules.

# Notes for adding new version of NECB:
#  Essentially all you need to do is copy this file to a new folder and update the class name. Only add json files and other rb
#  files if the content has changed. Do not forget to update the class name in the rb files.
#  The spacetypes and led lighting json files are required (in the data folder) as they have the NECB version hardcoded (which requires updating).
#  However there are a few other files to update:
#  1) NECB2011/necb_2011.rb:determine_spacetype_vintage method has an array of available versions of NECB hardcoded. Add the new one.
#  2) common/space_type_upgrade_map.json needs all the space types for the new version defined (386 in NECB 2020).
#  3) Add references to the new rb files in openstudio_standards.rb

# @ref [References::NECB2020]
class NECB2020 < NECB2017
  @template = self.new.class.name # rubocop:disable Style/ClassVars
  register_standard(@template)

  def initialize
    super()
    @template = self.class.name
    @standards_data = self.load_standards_database_new()
    self.corrupt_standards_database()
  end

  def load_standards_database_new()
    #load NECB2017 data.
    super()

    if __dir__[0] == ':' # Running from OpenStudio CLI
      embedded_files_relative('data/', /.*\.json/).each do |file|
        data = JSON.parse(EmbeddedScripting.getFileAsString(file))
        if !data['tables'].nil?
          @standards_data['tables'] = [*@standards_data['tables'], *data['tables']].to_h
        elsif !data['constants'].nil?
          @standards_data['constants'] = [*@standards_data['constants'], *data['constants']].to_h
        elsif !data['constants'].nil?
          @standards_data['formulas'] = [*@standards_data['formulas'], *data['formulas']].to_h
        end
      end
    else
      files = Dir.glob("#{File.dirname(__FILE__)}/data/*.json").select {|e| File.file? e}
      files.each do |file|
        data = JSON.parse(File.read(file))
        if !data['tables'].nil?
          @standards_data['tables'] = [*@standards_data['tables'], *data['tables']].to_h
        elsif !data['constants'].nil?
          @standards_data['constants'] = [*@standards_data['constants'], *data['constants']].to_h
        elsif !data['formulas'].nil?
          @standards_data['formulas'] = [*@standards_data['formulas'], *data['formulas']].to_h
        end
      end
    end
    #Write test report file.
    # Write database to file.
    # File.open(File.join(File.dirname(__FILE__), '..', 'NECB2020.json'), 'w') {|f| f.write(JSON.pretty_generate(@standards_data))}

    return @standards_data
  end

  def set_lighting_per_area_led_lighting(space_type:, definition:, lighting_per_area_led_lighting:, lights_scale:)

    # puts "#{space_type.name.to_s} - 'space_height' - #{space_height.to_s}"
    #TODO: Note that 'occ_sens_lpd_frac' in this function has been removed for NECB2015 and 2017.
    # ##### Since Atrium's LPD for LED lighting depends on atrium's height, the height of the atrium (if applicable) should be found.
    standards_space_type = space_type.standardsSpaceType.is_initialized ? space_type.standardsSpaceType.get : nil #Sara
    if standards_space_type.include? 'Atrium' # TODO: Note that since none of the archetypes has Atrium, this was tested for 'Dining'. #Atrium
      puts "#{standards_space_type} - has atrium"  # space_type.name.to_s
      # puts space_height
      if get_max_space_height_for_space_type(space_type: space_type) < 12.0
        # TODO: Regarding the below equations, identify which version of ASHRAE 90.1 was used in NECB2017.
        atrium_lpd_eq_smaller_12_intercept = 0
        atrium_lpd_eq_smaller_12_slope = 1.06
        atrium_lpd_eq_larger_12_intercept = 4.3
        atrium_lpd_eq_larger_12_slope = 0.71
        lighting_per_area_led_lighting_atrium = (atrium_lpd_eq_smaller_12_intercept + atrium_lpd_eq_smaller_12_slope * space_height) * 0.092903 # W/ft2
      else # i.e. get_max_space_height_for_space_type >= 12.0
        lighting_per_area_led_lighting_atrium = (atrium_lpd_eq_larger_12_intercept + atrium_lpd_eq_larger_12_slope * space_height) * 0.092903 # W/ft2
      end
      puts "#{standards_space_type} - has lighting_per_area_led_lighting_atrium - #{lighting_per_area_led_lighting_atrium}"
      lighting_per_area_led_lighting = lighting_per_area_led_lighting_atrium
    end
    lighting_per_area_led_lighting *= lights_scale

    definition.setWattsperSpaceFloorArea(OpenStudio.convert(lighting_per_area_led_lighting.to_f, 'W/ft^2', 'W/m^2').get)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set LPD to #{lighting_per_area_led_lighting} W/ft^2.")
  end

end
