# This abstract class holds generic methods that many energy standards would commonly use.
# Many of the methods in this class apply efficiency values from the
# OpenStudio-Standards spreadsheet.  If a method in this class is redefined
# by a child class, the implementation in the child class is used.
# @abstract
class StandardsModel
  attr_reader :standards_data
  attr_reader :template

  # The code below is required for the factory method. For an explanation see
  # https://stackoverflow.com/questions/1515577/factory-methods-in-ruby and clakes post. Which I think is the cleanest
  # implementation.
  #This creates a constant HASH to be set  during class instantiation.
  #When adding standards you must register the class by invoking 'register_standard ('NECB 2011')' for example for
  # NECB 2011.
  StandardsList = {}
  #Register the standard.
  def self.register_standard(name)
    StandardsList[name] = self
  end
  #Get an instance of the standard class by name.
  def self.get_standard_model(name)
    if StandardsList[name].nil?
      raise "ERROR: Did not find a class called '#{name}' to create in #{StandardsList}"
    end
    return StandardsList[name].new
  end
  #set up template class variable.
  def intialize()
    super()
  end

  # Loads the default openstudio standards dataset.
  #
  # @return [Hash] a hash of standards data
  def load_standards_database
    standards_files = []
    standards_files << 'OpenStudio_Standards_boilers.json'
    standards_files << 'OpenStudio_Standards_chillers.json'
    standards_files << 'OpenStudio_Standards_climate_zone_sets.json'
    standards_files << 'OpenStudio_Standards_climate_zones.json'
    standards_files << 'OpenStudio_Standards_construction_properties.json'
    standards_files << 'OpenStudio_Standards_construction_sets.json'
    standards_files << 'OpenStudio_Standards_constructions.json'
    standards_files << 'OpenStudio_Standards_curve_bicubics.json'
    standards_files << 'OpenStudio_Standards_curve_biquadratics.json'
    standards_files << 'OpenStudio_Standards_curve_cubics.json'
    standards_files << 'OpenStudio_Standards_curve_quadratics.json'
    standards_files << 'OpenStudio_Standards_ground_temperatures.json'
    standards_files << 'OpenStudio_Standards_heat_pumps_heating.json'
    standards_files << 'OpenStudio_Standards_heat_pumps.json'
    standards_files << 'OpenStudio_Standards_materials.json'
    standards_files << 'OpenStudio_Standards_motors.json'
    standards_files << 'OpenStudio_Standards_prototype_inputs.json'
    standards_files << 'OpenStudio_Standards_schedules.json'
    standards_files << 'OpenStudio_Standards_space_types.json'
    standards_files << 'OpenStudio_Standards_templates.json'
    standards_files << 'OpenStudio_Standards_unitary_acs.json'
    standards_files << 'OpenStudio_Standards_heat_rejection.json'
    standards_files << 'OpenStudio_Standards_exterior_lighting.json'
    standards_files << 'OpenStudio_Standards_parking.json'
    standards_files << 'OpenStudio_Standards_entryways.json'
    standards_files << 'OpenStudio_Standards_necb_climate_zones.json'
    standards_files << 'OpenStudio_Standards_necb_fdwr.json'
    standards_files << 'OpenStudio_Standards_necb_hvac_system_selection_type.json'
    standards_files << 'OpenStudio_Standards_necb_surface_conductances.json'
    standards_files << 'OpenStudio_Standards_water_heaters.json'
    standards_files << 'OpenStudio_Standards_economizers.json'
    standards_files << 'OpenStudio_Standards_refrigerated_cases.json'
    standards_files << 'OpenStudio_Standards_walkin_refrigeration.json'
    standards_files << 'OpenStudio_Standards_refrigeration_compressors.json'
    #    standards_files << 'OpenStudio_Standards_unitary_hps.json'
    # Combine the data from the JSON files into a single hash
    top_dir = File.expand_path('../../..', File.dirname(__FILE__))
    standards_data_dir = "#{top_dir}/data/standards"
    @standards_data = {}
    standards_files.sort.each do |standards_file|
      temp = ""
      begin
        temp = load_resource_relative("../../../data/standards/#{standards_file}", 'r:UTF-8')
      rescue NoMethodError
        File.open("#{standards_data_dir}/#{standards_file}", 'r:UTF-8') do |f|
          temp = f.read
        end
      end
      file_hash = JSON.load(temp)
      @standards_data = @standards_data.merge(file_hash)
    end

    # Check that standards data was loaded
    if @standards_data.keys.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'OpenStudio Standards JSON data was not loaded correctly.')
    end
    return @standards_data
  end
end




