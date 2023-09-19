class UserDataCSV
  def initialize(model, file_name, save_dir)
    @model = model
    @file_name = file_name
    @component_name = nil
    unless Dir.exist?(save_dir)
      raise ArgumentError "Saving directory #{save_dir} does not exist!"
    end
    @save_dir = save_dir
    @components = nil
    @headers = nil
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
  # This method is an abstract method for overridng.
  # subclass shall determine what data group to extract from a modle.
  # @return [Array] array of OpenStudio components.
  def load_component
    raise NotImplementedError, 'Method to load OpenStudio component should be implemented in class'
  end
end

class UserDataCSVAirLoopHVAC < UserDataCSV
  def initialize(model, file_name, save_dir)
    super
    @component_name = 'AirLoopHVACs'
  end

  def load_component
    return @model.getAirLoopHVACs
  end

  def write_default_rows
    # TODO we can do more here but right now, keep everything unchecked.
    return Array.new(@headers.length - 1, '')
  end
end

