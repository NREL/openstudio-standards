require_relative '../helpers/minitest_helper'

class TestParametricSchedules < Minitest::Test

  # todo - enable other tests. May be able to have single test and loop through hash of inputs. In the end I will compare prototype or starting model to parametric model

  def no_test_parametric_schedules_office

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/example_model_multipliers.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2013'
    standard = Standard.build(template)

  end

  def no_test_parametric_schedules_small_hotel

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/SmallHotel_5B_2004.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2004'
    standard = Standard.build(template)

  end

  def no_test_parametric_schedules_large_hotel

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/LargeHotel_3A_2010.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2010'
    standard = Standard.build(template)

  end

  def no_test_parametric_schedules_midrise

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MidriseApartment_2A_2013.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2013'
    standard = Standard.build(template)

  end

  def no_test_parametric_schedules_hospital

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/Hospital_4B_Pre1980.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref Pre-1980'
    standard = Standard.build(template)

  end

  def no_test_parametric_schedules_outpatient

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/Outpatient_7A_2010.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2010'
    standard = Standard.build(template)

  end

  def test_parametric_schedules_secondary

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/SecondarySchool_6A_1980-2004.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'
    standard = Standard.build(template)

    # find hours of operation
    hours_of_operation = standard.model_infer_hours_of_operation_building(model,gen_occ_profile: true)

    puts "Created a schedule named #{hours_of_operation.name}"
    puts hours_of_operation
    puts hours_of_operation.scheduleRules.last.daySchedule # default profile doesn't reflect hours of operation, last rule will be a monday?
    model.save("parametric_sch_test.osm", true)

    # todo - model_setup_parametric_schedules

    # todo - model_build_parametric_schedules

    # check recommendation
    # todo - loop through all schedules in orig model and store hash of schedule_ruleset_annual_equivalent_full_load_hrs
    # todo - loop through parametric schedules and add asserts to compare against orig

  end

  def no_test_parametric_schedules_multi_story_retail

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryRetail.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'
    standard = Standard.build(template)

  end

  def no_test_parametric_schedules_multi_story_warehouse

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryWarehouse.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'
    standard = Standard.build(template)

  end

end
