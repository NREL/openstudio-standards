# This abstract class holds generic methods that many energy standards would commonly use.
# Many of the methods in this class apply efficiency values from the
# OpenStudio-Standards spreadsheet.  If a method in this class is redefined
# by a child class, the implementation in the child class is used.
# @abstract
class StandardsModel
  attr_reader :standards_data
  attr_reader :instvartemplate

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

  def load_standards_database()
    # common_data_file = "#{Folders.instance.data_standards_folder}/common.json"
    # common_data = JSON.parse(File.read(common_data_file)).sort.to_h
    # standards_data_file = "#{Folders.instance.data_standards_folder}/#{@instvartemplate}.json"
    # standards_data = JSON.parse(File.read(standards_data_file)).sort.to_h
    # @standards_data = common_data.merge(standards_data)
    @standards_data = $os_standards
    return @standards_data
  end
end




