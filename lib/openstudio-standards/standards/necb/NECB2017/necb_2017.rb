# This class holds methods that apply NECB2017 rules.
# @ref [References::NECB2017]
class NECB2017 < NECB2015
  @template = self.new.class.name # rubocop:disable Style/ClassVars
  register_standard(@template)

  def initialize
    super()
    @template = self.class.name
    @standards_data = self.load_standards_database_new()
  end

  def load_standards_database_new()
    #load NECB2015 data.
    super()
    #replace template to 2017 for all tables.
    #puts JSON.pretty_generate( @standards_data['tables'] )
    @standards_data['tables'].each do |table|
      table['table'].each do |row|
        ["lighting_standard", "ventilation_standard", "template"].each do |item|
          row[item].gsub!('NECB2015', 'NECB2017') unless row[item].nil?
        end
      end
    end

    if __dir__[0] == ':' # Running from OpenStudio CLI
      embedded_files_relative('data/', /.*\.json/).each do |file|
        data = JSON.parse(EmbeddedScripting.getFileAsString(file))
        if not data["tables"].nil? and data["tables"].first["data_type"] =="table"
          @standards_data["tables"] << data["tables"].first
        else
          @standards_data[data.keys.first] = data[data.keys.first]
        end
      end
    else
      files = Dir.glob("#{File.dirname(__FILE__)}/data/*.json").select {|e| File.file? e}
      files.each do |file|
        data = JSON.parse(File.read(file))
        if not data["tables"].nil? and data["tables"].first["data_type"] =="table"
          @standards_data["tables"] << data["tables"].first
        else
          @standards_data[data.keys.first] = data[data.keys.first]
        end
      end
    end


    #needed for compatibility of standards database format
    @standards_data['tables'].each do |table|
      @standards_data[table['name']] = table
    end
    return @standards_data
  end

end
