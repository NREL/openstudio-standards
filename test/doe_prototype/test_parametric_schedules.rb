require_relative '../helpers/minitest_helper'

class TestParametricSchedules < Minitest::Test

  # inputs for tests to be run
  def input_hash
    # todo - fix school, office with multipliers, and warehouse
    test_hash = {}
    test_hash["MediumOffice_8A_2004"] = {template: '90.1-2004'}
=begin
    test_hash["SecondarySchool_6A_1980-2004"] = {template: 'DOE Ref 1980-2004'}
    # custom used to exercise mid day dip and see if clean hours of operation come out
    test_hash["example_model_multipliers"] = {template: '90.1-2013', fraction_of_daily_occ_range: 0.75} # office building
    test_hash["SmallHotel_5B_2004"] = {template: '90.1-2004'}
    test_hash["LargeHotel_3A_2010"] = {template: '90.1-2010'}
    test_hash["MidriseApartment_2A_2013,inverted"] = {template: '90.1-2013'}
    test_hash["MidriseApartment_2A_2013,not_inverted"] = {template: '90.1-2013',inver_res: false}
    test_hash["Hospital_4B_Pre1980"] = {template: 'DOE Ref Pre-1980'}
    test_hash["Outpatient_7A_2010"] = {template: '90.1-2010'}
    test_hash["MultiStoryRetail"] = {template: 'DOE Ref 1980-2004'}
    test_hash["MultiStoryWarehouse"] = {template: 'DOE Ref 1980-2004'}
=end

    return test_hash
  end

  def test_parametric_schedules_secondary

    # variables for CSV files
    schedule_csv_rows = []
    rule_csv_rows = []

    input_hash.each do |k,v|

      # Load the test model
      test_suffix = k.split(",").last
      k = k.split(",").first
      translator = OpenStudio::OSVersion::VersionTranslator.new
      path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/#{k}.osm")
      model = translator.loadModel(path)
      model = model.get
      puts "Test: Loaded #{k}_#{test_suffix}.osm for parametric schedule testing."

      # load standards
      template = v[:template]
      standard = Standard.build(template)

      # find and create hours of operation
      if v.has_key?(:fraction_of_daily_occ_range)
        hours_of_operation = standard.model_infer_hours_of_operation_building(model,gen_occ_profile: true,fraction_of_daily_occ_range: v[:fraction_of_daily_occ_range])
      elsif v.has_key?(:inver_res)
        hours_of_operation = standard.model_infer_hours_of_operation_building(model,gen_occ_profile: true,invert_res: v[:inver_res])
      else
        hours_of_operation = standard.model_infer_hours_of_operation_building(model,gen_occ_profile: true)
      end
      assert(hours_of_operation.to_ScheduleRuleset.is_initialized)
      puts "Test: Created building hours of operation schedule named #{hours_of_operation.name}."

      # report back hours of operation
      hours_of_operation_hash = standard.space_hours_of_operation(model.getSpaces.first)
      assert(hours_of_operation_hash.size > 0)
      puts "Test: Extracted hours of operation schedule from space."
      puts "Test: #{hours_of_operation_hash.keys.first}: #{hours_of_operation_hash.values.inspect}"

      # model_setup_parametric_schedules
      parametric_inputs = standard.model_setup_parametric_schedules(model,gather_data_only: false)
      assert(parametric_inputs.size > 0)
      puts "Test: Generated schedule profile formulas and saved as AdditionalProperties objects for #{parametric_inputs.size} schedules. Inspecting first entry returned."
      #puts "Test: #{parametric_inputs.keys.first.name}: #{parametric_inputs.values.first.inspect}"

      # store original areas as has, add to CSV for altered schedules
      orig_sch_hash = {}
      model.getScheduleRulesets.each do |schedule|
        orig_sch_hash[schedule] = standard.schedule_ruleset_annual_equivalent_full_load_hrs(schedule)
      end
      orig_sch_day_hash = {}
      model.getScheduleDays.each do |sch_day|
        orig_sch_day_hash[sch_day] = standard.day_schedule_equivalent_full_load_hrs(sch_day)
      end

      # todo - add in test code to change hours of operation for just one vs. the entire model. Make sure has unique days and hours


