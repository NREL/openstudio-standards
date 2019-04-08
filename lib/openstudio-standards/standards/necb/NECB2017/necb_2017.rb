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
    #load NECB2011 data.
    super()
    #replace template to 2015 for all tables.
    #puts JSON.pretty_generate( @standards_data['tables'] )
    @standards_data['tables'].each do |key,value|
      value['table'].each do |row|
        ["lighting_standard", "ventilation_standard", "template"].each do |item|
          row[item].gsub!('NECB2015', 'NECB2017') unless row[item].nil?
        end
      end
    end

    if __dir__[0] == ':' # Running from OpenStudio CLI
      embedded_files_relative('data/', /.*\.json/).each do |file|
        data = JSON.parse(EmbeddedScripting.getFileAsString(file))
        if !data['tables'].nil?
          @standards_data['tables'] = [*@standards_data['tables'],  *data['tables'] ].to_h
        elsif !data['constants'].nil?
          @standards_data['constants'] = [*@standards_data['constants'],  *data['constants'] ].to_h
        elsif !data['constants'].nil?
          @standards_data['formulas'] = [*@standards_data['formulas'],  *data['formulas'] ].to_h
        end
      end
    else
      files = Dir.glob("#{File.dirname(__FILE__)}/data/*.json").select {|e| File.file? e}
      files.each do |file|
        data = JSON.parse(File.read(file))
        if !data['tables'].nil?
          @standards_data['tables'] = [*@standards_data['tables'],  *data['tables'] ].to_h
        elsif !data['constants'].nil?
          @standards_data['constants'] = [*@standards_data['constants'],  *data['constants'] ].to_h
        elsif !data['formulas'].nil?
          @standards_data['formulas'] = [*@standards_data['formulas'],  *data['formulas'] ].to_h
        end
      end
    end
    #Write test report file.
    # Write database to file.
    # File.open(File.join(File.dirname(__FILE__), '..', 'NECB2017.json'), 'w') {|f| f.write(JSON.pretty_generate(@standards_data))}

    return @standards_data
  end

end
