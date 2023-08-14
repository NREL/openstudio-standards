# A set of methods for testing hvac system methods

# write errors to a log file
def log_hvac_test_errors(errs)
  File.open("#{File.dirname(__FILE__)}/output/test_add_hvac_systems.log", 'a') do |file|
    errs.each { |err| file.puts(err) }
  end
end

# default hash for hvac tests
def default_hvac_test_hash
  # example hash for an HVAC system type test
  # default optional arguments should match those in model_add_hvac_system
  default_hash = {template: '90.1-2013',
                  model_test_name: nil,
                  model_name: 'basic_2_story_office_no_hvac_60WWR',
                  climate_zone: 'ASHRAE 169-2013-7A',
                  system_type: nil,
                  main_heat_fuel: nil,
                  zone_heat_fuel: nil,
                  cool_fuel: nil,
                  zone_selection: 'all',
                  hot_water_loop_type: nil,
                  chilled_water_loop_cooling_type: nil,
                  heat_pump_loop_cooling_type: nil,
                  air_loop_heating_type: nil,
                  air_loop_cooling_type: nil,
                  zone_equipment_ventilation: nil,
                  unmet_hrs_htg: 300.0,
                  unmet_hrs_clg: 300.0,}
  return default_hash
end

# Runs an hvac test given an input model name and HVAC argument values
# Uses the default hash above
#
# @param hvac_arguments [Hash] a hash
def model_hvac_test(hvac_arguments)
  # Make the output directory if it doesn't exist
  output_dir = File.expand_path('output', File.dirname(__FILE__))
  FileUtils.mkdir output_dir unless Dir.exist? output_dir

  reset_log
  errs = []

  hash = default_hvac_test_hash.merge(hvac_arguments)
  template = hash[:template]
  model_test_name = hash[:model_test_name]
  model_name = hash[:model_name]
  climate_zone = hash[:climate_zone]
  system_type = hash[:system_type]
  main_heat_fuel = hash[:main_heat_fuel]
  zone_heat_fuel = hash[:zone_heat_fuel]
  cool_fuel = hash[:cool_fuel]
  zone_selection = hash[:zone_selection]
  hot_water_loop_type = hash[:hot_water_loop_type]
  chilled_water_loop_cooling_type = hash[:chilled_water_loop_cooling_type]
  heat_pump_loop_cooling_type = hash[:heat_pump_loop_cooling_type]
  air_loop_heating_type = hash[:air_loop_heating_type]
  air_loop_cooling_type = hash[:air_loop_cooling_type]
  zone_equipment_ventilation = hash[:zone_equipment_ventilation]
  unmet_hrs_htg = hash[:unmet_hrs_htg]
  unmet_hrs_clg = hash[:unmet_hrs_clg]

  standard = Standard.build(template)
  if model_test_name.nil?
    model_test_name = system_type.gsub(' ', '_')
  end
  model_dir = "#{output_dir}/hvac_#{model_test_name}"

  # Load the model if already created
  annual_run_success = false
  if File.exist?("#{model_dir}/AR/run/eplusout.sql")
    puts "test: '#{model_test_name}' results already available. Not re-rerunning energy simulation."
    model = OpenStudio::Model::Model.new
    sql = standard.safe_load_sql("#{model_dir}/AR/run/eplusout.sql")
    model.setSqlFile(sql)
    annual_run_success = true
  end

  # If not created, make and run annual simulation
  unless annual_run_success
    puts "test: '#{model_test_name}' results not available. Running energy simulation."
    # Load the test model
    model = standard.safe_load_model("#{File.dirname(__FILE__)}/models/#{model_name}.osm")

    # Assign a weather file
    standard.model_add_design_days_and_weather_file(model, climate_zone, '')
    standard.model_add_ground_temperatures(model, 'MediumOffice', climate_zone)

    zones = model.getThermalZones
    heated_and_cooled_zones = zones.select { |zone| standard.thermal_zone_heated?(zone) && standard.thermal_zone_cooled?(zone) }
    heated_zones = zones.select { |zone| standard.thermal_zone_heated?(zone) }
    cooled_zones = zones.select { |zone| standard.thermal_zone_cooled?(zone) }
    cooled_only_zones = zones.select { |zone| !standard.thermal_zone_heated?(zone) && standard.thermal_zone_cooled?(zone) }
    heated_only_zones = zones.select { |zone| standard.thermal_zone_heated?(zone) && !standard.thermal_zone_cooled?(zone) }
    system_zones = heated_and_cooled_zones + cooled_only_zones
    case zone_selection
    when 'heated_zones'
        zones = heated_zones
    when 'cooled_zones'
        zones = cooled_zones
    when 'heated_only_zones'
        zones = heated_only_zones
    when 'cooled_only_zones'
        zones = cooled_only_zones
    else # 'all'
        zones = system_zones
    end

    # Add the HVAC
    added_hvac = standard.model_add_hvac_system(model, system_type, main_heat_fuel, zone_heat_fuel, cool_fuel, zones,
                                                hot_water_loop_type: hot_water_loop_type,
                                                chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                                                heat_pump_loop_cooling_type: heat_pump_loop_cooling_type,
                                                air_loop_heating_type: air_loop_heating_type,
                                                air_loop_cooling_type: air_loop_cooling_type,
                                                zone_equipment_ventilation: zone_equipment_ventilation)

    unless added_hvac
      errs << "Unable to apply hvac constructor for system type '#{system_type}' to model #{model_test_name}."
      log_hvac_test_errors(errs)
      log_messages_to_file("#{model_dir}/openstudio-standards.log", debug=false)
      return errs
    end

    # Save the model
    model.save("#{model_dir}/final.osm", true)

    # Perform a sizing run
    sizing_run_success = standard.model_run_sizing_run(model, "#{model_dir}/SR")
    unless sizing_run_success
      errs << "#{model_test_name} sizing run failed"
      log_hvac_test_errors(errs)
      log_messages_to_file("#{model_dir}/openstudio-standards.log", debug=false)
      return errs
    end

    # Check the conditioned floor area
    if standard.model_net_conditioned_floor_area(model).zero?
      errs << "Test model #{model_test_name} has no conditioned area."
      log_hvac_test_errors(errs)
      return errs
    end

    # If there are any multizone systems, reset damper positions
    # to achieve a 60% ventilation effectiveness minimum for the system
    # following the ventilation rate procedure from 62.1
    standard.model_apply_multizone_vav_outdoor_air_sizing(model)

    # Apply the prototype HVAC assumptions
    standard.model_apply_prototype_hvac_assumptions(model, '', climate_zone)

    # Apply the HVAC efficiency standard
    apply_efficiency_success = standard.model_apply_hvac_efficiency_standard(model, climate_zone)
    unless apply_efficiency_success
      errs << "Failed to apply standard efficiencies after sizing run for model #{model_test_name}"
      errs << "#{apply_efficiency_success}"
      log_hvac_test_errors(errs)
      log_messages_to_file("#{model_dir}/openstudio-standards.log", debug=false)
      return errs
    end

    # Run the annual run
    annual_run_success = standard.model_run_simulation_and_log_errors(model, "#{model_dir}/AR")
    unless annual_run_success
      errs << "For #{model_test_name} annual run failed" unless annual_run_success
      log_hvac_test_errors(errs)
      log_messages_to_file("#{model_dir}/openstudio-standards.log", debug=false)
      return errs
    end
  end

  # Check unmet hours
  unmet_heating_hrs = standard.model_annual_occupied_unmet_heating_hours(model)
  unmet_cooling_hrs = standard.model_annual_occupied_unmet_cooling_hours(model)
  unmet_hrs = standard.model_annual_occupied_unmet_hours(model)
  if unmet_hrs
    if unmet_heating_hrs > unmet_hrs_htg
      errs << "Model #{model_test_name} has #{unmet_heating_hrs.round(1)} unmet occupied heating hours, more than the expected limit of #{unmet_hrs_htg}."
    end
    if unmet_cooling_hrs > unmet_hrs_clg
      errs << "Model #{model_test_name} has #{unmet_cooling_hrs.round(1)} unmet occupied cooling hours, more than the expected limit of #{unmet_hrs_clg}."
    end
  else
    errs << "Could not determine unmet hours for model #{model_test_name}.  Simulation may have failed."
  end
  log_hvac_test_errors(errs)
  log_messages_to_file("#{model_dir}/openstudio-standards.log", debug=false)

  # @todo add checks for hvac enduse euis, ventilation unmet hours
  return errs
end

# Runs individual model hvac tests for an array of hvac test hashes
#
# @param test_set [Array] an array of test hashes
def group_hvac_test(test_set)
  group_errs = []
  test_set.each do |test_hash|
    errs = model_hvac_test(test_hash)
    group_errs << errs unless errs.empty?
  end
  assert(group_errs.size == 0, group_errs.join("\n"))
end
