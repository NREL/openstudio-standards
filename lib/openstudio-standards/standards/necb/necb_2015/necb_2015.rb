# This class holds methods that apply NECB2011 rules.
# @ref [References::NECB2011]
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

  def model_create_prototype_model(climate_zone, epw_file, sizing_run_dir = Dir.pwd, debug = false, measure_model = nil, x_scale = 1.0, y_scale = 1.0, z_scale = 1.0)
    model = build_prototype_model(climate_zone, debug, epw_file, sizing_run_dir, x_scale, y_scale, z_scale)
    # Do another sizing run to take into account adjustments to equipment efficiency etc. on capacities. This was done primarily
    # because the cooling tower loop capacity is affected by the chiller COP.  If the chiller COP is not properly set then
    # the cooling tower loop capacity can be significantly off which will affect the NECB 2015 maximum loop pump capacity.  Found
    # all sizing was off somewhat if the additional sizing run was not done.
    if model_run_sizing_run(model, "#{sizing_run_dir}/SR2") == false
      raise("sizing run 2 failed!")
    end
    # Apply maxmimum loop pump power normalized by peak demand by served spaces as per NECB2015 5.2.6.3.(1)
    apply_maximum_loop_pump_power(model)
    # If measure model is passed, then replace measure model with new model created here.
    if measure_model.nil?
      return model
    else
      model_replace_model(measure_model, model)
      return measure_model
    end
  end
end
