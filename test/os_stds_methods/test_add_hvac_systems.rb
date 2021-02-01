require_relative '../helpers/minitest_helper'

class TestAddHVACSystems < Minitest::Test

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

    # TODO: add checks for hvac enduse euis, ventilation unmet hours
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

  # TODO: add support for additional variations of building type (office, multifamily), geometry (20, 60 wwr), and climate zone (2A, 5B, 7A)

  def test_add_hvac_systems_ideal_loads
    hvac_systems = [
      {system_type: 'Ideal Air Loads'}
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_residential
    hvac_systems = [
      {system_type: 'Window AC', cool_fuel: 'Electricity', zone_selection: 'cooled_zones', climate_zone: 'ASHRAE 169-2013-2B', unmet_hrs_htg: 3000.0},
      {system_type: 'Residential AC', cool_fuel: 'Electricity', zone_selection: 'cooled_zones', climate_zone: 'ASHRAE 169-2013-2B', unmet_hrs_htg: 3000.0},
      {system_type: 'Residential Forced Air Furnace', main_heat_fuel: 'NaturalGas', unmet_hrs_clg: 6000.0},
      {system_type: 'Residential Forced Air Furnace with AC', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity'},
      {system_type: 'Residential Air Source Heat Pump', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity'}
      # TODO: couple with baseboards and other heating systems, e.g. window ac and forced air
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_sz_heating
    hvac_systems = [
      {model_test_name: 'Baseboards_elec', system_type: 'Baseboards', main_heat_fuel: 'Electricity', zone_selection: 'heated_zones', unmet_hrs_clg: 6000.0},
      {model_test_name: 'Baseboards_gas', system_type: 'Baseboards', main_heat_fuel: 'NaturalGas', zone_selection: 'heated_zones', unmet_hrs_clg: 6000.0},
      {model_test_name: 'Baseboards_ashp', system_type: 'Baseboards', main_heat_fuel: 'AirSourceHeatPump', zone_selection: 'heated_zones', unmet_hrs_clg: 6000.0},
      {model_test_name: 'Baseboards_district', system_type: 'Baseboards', main_heat_fuel: 'DistrictHeating', zone_selection: 'heated_zones', unmet_hrs_clg: 6000.0},
      {system_type: 'Unit Heaters', main_heat_fuel: 'NaturalGas', zone_selection: 'heated_zones', unmet_hrs_clg: 6000.0},
      {system_type: 'High Temp Radiant', main_heat_fuel: 'NaturalGas', zone_selection: 'heated_zones', unmet_hrs_clg: 6000.0},
      {system_type: 'Forced Air Furnace', main_heat_fuel: 'NaturalGas', zone_selection: 'heated_zones', unmet_hrs_htg: 1800.0, unmet_hrs_clg: 6000.0}
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_sz_cooling
    hvac_systems = [
      {system_type: 'Evaporative Cooler', cool_fuel: 'Electricity', zones: 'cooled_zones', climate_zone: 'ASHRAE 169-2013-2B', unmet_hrs_htg: 6000.0, unmet_hrs_clg: 3000.0}
    ]
    # TODO: debug evaporative cooler performance
    # TODO: add more evaporative cooler tests, combine with baseboards
    # TODO: add climate zone coverage
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_ptac_pthp
    hvac_systems = [
      {model_test_name: 'PTAC_elec', system_type: 'PTAC', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity'},
      {model_test_name: 'PTAC_gas', system_type: 'PTAC', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity'},
      # {model_test_name: 'PTAC_ashp', system_type: 'PTAC', main_heat_fuel: 'AirSourceHeatPump', cool_fuel: 'Electricity'},
      # TODO: this test is failing the sizing run
      {model_test_name: 'PTAC_district_heat', system_type: 'PTAC', main_heat_fuel: 'DistrictHeating', cool_fuel: 'Electricity'},
      {model_test_name: 'PTAC_no_heat', system_type: 'PTAC', main_heat_fuel: nil, cool_fuel: 'Electricity', unmet_hrs_htg: 6000.0},
      # TODO: add PTAC and baseboard pairings
      {system_type: 'PTHP', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity'}
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_pszac_pszhp
    hvac_systems = [
      {model_test_name: 'PSZAC_elec_elec', system_type: 'PSZ-AC', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', unmet_hrs_htg: 450.0},
      {model_test_name: 'PSZAC_elec_district', system_type: 'PSZ-AC', main_heat_fuel: 'Electricity', cool_fuel: 'DistrictCooling', unmet_hrs_htg: 450.0},
      {model_test_name: 'PSZAC_gas_elec', system_type: 'PSZ-AC', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity', unmet_hrs_htg: 450.0},
      {model_test_name: 'PSZAC_gas_district', system_type: 'PSZ-AC', main_heat_fuel: 'NaturalGas', cool_fuel: 'DistrictCooling', unmet_hrs_htg: 450.0},
      # {model_test_name: 'PSZAC_ashp_elec', system_type: 'PSZ-AC', main_heat_fuel: 'AirSourceHeatPump', cool_fuel: 'Electricity'},
      # {model_test_name: 'PSZAC_ashp_district', system_type: 'PSZ-AC', main_heat_fuel: 'AirSourceHeatPump', cool_fuel: 'DistrictCooling'},
      # TODO: this test is failing the sizing run
      {model_test_name: 'PSZAC_district_elec', system_type: 'PSZ-AC', main_heat_fuel: 'DistrictHeating', cool_fuel: 'Electricity', unmet_hrs_htg: 450.0},
      {model_test_name: 'PSZAC_district_district', system_type: 'PSZ-AC', main_heat_fuel: 'DistrictHeating', cool_fuel: 'DistrictCooling', unmet_hrs_htg: 450.0},
      {model_test_name: 'PSZAC_no_heat_elec', system_type: 'PSZ-AC', main_heat_fuel: nil, cool_fuel: 'Electricity', unmet_hrs_htg: 6000.0},
      {model_test_name: 'PSZAC_no_heat_district', system_type: 'PSZ-AC', main_heat_fuel: nil, cool_fuel: 'DistrictCooling', unmet_hrs_htg: 6000.0},
      # TODO: add PSZ-AC and baseboard pairings
      {system_type: 'PSZ-HP', main_heat_fuel: ['Electricity'], cool_fuel: ['Electricity']}
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_vrf
    hvac_systems = [
      {system_type: 'VRF', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', unmet_hrs_htg: 900.0},
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_fan_coil
    hvac_systems = [
      {model_test_name: 'Fancoil_elec_elec_water', system_type: 'Fan Coil', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', chilled_water_loop_cooling_type: 'Water_Cooled'},
      {model_test_name: 'Fancoil_elec_elec_air', system_type: 'Fan Coil', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', chilled_water_loop_cooling_type: 'AirCooled'},
      {model_test_name: 'Fancoil_elec_district', system_type: 'Fan Coil', main_heat_fuel: 'Electricity', cool_fuel: 'DistrictCooling'},
      {model_test_name: 'Fancoil_gas_elec_water', system_type: 'Fan Coil', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity', chilled_water_loop_cooling_type: 'Water_Cooled'},
      {model_test_name: 'Fancoil_gas_elec_air', system_type: 'Fan Coil', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity', chilled_water_loop_cooling_type: 'AirCooled'},
      {model_test_name: 'Fancoil_gas_district', system_type: 'Fan Coil', main_heat_fuel: 'NaturalGas', cool_fuel: 'DistrictCooling'},
      {model_test_name: 'Fancoil_ashp_elec_water', system_type: 'Fan Coil', main_heat_fuel: 'AirSourceHeatPump', cool_fuel: 'Electricity', chilled_water_loop_cooling_type: 'Water_Cooled'},
      {model_test_name: 'Fancoil_ashp_elec_air', system_type: 'Fan Coil', main_heat_fuel: 'AirSourceHeatPump', cool_fuel: 'Electricity', chilled_water_loop_cooling_type: 'AirCooled'},
      {model_test_name: 'Fancoil_ashp_district', system_type: 'Fan Coil', main_heat_fuel: 'AirSourceHeatPump', cool_fuel: 'DistrictCooling'},
      {model_test_name: 'Fancoil_district_elec_water', system_type: 'Fan Coil', main_heat_fuel: 'DistrictHeating', cool_fuel: 'Electricity', chilled_water_loop_cooling_type: 'Water_Cooled'},
      {model_test_name: 'Fancoil_district_elec_air', system_type: 'Fan Coil', main_heat_fuel: 'DistrictHeating', cool_fuel: 'Electricity', chilled_water_loop_cooling_type: 'AirCooled'},
      {model_test_name: 'Fancoil_district_district', system_type: 'Fan Coil', main_heat_fuel: 'DistrictHeating', cool_fuel: 'DistrictCooling'}
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_wshp
    hvac_systems = [
      {model_test_name: 'WSHP_elec_elec_clg_twr', system_type: 'Water Source Heat Pumps', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', heat_pump_loop_cooling_type: 'CoolingTower'},
      {model_test_name: 'WSHP_elec_elec_fld_clr', system_type: 'Water Source Heat Pumps', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', heat_pump_loop_cooling_type: 'FluidCooler'},
      {model_test_name: 'WSHP_gas_elec_clg_twr', system_type: 'Water Source Heat Pumps', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity', heat_pump_loop_cooling_type: 'CoolingTower'},
      # {model_test_name: 'WSHP_ashp_clg_twr', system_type: 'Water Source Heat Pumps', main_heat_fuel: 'AirSourceHeatPump', cool_fuel: 'Electricity', heat_pump_loop_cooling_type: 'CoolingTower'},
      # TODO: fix failing sizing run
      {model_test_name: 'WSHP_ambient_clg_twr', system_type: 'Water Source Heat Pumps', main_heat_fuel: 'DistrictHeating', cool_fuel: 'Electricity', heat_pump_loop_cooling_type: 'CoolingTower'},
      {model_test_name: 'WSHP_ambient_clg_twr', system_type: 'Water Source Heat Pumps', main_heat_fuel: 'AmbientLoop', cool_fuel: 'AmbientLoop', heat_pump_loop_cooling_type: 'CoolingTower'},
      # {model_test_name: 'WSHP_ambient_fld_clr', system_type: 'Water Source Heat Pumps', main_heat_fuel: 'AmbientLoop', cool_fuel: 'AmbientLoop', heat_pump_loop_cooling_type: 'FluidCooler'}
      # TODO: this test is failing the sizing run
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_vav
    hvac_systems = [
      {model_test_name: 'PVAV_Reheat_gas_elec', system_type: 'PVAV Reheat', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'Electricity', cool_fuel: 'Electricity', unmet_hrs_htg: 1500.0},
      {model_test_name: 'PVAV_Reheat_gas_gas', system_type: 'PVAV Reheat', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity', unmet_hrs_htg: 1500.0},
      {model_test_name: 'PVAV_Reheat_ashp', system_type: 'PVAV Reheat', main_heat_fuel: 'AirSourceHeatPump', zone_heat_fuel: 'AirSourceHeatPump', cool_fuel: 'Electricity', unmet_hrs_htg: 1500.0},
      {model_test_name: 'PVAV_Reheat_district', system_type: 'PVAV Reheat', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: 'DistrictHeating', cool_fuel: 'Electricity', unmet_hrs_htg: 1500.0},
      {model_test_name: 'PVAV_PFP_Boxes', system_type: 'PVAV PFP Boxes', main_heat_fuel: 'Electricity', zone_heat_fuel: 'Electricity', cool_fuel: 'Electricity'},
      {model_test_name: 'VAV_Reheat_gas_gas', system_type: 'VAV Reheat', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity', unmet_hrs_htg: 550.0},
      {model_test_name: 'VAV_Reheat_ashp_gas', system_type: 'VAV Reheat', main_heat_fuel: 'AirSourceHeatPump', zone_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity', unmet_hrs_htg: 550.0},
      {model_test_name: 'VAV_Reheat_ashp_ashp', system_type: 'VAV Reheat', main_heat_fuel: 'AirSourceHeatPump', zone_heat_fuel: 'AirSourceHeatPump', cool_fuel: 'Electricity', unmet_hrs_htg: 550.0},
      {model_test_name: 'VAV_Reheat_district', system_type: 'VAV Reheat', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: 'DistrictHeating', cool_fuel: 'DistrictCooling', unmet_hrs_htg: 550.0},
      {model_test_name: 'VAV_PFP_gas_elec', system_type: 'VAV PFP Boxes', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'Electricity', cool_fuel: 'Electricity'},
      {model_test_name: 'VAV_PFP_ashp_elec', system_type: 'VAV PFP Boxes', main_heat_fuel: 'AirSourceHeatPump', zone_heat_fuel: 'Electricity', cool_fuel: 'Electricity'},
      {model_test_name: 'VAV_PFP_district', system_type: 'VAV PFP Boxes', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: 'Electricity', cool_fuel: 'DistrictCooling'},
      {model_test_name: 'VAV_Gas_Reheat_gas_gas', system_type: 'VAV Gas Reheat', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity', unmet_hrs_htg: 1500.0},
      {model_test_name: 'VAV_Gas_Reheat_ashp', system_type: 'VAV Gas Reheat', main_heat_fuel: 'AirSourceHeatPump', zone_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity', unmet_hrs_htg: 1500.0},
      {model_test_name: 'VAV_Gas_Reheat_district', system_type: 'VAV Gas Reheat', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: 'NaturalGas', cool_fuel: 'DistrictCooling', unmet_hrs_htg: 1500.0},
      {model_test_name: 'VAV_No_Reheat', system_type: 'VAV No Reheat', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: 'Electricity', zones: 'cooled_zones', unmet_hrs_htg: 3750.0}
      # TODO: unmet hours are likely related to the different ventilation rate procedure/zone sum sizing criteria
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_doas
    hvac_systems = [
      {system_type: 'Fan Coil with DOAS', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', chilled_water_loop_cooling_type: 'Water_Cooled'},
      {system_type: 'Water Source Heat Pumps with DOAS', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', heat_pump_loop_cooling_type: 'CoolingTower'},
      {system_type: 'Ground Source Heat Pumps with DOAS', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', air_loop_heating_type: 'DX', air_loop_cooling_type: 'DX'},
      {system_type: 'VRF with DOAS', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', air_loop_heating_type: 'DX', air_loop_cooling_type: 'DX', climate_zone: 'ASHRAE 169-2013-4A'}
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_doas_dcv
    hvac_systems = [
      {system_type: 'Fan Coil with DOAS with DCV', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', chilled_water_loop_cooling_type: 'Water_Cooled'}
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_ervs
    hvac_systems = [
        {system_type: 'Fan Coil with ERVs', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', chilled_water_loop_cooling_type: 'Water_Cooled'},
        {system_type: 'Water Source Heat Pumps with ERVs', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', heat_pump_loop_cooling_type: 'CoolingTower'},
        {system_type: 'Ground Source Heat Pumps with ERVs', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', air_loop_heating_type: 'DX', air_loop_cooling_type: 'DX'},
        {system_type: 'VRF with ERVs', main_heat_fuel: 'Electricity', cool_fuel: 'Electricity', air_loop_heating_type: 'DX', air_loop_cooling_type: 'DX', climate_zone: 'ASHRAE 169-2013-4A'}
    ]
    group_hvac_test(hvac_systems)
  end

  def test_add_hvac_systems_radiant
    hvac_systems = [
      {system_type: 'Radiant Slab with DOAS', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       unmet_hrs_htg: 700.0, unmet_hrs_clg: 3500.0}
       #TODO:
    ]
    group_hvac_test(hvac_systems)
  end
end
