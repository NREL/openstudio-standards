# Additional methods for NECB tests
require 'fileutils'
require 'pathname'
require 'json'
require 'hashdiff'

# Add significant digits capability to float amd integer class to tidy up reporting.
class Float
  def signif(digits=4)
    return 0 if self.zero?
    return self if self < 0.0
    self.round(-(Math.log10(self).ceil - digits))
  end
end
class Integer
  def signif(digits=4)
    return 0 if self.zero?
    return self if self < 0
    self.round(-(Math.log10(self).ceil - digits)).to_i
  end
end

module NecbHelper
  # Hold an array of the instantiated standards (to save recreating them all the time).
  @@standards = []

  # Standard path definitions for NECB testing.
  def define_folders(file_folder)
    @test_folder = File.join(file_folder, '..')
    @root_folder = File.join(@test_folder, '../../..')
    @resources_folder = File.join(@test_folder, 'resources')
    @expected_results_folder = File.join(@test_folder, 'expected_results')
    @test_results_folder = @expected_results_folder
    @top_output_folder = "#{@test_folder}/output/"
  end

  def method_output_folder(name="")
    output_folder = File.join(@top_output_folder, self.class.ancestors[0].to_s.downcase, name.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    return output_folder
  end

  def define_std_ranges
    @Templates = ['NECB2011', 'NECB2015', 'NECB2017', 'BTAPPRE1980']
    @AllTemplates = ['NECB2011', 'NECB2015', 'NECB2017', 'NECB2020', 'BTAPPRE1980', 'BTAP1980TO2010']
    @AllBuildings = [
      'FullServiceRestaurant',
      'LargeHotel',
      'LargeOffice',
      'MediumOffice',
      'HighriseApartment',
      'MidriseApartment',
      'Outpatient',
      'PrimarySchool',
      'QuickServiceRestaurant',
      'RetailStandalone',
      'RetailStripmall',
      'SmallHotel',
      'SmallOffice',
      'Warehouse',
      'Hospital'
    ]
    @CommonBuildings = [
      'MediumOffice',
      'MidriseApartment',
      'RetailStandalone',
      'Warehouse',
    ]
  end

  # Utility function to help make an expected results hash.
  # Expects the last two entries in the hash to be TestCase and TestPars.
  def make_empty_expected_json(loop_hash)
    expected_results_template = Hash.new
    loop_hash.reverse_each do |loop_k, loop_v|
      if loop_k.to_s == "TestPars" then 
        loop_v.each {|key| expected_results_template[key.to_sym] = "tbd"}
      else
        temp = Hash.new
        temp["VarType".to_sym] = loop_k
        if loop_k.to_s == "TestCase" then temp["reference".to_sym] = "Add NECB reference here" end
        loop_v.each {|key| temp[key.to_sym] = expected_results_template}
        expected_results_template = temp.clone
      end
    end
    #puts "\nFINAL hash:\n#{JSON.pretty_generate(expected_results_template)}"
    return expected_results_template
  end
    

  # Method used to recursively parse the expected json to figure out the test cases and then run them
  # (adapted template design pattern).
  # The test_pars hash is used by the recursion to remember what condition is being tested in a nested hash. It already 
  # contains some of the test parameters.
  # Will call the method 'do_test_...' to do the work. This method is called from 'test_...'
  def parse_json_and_test(expected_results:, test_pars:)

    # Find the test cases. Do this with recursion but remember where we are in a new hash passed to the do_test method.
    # The nested hash is has essentially a set of loops (vintages, weather files, fuel types etc). As the recursion 
    # descends down through these keep track of which one is the current 'iterator'.
    # While doing this build up the test_results hash.
    iterator_name = expected_results[:VarType]
    test_results = Hash.new
    test_results[:VarType] = iterator_name
    puts "******* #{iterator_name} **********"

    # If at the 'TestCase' level then stop recursion and run the test defined in the current hash.
    if iterator_name == "TestCase"

      test_results[:reference] = expected_results[:reference]

      # This hash is the test case. The key is the short name (usually something like 'case-1', and its unique).
      # The value of the hash has the test specific inputs and the result.
      expected_results.each do |key, value|
        puts "$$$ #{key}"
        next if key == :VarType # This is less expensive than using the except method chained before the each.
        next if key == :reference # This is less expensive than using the except method chained before the each.
        #puts "Test case: #{test_pars}"
        #puts "Current test: #{value}"

        # Run this test case. By default call the do_testMethod method.
        method_name = "do_#{test_pars[:test_method]}"
        case_results = self.send(method_name, test_pars: test_pars, test_case: value)
        puts "######### Case reults"
        puts JSON.pretty_generate(case_results)
        test_results[key] = case_results
      end
    else

      # Recursively go through the variables defined in the json file and find the test cases.
      expected_results.each do |key, value|
        next if key == :VarType
        #puts "k,v: #{key}, #{value}"
        if value.is_a? Hash
          test_pars[iterator_name.to_sym] = key.to_s
          test_results[key] = parse_json_and_test(expected_results: value, test_pars: test_pars)
        end
      end
    end
    puts "Test Results #################"
    puts JSON.pretty_generate(test_results)
    return test_results
  end

  # Method to recover existing template (or create on if it has not been instantiated).
  def get_standard(template)
    standard = nil
    if @@standards.any? {|std| std.template == template}
      standard = @@standards.select{|std| std.template == template}.first
    else
      standard = Standard.build(template)
      @@standards << standard
    end
    puts "**** Using template: #{standard.class}"
    return standard
  end

  # Standard method to run sizing for NECB testing. Parameters:
  #   model - the model object to be operated on
  #   template - version of NECB to use
  #   test_name - unique name of this test (used to create folders for output)
  #   second_run - true if a second sizing run is required.
  #   necb_ref_hp = true if the caase is for the NECB reference model using heat pumps
  #   sql_db_vars_map - ???
  #   save_model_versions - logical to trigger saving of osm files before and after standards applied
  def run_sizing(model:, 
                 template: 'NECB2011', 
                 test_name:, 
                 second_run: false,
                 necb_ref_hp: false,
                 sql_db_vars_map: nil, 
                 save_model_versions: false)

    # Report what we are doing (helps when things go wrong!).
    puts "**** Running measure for test class: #{self.class.ancestors[0]}"
    puts "****   from method: #{caller_locations(1,1)[0].label}"
    puts "****   with scenario name: #{test_name}"
    puts "****   for template: #{template}"

    # Instantiate the required version of standards.
    standard = get_standard(template)

    # Define output folder.
    test_class_name = self.class.ancestors[0].to_s.downcase
    test_method_name = caller_locations.first.base_label
    output_dir = File.join(@top_output_folder, test_class_name, test_method_name, test_name)
    puts "****************** #{output_dir}"

    # Check output_dir exists, if not create.
    unless Dir.exist? output_dir
      FileUtils.mkdir_p(output_dir)
    end

    # Save model before sizing.
    BTAP::FileIO.save_osm(model, "#{output_dir}/pre-sizing.osm") if save_model_versions

    # Perform first sizing run.
    sizing_folder = "#{output_dir}/SR1"
    if standard.model_run_sizing_run(model, sizing_folder) == false
      puts "could not find sizing run #{sizing_folder}"
      assert(false, "Failure in sizing run wile running test: #{self.class.ancestors[0]}")
    else
      puts "found sizing run #{sizing_folder}"
    end

    # Apply HVAC assumptions for efficiency etc.
    # Ensure we're doing this for NECB.
    building_type = 'NECB'
    climate_zone = 'NECB'

    # Need to set prototype assumptions so that HRV added.
    standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)

    # Apply the HVAC efficiency standard.
    standard.model_apply_hvac_efficiency_standard(model, climate_zone, necb_ref_hp: necb_ref_hp)

    # Second sizing run (if requested).
    if second_run
      
      # Save model before sizing run 2.
      BTAP::FileIO.save_osm(model, "#{output_dir}/pre-sizing2.osm") if save_model_versions

      # Do another sizing run after applying the hvac assumptions and efficiency standards 
      #  to properly apply the pump rules.
      sizing_folder = "#{output_dir}/SR2"
      if standard.model_run_sizing_run(model, sizing_folder) == false
        puts "could not find sizing run #{sizing_folder}"
        assert(false, "Failure in sizing run wile running test: #{self.class.ancestors[0]}")
      else
        puts "found sizing run #{sizing_folder}"
      end
    end

    # Save model after sizing.
    BTAP::FileIO.save_osm(model, "#{output_dir}/post-sizing.osm") if save_model_versions
  end

  # Check if two files are identical with some added smarts
  # (used in place of simple ruby methods)
  def file_compare(expected_results_file:, test_results_file:, msg: "Files do not match", type: nil)
  
    if type == "json_data" 

      # Compare two json classes.
      diff = Hashdiff.best_diff(expected_results_file, test_results_file, delimiter: '::')
      error_msg = ""
      if !diff.nil?
        diff.each do |e|
          if e[0]=="-"
            if e[2].nil? 
              error_msg << "test results missing #{e[1]}.\n"
            else
              error_msg << "test results missing #{e[2]} in #{e[1]}.\n"
            end
          elsif e[0]=="~"
            error_msg << "test results differ in #{e[1]}:\n  Expected: #{e[2]}\n      Test: #{e[3]}\n"
          elsif e[0]=="+"
            if e[2].nil? || e[2].to_s == "{}"
              error_msg << "expected results missing #{e[1]}.\n"
            else
              error_msg << "expected results missing #{e[2]} in #{e[1]}.\n"
            end
          end
        end
      end
      msg="  Test outputs do not match expected results!"
      assert_empty(error_msg, "#{msg} \n#{error_msg}")
    else

      # Open files and compare the line by line. Remove line endings before checking strings (this can be an issue when running in docker).
      same = true
      fe = File.open(expected_results_file, 'rb') 
      ft = File.open(test_results_file, 'rb')
      comp_lines_str = ""
      fe.each.zip(ft.each).each do |le, lt|
        le=le.gsub /(\r$|\n$)/,''
        lt=lt.gsub /(\r$|\n$)/,''
        comp_lines_str = "  Expected line: #{le}\n  Test res line: #{lt}"
        same = le.eql?(lt)
        break if !same
      end

      # Close files before assert.
      fe.close
      ft.close
      expected_results_file_path=Pathname.new(expected_results_file).cleanpath
      test_results_file_path=Pathname.new(test_results_file).cleanpath
      comp_files_str="  Compare #{expected_results_file_path} with #{test_results_file_path}. File contents differ!"
      assert(same, "#{msg} #{self.class.ancestors[0]}.\n#{comp_files_str}\n#{comp_lines_str}")
    end
  end
end