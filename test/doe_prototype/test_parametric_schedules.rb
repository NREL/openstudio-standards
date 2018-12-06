require_relative '../helpers/minitest_helper'

class TestParametricSchedules < Minitest::Test

  # inputs for tests to be run
  def input_hash
    test_hash = {}
    # custom used to exercise mid day dip and see if clean hours of operation come out
    test_hash["example_model_multipliers"] = {template: '90.1-2013', fraction_of_daily_occ_range: 0.75} # office building
    test_hash["SmallHotel_5B_2004"] = {template: '90.1-2004'}
    test_hash["LargeHotel_3A_2010"] = {template: '90.1-2010'}
    test_hash["MidriseApartment_2A_2013,inverted"] = {template: '90.1-2013'}
    test_hash["MidriseApartment_2A_2013,not_inverted"] = {template: '90.1-2013',inver_res: false}
    test_hash["Hospital_4B_Pre1980"] = {template: 'DOE Ref Pre-1980'}
    test_hash["Outpatient_7A_2010"] = {template: '90.1-2010'}
    test_hash["SecondarySchool_6A_1980-2004"] = {template: 'DOE Ref 1980-2004'}
    test_hash["MultiStoryRetail"] = {template: 'DOE Ref 1980-2004'}
    test_hash["MultiStoryWarehouse"] = {template: 'DOE Ref 1980-2004'}

    return test_hash
  end

  def test_parametric_schedules_secondary

    input_hash.each do |k,v|

      # Load the test model
      k = k.split(",").first
      translator = OpenStudio::OSVersion::VersionTranslator.new
      path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/#{k}.osm")
      model = translator.loadModel(path)
      model = model.get

      # create story hash
      template = v[:template]
      standard = Standard.build(template)

      # find hours of operation
      if v.has_key?(:fraction_of_daily_occ_range)
        hours_of_operation = standard.model_infer_hours_of_operation_building(model,gen_occ_profile: true,fraction_of_daily_occ_range: v[:fraction_of_daily_occ_range])
      elsif v.has_key?(:inver_res)
        hours_of_operation = standard.model_infer_hours_of_operation_building(model,gen_occ_profile: true,invert_res: v[:inver_res])
      else
        hours_of_operation = standard.model_infer_hours_of_operation_building(model,gen_occ_profile: true)
      end
      assert(hours_of_operation.to_ScheduleRuleset.is_initialized)

      puts "Created a schedule named #{hours_of_operation.name} for #{k}.osm"
      model.save("test_#{k}.osm", true)

      # inspect hours of operation
      hours_of_operation = standard.space_hours_of_operation(model.getSpaces.first)
      hours_of_operation.each do |k,v|
        puts "#{k}: #{v.inspect}"
      end

      # todo - model_setup_parametric_schedules

      # todo - model_build_parametric_schedules

      # check recommendation
      # todo - loop through all schedules in orig model and store hash of schedule_ruleset_annual_equivalent_full_load_hrs
      # todo - loop through parametric schedules and add asserts to compare against orig

    end
  end

end
