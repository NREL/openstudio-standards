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
    weather_file_path = @weather.get_standards_weather_file_path(weather_file_name)
    @weather.model_set_building_location(@model, weather_file_path: weather_file_path, ddy_list: nil)
  end

  def create_bar(options)
    # model articulation
    args = {
      climate_zone: options[:climate_zone],
      bldg_type_a: options[:bldg_type],
      bldg_subtype_a: 'largeoffice_default',
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

    # OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Debug)
    # OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Info)
    # OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Warn)

    # initialize namespace members
    @weather = OpenstudioStandards::Weather
    @schedules = OpenstudioStandards::Schedules
    @spaces = OpenstudioStandards::Space
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

  def model_get_lookup_name(building_type)
    lookup_name = building_type
    case building_type
    when 'SmallOffice'
      lookup_name = 'Office'
    when 'SmallOfficeDetailed'
      lookup_name = 'Office'
    when 'MediumOffice'
      lookup_name = 'Office'
    when 'MediumOfficeDetailed'
      lookup_name = 'Office'
    when 'LargeOffice'
      lookup_name = 'Office'
    when 'LargeOfficeDetailed'
      lookup_name = 'Office'
    when 'RetailStandalone'
      lookup_name = 'Retail'
    when 'RetailStripmall'
      lookup_name = 'StripMall'
    when 'Office'
      lookup_name = 'Office'
    end
    return lookup_name
  end

  def test_align_rules
    puts "\n######\nTEST:#{__method__}\n######\n"

    model = BTAP::FileIO.safe_load_model(File.join((__dir__), "output/comstock_hoos/LargeHotel_out.osm"))

    @schedules.model_infer_hours_of_operation_building(model)
    hours_of_operation = @spaces.spaces_hours_of_operation(model.getSpaces)
    puts hours_of_operation

    # sch = model.getScheduleRulesetByName('LargeHotel ClgSetp').get
    # sch = model.getScheduleRulesetByName("Building Hours of Operation NonResidential").get
    sch = model.getScheduleRulesetByName('LargeHotel Kitchen_Elec_Equip_SCH').get

    ann_ind = @schedules.schedule_ruleset_get_annual_rule_indices(sch)
    puts "#{ann_ind}"

    days_used = @schedules.schedule_ruleset_days_used_hash(sch)
    puts "#{days_used}"

    puts sch.scheduleRules

    @schedules.schedule_ruleset_align_rules_with_hours_of_operation(sch, hours_of_operation)

    puts OpenStudio::Model.getRecursiveChildren(sch)
    # puts sch.scheduleRules

    days_used = @schedules.schedule_ruleset_days_used_hash(sch)
    puts "#{days_used}"
  end



  def test_comstock_hoos
    puts "\n######\nTEST:#{__method__}\n######\n"
    OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Error)

    run_dir = "#{@test_dir}/comstock_hoos"

    types = []
    types << 'SecondarySchool'
    types << 'PrimarySchool'
    types << 'SmallOffice'
    types << 'MediumOffice'
    types << 'LargeOffice'
    types << 'SmallHotel'
    types << 'LargeHotel'
    types << 'Warehouse'
    types << 'RetailStandalone'
    types << 'RetailStripmall'
    types << 'QuickServiceRestaurant'
    types << 'FullServiceRestaurant'
    types << 'Hospital'
    types << 'Outpatient'


    types.each do |type|
      puts "-------------------------------------------------------------"
      puts type
      # create geometry
      args = {
        climate_zone: 'ASHRAE 169-2013-5B',
        bldg_type: type,
        flr_area: 15000,
        wwr: 0.38,
        aspect_ratio: 3,
        template: 'ComStock DOE Ref 1980-2004'
      }
      create_bar(args)

      # simulation settings
      simulation_settings()

      # weather file
      weather_file_name = "USA_ID_Boise.Air.Terminal.726810_TMY3.epw"
      change_location(weather_file_name)

      assert(@model)
      template = 'ComStock DOE Ref 1980-2004'
      climate_zone = 'ASHRAE 169-2013-5B'

      orig_dir = Dir.pwd
      Dir.chdir(File.join((__dir__), '/output'))

      # create typical without parametric schedules, or hvac
      OpenstudioStandards::CreateTypical.create_typical_building_from_model(@model,
                                                                            template,
                                                                            climate_zone: climate_zone,
                                                                            hvac_system_type: "VAV chiller with gas boiler reheat",
                                                                            hvac_delivery_type: "Inferred",
                                                                            heating_fuel: "Inferred",
                                                                            service_water_heating_fuel: "Inferred",
                                                                            cooling_fuel: "Inferred",
                                                                            modify_wkdy_op_hrs: false,
                                                                            modify_wknd_op_hrs: false,
                                                                            add_hvac: false,
                                                                            add_elevators: false
                                                                            )
      Dir.chdir(orig_dir)

      @schedules.model_infer_hours_of_operation_building(@model)
      osm_path = "#{run_dir}/#{args[:bldg_type]}_out.osm"
      assert(@model.save(osm_path, true))

      space_types = OpenstudioStandards::CreateTypical.get_space_types_from_building_type(type, building_subtype:'largeoffice_default')
      max_space_type = space_types.keys.find{|k| space_types[k][:ratio] == space_types.values.map{|hash| hash[:ratio]}.max}
      puts max_space_type

      space_type = @model.getSpaceTypeByName("#{model_get_lookup_name(type)} #{max_space_type} - #{template}").get
      hours_of_operation = @spaces.space_hours_of_operation(space_type)

      year = 2018
      puts type
      hours_of_operation.each do |k,v|
        if k == :schedule
          puts v.name.get
        else
          puts "#{k}: #{v[:hoo_start]} - #{v[:hoo_end]}"
          puts "days used: #{v[:days_used]}"
          day_of_weeks = []
          v[:days_used].each do |day_i|
            day_obj = OpenStudio::Date.fromDayOfYear(day_i,year)
            day_of_weeks << day_obj.dayOfWeek.valueName
          end
          puts day_of_weeks.uniq
        end
      end


      # light = space_type.lights.first
      # parametric_inputs = @spaces.gather_inputs_parametric_load_inst_schedules(light, {}, hours_of_operation, false)
      # try all schedules
      parametric_inputs = @schedules.model_setup_parametric_schedules(@model, hoo_var_method:'hours')
      parametric_inputs.each do |k,v|
        # puts k.name.get
        target = v[:target]
        # puts target.name.get
        profiles = @schedules.schedule_ruleset_get_day_schedules(k)
        # print_additional_properties(k.additionalProperties)
        # profiles.each{|sch| print_additional_properties(sch.additionalProperties)}

        # print_additional_properties(k.additionalProperties)
        # puts v[:hoo_inputs]
      end
    end
  end


  def test_space_hours_of_operation
    puts "\n######\nTEST:#{__method__}\n######\n"
    OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Warn)

    run_dir = "#{@test_dir}/space_hours_of_operation"
    # puts @model.getSpaces.size

    # create geometry
    args = {
      climate_zone: 'ASHRAE 169-2013-5B',
      # bldg_type: 'FullServiceRestaurant',
      bldg_type: 'SecondarySchool',
      flr_area: 150000,
      wwr: 0.38,
      aspect_ratio: 3,
      template: 'ComStock DOE Ref 1980-2004'
    }
    create_bar(args)

    # simulation settings
    simulation_settings()

    # weather file
    weather_file_name = "USA_ID_Boise.Air.Terminal.726810_TMY3.epw"
    change_location(weather_file_name)

    assert(@model)

    template = 'ComStock DOE Ref 1980-2004'
    climate_zone = 'ASHRAE 169-2013-5B'

    orig_dir = Dir.pwd
    Dir.chdir(File.join((__dir__), '/output'))

    # create typical without parametric schedules, or hvac
    OpenstudioStandards::CreateTypical.create_typical_building_from_model(@model,
                                                                         template,
                                                                         climate_zone: climate_zone,
                                                                         hvac_system_type: "VAV chiller with gas boiler reheat",
                                                                         hvac_delivery_type: "Inferred",
                                                                         heating_fuel: "Inferred",
                                                                         service_water_heating_fuel: "Inferred",
                                                                         cooling_fuel: "Inferred",
                                                                         modify_wkdy_op_hrs: false,
                                                                         modify_wknd_op_hrs: false,
                                                                         add_hvac: false,
                                                                         add_elevators: false
                                                                         )

    Dir.chdir(orig_dir)



    @schedules.model_infer_hours_of_operation_building(@model)

    space_type = @model.getSpaceTypes.first
    hours_of_operation = @spaces.space_hours_of_operation(space_type)
    # puts space_type
    # check lights
    # light = space_type.lights.first
    # puts light
    # parametric_inputs = @spaces.gather_inputs_parametric_load_inst_schedules(light, {}, hours_of_operation, false)

    # check equipment
    equipment = space_type.electricEquipment.first
    parametric_inputs = @spaces.gather_inputs_parametric_load_inst_schedules(equipment, {}, hours_of_operation, false)
    # all internal loads
    # parametric_inputs = @schedules.gather_inputs_parametric_space_space_type_schedules([space_type], {}, false)

    # puts parametric_inputs

    # parametric_inputs = @schedules.model_setup_parametric_schedules(@model, hoo_var_method:'hours')

    parametric_inputs.each do |k,v|
      puts k.name.get
      target = v[:target]
      puts target.name.get
      profiles = @schedules.schedule_ruleset_get_day_schedules(k)
      # print_additional_properties(k.additionalProperties)
      profiles.each{|sch| print_additional_properties(sch.additionalProperties)}

      print_additional_properties(k.additionalProperties)
      puts v[:hoo_inputs]
    end

    # require 'pp'
    # pp parametric_inputs
    # @schedules.gather_inputs_parametric_space_space_type_schedules(@model.getSpaces, {}, false)
    # all_hoos = {}
    # @model.getSpaces.each do |space|

    #   hours_of_operation_hash = @spaces.space_hours_of_operation(space)
    #   all_hoos[space.name.get] = hours_of_operation_hash
    # end

    # all_hoos.values.uniq.each do |val|
    #   all_hoos.keys.each{|k| if all_hoos[k] == val then puts k end}
    #   puts val
    # end

    # max = all_hoos.values.max_by{|i| all_hoos.values.count(i)}

    # puts max

    # osm_path = "#{run_dir}/#{args[:bldg_type]}_out.osm"
    # assert(@model.save(osm_path, true))
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

    orig_dir = Dir.pwd
    Dir.chdir(File.join((__dir__), '/output'))

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

    Dir.chdir(orig_dir)

    osm_path = "#{run_dir}/schedules_unmodified.osm"
    assert(@model.save(osm_path, true))
  end

  def skip_test_modify_specific_schedules
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

    orig_dir = Dir.pwd
    Dir.chdir(File.join((__dir__), '/output'))

    # create typical without parametric schedules, or hvac
    OpenstudioStandards::CreateTypical.create_typical_building_from_model(@model,
                                                                         template,
                                                                         climate_zone: climate_zone,
                                                                         hvac_system_type: "VAV chiller with gas boiler reheat",
                                                                         hvac_delivery_type: "Inferred",
                                                                         heating_fuel: "Inferred",
                                                                         service_water_heating_fuel: "Inferred",
                                                                         cooling_fuel: "Inferred",
                                                                         modify_wkdy_op_hrs: false,
                                                                         modify_wknd_op_hrs: false,
                                                                         add_hvac: false
                                                                         )

    Dir.chdir(orig_dir)

    osm_path = "#{run_dir}/create_typical_no_sch_mod_no_hvac.osm"
    assert(@model.save(osm_path, true))

    # Infer the current hours of operation schedule for the building
    op_sch = OpenstudioStandards::Schedules.model_infer_hours_of_operation_building(model)

    # OpenstudioStandards::Schedules.model_setup_parametric_schedules(model, hoo_var_method: hoo_var_method)
    @model.getThermalZones.sort.each do |zone|
    end

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

    orig_dir = Dir.pwd
    Dir.chdir(File.join((__dir__), '/output'))

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

    Dir.chdir(orig_dir)

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