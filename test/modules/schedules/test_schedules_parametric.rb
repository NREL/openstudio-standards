require_relative '../../helpers/minitest_helper'

class TestSchedulesParametric < Minitest::Test

  def simulation_settings
    # enable daylight saving
    dst_control = @model.getRunPeriodControlDaylightSavingTime
    dst_control.setStartDate('2nd Sunday in March')
    dst_control.setEndDate('1st Sunday in November')

    # set timestep
    timestep = @model.getTimestep
    timestep.setNumberOfTimestepsPerHour(4)

    # run period
    run_period = @model.getRunPeriod
    run_period.setBeginMonth(1)
    run_period.setBeginDayOfMonth(1)
    run_period.setEndMonth(12)
    run_period.setEndDayOfMonth(31)

    # calendar year
    yr_desc = @model.getYearDescription
    yr_desc.setCalendarYear(2018)
  end

  def change_location(weather_file_name)
    ddy_list = @weather.ddy_regex_lookup("All Heating") + @weather.ddy_regex_lookup("All Cooling")
    puts ddy_list
    weather_file_path = @weather.get_standards_weather_file_path(weather_file_name)
    @weather.model_set_building_location(@model, weather_file_path: weather_file_path, ddy_list: ddy_list)
  end

  def create_bar(options)
    # model articulation
    args = {
      climate_zone: options[:climate_zone],
      bldg_type_a: options[:bldg_type],
      bldg_type_a_num_units: 1,
      bldg_type_b: 'SecondarySchool',
      bldg_subtype_b: 'NA',
      bldg_type_b_fract_bldg_area: 0,
      bldg_type_b_num_units: 1,
      bldg_type_c: 'SecondarySchool',
      bldg_subtype_c: 'NA',
      bldg_type_c_fract_bldg_area: 0,
      bldg_type_c_num_units: 1,
      bldg_type_d: 'SecondarySchool',
      bldg_subtype_d: 'NA',
      bldg_type_d_fract_bldg_area: 0,
      bldg_type_d_num_units: 1,
      num_stories_below_grade: 0,
      num_stories_above_grade: 1,
      story_multiplier: 'None',
      bar_division_method: 'Multiple Space Types - Individual Stories Sliced',
      bottom_story_ground_exposed_floor: true,
      top_story_exterior_exposed_roof: true,
      make_mid_story_surfaces_adiabatic: true,
      total_bldg_floor_area: options[:flr_area],
      wwr: options[:wwr],
      ns_to_ew_ratio: options[:aspect_ratio],
      perim_mult: 0.0,
      bar_width: 0.0,
      bar_sep_dist_mult: 10.0,
      building_rotation: 0.0,
      template: options[:template],
      custom_height_bar: true,
      floor_height: 0.0,
      party_wall_fraction: 0.0,
      party_wall_stories_north: 0,
      party_wall_stories_south: 0,
      party_wall_stories_east: 0,
      party_wall_stories_west: 0,
      double_loaded_corridor: 'Primary Space Type',
      space_type_sort_logic: 'Building Type > Size',
      single_floor_area: 0
    }
    @model = OpenStudio::Model::Model.new
    OpenstudioStandards::Geometry.create_bar_from_building_type_ratios(@model, args)
  end

  def setup
    # setup test output dirs
    @test_dir = File.expand_path("#{__dir__}/output/")
    if !Dir.exists?(@test_dir)
      Dir.mkdir(@test_dir)
    end

    OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Debug)
    # OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Info)
    # OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Warn)

    # initialize namespace members
    @weather = OpenstudioStandards::Weather
    @schedules = OpenstudioStandards::Schedules
  end

  def print_additional_properties(props)
    puts "Additional property for object #{props.modelObject.name.get}"
    props.featureNames.each do |name|
      if props.hasFeature(name)
        feature_type = props.getFeatureDataType(name).to_s
        feature = nil
        case feature_type
        when 'Integer'
          feature = props.getFeatureAsInteger(name).get
        when 'Double'
          feature = props.getFeatureAsDouble(name).get
        when 'String'
          feature = props.getFeatureAsString(name).get
        when 'Boolean'
          feature = props.getFeatureAsBoolean(name).get
        end
        puts "Property: #{name} - Value: #{feature.to_s}"
      else
        puts "No value found for property: #{name}"
      end
    end
  end


  def test_schedules_unmodified
    puts "\n######\nTEST:#{__method__}\n######\n"

    run_dir = "#{@test_dir}/schedules_unmodified"
    # puts @model.getSpaces.size

    # create geometry
    create_bar({
      climate_zone: 'ASHRAE 169-2013-5B',
      bldg_type: 'SecondarySchool',
      flr_area: 150000,
      wwr: 0.38,
      aspect_ratio: 3,
      template: 'ComStock DOE Ref 1980-2004'
    })

    # simulation settings
    simulation_settings()

    # weather file
    weather_file_name = "USA_ID_Boise.Air.Terminal.726810_TMY3.epw"
    change_location(weather_file_name)

    assert(@model)

    template = 'ComStock DOE Ref 1980-2004'
    climate_zone = 'ASHRAE 169-2013-5B'

    # create typical without parametric schedules
    OpenstudioStandards::CreateTypical.create_typical_building_from_model(@model,
                                                                         template,
                                                                         climate_zone: climate_zone,
                                                                         hvac_system_type: "VAV chiller with gas boiler reheat",
                                                                         hvac_delivery_type: "Inferred",
                                                                         heating_fuel: "Inferred",
                                                                         service_water_heating_fuel: "Inferred",
                                                                         cooling_fuel: "Inferred",
                                                                         modify_wkdy_op_hrs: false,
                                                                         modify_wknd_op_hrs: false)

    osm_path = "#{run_dir}/schedules_unmodified.osm"
    assert(@model.save(osm_path, true))
  end

  def test_schedules_modified
    puts "\n######\nTEST:#{__method__}\n######\n"

    run_dir = "#{@test_dir}/schedules_modified"

    # create geometry
    create_bar({
      climate_zone: 'ASHRAE 169-2013-5B',
      bldg_type: 'SecondarySchool',
      flr_area: 150000,
      wwr: 0.38,
      aspect_ratio: 3,
      template: 'ComStock DOE Ref 1980-2004'
    })

    # simulation settings
    simulation_settings()

    # weather file
    weather_file_name = "USA_ID_Boise.Air.Terminal.726810_TMY3.epw"
    change_location(weather_file_name)

    assert(@model)

    template = 'ComStock DOE Ref 1980-2004'
    climate_zone = 'ASHRAE 169-2013-5B'

    # create typical with parametric schedules
    # default wkdy start: 8.0, wkdy duration: 8.0
    # default wknd start: 8.0, wknd duration: 8.0
    OpenstudioStandards::CreateTypical.create_typical_building_from_model(@model,
                                                                         template,
                                                                         climate_zone: climate_zone,
                                                                         hvac_system_type: "VAV chiller with gas boiler reheat",
                                                                         hvac_delivery_type: "Inferred",
                                                                         heating_fuel: "Inferred",
                                                                         service_water_heating_fuel: "Inferred",
                                                                         cooling_fuel: "Inferred",
                                                                         modify_wkdy_op_hrs: true,
                                                                         modify_wknd_op_hrs: true)

    osm_path = "#{run_dir}/schedules_modified.osm"
    assert(@model.save(osm_path, true))

    # building hours of operation match start/duration inputs
    default_sch_set = @model.getBuilding.defaultScheduleSet.get
    hoo_sch = default_sch_set.hoursofOperationSchedule.get.to_ScheduleRuleset.get
    puts hoo_sch.defaultDaySchedule

    # get thermostat schedules
    tstat = @model.getThermostatSetpointDualSetpoints.first
    zone = tstat.thermalZone.get
    space = zone.spaces.first
    ppl_sch = space.spaceType.get.defaultScheduleSet.get.numberofPeopleSchedule.get.to_ScheduleRuleset.get
    ppl_sch_profiles = @schedules.schedule_ruleset_get_day_schedules(ppl_sch)
    print_additional_properties(ppl_sch.additionalProperties)
    ppl_sch_profiles.each{|sch| print_additional_properties(sch.additionalProperties)}


    clg_sch = tstat.coolingSetpointTemperatureSchedule.get.to_ScheduleRuleset.get
    htg_sch = tstat.heatingSetpointTemperatureSchedule.get.to_ScheduleRuleset.get

    puts clg_sch.name.get
    clg_sch_profiles = @schedules.schedule_ruleset_get_day_schedules(clg_sch)
    print_additional_properties(clg_sch.additionalProperties)
    clg_sch_profiles.each{|sch| print_additional_properties(sch.additionalProperties)}
    # clg_sch.additionalProperties.featureNames.each do |prop_feature|
    #   puts prop_feature
    #   puts clg_sch.additionalProperties.getFeatureAsDouble(prop_feature)
    # end

    puts htg_sch.name.get
    htg_sch_profiles = @schedules.schedule_ruleset_get_day_schedules(htg_sch)
    print_additional_properties(htg_sch.additionalProperties)
    htg_sch_profiles.each{|sch| print_additional_properties(sch.additionalProperties)}
    # htg_sch.additionalProperties.featureNames.each do |prop_feature|
    #   puts prop_feature
    #   puts htg_sch.additionalProperties.getFeatureAsDouble(prop_feature)
    # end


  end

  def test_parametric_schedule_buildup
    puts "\n######\nTEST:#{__method__}\n######\n"

    run_dir = "#{@test_dir}/parametric_schedule_buildup"

    create_bar({
      climate_zone: 'ASHRAE 169-2013-5B',
      bldg_type: 'SecondarySchool',
      flr_area: 150000,
      wwr: 0.38,
      aspect_ratio: 3,
      template: 'ComStock DOE Ref 1980-2004'
    })

    simulation_settings()

    weather_file_name = "USA_ID_Boise.Air.Terminal.726810_TMY3.epw"
    change_location(weather_file_name)

    assert(@model)

    # create instance of standard
    template = 'ComStock DOE Ref 1980-2004'
    # std = Standard.build(template)

    op_sch = OpenstudioStandards::Schedules.model_infer_hours_of_operation_building(@model)
    before = op_sch.defaultDaySchedule
    puts before

    @model.save("#{run_dir}/before_set_hoo.osm", true)

    wkdy_start_time_hr = 6
    wkdy_start_time_min = 0
    wkdy_op_hrs_duration_hr = 8
    wkdy_op_hrs_duration_min = 0
    wknd_start_time_hr = 10
    wknd_start_time_min = 0
    wknd_op_hrs_duration_hr = 8
    wknd_op_hrs_duration_min = 0

    wkdy_start_time = OpenStudio::Time.new(0, wkdy_start_time_hr, wkdy_start_time_min, 0)
    wkdy_end_time = wkdy_start_time + OpenStudio::Time.new(0, wkdy_op_hrs_duration_hr, wkdy_op_hrs_duration_min, 0)

    wknd_start_time = OpenStudio::Time.new(0, wknd_start_time_hr, wknd_start_time_min, 0)
    wknd_end_time = wkdy_start_time + OpenStudio::Time.new(0, wknd_op_hrs_duration_hr, wknd_op_hrs_duration_min, 0)


    OpenstudioStandards::Schedules.schedule_ruleset_set_hours_of_operation(op_sch,
                                                wkdy_start_time: wkdy_start_time,
                                                wkdy_end_time: wkdy_end_time,
                                                sat_start_time: wknd_start_time,
                                                sat_end_time: wknd_end_time,
                                                sun_start_time: wknd_start_time,
                                                sun_end_time: wknd_end_time)

    after = op_sch.defaultDaySchedule


    puts after

    @model.save("#{run_dir}/after_set_hoo.osm", true)
    # climate_zone = 'ASHRAE 169-2013-5B'

    # osm_path = "#{run_dir}/parametric_schedule_buildup.osm"
    # assert(@model.save(osm_path, true))

  end

  def skip_test_setup_parametric_schedules
    puts "\n######\nTEST:#{__method__}\n######\n"

    require 'pp'
    run_dir = "#{@test_dir}/test_setup_parametric_schedules"

    create_bar({
      climate_zone: 'ASHRAE 169-2013-5B',
      bldg_type: 'SecondarySchool',
      flr_area: 150000,
      wwr: 0.38,
      aspect_ratio: 3,
      template: 'ComStock DOE Ref 1980-2004'
    })

    simulation_settings()

    weather_file_name = "USA_ID_Boise.Air.Terminal.726810_TMY3.epw"
    change_location(weather_file_name)

    assert(@model)

    # create instance of standard
    template = 'ComStock DOE Ref 1980-2004'
    std = Standard.build(template)

    template = 'ComStock DOE Ref 1980-2004'
    climate_zone = 'ASHRAE 169-2013-5B'

    # create typical without parametric schedules
    OpenstudioStandards::CreateTypical.create_typical_building_from_model(@model,
        template,
        climate_zone: climate_zone,
        hvac_system_type: "VAV chiller with gas boiler reheat",
        hvac_delivery_type: "Inferred",
        heating_fuel: "Inferred",
        service_water_heating_fuel: "Inferred",
        cooling_fuel: "Inferred",
        modify_wkdy_op_hrs: false,
        modify_wknd_op_hrs: false)

    # start/end time inputs
    wkdy_start_time_hr = 6
    wkdy_start_time_min = 0
    wkdy_op_hrs_duration_hr = 8
    wkdy_op_hrs_duration_min = 0
    wknd_start_time_hr = 10
    wknd_start_time_min = 0
    wknd_op_hrs_duration_hr = 8
    wknd_op_hrs_duration_min = 0

    wkdy_start_time = OpenStudio::Time.new(0, wkdy_start_time_hr, wkdy_start_time_min, 0)
    wkdy_end_time = wkdy_start_time + OpenStudio::Time.new(0, wkdy_op_hrs_duration_hr, wkdy_op_hrs_duration_min, 0)

    wknd_start_time = OpenStudio::Time.new(0, wknd_start_time_hr, wknd_start_time_min, 0)
    wknd_end_time = wkdy_start_time + OpenStudio::Time.new(0, wknd_op_hrs_duration_hr, wknd_op_hrs_duration_min, 0)

    # infer current hours of operation schedule of building
    op_sch = OpenstudioStandards::Schedules.model_infer_hours_of_operation_building(@model)
    puts op_sch

    # convert existing schedules to parametric schedules
    result = OpenstudioStandards::Schedules.model_setup_parametric_schedules(@model, hoo_var_method: 'hours')

    pp result

    # @model.getScheduleRulesets.each do |sch|
    #   if sch.hasAdditionalProperties
    #     puts sch.name.get
    #     puts sch.additionalProperties
    #   end
    # end

  end



  def skip_test_location_short
    run_dir = "#{@test_dir}/location_short"

    create_bar()
    simulation_settings()

    weather_file_name = "USA_ID_Boise.Air.Terminal.726810_TMY3.epw"
    change_location(weather_file_name)

    assert(@model)

    template = 'ComStock DOE Ref 1980-2004'
    climate_zone = 'ASHRAE 169-2013-5B'

    osm_path = "#{run_dir}/location_short.osm"
    assert(@model.save(osm_path, true))
  end

  def skip_test_multiple_modifications
    run_dir = "#{@test_dir}/schedules_multiple_mods"

    # assert(@model)
    template = "ComStock DOE Ref 1980-2004"
    climate_zone = 'ASHRAE 169-2013-5B'

    [2, 4, 6, 8, 10, 12].each do |mod|
      # create geometry
      create_bar

      # simulation settings
      simulation_settings()

      # weather file
      weather_file_name = "USA_ID_Boise.Air.Terminal.726810_TMY3.epw"
      change_location(weather_file_name)


      OpenstudioStandards::CreateTypical.create_typical_building_from_model(@model,
                                                                            template,
                                                                            climate_zone: climate_zone,
                                                                            hvac_system_type: "VAV chiller with gas boiler reheat",
                                                                            hvac_delivery_type: "Inferred",
                                                                            heating_fuel: "Inferred",
                                                                            service_water_heating_fuel: "Inferred",
                                                                            cooling_fuel: "Inferred",
                                                                            modify_wkdy_op_hrs: true,
                                                                            wkdy_op_hrs_duration: mod,
                                                                            modify_wknd_op_hrs: true,
                                                                            wknd_op_hrs_duration: mod)
      osm_path = "#{run_dir}/schedules_multiple_mods_#{mod}.osm"
      assert(@model.save(osm_path, true))

      sch = @model.getScheduleRulesetByName("SecondarySchool Bldg Occ").get
      def_sch = sch.defaultDaySchedule
      puts def_sch.additionalProperties
    end

  end


end