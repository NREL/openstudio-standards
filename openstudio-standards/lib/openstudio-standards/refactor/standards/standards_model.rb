# This abstract class holds generic methods that many energy standards would commonly use.
# Many of the methods in this class apply efficiency values from the
# OpenStudio-Standards spreadsheet.  If a method in this class is redefined
# by a child class, the implementation in the child class is used.
# @abstract
class StandardsModel < OpenStudio::Model::Model
  @@prototype_folder =  "#{File.dirname(__FILE__)}/../../prototypes"
  @@standards_folder =  "#{File.dirname(__FILE__)}/../../standards"
  @@data_folder =       "#{File.dirname(__FILE__)}/../../../../data"

  # Require the files containing the modules first
  require_relative 'Standards.CoilDX'
  require_relative 'Standards.CoolingTower'
  require_relative 'Standards.Fan'
  require_relative 'Standards.Pump'
  require_relative 'ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.CoolingTower'
  require_relative 'ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.CoolingTower'
  require_relative 'ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.CoolingTower'
  require_relative 'necb/necb_2011/necb_2011.Fan'
  require_relative 'ashrae_90_1/ashrae_90_1.rb'

  # Require all the standards files below this dynamically for now
  # TODO refactor: hard code requires later
  Dir.glob("#{File.dirname(__FILE__)}/**/*.rb").each do |file_path|
    # Don't load temp scripts
    next if file_path.include?('temporary_scripts')
    # Don't load already loaded files
    already_loaded_files = [
      'necb_2011',
      'ashrae90_1_2007',
      'ashrae90_1_2004',
      'ashrae90_1_2010',
      'ashrae90_1_2013',
      'doe_ref_pre_1980',
      'doe_ref_pre_1980_2004',
      'nrel_zne_ready_2017'
    ]
    next if already_loaded_files.include?(File.basename(file_path, '.rb'))
    puts "Requiring: #{file_path}."
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




