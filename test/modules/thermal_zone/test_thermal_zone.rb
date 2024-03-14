require_relative '../../helpers/minitest_helper'

class TestSpace < Minitest::Test
  def setup
    @zone = OpenstudioStandards::ThermalZone
    @sch = OpenstudioStandards::Schedules
  end

  def test_thermal_zone_plenum?
    model = OpenStudio::Model::Model.new
    polygon = OpenStudio::Point3dVector.new
    origin = OpenStudio::Point3d.new(0.0, 0.0, 0.0)
    polygon << origin
    polygon << origin + OpenStudio::Vector3d.new(0.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 0.0, 0.0)
    space = OpenStudio::Model::Space.fromFloorPrint(polygon, 3.0, model).get
    space.setName('some space')
    thermal_zone = OpenStudio::Model::ThermalZone.new(model)
    space.setThermalZone(thermal_zone)
    assert_equal(false, @zone.thermal_zone_plenum?(thermal_zone))

    space.setPartofTotalFloorArea(false)
    assert_equal(true, @zone.thermal_zone_plenum?(thermal_zone))

    space.setPartofTotalFloorArea(true)
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setName('Plenum')
    space.setSpaceType(space_type)
    assert_equal(true, @zone.thermal_zone_plenum?(thermal_zone))
  end

  def test_thermal_zone_residential?
    model = OpenStudio::Model::Model.new
    # from plenum
    polygon = OpenStudio::Point3dVector.new
    origin = OpenStudio::Point3d.new(0.0, 0.0, 0.0)
    polygon << origin
    polygon << origin + OpenStudio::Vector3d.new(0.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 0.0, 0.0)
    space = OpenStudio::Model::Space.fromFloorPrint(polygon, 3.0, model).get
    thermal_zone = OpenStudio::Model::ThermalZone.new(model)
    space.setThermalZone(thermal_zone)

    # from space type
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setName('MidriseApartment Apartment')
    space.setSpaceType(space_type)
    assert_equal(true, @zone.thermal_zone_residential?(thermal_zone))

    apt_ofc = OpenStudio::Model::SpaceType.new(model)
    apt_ofc.setName('MidriseApartment Office')
    ofc = OpenStudio::Model::Space.new(model)
    ofc.setSpaceType(apt_ofc)
    ofc_thermal_zone = OpenStudio::Model::ThermalZone.new(model)
    ofc.setThermalZone(ofc_thermal_zone)
    assert_equal(false, @zone.thermal_zone_residential?(ofc_thermal_zone))
  end

  def test_thermal_zone_heated?
    model = OpenStudio::Model::Model.new
    polygon = OpenStudio::Point3dVector.new
    origin = OpenStudio::Point3d.new(0.0, 0.0, 0.0)
    polygon << origin
    polygon << origin + OpenStudio::Vector3d.new(0.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 0.0, 0.0)
    space = OpenStudio::Model::Space.fromFloorPrint(polygon, 3.0, model).get
    thermal_zone = OpenStudio::Model::ThermalZone.new(model)
    space.setThermalZone(thermal_zone)
    thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
    thermal_zone.setThermostatSetpointDualSetpoint(thermostat)
    htg_stpt_sch = @sch.create_constant_schedule_ruleset(model, 20.0,
                                                         name: 'Heating Setpoint Schedule',
                                                         schedule_type_limit: 'Temperature')
    clg_stpt_sch = @sch.create_constant_schedule_ruleset(model, 24.0,
                                                         name: 'Cooling Setpoint Schedule',
                                                         schedule_type_limit: 'Temperature')
    thermostat.setHeatingSetpointTemperatureSchedule(htg_stpt_sch)
    thermostat.setCoolingSetpointTemperatureSchedule(clg_stpt_sch)
    assert_equal(true, @zone.thermal_zone_heated?(thermal_zone))

    # test unconditioned (<41F)
    htg_stpt_sch = @sch.create_constant_schedule_ruleset(model, 4.0,
                                                         name: 'Unconditioned Heating Schedule',
                                                         schedule_type_limit: 'Temperature')
    thermostat.setHeatingSetpointTemperatureSchedule(htg_stpt_sch)
    assert_equal(false, @zone.thermal_zone_heated?(thermal_zone))
  end

  def test_thermal_zone_cooled?
    model = OpenStudio::Model::Model.new
    polygon = OpenStudio::Point3dVector.new
    origin = OpenStudio::Point3d.new(0.0, 0.0, 0.0)
    polygon << origin
    polygon << origin + OpenStudio::Vector3d.new(0.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 0.0, 0.0)
    space = OpenStudio::Model::Space.fromFloorPrint(polygon, 3.0, model).get
    thermal_zone = OpenStudio::Model::ThermalZone.new(model)
    space.setThermalZone(thermal_zone)
    thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
    thermal_zone.setThermostatSetpointDualSetpoint(thermostat)
    htg_stpt_sch = @sch.create_constant_schedule_ruleset(model, 20.0,
                                                         name: 'Heating Setpoint Schedule',
                                                         schedule_type_limit: 'Temperature')
    clg_stpt_sch = @sch.create_constant_schedule_ruleset(model, 24.0,
                                                         name: 'Cooling Setpoint Schedule',
                                                         schedule_type_limit: 'Temperature')
    thermostat.setHeatingSetpointTemperatureSchedule(htg_stpt_sch)
    thermostat.setCoolingSetpointTemperatureSchedule(clg_stpt_sch)
    assert_equal(true, @zone.thermal_zone_cooled?(thermal_zone))

    # test unconditioned (>91F)
    clg_stpt_sch = @sch.create_constant_schedule_ruleset(model, 35.0,
                                                         name: 'Unconditioned Cooling Schedule',
                                                         schedule_type_limit: 'Temperature')
    thermostat.setCoolingSetpointTemperatureSchedule(clg_stpt_sch)
    assert_equal(false, @zone.thermal_zone_cooled?(thermal_zone))
  end

  def test_thermal_zone_get_design_internal_load
    model = OpenStudio::Model::Model.new
    polygon = OpenStudio::Point3dVector.new
    origin = OpenStudio::Point3d.new(0.0, 0.0, 0.0)
    polygon << origin
    polygon << origin + OpenStudio::Vector3d.new(0.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 0.0, 0.0)
    space = OpenStudio::Model::Space.fromFloorPrint(polygon, 3.0, model).get
    thermal_zone = OpenStudio::Model::ThermalZone.new(model)
    space.setThermalZone(thermal_zone)
    assert_equal(0.0, @zone.thermal_zone_get_design_internal_load(thermal_zone))

    # create space type and set standards info
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setStandardsBuildingType('PrimarySchool')
    space_type.setStandardsSpaceType('Classroom')
    space.setSpaceType(space_type)

    # add loads
    std = Standard.build('90.1-2013')
    std.model_add_loads(model)
    assert_in_delta(708.67, @zone.thermal_zone_get_design_internal_load(thermal_zone), 0.1)
  end
end
