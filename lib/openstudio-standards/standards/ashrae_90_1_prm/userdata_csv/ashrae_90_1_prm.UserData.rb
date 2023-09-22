class UserDataCSV
  # Abstract class for writing user data template from user model.
  #
  # @param model [OpenStudio::Model::Model]
  # @param save_dir [String] directory to save user data files
  def initialize(model, save_dir)
    @model = model
    @component_name = nil
    unless Dir.exist?(save_dir)
      raise ArgumentError "Saving directory #{save_dir} does not exist!"
    end
    @save_dir = save_dir
    @components = nil
    @headers = nil
    @file_name = nil
  end

  # getter function to get file name
  def file_name
    @file_name
  end

  # method to write csv files
  # this method controls the workflow for generating a user data file.
  # @return [Boolean] True for success, false otherwise
  def write_csv
    @components = load_component
    @headers = load_header
    unless @components
      OpenStudio.logFree(OpenStudio::Warn, 'prm.log', "No relevant component #{@component_name} found in model. Skip the process")
      return false
    end

    CSV.open("#{@save_dir}/#{@file_name}.csv", 'w') do |csv|
      csv << @headers
      @components.each do |component|
        csv << [prm_get_component_name(component)] + write_default_rows
      end
    end
    return true
  end

  private

  # method to write the parameters in the csv file.
  # This method provides a template to write in default values to the user data file
  # return [Array] array of strings that contains the data in the userdata file
  def write_default_rows
    raise NotImplementedError, 'Method write rows should be implemented in class'
  end

  # Load header from pre-defined user data files.
  # This method loads the user data file from the list.
  #
  # @return [Boolean] true if success, false otherwise.
  def load_header
    userdata_dir = __dir__
    src_csv_dir = "#{userdata_dir}/*.csv"
    headers = nil
    Dir.glob(src_csv_dir).each do |csv_full_name|
      csv_file_name = File.basename(csv_full_name, File.extname(csv_full_name))
      if csv_file_name == @file_name
        headers = CSV.read(csv_full_name, headers: true).headers
      end
    end
    return headers
  end

  # Method to load OpenStudio component list from the model and save to @Component
  # subclass shall determine what data group to extract from a modle.
  # @return [Array] array of OpenStudio components.
  def load_component
    return @model.public_send("get#{@component_name}")
  end
end

class UserDataCSVAirLoopHVAC < UserDataCSV
  # user data userdata_airloop_hvac
  # @param model [OpenStudio::Model::Model]
  # @param save_dir [String] directory to save user data files
  def initialize(model, save_dir)
    super
    @component_name = 'AirLoopHVACs'
    @file_name = UserDataFiles::AIRLOOP_HVAC
  end

  def write_default_rows
    # @todo we can do more here but right now, keep everything unchecked.
    return Array.new(@headers.length - 1, '')
  end
end

class UserDataCSVBuilding < UserDataCSV
  # user data userdata_building
  # @param model [OpenStudio::Model::Model]
  # @param save_dir [String] directory to save user data files
  def initialize(model, save_dir)
    super
    @component_name = 'Building'
    @file_name = UserDataFiles::BUILDING
  end

  private

  def load_component
    return [@model.public_send("get#{@component_name}")]
  end

  def write_default_rows
    # @todo we can do more here but right now, keep everything unchecked.
    return Array.new(@headers.length - 1, '')
  end
end

class UserDataCSVSpace < UserDataCSV
  # user data userdata_space
  # @param model [OpenStudio::Model::Model]
  # @param save_dir [String] directory to save user data files
  def initialize(model, save_dir)
    super
    @component_name = 'Spaces'
    @file_name = UserDataFiles::SPACE
  end

  private

  def write_default_rows
    # @todo we can do more here but right now, keep everything unchecked.
    return Array.new(@headers.length - 1, '')
  end
end

class UserDataCSVSpaceTypes < UserDataCSV
  # user data userdata_spacetypes
  # @param model [OpenStudio::Model::Model]
  # @param save_dir [String] directory to save user data files
  def initialize(model, save_dir)
    super
    @component_name = 'SpaceTypes'
    @file_name = UserDataFiles::SPACETYPE
  end

  private

  def write_default_rows
    # @todo we can do more here but right now, keep everything unchecked.
    return Array.new(@headers.length - 1, '')
  end
end

class UserDataCSVAirLoopHVACDOAS < UserDataCSV
  # user data userdata_airloop_hvac_doas
  # @param model [OpenStudio::Model::Model]
  # @param save_dir [String] directory to save user data files
  def initialize(model, save_dir)
    super
    @component_name = 'AirLoopHVACDedicatedOutdoorAirSystems'
    @file_name = UserDataFiles::AIRLOOP_HVAC_DOAS
  end

  def write_default_rows
    # @todo we can do more here but right now, keep everything unchecked.
    return Array.new(@headers.length - 1, '')
  end
end

class UserDataCSVExteriorLights < UserDataCSV
  # user data userdata_airloop_hvac_doas
  # @param model [OpenStudio::Model::Model]
  # @param save_dir [String] directory to save user data files
  def initialize(model, save_dir)
    super
    @component_name = 'ExteriorLightss'
    @file_name = UserDataFiles::EXTERIOR_LIGHTS
  end

  def write_default_rows
    # @todo we can do more here but right now, keep everything unchecked.
    return Array.new(@headers.length - 1, '')
  end
end

class UserDataCSVThermalZone < UserDataCSV
  # user data userdata_thermal_zone
  # @param model [OpenStudio::Model::Model]
  # @param save_dir [String] directory to save user data files
  def initialize(model, save_dir)
    super
    @component_name = 'ThermalZones'
    @file_name = UserDataFiles::THERMAL_ZONE
  end

  def write_default_rows
    # @todo we can do more here but right now, keep everything unchecked.
    return Array.new(@headers.length - 1, '')
  end
end

class UserDataCSVElectricEquipment < UserDataCSV
  # user data userdata_electric_equipment
  # @param model [OpenStudio::Model::Model]
  # @param save_dir [String] directory to save user data files
  def initialize(model, save_dir)
    super
    @component_name = 'ElectricEquipments'
    @file_name = UserDataFiles::ELECTRIC_EQUIPMENT
  end

  def write_default_rows
    # @todo we can do more here but right now, keep everything unchecked.
    return Array.new(@headers.length - 1, '')
  end
end

class UserDataCSVOutdoorAir < UserDataCSV
  # user data userdata_design_specification_outdoor_air
  # @param model [OpenStudio::Model::Model]
  # @param save_dir [String] directory to save user data files
  def initialize(model, save_dir)
    super
    @component_name = 'DesignSpecificationOutdoorAirs'
    @file_name = UserDataFiles::DESIGN_SPECIFICATION_OUTDOOR_AIR
  end

  def write_default_rows
    # @todo we can do more here but right now, keep everything unchecked.
    return Array.new(@headers.length - 1, '')
  end
end
