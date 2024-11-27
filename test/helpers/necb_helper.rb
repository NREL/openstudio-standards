# Additional methods for NECB tests
require 'logger'
require 'fileutils'
require 'pathname'
require 'json'
require 'parallel'
#require 'hashdiff'

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

  # Create a logger for the tests.
  def logger
    NecbHelper.logger
  end

  # Global, memoized, lazy initialized instance of a logger
  def self.logger
    logfile = "#{__dir__}/../necb/unit_tests/log.txt"
    @logger ||= Logger.new(logfile, File::WRONLY | File::APPEND)
  end

  # Set the logging level
  logger.info!
  #logger.debug!

  # Customize the log format
  logger.formatter = proc do |severity, datetime, _progname, msg|
    datefmt = datetime.strftime('%Y-%m-%dT%H:%M:%S.%6N')
    "timestamp=#{datefmt} level=#{severity.ljust(5)} msg='#{msg}' location=[#{caller_locations(4,1)[0].to_s}]\n"
  end

  # Hold an array of the instantiated standards (to save recreating them all the time).
  @@standards = []

  # Standard path definitions for NECB testing.
  def define_folders(file_folder)
    @test_folder = File.join(file_folder, '..')
    @root_folder = File.join(@test_folder, '../../..')
    @resources_folder = File.join(@test_folder, 'resources')
    @expected_results_folder = File.join(@test_folder, 'expected_results')
    @test_results_folder = @expected_results_folder
    @top_output_folder = File.join(@test_folder, 'output')
  end

  def method_output_folder(name="")
    name.gsub!(/\s+/, "-")
    output_folder = File.join(@top_output_folder, self.class.ancestors[0].to_s.downcase, name.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    return output_folder
  end

  def define_std_ranges
    @Templates = ["NECB2011", "NECB2015", "NECB2017", "BTAPPRE1980"]
	@SomeTemplates = ["NECB2015", "NECB2017", "NECB2020"]  # for the Pumppower rules as they started with NECB2015
    @AllTemplates = ["NECB2011", "NECB2015", "NECB2017", "NECB2020", "BTAPPRE1980", "BTAP1980TO2010"]
    @AllBuildings = [
      "FullServiceRestaurant",
      "LargeHotel",
      "LargeOffice",
      "MediumOffice",
      "HighriseApartment",
      "MidriseApartment",
      "Outpatient",
      "PrimarySchool",
      "QuickServiceRestaurant",
      "RetailStandalone",
      "RetailStripmall",
      "SmallHotel",
      "SmallOffice",
      "Warehouse",
      "Hospital"
    ]
    @CommonBuildings = [
      "MediumOffice",
      "MidriseApartment",
      "RetailStandalone",
      "Warehouse",
    ]
  end

  # Utility function to help make an expected results hash.
  # @param test_cases_loop_hash [Hash] defines the variables that the test will loop through.
  #  see test/necb/unit_tests/tests/test_necb_boiler_rules.rb for examples.
  # @return a nested json containing the test case descriptions and placeholders for results.
  # @note Expects the last two entries in the hash to be TestCase and TestPars.
  def make_test_cases_json(test_cases_loop_hash)
    expected_results_template = Hash.new
    test_cases_loop_hash.reverse_each do |loop_k, loop_v|
      logger.debug "loop key: #{loop_k}, loop value: #{loop_v}"
      if loop_k.to_s == "TestPars" then
        loop_v.each {|key, value| expected_results_template[key] = value}
      else
        temp = Hash.new
        temp["VarType".to_sym] = loop_k.to_s
        loop_v.each {|key| temp[key.to_sym] = expected_results_template}
        expected_results_template = temp.clone
      end
      logger.debug "expected_results_template #{expected_results_template}"
    end
    logger.debug "\nFINAL hash:\n#{JSON.pretty_generate(expected_results_template)}"
    return expected_results_template
  end

  # @param test_cases_hash [Hash] target hash that we will be **altering**
  # @param additional_cases_hash [Hash] read from this hash
  # @return the modified test_cases_hash hash
  # @note this one does not merge Arrays
  def merge_test_cases!(test_cases_hash, additional_cases_hash)
    logger.debug "test_cases_hash: #{test_cases_hash}"
    logger.debug "additional_cases_hash: #{additional_cases_hash}"
    test_cases_hash.merge!(additional_cases_hash) { |key, oldval, newval|
      if oldval.kind_of?(Hash) && newval.kind_of?(Hash)
        merge_test_cases!(oldval, newval)
      else
        newval
      end
    }
    logger.debug "\nMerged hash:\n#{JSON.pretty_generate(test_cases_hash)}"
    return test_cases_hash
  end
  
  # Method used to recursively parse the expected json to figure out the test cases and then run them
  # (adapted template design pattern).
  # The test_pars hash is used by the recursion to remember what condition is being tested in a nested hash. It already 
  # contains some of the test parameters.
  # Will call the method 'do_test_...' to do the work. This method is called from 'test_...'
  # VarType and Reference are reserved keys that are ignored here.
  def do_test_cases(test_cases:, test_pars:)
    logger.debug "Test cases #{test_cases}"
    logger.debug "Test pars #{test_pars}"

    # Find the test cases. Do this with recursion but remember where we are in a new hash passed to the do_test method.
    # The nested hash is has essentially a set of loops (vintages, weather files, fuel types etc). As the recursion 
    # descends down through these keep track of which one is the current 'var_type'.
    # While doing this build up the test_results hash.
    var_type = test_cases[:VarType].to_s
    test_results = Hash.new
    test_results[:VarType] = var_type
    test_results[:Reference] = test_cases[:Reference] if test_cases.key?(:Reference)

    if var_type == "TestCase"
      test_cases.each do |key, value|
        next if key == :VarType # Skip to next. This is less expensive than using the except method chained before the each.
        next if key == :Reference # Skip to next. 
        logger.info  "Initiating test case #{key}"
        logger.debug  "Test case: #{test_pars}"
        logger.debug  "Current test: #{value}"

        # Run this test case. By default call the do_testMethod method.
        method_name = "do_#{test_pars[:test_method]}"
        case_results = self.send(method_name, test_pars: test_pars, test_case: value)
        logger.debug  "Test case results: #{case_results}"
        test_results[key] = case_results
      end
    else

      # Recursively go through the variables defined in the json file and find the test cases.
      test_cases.each do |key, value|
        next if key == :VarType
        next if key == :Reference
        logger.debug  "Test case k,v: #{key}, #{value}"
        if value.is_a? Hash
          test_pars[var_type.to_sym] = key.to_s
          test_results[key] = do_test_cases(test_cases: value, test_pars: test_pars)
        end
      end
    end
    logger.debug  "All test results: #{test_results}"
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
    logger.debug "Using template: #{standard.class}"
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
  #   output_dir - folder where the models are saved to (if requested)
  def run_sizing(model:,
                 template: 'NECB2011',
                 second_run: false,
                 necb_ref_hp: false,
                 sql_db_vars_map: nil,
                 save_model_versions: false,
                 output_dir: nil)

    # Report what we are doing (helps when things go wrong!).
    logger.debug "Running measure for test class: #{self.class.ancestors[0]}"
    logger.debug "  from method: #{caller_locations(1,1)[0].label}"
    logger.debug "  for template: #{template}"

    # Instantiate the required version of standards.
    standard = get_standard(template)

    # Define output folder if not passed. This should be removed once all calls updated.
    if output_dir == nil then
      test_class_name = self.class.ancestors[0].to_s.downcase
      test_method_name = caller_locations.first.base_label
      output_dir = File.join(@top_output_folder, test_class_name, test_method_name, template)
    end
    logger.debug "Output folder #{output_dir}"

    # Check output_dir exists, if not create.
    unless Dir.exist? output_dir
      FileUtils.mkdir_p(output_dir)
    end

    # Save model before sizing.
    BTAP::FileIO.save_osm(model, "#{output_dir}/pre-sizing.osm") if save_model_versions

    # Perform first sizing run.
    sizing_folder = "#{output_dir}/SR1"
    if standard.model_run_sizing_run(model, sizing_folder) == false
      logger.error "Could not find sizing run #{sizing_folder}"
      assert(false, "Failure in sizing run wile running test: #{self.class.ancestors[0]}")
    else
      logger.debug "Found sizing run #{sizing_folder}"
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
        logger.error "Could not find second sizing run #{sizing_folder}"
        assert(false, "Failure in sizing run wile running test: #{self.class.ancestors[0]}")
      else
        logger.debug "Found second sizing run #{sizing_folder}"
      end
    end

    # Save model after sizing.
    BTAP::FileIO.save_osm(model, "#{output_dir}/post-sizing.osm") if save_model_versions
  end

  # Check if two files are identical with some added smarts.
  # (used in place of simple ruby methods)
  def compare_results(expected_results:, test_results:, msg: "Files do not match", type: nil)

    if type == "json_data"

      # Compare two json classes.
      #diff = hashdiff.diff(expected_results, test_results)
      diff = CompareJSON.diff(expected_results, test_results)
      error_msg = ""
      if !diff.nil?
        diff.each do |e|
          if e[0]=="-"
            if e[2].nil?
              error_msg << "test results missing #{e[1]}.\n"
            else
              error_msg << "test results missing #{JSON.pretty_generate(e[2])} in #{e[1]}.\n"
            end
          elsif e[0]=="~"
            error_msg << "test results differ in #{e[1]}:\n  Expected: #{JSON.pretty_generate(e[2])}\n      Test: #{JSON.pretty_generate(e[3])}\n"
          elsif e[0]=="+"
            if e[2].nil? || e[2].to_s == "{}"
              error_msg << "expected results missing #{e[1]}.\n"
            else
              error_msg << "expected results missing #{JSON.pretty_generate(e[2])} in #{e[1]}.\n"
            end
          end
        end
      end
      msg="Test outputs do not match expected results!\n" + error_msg
      assert(error_msg.empty?, msg) # Works better than assert_empty.
    else

      # Open files and compare the line by line. Remove line endings before checking strings (this can be an issue when running in docker).
      same = true
      fe = File.open(expected_results, 'rb')
      ft = File.open(test_results, 'rb')
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
      expected_results_file_path=Pathname.new(expected_results).cleanpath
      test_results_file_path=Pathname.new(test_results).cleanpath
      comp_files_str="  Compare #{expected_results_file_path} with #{test_results_file_path}. File contents differ!"
      assert(same, "#{msg} #{self.class.ancestors[0]}.\n#{comp_files_str}\n#{comp_lines_str}")
    end
  end

  # @param obj1 [Hash] json data for comparison
  # @param obj2 [Hash] json data for comparison
  # @param prefix [string] built up reference of where we are in the nested json, :: separated keys
  # @return the differences between the two json data objects
  # @note Derived from Hashdiff gem (https://github.com/liufengyun/hashdiff/tree/master). Extracted core functionality that is used above.
  module CompareJSON
    def self.diff(obj1, obj2, prefix = '')

      return [] if obj1.nil? && obj2.nil?

      return [['~', prefix, obj1, obj2]] if obj1.nil? || obj2.nil?

      return LcsCompareArrays.call(obj1, obj2, prefix) if obj1.is_a?(Array)

      return CompareHashes.call(obj1, obj2, prefix) if obj1.is_a?(Hash)

      return [] if obj1 == obj2

      [['~', prefix, obj1, obj2]]
    end

    class CompareHashes
      class << self
        def call(obj1, obj2, prefix = '')
          current_prefix = prefix
          prefix = ''
          return [] if obj1.empty? && obj2.empty?

          obj1_keys = obj1.keys
          obj2_keys = obj2.keys
          obj1_lookup = {}
          obj2_lookup = {}

          added_keys = (obj2_keys - obj1_keys).sort_by(&:to_s)
          common_keys = (obj1_keys & obj2_keys).sort_by(&:to_s)
          deleted_keys = (obj1_keys - obj2_keys).sort_by(&:to_s)

          result = []

          # Add deleted properties.
          deleted_keys.each do |k|
            change_key = CompareJSON.prefix_append_key(current_prefix, k)
            result << ['-', change_key, obj1[k]]
          end

          # Recursive comparison for common keys.
          common_keys.each do |k|
            prefix = CompareJSON.prefix_append_key(current_prefix, k)
            result.concat(CompareJSON.diff(obj1[k], obj2[k], prefix))
          end

          # Added properties.
          added_keys.each do |k|
            change_key = CompareJSON.prefix_append_key(current_prefix, k)
            result << ['+', change_key, obj2[k]]
          end

          return result
        end
      end
    end

    class LcsCompareArrays
      class << self
        def call(obj1, obj2, prefix = '')
          result = []

          changeset = CompareJSON.diff_array_lcs(obj1, obj2, prefix) do |lcs|
            # Use a's index for similarity.
            lcs.each do |pair|
              prefix = CompareJSON.prefix_append_array_index(prefix, pair[0])

              result.concat(CompareJSON.diff(obj1[pair[0]], obj2[pair[1]], prefix))
            end
          end

          changeset.each do |change|
            next if change[0] != '-' && change[0] != '+'

            change_key = CompareJSON.prefix_append_array_index(prefix, change[1])

            result << [change[0], change_key, change[2]]
          end

          result
        end
      end
    end

    # Diff array using LCS algorithm
    def self.diff_array_lcs(arraya, arrayb, prefix = '')
      current_prefix = prefix
      prefix = ''
      return [] if arraya.empty? && arrayb.empty?

      change_set = []

      if arraya.empty?
        arrayb.each_index do |index|
          change_set << ['+', index, arrayb[index]]
        end

        return change_set
      end

      if arrayb.empty?
        arraya.each_index do |index|
          i = arraya.size - index - 1
          change_set << ['-', i, arraya[i]]
        end

        return change_set
      end

      prefix = current_prefix
      links = lcs(arraya, arrayb, prefix)

      # yield common
      yield links if block_given?

      # padding the end
      links << [arraya.size, arrayb.size]

      last_x = -1
      last_y = -1
      links.each do |pair|
        x, y = pair

        # remove from a, beginning from the end
        (x > last_x + 1) && (x - last_x - 2).downto(0).each do |i|
          change_set << ['-', last_y + i + 1, arraya[i + last_x + 1]]
        end

        # add from b, beginning from the head
        (y > last_y + 1) && 0.upto(y - last_y - 2).each do |i|
          change_set << ['+', last_y + i + 1, arrayb[i + last_y + 1]]
        end

        # update flags
        last_x = x
        last_y = y
      end

      change_set
    end

    # Calculate array difference using LCS algorithm
    # http://en.wikipedia.org/wiki/Longest_common_subsequence_problem
    def self.lcs(arraya, arrayb, prefix = '')
      return [] if arraya.empty? || arrayb.empty?

      prefix = prefix_append_array_index(prefix, '*')

      a_start = b_start = 0
      a_finish = arraya.size - 1
      b_finish = arrayb.size - 1
      vector = []

      lcs = []
      (b_start..b_finish).each do |bi|
        lcs[bi] = []
        (a_start..a_finish).each do |ai|
          if arraya[ai] == arrayb[bi]
            topleft = (ai > 0) && (bi > 0) ? lcs[bi - 1][ai - 1][1] : 0
            lcs[bi][ai] = [:topleft, topleft + 1]
          elsif (top = bi > 0 ? lcs[bi - 1][ai][1] : 0)
            left = ai > 0 ? lcs[bi][ai - 1][1] : 0
            count = top > left ? top : left

            direction = if top > left
                          :top
                        elsif top < left
                          :left
                        elsif bi.zero?
                          :top
                        elsif ai.zero?
                          :left
                        else
                          :both
                        end

            lcs[bi][ai] = [direction, count]
          end
        end
      end

      x = a_finish
      y = b_finish
      while (x >= 0) && (y >= 0) && (lcs[y][x][1] > 0)
        if lcs[y][x][0] == :both
          x -= 1
        elsif lcs[y][x][0] == :topleft
          vector.insert(0, [x, y])
          x -= 1
          y -= 1
        elsif lcs[y][x][0] == :top
          y -= 1
        elsif lcs[y][x][0] == :left
          x -= 1
        end
      end

      return vector
    end

    def self.prefix_append_key(prefix, key)
      prefix.empty? ? key.to_s : "#{prefix}::#{key}"
    end
    def self.prefix_append_array_index(prefix, array_index)
      "#{prefix}[#{array_index}]"
    end
  end
end