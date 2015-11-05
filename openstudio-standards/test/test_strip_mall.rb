require_relative 'minitest_helper'

class TestOpenstudioStandards < CreateDOEPrototypeBuildingTest
  def test_case
    # RetailStandalone, LargeHotel, RetailStripmall
    bldg_types = ['RetailStripmall']
    vintages = ['90.1-2013']
    climate_zones =['ASHRAE 169-2006-2A']
    all_failures = []

    # Create the models
    all_failures += create_models(bldg_types, vintages, climate_zones)

    # Run the models
    all_failures += run_models(bldg_types, vintages, climate_zones)

    # Compare the results to the legacy idf results
    all_failures += compare_results(bldg_types, vintages, climate_zones)

    # Assert if there are any errors
    puts "There were #{all_failures.size} failures"
    assert(all_failures.size == 0, "FAILURES: #{all_failures.join("\n")}")
  end
end