# This abstract class holds generic methods that many energy standards would commonly use.
# Many of the methods in this class apply efficiency values from the
# OpenStudio-Standards spreadsheet.  If a method in this class is redefined
# by a subclass, the implementation in the subclass is used.
# @abstract
class Standard
  attr_reader :standards_data
  attr_reader :template

  # The code below is required for the factory method. For an explanation see
  # https://stackoverflow.com/questions/1515577/factory-methods-in-ruby and clakes post. Which I think is the cleanest
  # implementation.
  # This creates a constant HASH to be set  during class instantiation.
  # When adding standards you must register the class by invoking 'register_standard ('NECB2011')' for example for
  # NECB2011.

  # A list of available Standards subclasses that can
  # be created using the Standard.build() method.
  STANDARDS_LIST = {} # rubocop:disable Style/MutableConstant

  # Add the standard to the STANDARDS_LIST.
  def self.register_standard(name)
    STANDARDS_LIST[name] = self
  end

  # Create an instance of a Standard by passing it's name
  #
  # @param name [String] the name of the Standard to build.
  #   valid choices are: DOE Pre-1980, DOE 1980-2004, 90.1-2004,
  #   90.1-2007, 90.1-2010, 90.1-2013, NREL ZNE Ready 2017, NECB2011
  # @example Create a new Standard object by name
  #   standard = Standard.build('NECB2011')
  def self.build(name)
    if STANDARDS_LIST[name].nil?
      raise "ERROR: Did not find a class called '#{name}' to create in #{JSON.pretty_generate(STANDARDS_LIST)}"
    end
    return STANDARDS_LIST[name].new
  end

  # set up template class variable.
  def intialize
    super()
  end

  # Get the name of the building type used in lookups
  #
  # @param building_type [String] the building type
  # @return [String] returns the lookup name as a string
  # @todo Unify the lookup names and eliminate this method
  def model_get_lookup_name(building_type)
    lookup_name = building_type
    case building_type
      when 'SmallOffice'
        lookup_name = 'Office'
      when 'SmallOfficeDetailed'
        lookup_name = 'Office'
      when 'MediumOffice'
        lookup_name = 'Office'
      when 'MediumOfficeDetailed'
        lookup_name = 'Office'
      when 'LargeOffice'
        lookup_name = 'Office'
      when 'LargeOfficeDetailed'
        lookup_name = 'Office'
      when 'RetailStandalone'
        lookup_name = 'Retail'
      when 'RetailStripmall'
        lookup_name = 'StripMall'
      when 'Office'
        lookup_name = 'Office'
    end
    return lookup_name
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
    standards_files << 'OpenStudio_Standards_curves.json'
    standards_files << 'OpenStudio_Standards_fans.json'
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
    standards_files << 'OpenStudio_Standards_refrigeration_compressors.json'
    standards_files << 'OpenStudio_Standards_refrigeration_walkins.json'
    standards_files << 'OpenStudio_Standards_refrigeration_system.json'
    standards_files << 'OpenStudio_Standards_refrigeration_system_lineup.json'
    standards_files << 'OpenStudio_Standards_refrigeration_condenser.json'
    standards_files << 'OpenStudio_Standards_hvac_inference.json'
    standards_files << 'OpenStudio_Standards_size_category.json'
    standards_files << 'OpenStudio_Standards_elevators.json'
    #    standards_files << 'OpenStudio_Standards_unitary_hps.json'
    # Combine the data from the JSON files into a single hash
    top_dir = File.expand_path('../../..', File.dirname(__FILE__))
    standards_data_dir = "#{top_dir}/data/standards"
    @standards_data = {}
    standards_files.sort.each do |standards_file|
      temp = ''
      if __dir__[0] == ':' # Running from OpenStudio CLI
        temp = load_resource_relative("../../../data/standards/#{standards_file}", 'r:UTF-8')
      else
        File.open("#{standards_data_dir}/#{standards_file}", 'r:UTF-8') do |f|
          temp = f.read
        end
      end
      file_hash = JSON.parse(temp)
      @standards_data = @standards_data.merge(file_hash)
    end

    # Check that standards data was loaded
    if @standards_data.keys.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'OpenStudio Standards JSON data was not loaded correctly.')
    end
    return @standards_data
  end
end
