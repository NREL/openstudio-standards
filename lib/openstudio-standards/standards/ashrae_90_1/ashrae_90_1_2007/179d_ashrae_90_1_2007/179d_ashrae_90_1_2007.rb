# This class holds methods that apply a version of ASHRAE 90.1-2007 that has
# been modified to suit 179D needs
# @ref [References::ASHRAE9012007]
class ACM179dASHRAE9012007 < ASHRAE9012007
  register_standard '179D 90.1-2007'
  attr_reader :template, :whole_building_space_type_name

  def initialize
    @template = '179d-90.1-2007'
    load_standards_database

    # This is super weird, but this is for resolving ventilation and exhaust
    # per the space type's... and merging with the rest
    @std_2007 = ASHRAE9012007.new
  end

  # Loads the openstudio standards dataset for this standard.
  #
  # It will load ASHRAE90.1-2007, and do the following:
  # * space_types: overwritten completely
  # * schedules: are added onto the ASHRAE90.1-2007 ones
  #
  # @param data_directories [Array<String>] array of file paths that contain standards data
  # @return [Hash] a hash of standards data
  def load_standards_database(data_directories = [])
    # Load ASHRAE 90.1-2007 data
    super(data_directories)
    # And patch in our own
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.standard', "Extending with JSON files from #{__dir__}")
    files = Dir.glob("#{__dir__}/data/*.json").select { |e| File.file? e }
    files.each do |file|
      data = JSON.parse(File.read(file))
      data.each_pair do |key, objs|
        # Override the template in inherited files to match the instantiated template
        objs.each do |obj|
          if obj.key?('template')
            obj['template'] = template
          end
        end
        if @standards_data[key].nil?
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.standard', "Adding #{key} from #{File.basename(file)}")
          @standards_data[key] = objs
        elsif ['schedules', 'constructions', 'materials'].include?(key)
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.standard', "Extending #{key} with #{File.basename(file)}")
          @standards_data[key] += objs
        else
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.standard', "Overriding #{key} with #{File.basename(file)}")
          @standards_data[key] = objs
        end
      end
    end
  end
end
