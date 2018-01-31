# This class holds methods that apply NECB2011 rules.
# @ref [References::NECB2011]
require 'rubyXL'
require 'deep_merge'
class NECB2015 < NECB2011
  @@template = 'NECB 2015' # rubocop:disable Style/ClassVars
  register_standard @@template
  def load_standards_database_new()
    #load NECB2011 data.
    super()
    #replace template to 2015 for all tables.
    @standards_data['tables'].each do |table|
      table.each do |item|
        item.each do |row|
          if row.has_key? "template"
            row["template"].gsub!('NECB2011', 'NECB 2015')
          end
        end
      end
    end
    #Now load and overwrite any json data that is in the local NECB 2015.
    top_dir = File.expand_path('../../..', File.dirname(__FILE__))
    standards_data_dir = "#{top_dir}/data/"
    files = Dir.glob("#{File.dirname(__FILE__)}/data/*.json").select {|e| File.file? e}
    @standards_data = {}
    files.each do |file|
      @standards_data = @standards_data.deep_merge (JSON.parse(File.read(file)))
    end
    #needed for compatibility of standards database format
    @standards_data['tables'].each do |table|
      @standards_data[table['name']] = table
    end
    return @standards_data
  end
end
