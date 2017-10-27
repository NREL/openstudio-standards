# This abstract class holds generic methods that many energy standards would commonly use.
# Many of the methods in this class apply efficiency values from the
# OpenStudio-Standards spreadsheet.  If a method in this class is redefined
# by a child class, the implementation in the child class is used.
# @abstract
class StandardsModel
  @@data_folder = "#{File.dirname(__FILE__)}/../../../../data"

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




