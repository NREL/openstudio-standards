require_relative 'minitest_helper'

class TestSecondarySchool < CreateDOEPrototypeBuildingTest
  def test_case

    bldg_types = ['SecondarySchool']
    templates = ['DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010']
    climate_zones = ['ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A','ASHRAE 169-2006-2B',
                      'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A',
                      'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C', 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-5B',
                      'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A', 'ASHRAE 169-2006-8A']
    all_failures = []

    # Create the models
    #all_failures += create_models(bldg_types, templates, climate_zones)

    # Run the models
    #all_failures += run_models(bldg_types, templates, climate_zones)

    # Compare the results to the legacy idf results
    #all_failures += compare_results(bldg_types, templates, climate_zones)

    # Assert if there are any errors
    puts "There were #{all_failures.size} failures"
    assert(all_failures.size == 0, "FAILURES: #{all_failures.join("\n")}")
  end
end

