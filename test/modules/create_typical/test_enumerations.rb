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
end