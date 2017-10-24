# The is the new base class that will contain the common standard code.
class StandardsModel < OpenStudio::Model::Model
  @@prototype_folder =  "#{File.dirname(__FILE__)}/../../prototypes"
  @@standards_folder =  "#{File.dirname(__FILE__)}/../../standards"
  @@data_folder =       "#{File.dirname(__FILE__)}/../../../../data"

  # Require all the standards files below this dynamically for now
  # TODO refactor: hard code requires later
  Dir.glob("#{File.dirname(__FILE__)}/*.rb").each do |file_path|
    require file_path
  end

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
    StandardsList[name].new
  end
  #set up template class variable.
  def intialize()
    super()
  end
end




