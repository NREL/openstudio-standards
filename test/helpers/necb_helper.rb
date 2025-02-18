# Additional methods for NECB tests
require 'fileutils'
require 'pathname'
#require 'json'
#require 'hashdiff'

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

    # Define output folders.
    test_method_name = self.class.ancestors[0].to_s.downcase
    sizing_dir = File.join(@top_output_folder, test_method_name, test_name, 'sizing')
    models_dir = File.join(@top_output_folder, test_method_name, test_name)

    # Make a directory to run the sizing run in.
    unless Dir.exist? sizing_dir
      FileUtils.mkdir_p(sizing_dir)
    end

    # Save model before sizing.
    BTAP::FileIO.save_osm(model, "#{models_dir}/pre-sizing.osm") if save_model_versions

    # Perform first sizing run.
    sizing_folder = "#{sizing_dir}/SR1"
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
      BTAP::FileIO.save_osm(model, "#{models_dir}/pre-sizing2.osm") if save_model_versions

      # Do another sizing run after applying the hvac assumptions and efficiency standards
      #  to properly apply the pump rules.
      sizing_folder = "#{sizing_dir}/SR2"
      if standard.model_run_sizing_run(model, sizing_folder) == false
        puts "could not find sizing run #{sizing_folder}"
        assert(false, "Failure in sizing run wile running test: #{self.class.ancestors[0]}")
      else
        puts "found sizing run #{sizing_folder}"
      end
    end

    # Save model after sizing.
    BTAP::FileIO.save_osm(model, "#{models_dir}/post-sizing.osm") if save_model_versions
  end

  # Check if two files are identical with some added smarts
  # (used in place of simple ruby methods)
  def file_compare(expected_results_file:, test_results_file:, msg: "Files do not match", type: nil)

    #if type == "fred" # Place holder for other file compare options. So far just defined the default behaviour.
    #else
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
      comp_files_str = "Compare #{expected_results_file_path} with #{test_results_file_path}. File contents differ!"
      assert(same, "#{msg} #{self.class.ancestors[0]}.\n#{comp_files_str}\n#{comp_lines_str}")
    #end
  end
end