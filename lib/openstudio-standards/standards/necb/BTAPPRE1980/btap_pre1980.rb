# This class holds methods that apply NECB2011 rules.
# @ref [References::NECB2011]
class BTAPPRE1980 < NECB2011
  @template = self.new.class.name # rubocop:disable Style/ClassVars
  register_standard(@template)


  def initialize
    super()
    @template = self.class.name
    @standards_data = self.load_standards_database_new()
    self.corrupt_standards_database()
  end

  def load_standards_database_new()
    #load NECB2011 data.
    super()

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
      files = Dir.glob("#{File.dirname(__FILE__)}/data/*.json").select { |e| File.file? e }
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
                           sizing_run_dir: Dir.pwd,
                           primary_heating_fuel: 'DefaultFuel',
                           dcv_type: 'NECB_Default',
                           lights_type: 'NECB_Default',
                           lights_scale: 1.0,
                           daylighting_type: 'NECB_Default',
                           ecm_system_name: 'NECB_Default',
                           erv_package: 'NECB_Default',
                           boiler_eff: nil,
                           furnace_eff: nil,
                           unitary_cop: nil,
                           shw_eff: nil,
                           ext_wall_cond: nil,
                           ext_floor_cond: nil,
                           ext_roof_cond: nil,
                           ground_wall_cond: nil,
                           ground_floor_cond: nil,
                           ground_roof_cond: nil,
                           door_construction_cond: nil,
                           fixed_window_cond: nil,
                           glass_door_cond: nil,
                           overhead_door_cond: nil,
                           skylight_cond: nil,
                           glass_door_solar_trans: nil,
                           fixed_wind_solar_trans: nil,
                           skylight_solar_trans: nil,
                           fdwr_set: -1,
                           srr_set: -1,
                           rotation_degrees: nil,
                           scale_x: nil,
                           scale_y: nil,
                           scale_z: nil,
                           pv_ground_type: 'NECB_Default',
                           pv_ground_total_area_pv_panels_m2: nil ,
                           pv_ground_tilt_angle: nil,
                           pv_ground_azimuth_angle: nil,
                           pv_ground_module_description: nil,
                           nv_type: 'NECB_Default',
                           nv_opening_fraction: nil,
                           nv_Tout_min: nil,
                           nv_Delta_Tin_Tout: nil

  )
    # This will allow changes to default fdwr/srr for vintages.. but will not touch the existing models if they were
    # called for with -1.0 in the fdwr_srr method.
    fdwr_set = -2 if fdwr_set.nil? || fdwr_set == -1.0
    srr_set = -2 if srr_set.nil? || srr_set == -1.0
    return super(model: model,
                 epw_file: epw_file,
                 sizing_run_dir: sizing_run_dir,
                 primary_heating_fuel: primary_heating_fuel,
                 dcv_type: dcv_type,
                 lights_type: lights_type,
                 lights_scale: lights_scale,
                 daylighting_type: daylighting_type,
                 ecm_system_name: ecm_system_name,
                 erv_package: erv_package,
                 boiler_eff: boiler_eff,
                 furnace_eff: furnace_eff,
                 unitary_cop: unitary_cop,
                 shw_eff: shw_eff,
                 ext_wall_cond: ext_wall_cond,
                 ext_floor_cond: ext_floor_cond,
                 ext_roof_cond: ext_roof_cond,
                 ground_wall_cond: ground_wall_cond,
                 ground_floor_cond: ground_floor_cond,
                 ground_roof_cond: ground_roof_cond,
                 door_construction_cond: door_construction_cond,
                 fixed_window_cond: fixed_window_cond,
                 glass_door_cond: glass_door_cond,
                 overhead_door_cond: overhead_door_cond,
                 skylight_cond: skylight_cond,
                 glass_door_solar_trans: glass_door_solar_trans,
                 fixed_wind_solar_trans: fixed_wind_solar_trans,
                 skylight_solar_trans: skylight_solar_trans,
                 fdwr_set: fdwr_set,
                 srr_set: srr_set,
                 rotation_degrees: rotation_degrees,
                 scale_x: scale_x,
                 scale_y: scale_y,
                 scale_z: scale_z)
  end

  def apply_standard_efficiencies(model:, sizing_run_dir:, dcv_type: 'NECB_Default')
    raise('validation of model failed.') unless validate_initial_model(model)
    climate_zone = 'NECB HDD Method'
    raise("sizing run 1 failed! check #{sizing_run_dir}") if model_run_sizing_run(model, "#{sizing_run_dir}/plant_loops") == false
    # This is needed for NECB2011 as a workaround for sizing the reheat boxes
    model.getAirTerminalSingleDuctVAVReheats.each { |iobj| air_terminal_single_duct_vav_reheat_set_heating_cap(iobj) }
    # Apply the prototype HVAC assumptions
    model_apply_prototype_hvac_assumptions(model, nil, climate_zone)
    # Apply the HVAC efficiency standard
    sql_db_vars_map = {}
    model_apply_hvac_efficiency_standard(model, climate_zone, sql_db_vars_map: sql_db_vars_map)
    model_enable_demand_controlled_ventilation(model, dcv_type)
    model_apply_existing_building_fan_performance(model: model)
    return sql_db_vars_map
  end

  #occupancy sensor control applied using lighting schedule, see apply_lighting_schedule method
  def set_occ_sensor_spacetypes(model, space_type_map)
    return true
  end

=begin
  def apply_loop_pump_power(model:, sizing_run_dir:)
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
    #model = BTAP::FileIO::remove_duplicate_materials_and_constructions(model)
    return model
  end
=end
end
