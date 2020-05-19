require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class DOEPrototypeBaseline < CreateDOEPrototypeBuildingTest

  def self.generate_prototype_model_and_baseline(building_type, template, climate_zone, hvac_building_type = 'All others', wwr_building_type = 'All others', swh_building_type = 'All others')
      # Initialize weather file, necessary but not used
      epw_file = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'

      # Set folder for JSON files related to tests
      @json_dir = "#{Dir.pwd}/data"

      # Create output folder if it doesn't already exist
      @test_dir = "#{Dir.pwd}/output"
      if !Dir.exists?(@test_dir)
        Dir.mkdir(@test_dir)
      end

      # Define model name and run folder if it doesn't already exist,
      # if it does, remove it and re-create it.
      model_name = "#{building_type}-#{template}-#{climate_zone}"
      run_dir = "#{@test_dir}/#{model_name}"
      if !Dir.exists?(run_dir)
        Dir.mkdir(run_dir)
      else
        FileUtils.rm_rf(run_dir)
        Dir.mkdir(run_dir)
      end
      run_dir_baseline = "#{run_dir}-Baseline"
      if Dir.exists?(run_dir_baseline)
        FileUtils.rm_rf(run_dir_baseline)
      end

      # Create the prototype
      prototype_creator = Standard.build("#{template}_#{building_type}")
      model = prototype_creator.model_create_prototype_model(climate_zone, epw_file, run_dir)

      # Save prototype OSM file
      osm_path = OpenStudio::Path.new("#{run_dir}/#{model_name}.osm")
      model.save(osm_path, true)

      # Translate prototype model to an IDF file
      forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
      idf_path = OpenStudio::Path.new("#{run_dir}/#{model_name}.idf")
      idf = forward_translator.translateModel(model)
      idf.save(idf_path,true)

      # Initialize 90.1-2019 PRM Standard class
      prototype_creator = Standard.build("90.1-PRM-2019")

      # Convert standardSpaceType string for each space to values expected for prm creation
      lpd_space_types = JSON.parse(File.read("#{@json_dir}/lpd_space_types.json"))
      model.getSpaceTypes.sort.each do |space_type|
        next if space_type.floorArea == 0
        standards_space_type = if space_type.standardsSpaceType.is_initialized
        space_type.standardsSpaceType.get
        end
        std_bldg_type = space_type.standardsBuildingType.get
        bldg_type_space_type = std_bldg_type + space_type.standardsSpaceType.get
        new_space_type = lpd_space_types[bldg_type_space_type]
        space_type.setStandardsSpaceType(lpd_space_types[bldg_type_space_type])
      end

      # Create baseline model
      model_baseline = prototype_creator.model_create_prm_stable_baseline_building(model, building_type, climate_zone, hvac_building_type, wwr_building_type, swh_building_type, nil, run_dir_baseline, false)
      return model_baseline, model
    end

  def test_create_prototype_baseline_building
      # Define prototypes to be generated
      @templates = ['90.1-2013']
      @building_types = ['SmallOffice','MidriseApartment']
      @climate_zones = ['ASHRAE 169-2013-2A']

      # Set folder for JSON files related to tests
      @json_dir = "#{Dir.pwd}/data"

      wwr_building_types = {
        'HighriseApartment' => 'All others',
        'MidriseApartment' => 'All others',
        'Hospital' => 'Hospital',
        'LargeHotel' => 'Hotel/motel > 75 rooms',
        'RetailStripmall' => 'Retail (strip mall)',
        'SmallHotel' => 'Hotel/motel <= 75 rooms',
        'LargeOffice' => 'Office > 50,000 sq ft',
        'MediumOffice' => 'Office 5,000 to 50,000 sq ft',
        'SmallOffice' => 'Office <= 5,000 sq ft',
        'Outpatient' => 'Healthcare (outpatient)',
        'QuickServiceRestaurant' => 'Restaurant (quick service)',
        'FullServiceRestaurant' => 'Restaurant (full service)',
        'RetailStandalone' => 'Retail (stand alone)',
        'PrimarySchool' => 'School (primary)',
        'SecondarySchool' => 'School (secondary and university)',
        'Warehouse' => 'Warehouse (nonrefrigerated)'
      }

      hvac_building_types = {
        'HighriseApartment' => 'residential',
        'MidriseApartment' => 'residential',
        'Hospital' => 'hospital',
        'LargeHotel' => 'residential',
        'RetailStripmall' => 'retail',
        'SmallHotel' => 'residential',
        'LargeOffice' => 'other nonresidential',
        'MediumOffice' => 'other nonresidential',
        'SmallOffice' => 'other nonresidential',
        'Outpatient' => 'hospital',
        'QuickServiceRestaurant' => 'other nonresidential',
        'FullServiceRestaurant' => 'other nonresidential',
        'RetailStandalone' => 'retail',
        'PrimarySchool' => 'other nonresidential',
        'SecondarySchool' => 'other nonresidential',
        'Warehouse' => 'heated-only storage'
      }

      swh_building_types = {
        'HighriseApartment' => 'Multifamily ',
        'MidriseApartment' => 'Multifamily ',
        'Hospital' => 'Hospital and outpatient surgery center ',
        'LargeHotel' => 'Hotel ',
        'RetailStripmall' => 'Retail ',
        'SmallHotel' => 'Motel ',
        'LargeOffice' => 'Office ',
        'MediumOffice' => 'Office ',
        'SmallOffice' => 'Office ',
        'Outpatient' => 'Hospital and outpatient surgery center ',
        'QuickServiceRestaurant' => 'Dining: Cafeteria/fast food ',
        'FullServiceRestaurant' => 'Dining: Family ',
        'RetailStandalone' => 'Retail ',
        'PrimarySchool' => 'School/university ',
        'SecondarySchool' => 'School/university ',
        'Warehouse' => 'Warehouse '
      }

      wwr_values = {
        'HighriseApartment' => '0.3',
        'MidriseApartment' => '0.2',
        'Hospital' => '0.27',
        'LargeHotel' => '0.34',
        'RetailStripmall' => '0.2',
        'SmallHotel' => '0.24',
        'LargeOffice' => '0.4',
        'MediumOffice' => '0.31',
        'SmallOffice' => '0.19',
        'Outpatient' => '0.21',
        'QuickServiceRestaurant' => '0.34',
        'FullServiceRestaurant' => '0.24',
        'RetailStandalone' => '0.11',
        'PrimarySchool' => '0.22',
        'SecondarySchool' => '0.22',
        'Warehouse' => '0.06'
      }

      hasres_values = {
        'HighriseApartment' => 'true',
        'MidriseApartment' => 'true',
        'Hospital' => 'true',
        'LargeHotel' => 'true',
        'RetailStripmall' => 'false',
        'SmallHotel' => 'true',
        'LargeOffice' => 'false',
        'MediumOffice' => 'false',
        'SmallOffice' => 'false',
        'Outpatient' => 'true',
        'QuickServiceRestaurant' => 'false',
        'FullServiceRestaurant' => 'false',
        'RetailStandalone' => 'false',
        'PrimarySchool' => 'false',
        'SecondarySchool' => 'false',
        'Warehouse' => 'false'
      }


      all_comp =  @building_types.product @templates, @climate_zones
      all_comp.each do |building_type, template, climate_zone|

        # Generate prototype building models and associated baselines
        model_baseline, model = DOEPrototypeBaseline.generate_prototype_model_and_baseline(building_type, template, climate_zone, hvac_building_types[building_type], wwr_building_types[building_type], swh_building_types[building_type])
        assert(model_baseline,"Baseline model could not be generated for #{building_type}, #{template}, #{climate_zone}.")

        # Load baseline model
        @test_dir = "#{Dir.pwd}/output"
        model_baseline = OpenStudio::Model::Model.load("#{@test_dir}/#{building_type}-#{template}-#{climate_zone}-Baseline/final.osm")
        model_baseline = model_baseline.get

        # Do sizing run for baseline model
        prototype_creator = Standard.build("90.1-PRM-2019")
        sim_control = model_baseline.getSimulationControl
        sim_control.setRunSimulationforSizingPeriods(true)
        sim_control.setRunSimulationforWeatherFileRunPeriods(false)
        baseline_run = prototype_creator.model_run_simulation_and_log_errors(model_baseline, "#{@test_dir}/#{building_type}-#{template}-#{climate_zone}-Baseline/SR1")

        # Get WWR of baseline model
        query = "Select Value FROM TabularDataWithStrings WHERE
        ReportName = 'InputVerificationandResultsSummary' AND
        TableName = 'Window-Wall Ratio' AND
        RowName = 'Gross Window-Wall Ratio' AND
        ColumnName = 'Total' AND
        Units = '%'"
        wwr_baseline = model_baseline.sqlFile().get().execAndReturnFirstDouble(query).get().to_f

        # Check WWR against expected WWR
        wwr_goal = 100 * wwr_values[building_type].to_f
        assert(wwr_baseline == wwr_goal, "Baseline WWR for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The WWR of the baseline model is #{wwr_baseline} but should be #{wwr_goal}.")

         # Check that proposed sizing ran
        assert(File.file?("#{@test_dir}/#{building_type}-#{template}-#{climate_zone}-Baseline/SR_PROP/run/eplusout.sql"), "The #{building_type}, #{template}, #{climate_zone} proposed model sizing run did not run.")
 
        # Check IsResidential for Small Office
        # Determine whether any space is residential
        has_res = 'false'
        model_baseline.getSpaces.sort.each do |space|
          if prototype_creator.space_residential?(space)
            has_res = 'true'
          end
        end

        # Check whether space_residential? function is working
        has_res_goal = hasres_values[building_type]
        assert(has_res == has_res_goal, "Failure to set space_residential? for #{building_type}, #{template}, #{climate_zone}.")

      end
  end
end