=begin
      # todo - temp code to chane hours of operation.
      default_sch = hours_of_operation.defaultDaySchedule
      default_sch.clearValues
      # office hoo_start is 8 hoo_end is 18
      os_time = OpenStudio::Time.new(0, 5, 30, 0) # day, hour, min, sec
      default_sch.addValue(os_time,1)
      os_time = OpenStudio::Time.new(0, 19, 30, 0) # day, hour, min, sec
      default_sch.addValue(os_time,0)
      os_time = OpenStudio::Time.new(0, 24, 0, 0) # day, hour, min, sec
      default_sch.addValue(os_time,1)
=end


=begin
      # todo - temp code to change profile shape for occupancy schedule
      target_name = "OfficeMedium BLDG_OCC_SCH Default"
      model.getScheduleDays.each do |sch_day|
        next if sch_day.name.get.to_s != target_name

        model.getAdditionalPropertiess.each do |prop|
          next if prop.modelObject != sch_day

          #formula = "hoo_start - 7.0 ~ 0.0 | hoo_start - 2.5 ~ 0.0 | hoo_start - 1.5 ~ 0.1 | hoo_start - 0.5 ~ 0.2 | hoo_start + 0.5 ~ 0.95 | mid - 1.5 ~ 0.95 | mid - 0.5 ~ 0.5 | mid + 0.5 ~ 0.95 | hoo_end - 1.5 ~ 0.95 | hoo_end - 0.5 ~ 0.3 | hoo_end + 0.5 ~ 0.1 | hoo_end + 3.0 ~ 0.1 | hoo_end + 5.0 ~ 0.05"
          formula = "hoo_start - 7.0 ~ 0.0 | hoo_start - 2.5 ~ 0.0 | hoo_start - 1.5 ~ 0.1 | hoo_start - 0.5 ~ 0.2 | hoo_start + 0.5 ~ 0.85 | hoo_start + 1.5 ~ 0.95| hoo_start + 3 ~ 0.95 | hoo_end - 3 ~ 0.85| hoo_end - 1.5 ~ 0.6 | hoo_end - 0.5 ~ 0.3 | hoo_end + 0.5 ~ 0.2 | hoo_end + 3.0 ~ 0.1 | hoo_end + 5.0 ~ 0.05"

          prop.setFeature("param_day_profile",formula)
        end
      end
=end

      # model_build_parametric_schedules
      parametric_schedules = standard.model_apply_parametric_schedules(model)
      assert(parametric_schedules.size > 0)
      puts "Test: Updated #{parametric_schedules.size} parametric schedules"

      # save resulting model
      puts "Test: Saving model named test_#{k}.osm."
      Dir.mkdir('output') unless Dir.exist?('output') # assuming test run from directory it is in
      model.save("output/test_#{k}.osm", true)

      # loop through parametric schedules and add asserts to compare against orig
      parametric_schedules.each do |k2,v2|
        orig_hours = orig_sch_hash[k2]
        final_hours = standard.schedule_ruleset_annual_equivalent_full_load_hrs(k2)
        delta_hours = orig_hours - final_hours
        percent_change = 100 * delta_hours/orig_hours
        schedule_csv_rows << [k, k2.name.get.to_s, orig_hours, final_hours,delta_hours,percent_change]
      end
      puts "Test: Saved schedule input analysis csv"

      # todo - run simulations and look at end uses.

    end

    # write out csv file for schedules
    require 'csv'
    CSV.open("output/sch_ann_equiv_hours.csv", "w") do |csv|
      csv << ["model_name","schedule_name", "orig_annual_hours", "final-annual_hours","delta_hours","percent_change"]
      schedule_csv_rows.each do |row|
        csv << row
      end
    end
    puts "saving sch_ann_equiv_hours.csv"

  end
end
