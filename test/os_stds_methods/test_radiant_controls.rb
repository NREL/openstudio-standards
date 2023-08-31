require_relative '../helpers/minitest_helper'
require_relative '../helpers/hvac_system_test_helper'

class TestRadiantControls < Minitest::Test
  def test_default_radiant_controls
    arguments = {model_test_name: 'default_radiant', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       unmet_hrs_htg: 600.0, unmet_hrs_clg: 2750.0}

    test_return = model_radiant_system_test(arguments)
    errs = test_return['errs']
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end

  def test_default_radiant_ceiling
    arguments = {model_test_name: 'default_radiant_ceiling', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       radiant_type: 'ceiling', unmet_hrs_htg: 500.0, unmet_hrs_clg: 1500.0}

    test_return = model_radiant_system_test(arguments)
    errs = test_return['errs']
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end

  def test_whole_building_hours
    arguments = {model_test_name: 'whole_building_hours', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       radiant_type: 'ceiling', use_zone_occupancy_for_control: false, unmet_hrs_htg: 500.0, unmet_hrs_clg: 2500.0}

    test_return = model_radiant_system_test(arguments)
    errs = test_return['errs']
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end

  def test_radiant_precool_hours_schedule
    arguments = {model_test_name: 'test_radiant_precool_hours_schedule', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       radiant_type: 'ceiling', use_zone_occupancy_for_control: false, radiant_availability_type: 'precool',
       custom_variables_output: [['Zone Radiant HVAC Heating Rate', '*', 'Hourly'], ['Zone Radiant HVAC Cooling Rate', '*', 'Hourly']],
       unmet_hrs_htg: 500.0, unmet_hrs_clg: 1500.0}

    standard = Standard.build('90.1-2013')

    test_return = model_radiant_system_test(arguments)
    model = test_return['model']
    errs = test_return['errs']

    # radiant lockout hours for precool operation
    radiant_lockout_start_time = 10.0
    radiant_lockout_end_time = 22.0

    start_hour = radiant_lockout_start_time.to_i
    start_minute = ((radiant_lockout_start_time % 1) * 60).to_i
    end_hour = radiant_lockout_end_time.to_i
    end_minute = ((radiant_lockout_end_time % 1) * 60).to_i

    # get array of hours to test
    if end_hour > start_hour
      time_OFF = ((start_hour + 1)..end_hour).to_a
      time_ON = ((end_hour + 1)..24).to_a + ((1)..(start_hour)).to_a
    elsif start_hour > end_hour
      time_OFF = ((start_hour + 1)..24).to_a + (1..end_hour).to_a
      time_ON = ((end_hour + 1)..(start_hour)).to_a
    else
      time_OFF = []
      time_ON = (1..24).to_a
    end

    unless start_minute == 0
      time_OFF << start_hour + (start_minute + 1).fdiv(60)
    end

    unless end_minute == 0
      time_ON << end_hour + (end_minute + 1).fdiv(60)
    end

    # get availability schedule for all radiant loops
    control_errs = []
    radiant_loops = model.getZoneHVACLowTempRadiantVarFlows
    if radiant_loops.length == 0
      # check constant flow radiant loops
      radiant_loops = model.getZoneHVACLowTempRadiantConstFlows
    end

    # test each radiant loop schedule against each time ON/OFF array to verify
    # correct definition of object
    correct_schedule = []
    radiant_loops.each do |radiant_loop|
      availability_sch = radiant_loop.availabilitySchedule.to_ScheduleRuleset.get
      day_schedule = availability_sch.defaultDaySchedule

      # test radiant OFF operation
      time_OFF.each do |time|
        hour = time.to_i
        minute = ((time % 1) * 60).to_i

        test_time = OpenStudio::Time.new(0, hour, minute, 0)
        correct_schedule << (day_schedule.getValue(test_time) == 0)
      end

      # test radiant ON operation
      time_ON.each do |time|
        hour = time.to_i
        minute = ((time % 1) * 60).to_i

        test_time = OpenStudio::Time.new(0, hour, minute, 0)
        correct_schedule << (day_schedule.getValue(test_time) == 1)
      end
    end

    unless correct_schedule.all?
      control_errs << "Model #{arguments[:model_test_name]} has at least one incorrect availability schedule for radiant system in operation type #{arguments[:radiant_availability_type]}"
    end

    errs += control_errs
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end

end
