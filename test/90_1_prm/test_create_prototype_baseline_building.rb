require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class DOEPrototypeBaseline < CreateDOEPrototypeBuildingTest

  def self.generate_prototype_model_and_baseline(building_type, template, climate_zone, hvac_building_type = 'All others', wwr_building_type = 'All others', swh_building_type = 'All others')
      # Initialize weather file, necessary but not used
      epw_file = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'

      # Set folder for JSON files related to tests
      @json_dir = "#{File.dirname(__FILE__)}/data"

      # Create output folder if it doesn't already exist
      @test_dir = "#{File.dirname(__FILE__)}/output"
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
      @json_dir = "#{File.dirname(__FILE__)}/data"

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
        @test_dir = "#{File.dirname(__FILE__)}/output"
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
        TableName = 'Conditioned Window-Wall Ratio' AND
        RowName = 'Gross Window-Wall Ratio' AND
        ColumnName = 'Total' AND
        Units = '%'"
        wwr_baseline = model_baseline.sqlFile().get().execAndReturnFirstDouble(query).get().to_f

        # Check WWR against expected WWR
        wwr_goal = 100 * wwr_values[building_type].to_f
        assert(wwr_baseline == wwr_goal, "Baseline WWR for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The WWR of the baseline model is #{wwr_baseline} but should be #{wwr_goal}.")

        # Get U-value of envelope in baseline model
		    if building_type == 'SmallOffice' && template == '90.1-2013' && climate_zone == 'ASHRAE 169-2013-2A'
			    u_value_baseline = {}
          construction_baseline = {}
          opaque_exterior_name = ['ATTIC_ROOF_EAST','PERIMETER_ZN_1_WALL_SOUTH']
          exterior_fenestration_name = ['PERIMETER_ZN_1_WALL_SOUTH_DOOR','PERIMETER_ZN_1_WALL_SOUTH_WINDOW_1']
          exterior_door_name = ['PERIMETER_ZN_3_WALL_NORTH_DOOR1']

          opaque_exterior_name.each do |val|
            query = "Select Value FROM TabularDataWithStrings WHERE
            ReportName = 'EnvelopeSummary' AND
            TableName = 'Opaque Exterior' AND
            RowName = '#{val}' AND
            ColumnName = 'U-Factor with Film' AND
            Units = 'W/m2-K'"
            u_value_baseline[val] = model_baseline.sqlFile().get().execAndReturnFirstDouble(query).get().to_f
          end

          opaque_exterior_name.each do |val|
            query = "Select Value FROM TabularDataWithStrings WHERE
            ReportName = 'EnvelopeSummary' AND
            TableName = 'Opaque Exterior' AND
            RowName = '#{val}' AND
            ColumnName = 'Construction'"
            construction_baseline[val] = model_baseline.sqlFile().get().execAndReturnFirstString(query).get().to_s
          end

          exterior_fenestration_name.each do |val|
            query = "Select Value FROM TabularDataWithStrings WHERE
            ReportName = 'EnvelopeSummary' AND
            TableName = 'Exterior Fenestration' AND
            RowName = '#{val}' AND
            ColumnName = 'Glass U-Factor' AND
            Units = 'W/m2-K'"
            u_value_baseline[val] = model_baseline.sqlFile().get().execAndReturnFirstDouble(query).get().to_f
          end

          exterior_fenestration_name.each do |val|
            query = "Select Value FROM TabularDataWithStrings WHERE
            ReportName = 'EnvelopeSummary' AND
            TableName = 'Exterior Fenestration' AND
            RowName = '#{val}' AND
            ColumnName = 'Construction'"
            construction_baseline[val] = model_baseline.sqlFile().get().execAndReturnFirstString(query).get().to_s
          end

          exterior_door_name.each do |val|
            query = "Select Value FROM TabularDataWithStrings WHERE
            ReportName = 'EnvelopeSummary' AND
            TableName = 'Exterior Door' AND
            RowName = '#{val}' AND
            ColumnName = 'U-Factor with Film' AND
            Units = 'W/m2-K'"
            u_value_baseline[val] = model_baseline.sqlFile().get().execAndReturnFirstDouble(query).get().to_f
          end

          exterior_door_name.each do |val|
            query = "Select Value FROM TabularDataWithStrings WHERE
            ReportName = 'EnvelopeSummary' AND
            TableName = 'Exterior Door' AND
            RowName = '#{val}' AND
            ColumnName = 'Construction'"
            construction_baseline[val] = model_baseline.sqlFile().get().execAndReturnFirstString(query).get().to_s
          end

          # Check U-value against expected U-value
          u_value_goal = {'ATTIC_ROOF_EAST' => 0.063,
                          'PERIMETER_ZN_1_WALL_SOUTH' => 0.124,
                          'PERIMETER_ZN_1_WALL_SOUTH_DOOR' => 1.22,
                          'PERIMETER_ZN_1_WALL_SOUTH_WINDOW_1' => 1.22,
                          'PERIMETER_ZN_3_WALL_NORTH_DOOR1' => 0.7}
          u_value_goal.each do |key, value|
            value_si = OpenStudio.convert(value, 'Btu/ft^2*hr*R', 'W/m^2*K').get
            assert(((u_value_baseline[key] - value_si).abs < 0.001 || u_value_baseline[key] == 5.838),"Baseline U-value for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The U-value of the #{key} is #{u_value_baseline[key]} but should be #{value_si}.")
            if key != 'PERIMETER_ZN_3_WALL_NORTH_DOOR1'
              assert((construction_baseline[key].include? "PRM"),"Baseline U-value for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The construction of the #{key} is #{construction_baseline[key]}, which is not from PRM_Construction tab.")
            end
          end
        end

        # Get LPD in baseline model
		    if building_type == 'SmallOffice' || building_type == 'MidriseApartment'
			    lpd_baseline = {}
          zone_name_smalloffice = ['CORE_ZN ZN OFFICE WHOLEBUILDING - SM OFFICE LIGHTS','PERIMETER_ZN_1 ZN OFFICE WHOLEBUILDING - SM OFFICE LIGHTS']
          zone_name_midriseapartment = ['G CORRIDOR ZN MIDRISEAPARTMENT CORRIDOR LIGHTS','G N1 APARTMENT ZN MIDRISEAPARTMENT APARTMENT ADDITIONAL LIGHTS']
          if building_type == 'SmallOffice'
            zone_name = zone_name_smalloffice
          else
            zone_name = zone_name_midriseapartment
          end
          zone_name.each do |val|
            query = "Select Value FROM TabularDataWithStrings WHERE
            ReportName = 'LightingSummary' AND
            TableName = 'Interior Lighting' AND
            RowName = '#{val}' AND
            ColumnName = 'Lighting Power Density' AND
            Units = 'W/m2'"
            lpd_baseline[val] = model_baseline.sqlFile().get().execAndReturnFirstDouble(query).get().to_f
          end

          # Check lpd against expected lpd
          if building_type == 'SmallOffice'
            lpd_goal = {'CORE_ZN ZN OFFICE WHOLEBUILDING - SM OFFICE LIGHTS' => 1.0,
                        'PERIMETER_ZN_1 ZN OFFICE WHOLEBUILDING - SM OFFICE LIGHTS' => 1.0}
          else
            lpd_goal = {'G CORRIDOR ZN MIDRISEAPARTMENT CORRIDOR LIGHTS' => 0.5,
                        'G N1 APARTMENT ZN MIDRISEAPARTMENT APARTMENT ADDITIONAL LIGHTS' => 1.07}
          end
          lpd_goal.each do |key, value|
            value_si = OpenStudio.convert(value, 'W/ft^2', 'W/m^2').get
            assert(((lpd_baseline[key] - value_si).abs < 0.001),"Baseline U-value for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The U-value of the #{key} is #{lpd_baseline[key]} but should be #{value_si}.")
          end
        end

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

        # Check the model include daylighting control objects
        model_baseline.getSpaces.sort.each do |space|
          existing_daylighting_controls = space.daylightingControls
          assert(existing_daylighting_controls.empty?, "The baseline model for the #{building_type}-#{template} in #{climate_zone} has daylighting control.")
		end
      end
  end
end