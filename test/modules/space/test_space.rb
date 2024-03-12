require_relative '../../helpers/minitest_helper'

class TestSpace < Minitest::Test
  def setup
    @space = OpenstudioStandards::Space
    @sch = OpenstudioStandards::Schedules
  end

  def test_space_plenum?
    model = OpenStudio::Model::Model.new
    space = OpenStudio::Model::Space.new(model)
    space.setName('some space')
    space.setPartofTotalFloorArea(false)
    assert_equal(@space.space_plenum?(space), true)

    space.setPartofTotalFloorArea(true)
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setName('Plenum')
    space.setSpaceType(space_type)
    assert_equal(@space.space_plenum?(space), true)
  end

  def test_space_residential?
    model = OpenStudio::Model::Model.new
    # from plenum
    polygon = OpenStudio::Point3dVector.new
    origin = OpenStudio::Point3d.new(0.0, 0.0, 0.0)
    polygon << origin
    polygon << origin + OpenStudio::Vector3d.new(0.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 0.0, 0.0)
    space1 = OpenStudio::Model::Space.fromFloorPrint(polygon, 3.0, model).get

    # from space type
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setName('Apartment Space Type')
    space1.setSpaceType(space_type)
    assert_equal(@space.space_residential?(space1), true)

    # plenum from below space
    polygon = OpenStudio::Point3dVector.new
    origin = OpenStudio::Point3d.new(0.0, 0.0, 3.0)
    polygon << origin
    polygon << origin + OpenStudio::Vector3d.new(0.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 0.0, 0.0)
    space2 = OpenStudio::Model::Space.fromFloorPrint(polygon, 1.0, model).get
    space2.setPartofTotalFloorArea(false)
    space1.matchSurfaces(space2)
    assert_equal(@space.space_residential?(space2), true)
  end

  def test_space_hours_of_operation
    model = OpenStudio::Model::Model.new
    model.getYearDescription.setCalendarYear(2018)
    space = OpenStudio::Model::Space.new(model)
    wkdy_start_time = OpenStudio::Time.new(0,8,0,0)
    wkdy_end_time = OpenStudio::Time.new(0,20,0,0)
    wknd_start_time = OpenStudio::Time.new(0,10,0,0)
    wknd_end_time = OpenStudio::Time.new(0,14,0,0)
    hours_of_operation_schedule = OpenStudio::Model::ScheduleRuleset.new(model)
    wknd_rule = OpenStudio::Model::ScheduleRule.new(hours_of_operation_schedule)
    wknd_rule.setApplyWeekends(true)
    @sch.schedule_ruleset_set_hours_of_operation(hours_of_operation_schedule,
                                                 wkdy_start_time: wkdy_start_time,
                                                 wkdy_end_time: wkdy_end_time,
                                                 sat_start_time: wknd_start_time,
                                                 sat_end_time: wknd_end_time,
                                                 sun_start_time: wknd_start_time,
                                                 sun_end_time: wknd_end_time)
    default_schedule_set = OpenStudio::Model::DefaultScheduleSet.new(model)
    default_schedule_set.setHoursofOperationSchedule(hours_of_operation_schedule)
    space.setDefaultScheduleSet(default_schedule_set)
    hoo_hash = @space.space_hours_of_operation(space)
    puts hoo_hash
    assert_equal(hoo_hash[-1][:hoo_start], 8)
    assert_equal(hoo_hash[-1][:hoo_end], 20)
    assert_equal(hoo_hash[-1][:hoo_hours], 20-8)
    assert_equal(hoo_hash[-1][:days_used].size, 261)
    assert_equal(hoo_hash[0][:hoo_start], 10)
    assert_equal(hoo_hash[0][:hoo_end], 14)
    assert_equal(hoo_hash[0][:hoo_hours], 14-10)
    assert_equal(hoo_hash[0][:days_used].size, 104)
  end

  def test_spaces_get_occupancy_schedule
    OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Error)
    model = OpenStudio::Model::Model.new
    model.getYearDescription.setCalendarYear(2018)

    space1 = OpenStudio::Model::Space.new(model)

    # people at space type
    sch1_opts = {
      'name' => 'People Schedule 1',
      'default_time_value_pairs' => { 8.0 => 0, 16.0 => 1.0, 24.0 => 0}
    }
    ppl_sch1 = @sch.create_simple_schedule(model, sch1_opts)
    default_schedule_set = OpenStudio::Model::DefaultScheduleSet.new(model)
    default_schedule_set.setNumberofPeopleSchedule(ppl_sch1)
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setDefaultScheduleSet(default_schedule_set)
    ppl_def1 = OpenStudio::Model::PeopleDefinition.new(model)
    ppl_def1.setNumberofPeople(10)
    ppl1 = OpenStudio::Model::People.new(ppl_def1)
    ppl1.setSpaceType(space_type)
    space1.setSpaceType(space_type)

    polygon = OpenStudio::Point3dVector.new
    origin = OpenStudio::Point3d.new(0.0, 5.0, 0.0)
    polygon << origin
    polygon << origin + OpenStudio::Vector3d.new(0.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 0.0, 0.0)
    space2 = OpenStudio::Model::Space.fromFloorPrint(polygon, 1.0, model).get

    # people at space
    sch2_opts = {
      'name' => 'People Schedule 2',
      'default_day' => ['default', [6.0, 0.2], [12.0, 0.4], [18.0, 0.8], [22.0, 0.2]],
      'rules' => [['weekends', '1/1-12/31', 'Sat/Sun',  [24.0, 0]]]
    }
    ppl_sch2 = @sch.create_complex_schedule(model, sch2_opts)
    ppl_def2 = OpenStudio::Model::PeopleDefinition.new(model)
    ppl_def2.setPeopleperSpaceFloorArea(1.0)
    ppl2 = OpenStudio::Model::People.new(ppl_def2)
    ppl2.setNumberofPeopleSchedule(ppl_sch2)
    ppl2.setSpace(space2)

    # people at space
    sch3_opts = {
      'name' => 'People Schedule 3',
      'default_day' => ['default', [24.0, 0]],
      'rules' => [['summer', '6/1-8/31', 'Mon/Tue/Wed/Thu/Fri',  [10.0, 0], [16.0, 1.0], [20.0, 0.3], [24.0, 0]]]
    }
    ppl_sch3 = @sch.create_complex_schedule(model, sch3_opts)
    # puts OpenStudio::Model.getRecursiveChildren(ppl_sch3)
    ppl_def3 = OpenStudio::Model::PeopleDefinition.new(model)
    ppl_def3.setNumberofPeople(5.0)
    ppl3 = OpenStudio::Model::People.new(ppl_def3)
    ppl3.setNumberofPeopleSchedule(ppl_sch3)
    ppl3.setSpace(space2)

    # fractional values
    occ_sch_fracs = @space.spaces_get_occupancy_schedule([space1,space2], sch_name: 'test occupancy frac', occupied_percentage_threshold: nil, threshold_calc_method: nil)
    puts "Fractional Values: #{occ_sch_fracs.scheduleRules.size} Schedule Rules"

    spring_wkdy = occ_sch_fracs.getDaySchedules(OpenStudio::Date.new('2018-Apr-10'),OpenStudio::Date.new('2018-Apr-10')).first
    spring_wkdy_hrly_vals = @sch.schedule_day_get_hourly_values(spring_wkdy)
    assert_equal(spring_wkdy_hrly_vals.index(0.25), 6)
    assert_equal(spring_wkdy_hrly_vals.index(0.5), 8)
    assert_equal(spring_wkdy_hrly_vals.rindex(0.5), 17)
    assert_equal(spring_wkdy_hrly_vals.index(0.75), 12)
    assert_equal(spring_wkdy_hrly_vals.rindex(0.75), 15)
    assert_equal(spring_wkdy_hrly_vals.rindex(0.125), 21)

    spring_wknd = occ_sch_fracs.getDaySchedules(OpenStudio::Date.new('2018-Apr-14'),OpenStudio::Date.new('2018-Apr-14')).first
    spring_wknd_hrly_vals = @sch.schedule_day_get_hourly_values(spring_wknd)
    assert_equal(spring_wknd_hrly_vals.index(0.25), 8)
    assert_equal(spring_wknd_hrly_vals.rindex(0.25), 15)

    summer_wkdy = occ_sch_fracs.getDaySchedules(OpenStudio::Date.new('2018-Jul-23'),OpenStudio::Date.new('2018-Jul-23')).first
    summer_wkdy_hrly_vals = @sch.schedule_day_get_hourly_values(summer_wkdy)
    assert_equal(summer_wkdy_hrly_vals.index(0.25), 6)
    assert_equal(summer_wkdy_hrly_vals.index(0.5), 8)
    assert_equal(summer_wkdy_hrly_vals.rindex(0.625), 11)
    assert_equal(summer_wkdy_hrly_vals.index(0.875), 12)
    assert_equal(summer_wkdy_hrly_vals.rindex(0.875), 15)
    assert_equal(summer_wkdy_hrly_vals.rindex(0.538), 17)
    assert_equal(summer_wkdy_hrly_vals.rindex(0.163), 19)

    assert_in_delta(@sch.schedule_ruleset_get_equivalent_full_load_hours(occ_sch_fracs), 2290.28, 0.01)

    # not normalized
    occ_sch_values = @space.spaces_get_occupancy_schedule([space1,space2], sch_name: 'test occupancy threshold', occupied_percentage_threshold: 0.3, threshold_calc_method: nil)
    puts "Un-normalized: #{occ_sch_values.scheduleRules.size} Schedule Rules"

    spring_wkdy = occ_sch_values.getDaySchedules(OpenStudio::Date.new('2018-Apr-10'),OpenStudio::Date.new('2018-Apr-10')).first
    spring_wkdy_hrly_vals = @sch.schedule_day_get_hourly_values(spring_wkdy)
    assert_equal(spring_wkdy_hrly_vals.index(1.0), 8)
    assert_equal(spring_wkdy_hrly_vals.rindex(1.0), 17)

    spring_wknd = occ_sch_values.getDaySchedules(OpenStudio::Date.new('2018-Apr-14'),OpenStudio::Date.new('2018-Apr-14')).first
    spring_wknd_hrly_vals = @sch.schedule_day_get_hourly_values(spring_wknd)
    assert_nil(spring_wknd_hrly_vals.index(1.0))

    summer_wkdy = occ_sch_values.getDaySchedules(OpenStudio::Date.new('2018-Jul-23'),OpenStudio::Date.new('2018-Jul-23')).first
    summer_wkdy_hrly_vals = @sch.schedule_day_get_hourly_values(summer_wkdy)
    assert_equal(summer_wkdy_hrly_vals.index(1.0), 8)
    assert_equal(summer_wkdy_hrly_vals.rindex(1.0), 17)

    assert_equal(@sch.schedule_ruleset_get_equivalent_full_load_hours(occ_sch_values), 2610)

    # normalized daily
    occ_sch_daily = @space.spaces_get_occupancy_schedule([space1,space2], sch_name: 'test occupancy daily', occupied_percentage_threshold: 0.3, threshold_calc_method: 'normalized_daily_range')
    puts "Normalized Daily: #{occ_sch_daily.scheduleRules.size} Schedule Rules"

    spring_wkdy = occ_sch_daily.getDaySchedules(OpenStudio::Date.new('2018-Apr-10'),OpenStudio::Date.new('2018-Apr-10')).first
    spring_wkdy_hrly_vals = @sch.schedule_day_get_hourly_values(spring_wkdy)
    assert_equal(spring_wkdy_hrly_vals.index(1.0), 6)
    assert_equal(spring_wkdy_hrly_vals.rindex(1.0), 17)

    spring_wknd = occ_sch_daily.getDaySchedules(OpenStudio::Date.new('2018-Apr-14'),OpenStudio::Date.new('2018-Apr-14')).first
    spring_wknd_hrly_vals = @sch.schedule_day_get_hourly_values(spring_wknd)
    assert_equal(spring_wknd_hrly_vals.index(1.0), 8)
    assert_equal(spring_wknd_hrly_vals.rindex(1.0), 15)

    summer_wkdy = occ_sch_daily.getDaySchedules(OpenStudio::Date.new('2018-Jul-23'),OpenStudio::Date.new('2018-Jul-23')).first
    summer_wkdy_hrly_vals = @sch.schedule_day_get_hourly_values(summer_wkdy)
    assert_equal(summer_wkdy_hrly_vals.index(1.0), 8)
    assert_equal(summer_wkdy_hrly_vals.rindex(1.0), 17)

    assert_equal(@sch.schedule_ruleset_get_equivalent_full_load_hours(occ_sch_daily), 3832)

    # normalized annually
    occ_sch_annual = @space.spaces_get_occupancy_schedule([space1,space2], sch_name: 'test occupancy annual', occupied_percentage_threshold: 0.3, threshold_calc_method: 'normalized_annual_range')
    puts "Normalized Annually: #{occ_sch_annual.scheduleRules.size} Schedule Rules"

    spring_wkdy = occ_sch_annual.getDaySchedules(OpenStudio::Date.new('2018-Apr-10'),OpenStudio::Date.new('2018-Apr-10')).first
    spring_wkdy_hrly_vals = @sch.schedule_day_get_hourly_values(spring_wkdy)
    assert_equal(spring_wkdy_hrly_vals.index(1.0), 8)
    assert_equal(spring_wkdy_hrly_vals.rindex(1.0), 17)

    spring_wknd = occ_sch_annual.getDaySchedules(OpenStudio::Date.new('2018-Apr-14'),OpenStudio::Date.new('2018-Apr-14')).first
    spring_wknd_hrly_vals = @sch.schedule_day_get_hourly_values(spring_wknd)
    assert_nil(spring_wknd_hrly_vals.index(1.0))

    summer_wkdy = occ_sch_annual.getDaySchedules(OpenStudio::Date.new('2018-Jul-23'),OpenStudio::Date.new('2018-Jul-23')).first
    summer_wkdy_hrly_vals = @sch.schedule_day_get_hourly_values(summer_wkdy)
    assert_equal(summer_wkdy_hrly_vals.index(1.0), 8)
    assert_equal(summer_wkdy_hrly_vals.rindex(1.0), 17)

    assert_equal(@sch.schedule_ruleset_get_equivalent_full_load_hours(occ_sch_annual), 2610)
  end
end
