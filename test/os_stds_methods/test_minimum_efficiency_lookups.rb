require_relative '../helpers/minitest_helper'

class TestSpaceType < Minitest::Test
    def test_water_heater_efficiency_lookup
        std = Standard.build('90.1-2019')
        volume_gal = 10.0
        capacity_btu_per_hr = 20_472
        water_heater_mixed = nil
        fuel_type = 'Electricity'
        wh_props = std.water_heater_mixed_get_efficiency_requirement(water_heater_mixed, fuel_type, capacity_btu_per_hr, volume_gal)
        assert wh_props == {}

        volume_gal = 19.9
        capacity_btu_per_hr = 20_472
        water_heater_mixed = nil
        fuel_type = 'NaturalGas'
        wh_props = std.water_heater_mixed_get_efficiency_requirement(water_heater_mixed, fuel_type, capacity_btu_per_hr, volume_gal)
        assert wh_props['uniform_energy_factor_base'] == 0.6483
        assert wh_props['uniform_energy_factor_volume_allowance'] == 0.0017

        volume_gal = 19.9
        capacity_btu_per_hr = 135_000
        water_heater_mixed = nil
        fuel_type = 'Oil'
        wh_props = std.water_heater_mixed_get_efficiency_requirement(water_heater_mixed, fuel_type, capacity_btu_per_hr, volume_gal)
        assert wh_props['uniform_energy_factor_base'] == 0.6194
        assert wh_props['uniform_energy_factor_volume_allowance'] == 0.0016

        volume_gal = 19.9
        capacity_btu_per_hr = 150_000
        water_heater_mixed = nil
        fuel_type = 'NaturalGas'
        wh_props = std.water_heater_mixed_get_efficiency_requirement(water_heater_mixed, fuel_type, capacity_btu_per_hr, volume_gal)
        assert wh_props['thermal_efficiency'] == 0.80
    end
end