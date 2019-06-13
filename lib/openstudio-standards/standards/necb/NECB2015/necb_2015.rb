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
    @standards_data['tables'].each do |key,value|
      value['table'].each do |row|
        ["lighting_standard", "ventilation_standard", "template"].each do |item|
          row[item].gsub!('NECB2011', 'NECB2015') unless row[item].nil?
        end
      end
    end

    if __dir__[0] == ':' # Running from OpenStudio CLI
      embedded_files_relative('data/', /.*\.json/).each do |file|
        data = JSON.parse(EmbeddedScripting.getFileAsString(file))
        if !data['tables'].nil?
          @standards_data['tables'] = [*@standards_data['tables'], *data['tables']].to_h
        elsif !data['constants'].nil?
          @standards_data['constants'] = [*@standards_data['constants'], *data['constants']].to_h
        elsif !data['constants'].nil?
          @standards_data['formulas'] = [*@standards_data['formulas'], *data['formulas']].to_h
        end
      end
    else
      files = Dir.glob("#{File.dirname(__FILE__)}/data/*.json").select {|e| File.file? e}
      files.each do |file|
        data = JSON.parse(File.read(file))
        if !data['tables'].nil?
          @standards_data['tables'] = [*@standards_data['tables'], *data['tables']].to_h
        elsif !data['constants'].nil?
          @standards_data['constants'] = [*@standards_data['constants'], *data['constants']].to_h
        elsif !data['formulas'].nil?
          @standards_data['formulas'] = [*@standards_data['formulas'], *data['formulas']].to_h
        end
      end
    end
    # Write database to file.
    # File.open(File.join(File.dirname(__FILE__), '..', 'NECB2017.json'), 'w') {|f| f.write(JSON.pretty_generate(@standards_data))}

    return @standards_data
  end

  # Created this method so that additional methods can be addded for bulding the prototype model in later
  # code versions without modifying the build_protoype_model method or copying it wholesale for a few changes.
  def model_apply_standard(model:,
                           epw_file:,
                           debug: false,
                           sizing_run_dir: Dir.pwd,
                           x_scale: 1.0,
                           y_scale: 1.0,
                           z_scale: 1.0,
                           fdwr_set: 1.1,
                           srr_set: 1.1,
                           new_auto_zoner: false)

    #Run everything like parent NECB2011 'model_apply_standard' method.
    model = super(model: model,
                  epw_file: epw_file,
                  debug: debug,
                  sizing_run_dir: sizing_run_dir,
                  x_scale: x_scale,
                  y_scale: y_scale,
                  z_scale: z_scale,
                  fdwr_set: fdwr_set,
                  srr_set: srr_set)
    # NECB2015 Custom code
    # Do another sizing run to take into account adjustments to equipment efficiency etc. on capacities. This was done primarily
    # because the cooling tower loop capacity is affected by the chiller COP.  If the chiller COP is not properly set then
    # the cooling tower loop capacity can be significantly off which will affect the NECB 2015 maximum loop pump capacity.  Found
    # all sizing was off somewhat if the additional sizing run was not done.
    if model_run_sizing_run(model, "#{sizing_run_dir}/SR2") == false
      raise("sizing run 2 failed!")
    end
    # Apply maxmimum loop pump power normalized by peak demand by served spaces as per NECB2015 5.2.6.3.(1)
    apply_maximum_loop_pump_power(model)

    # Remove duplicate materials and constructions
    # Note For NECB2015 This is the 2nd time this method is bieng run.
    # First time it ran in the super() within model_apply_standard() method
    model  = BTAP::FileIO::remove_duplicate_materials_and_constructions(model)
    return model
  end

  #occupancy sensor control applied using lighting schedule, see apply_lighting_schedule method
  def set_occ_sensor_spacetypes(model, space_type_map)
    return true
  end
end
