require_relative '../../helpers/minitest_helper'

class TestCreateTypicalEnumerations < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical
  end

  def test_get_doe_building_types
    result = @create.get_doe_building_types
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)

    result = @create.get_doe_building_types(extended = true)
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)
  end

  def test_get_deer_building_types
    result = @create.get_deer_building_types
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)

    result = @create.get_deer_building_types(extended = true)
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)
  end

  def test_get_building_types
    result = @create.get_building_types
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)

    result = @create.get_building_types(extended = true)
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)
  end

  def test_get_doe_templates
    result = @create.get_doe_templates
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)

    result = @create.get_doe_templates(extended = true)
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)
  end

  def test_get_deer_templates
    result = @create.get_deer_templates
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)

    result = @create.get_deer_templates(extended = true)
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)
  end

  def test_get_templates
    result = @create.get_templates
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)

    result = @create.get_templates(extended = true)
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)
  end

  def test_get_doe_climate_zones
    result1 = @create.get_doe_climate_zones
    assert(result1.class.to_s == 'OpenStudio::StringVector')
    assert(!result1.empty?)

    result2 = @create.get_doe_climate_zones(extended = true)
    assert(result2.class.to_s == 'OpenStudio::StringVector')
    assert(!result2.empty?)

    result3 = @create.get_doe_climate_zones(extended = false, extra = 'ASHRAE 169-2013-0A')
    assert(result3.class.to_s == 'OpenStudio::StringVector')
    assert(!result3.empty?)
    assert(result1.size + 1 == result3.size)
  end

  def test_get_deer_climate_zones
    result = @create.get_deer_climate_zones
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)

    result = @create.get_deer_climate_zones(extended = true)
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)
  end

  def test_get_climate_zones
    result = @create.get_climate_zones
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)

    result = @create.get_climate_zones(extended = true)
    assert(result.class.to_s == 'OpenStudio::StringVector')
    assert(!result.empty?)
  end

  def test_deer_building_type_to_long
    result = @create.deer_building_type_to_long('MLI')
    assert(result == 'Manufacturing Light Industrial')

    result = @create.deer_building_type_to_long('RtL')
    assert(result == 'Retail - Single-Story Large')
  end

  def test_deer_hvac_system_to_long
    result = @create.deer_hvac_system_to_long('NCEH')
    assert(result == 'No Cooling with Electric Heat')

    result = @create.deer_hvac_system_to_long('SVVE')
    assert(result == 'Built-Up VAV System with Electric Reheat')
  end

  def test_deer_building_type_to_hvac_systems
    result = @create.deer_building_type_to_hvac_systems('Asm')
    assert(result == ['DXEH', 'DXGF', 'DXHP', 'NCEH', 'NCGF'])

    result = @create.deer_building_type_to_hvac_systems('RtS')
    assert(result == ['DXEH', 'DXGF', 'DXHP', 'NCEH', 'NCGF'])
  end

  def test_deer_template_to_age_range
    result = @create.deer_template_to_age_range('DEER Pre-1975')
    assert(result == 'Before 1978')

    result = @create.deer_template_to_age_range('DEER 2017')
    assert(result == '2017 or Later')
  end
end