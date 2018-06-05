# This class holds methods that apply NECB2011 rules.
# @ref [References::NECB2011]
require 'rubyXL'
class NECB2015 < NECB2011
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
    @standards_data['tables'].each do |table|
      table['table'].each do |row|
        ["lighting_standard", "ventilation_standard", "template"].each do |item|
          row[item].gsub!('NECB2011', 'NECB2015') unless row[item].nil?
        end
      end
    end

    # Combine the data from the JSON files into a single hash
    top_dir = File.expand_path('../../..', File.dirname(__FILE__))
    standards_data_dir = "#{top_dir}/data/"
    files = Dir.glob("#{File.dirname(__FILE__)}/data/*.json").select {|e| File.file? e}
    files.each do |file|
      #puts "loading standards data from #{file}"
      data = JSON.parse(File.read(file))
      if not data["tables"].nil? and data["tables"].first["data_type"] =="table"
        @standards_data["tables"] << data["tables"].first
      else
        @standards_data[data.keys.first] = data[data.keys.first]
      end
    end

    #needed for compatibility of standards database format
    @standards_data['tables'].each do |table|
      @standards_data[table['name']] = table
    end
    return @standards_data
  end

  def necb_qaqc(qaqc, model)
    puts "\n\nin necb_qaqc 2015 now\n\n"
    #Now perform basic QA/QC on items for NECB2015
    qaqc[:information] = []
    qaqc[:warnings] =[]
    qaqc[:errors] = []
    qaqc[:unique_errors]=[]

    # necb_space_compliance(qaqc)
    #
    # necb_envelope_compliance(qaqc)
    #
    # necb_infiltration_compliance(qaqc)
    #
    # necb_exterior_opaque_compliance(qaqc)
    #
    # necb_exterior_fenestration_compliance(qaqc)
    #
    # necb_exterior_ground_surfaces_compliance(qaqc)
    #
    # necb_zone_sizing_compliance(qaqc)
    #
    # necb_design_supply_temp_compliance(qaqc)
    #
    # necb_economizer_compliance(qaqc)
    #
    # necb_hrv_compliance(qaqc, model)
    #
    # necb_vav_fan_power_compliance(qaqc)

    sanity_check(qaqc)

    necb_plantloop_sanity(qaqc)

    qaqc[:information] = qaqc[:information].sort
    qaqc[:warnings] = qaqc[:warnings].sort
    qaqc[:errors] = qaqc[:errors].sort
    qaqc[:unique_errors]= qaqc[:unique_errors].sort
  end
end
