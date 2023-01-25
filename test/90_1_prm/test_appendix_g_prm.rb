require_relative '../helpers/minitest_helper'

# Test suite for the ASHRAE 90.1 appendix G Performance
# Rating Method (PRM) baseline automation implementation
# in openstudio-standards.
# @author Doug Maddox (PNNL), Jeremy Lerond (PNNL), and Yunyang Ye (PNNL)
class AppendixGPRMTests < Minitest::Test
  # Set folder for JSON files related to tests and
  # parse individual JSON files used by all methods
  # in this class.
  @@json_dir = "#{File.dirname(__FILE__)}/data"
  @@prototype_list = JSON.parse(File.read("#{@@json_dir}/prototype_list.json"))
  @@wwr_building_types = JSON.parse(File.read("#{@@json_dir}/wwr_building_types.json"))
  @@hvac_building_types = JSON.parse(File.read("#{@@json_dir}/hvac_building_types.json"))
  @@swh_building_types = JSON.parse(File.read("#{@@json_dir}/swh_building_types.json"))
  @@wwr_values = JSON.parse(File.read("#{@@json_dir}/wwr_values.json"))
  @@hasres_values = JSON.parse(File.read("#{@@json_dir}/hasres_values.json"))
  # Global variable to ...
  # Make sure to turn it to false so CI will not fail for time out.
  GENERATE_PRM_LOG = false
  MAX_PATH_CHAR = 1800 #linux should set to a 1800, windows should set to 200, set to 1800 when push to the repo or open PR to pass CI.

  def prm_test_helper(test_string, require_prototype=true, require_baseline=true)
    # Get list of unique prototypes
    prototypes_to_generate = get_prototype_to_generate(test_string, @@prototype_list)
    # Generate all unique prototypes
    prototypes_generated = generate_prototypes(prototypes_to_generate, test_string)
    # Create all unique baseline
    prototypes_baseline_generated = generate_baseline(prototypes_generated, prototypes_to_generate, test_string)

    model_hash = {}
    if require_prototype
      prototypes = assign_prototypes(prototypes_generated, [test_string], prototypes_to_generate)
      model_hash['prototype'] = prototypes[test_string]
    end
    if require_baseline
      # Assign prototypes and baseline to each test
      prototypes_base = assign_prototypes(prototypes_baseline_generated, [test_string], prototypes_to_generate)
      model_hash['baseline'] = prototypes_base[test_string]
    end
    return model_hash
  end

  # Generate one of the ASHRAE 90.1 prototype model included in openstudio-standards.
  #
  # @param prototypes_to_generate [Array] List of prototypes to generate, see prototype_list.json to see the structure of the list
  # @param test_string [String] test string
  # @return [Hash] Hash of OpenStudio Model of the prototypes
  def generate_prototypes(prototypes_to_generate, test_string)
    prototypes = {}
    @lpd_space_types_alt = {}
    @bldg_type_alt = {}
    @bldg_type_alt_now = nil

    prototypes_to_generate.each do |id, prototype|
      # mod is an array of method intended to modify the model
      building_type, template, climate_zone, user_data_dir, mod = prototype

      climate_zone_code = climate_zone.split('-')[-1]
      assert(building_type != 'LargeOffice' || ['0A', '0B', '1A', '1B', '2A', '2B'].include?(climate_zone_code), "Baseline model cannot be generated for #{building_type} in climate zone: #{climate_zone}. Due to a known problem with sizing of heating system for data center (which has zero heating load), the large office model fails in mild to cold climates (CZ 3 and higher). Use climate zone 0, 1 or 2 instead")


      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join('_') unless mod.empty?

      # Initialize weather file, necessary but not used
      epw_file = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'

      # Create output folder if it doesn't already exist
      @test_dir = "#{File.dirname(__FILE__)}/output"
      if !Dir.exist?(@test_dir)
        Dir.mkdir(@test_dir)
      end

      # Define model name and run folder if it doesn't already exist,
      # if it does, remove it and re-create it.
      model_name = mod.empty? ? "#{building_type}-#{template}-#{climate_zone}-#{test_string}-#{user_data_dir}" : "#{building_type}-#{template}-#{climate_zone}-#{test_string}-#{user_data_dir}-#{mod_str}"
      run_dir = "#{@test_dir}/#{model_name}"
      run_dir = run_dir.length > MAX_PATH_CHAR ? "#{run_dir[0...MAX_PATH_CHAR]}" : run_dir
      if !Dir.exist?(run_dir)
        Dir.mkdir(run_dir)
      else
        FileUtils.rm_rf(run_dir)
        Dir.mkdir(run_dir)
      end

      # Create the prototype
      @prototype_creator = Standard.build("#{template}_#{building_type}")
      model = @prototype_creator.model_create_prototype_model(climate_zone, epw_file, run_dir)

      # Make modification if requested
      @bldg_type_alt_now = nil
      if !mod.empty?
        mod.each do |method_mod|
          mthd, arguments = method_mod
          model = public_send(mthd, model, arguments)
        end
      end

      # Store alternate building type into hash
      if !@bldg_type_alt_now.nil?
        @bldg_type_alt[prototype] = @bldg_type_alt_now
      else
        @bldg_type_alt[prototype] = nil?
      end

      # Save prototype OSM file
      osm_path = OpenStudio::Path.new("#{run_dir}/#{model_name}.osm")
      model.save(osm_path, true)

      # Translate prototype model to an IDF file
      forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
      idf_path = OpenStudio::Path.new("#{run_dir}/#{model_name}.idf")
      idf = forward_translator.translateModel(model)
      idf.save(idf_path, true)

      # Save OpenStudio model object
      prototypes[id] = model
    end
    return prototypes
  end

  # Generate the 90.1 Appendix G baseline for a model following the 90.1-2019 PRM rules
  #
  # @param prototypes_generated [Array] List of all unique prototypes for which baseline models will be created
  # @param id_prototype_mapping [Hash] Mapping of prototypes to their identifiers generated by prototypes_to_generate()
  # @param test_string [String] test string
  # @return [Hash] Hash of OpenStudio Model of the prototypes
  def generate_baseline(prototypes_generated, id_prototype_mapping, test_string)
    baseline_prototypes = {}
    prototypes_generated.each do |id, proposed_model|
      building_type, template, climate_zone, user_data_dir, mod = id_prototype_mapping[id]

      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join('_') unless mod.empty?

      # Create a deep copy of the proposed model
      model = BTAP::FileIO.deep_copy(proposed_model)

      # Initialize Standard class
      @prototype_creator = Standard.build('90.1-PRM-2019')

      # user data CSV files are in @user_data_dir, if appicable
      # user data JSON files will be created in sub-folder inside @test_dir
      model_name = mod.empty? ? "#{building_type}-#{template}-#{climate_zone}-#{test_string}-#{user_data_dir}" : "#{building_type}-#{template}-#{climate_zone}-#{test_string}-#{user_data_dir}-#{mod_str}"
      proto_run_dir = "#{@test_dir}/#{model_name}"
      proto_run_dir = proto_run_dir.length > MAX_PATH_CHAR ? "#{proto_run_dir[0...MAX_PATH_CHAR]}" : proto_run_dir

      if not user_data_dir == 'no_user_data'
        json_path = @prototype_creator.convert_userdata_csv_to_json("#{@@json_dir}/#{user_data_dir}", proto_run_dir)
        @prototype_creator.load_userdata_to_standards_database(json_path)
      end

      # Convert standardSpaceType string for each space to values expected for prm creation
      lpd_space_types = JSON.parse(File.read("#{@@json_dir}/lpd_space_types.json"))
      model.getSpaceTypes.sort.each do |space_type|
        next if space_type.floorArea == 0

        standards_space_type = if space_type.standardsSpaceType.is_initialized
                                 space_type.standardsSpaceType.get
                               end
        std_bldg_type = space_type.standardsBuildingType.get
        bldg_type_space_type = std_bldg_type + space_type.standardsSpaceType.get
        new_space_type = lpd_space_types[bldg_type_space_type]
        alt_space_type_was_found = false
        unless @lpd_space_types_alt.nil?
          # Check alternate hash of LPD space types before replacing from JSON list
          @lpd_space_types_alt.each do |alt_bldg_space_type, n_spc_t|
            if bldg_type_space_type == alt_bldg_space_type
              alt_space_type_was_found = true
              space_type.setStandardsSpaceType(n_spc_t)
              break
            end
          end
        end
        if alt_space_type_was_found == false
          if lpd_space_types.key? bldg_type_space_type
            space_type.setStandardsSpaceType(lpd_space_types[bldg_type_space_type])
          else
            puts 'key not found in lpd_space_types.json'
          end
        end
      end

      # Disable Under Case HVAC Return Air Fraction for refrigerated cases
      # Since current tests result in ZoneHVAC systems for zones with refrigeration for large hotel
      # TODO: remove this when we have multiple HVAC building types available
      # since PSZ will be the typical baseline system for those zones with that in place
      model.getRefrigerationCases.sort.each do |refg_case|
        if !refg_case.isUnderCaseHVACReturnAirFractionDefaulted
          refg_case.setUnderCaseHVACReturnAirFraction(0)
        end
      end

      # Define run directory and run name, delete existing folder if it exists
      run_dir_baseline = "#{proto_run_dir}-Baseline"
      if Dir.exist?(run_dir_baseline)
        FileUtils.rm_rf(run_dir_baseline)
      end

      if @bldg_type_alt[id_prototype_mapping[id]] == false
        hvac_building_type = building_type
      else
        hvac_building_type = @bldg_type_alt[id_prototype_mapping[id]]
      end

      unmet_load_hours = (mod_str == 'unmet_load_hours') ? true : false

      # Create baseline model
      model_baseline = @prototype_creator.model_create_prm_stable_baseline_building(model, climate_zone,
                                                                                    @@hvac_building_types[hvac_building_type],
                                                                                    @@wwr_building_types[building_type],
                                                                                    @@swh_building_types[building_type],
                                                                                    run_dir_baseline, false, GENERATE_PRM_LOG)


      # Check if baseline could be created
      assert(model_baseline, "Baseline model could not be generated for #{building_type}, #{template}, #{climate_zone}.")

      # Load newly generated baseline model
      @test_dir = "#{File.dirname(__FILE__)}/output"
      model_baseline_file_name = "#{run_dir_baseline}/final.osm"
      model_baseline = OpenStudio::Model::Model.load(model_baseline_file_name)
      model_baseline = model_baseline.get

      # Do sizing run for baseline model
      sim_control = model_baseline.getSimulationControl
      sim_control.setRunSimulationforSizingPeriods(true)
      sim_control.setRunSimulationforWeatherFileRunPeriods(false)
      baseline_run = @prototype_creator.model_run_simulation_and_log_errors(model_baseline, "#{model_baseline_file_name}-SR")

      # Add prototype to the list of baseline prototypes generated
      baseline_prototypes[id] = model_baseline
    end
    return baseline_prototypes
  end

  # Identify individual prototypes to be created
  #
  # @param tests [Array] Names of the tests to be performed
  # @param prototype_list [Hash] List of prototypes needed for each test
  #
  # @return [Hash] Prototypes to be generated
  def get_prototype_to_generate(tests, prototype_list)
    # Initialize prototype identifier
    id = 0
    # Associate model description to identifiers
    prototypes_to_generate = {}
    prototype_list.each do |utest, prototypes|
      prototypes.each do |prototype|
        if !prototypes_to_generate.values.include?(prototype) && tests.include?(utest)
          prototypes_to_generate[id] = prototype
          id += 1
        end
      end
    end
    return prototypes_to_generate
  end

  # Assign prototypes to each individual tests
  #
  # @param prototypes_generated [Hash] Hash containing all the OpenStudio model objects of the prototypes that have been created
  # @param tests [Array] List of tests to be performed
  # @param id_prototype_mapping [Hash] Mapping of prototypes to their respective ids
  #
  # @return [Hash] Association of OpenStudio model object to model description for each test
  def assign_prototypes(prototypes_generated, tests, id_prototype_mapping)
    test_prototypes = {}
    tests.each do |test|
      test_prototypes[test] = {}
      @@prototype_list[test].each do |prototype|
        # Find prototype id in mapping
        prototype_id = -9999.0
        id_prototype_mapping.each do |id, prototype_description|
          if prototype_description == prototype
            prototype_id = id
          end
        end
        test_prototypes[test][prototype] = prototypes_generated[prototype_id]
      end
    end
    return test_prototypes
  end

  # Change the building name in the model
  def set_model_building_name(model, arguments)
    model.getBuilding.setName(arguments)
    return model
  end

  # Check Window-to-Wall Ratio (WWR) for the baseline models
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_wwr(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      # Get WWR of baseline model
      std = Standard.build('90.1-PRM-2019')
      wwr_baseline = std.run_query_tabulardatawithstrings(model_baseline, 'InputVerificationandResultsSummary', 'Conditioned Window-Wall Ratio', 'Gross Window-Wall Ratio', 'Total', '%').to_f

      # Check WWR against expected WWR
      wwr_goal = 100 * @@wwr_values[building_type].to_f
      if building_type == 'MidriseApartment' && climate_zone == 'ASHRAE 169-2013-3A'
        assert(((wwr_baseline - 40.0)/40.0).abs < 0.01, "Baseline WWR for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The WWR of the baseline model is #{wwr_baseline} but should be #{wwr_goal}.")
      else
        assert(((wwr_baseline - wwr_goal)/wwr_goal).abs < 0.01, "Baseline WWR for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The WWR of the baseline model is #{wwr_baseline} but should be #{wwr_goal}.")
      end
    end
  end

  # Check Skylight-to-Roof Ratio (SRR) for the baseline models
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_srr(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      # Get srr of baseline model
      std = Standard.build('90.1-PRM-2019')
      srr_baseline = std.run_query_tabulardatawithstrings(model_baseline, 'InputVerificationandResultsSummary', 'Skylight-Roof Ratio', 'Skylight-Roof Ratio', 'Total', '%').to_f

      # Check WWR against expected WWR
      srr_goal = 3
      assert((srr_baseline - srr_goal).abs < 0.1, "Baseline SRR for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The SRR of the baseline model is #{srr_baseline} but should be #{srr_goal}.")
    end
  end

  # Check that no daylighting controls are modeled in the baseline models
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_daylighting_control(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype
      # Check the model include daylighting control objects
      model_baseline.getSpaces.sort.each do |space|
        existing_daylighting_controls = space.daylightingControls
        assert(existing_daylighting_controls.empty?, "The baseline model for the #{building_type}-#{template} in #{climate_zone} has daylighting control.")
      end
    end
  end

  def check_building_rotation_exception(prototypes_base, test_string)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype
      @test_dir = "#{File.dirname(__FILE__)}/output"
      mod_str = mod.flatten.join('_') unless mod.empty?
      model_baseline_file_name = mod.empty? ? "#{building_type}-#{template}-#{climate_zone}-#{test_string}-#{user_data_dir}-Baseline/final.osm" : "#{building_type}-#{template}-#{climate_zone}-#{user_data_dir}-#{mod.flatten.join('_') unless mod.empty?}-Baseline/final.osm"
      model_baseline_file_name_90 = mod.empty? ? "#{building_type}-#{template}-#{climate_zone}-#{test_string}-#{user_data_dir}-Baseline/final_90.osm" : "#{building_type}-#{template}-#{climate_zone}-#{user_data_dir}-#{mod.flatten.join('_') unless mod.empty?}-Baseline/final_90.osm"
      model_baseline_file_name_180 = mod.empty? ? "#{building_type}-#{template}-#{climate_zone}-#{test_string}-#{user_data_dir}-Baseline/final_180.osm" : "#{building_type}-#{template}-#{climate_zone}-#{user_data_dir}-#{mod.flatten.join('_') unless mod.empty?}-Baseline/final_180.osm"
      model_baseline_file_name_270 = mod.empty? ? "#{building_type}-#{template}-#{climate_zone}-#{test_string}-#{user_data_dir}-Baseline/final_270.osm" : "#{building_type}-#{template}-#{climate_zone}-#{user_data_dir}-#{mod.flatten.join('_') unless mod.empty?}-Baseline/final_270.osm"
      rotated = File.exist?("#{@test_dir}/#{model_baseline_file_name}") && File.exist?("#{@test_dir}/#{model_baseline_file_name_90}") &&  File.exist?("#{@test_dir}/#{model_baseline_file_name_180}") &&  File.exist?("#{@test_dir}/#{model_baseline_file_name_270}")

      if mod.empty?
        # test case 1 - rotation
        assert(rotated == true, 'Small Office with default WWR shall rotate orientations, but it didnt')
      elsif mod == 'change_wwr_model_0.4_0.4_0.4_0.4'
        # test case 2 - true
        assert(rotated == true, 'Small Office with updated WWR (0.4, 0.4, 0.4, 0.4) shall rotate orientations, but it didnt')
      elsif mod == 'change_wwr_model_0.4_0.4_0.6_0.6'
        assert(rotated == false, 'Small Office with updated WWR (0.4, 0.4, 0.6, 0.6) do not need to rotate, but it did rotate')
      end
    end
  end

  # Check if the IsResidential flag used by the PRM works as intended (i.e. should be false for commercial spaces)
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_residential_flag(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype
      # Determine whether any space is residential
      has_res = 'false'
      std = Standard.build("#{template}_#{building_type}")
      model_baseline.getSpaces.sort.each do |space|
        if std.space_residential?(space)
          has_res = 'true'
        end
      end
      # Check whether space_residential? function is working
      has_res_goal = @@hasres_values[building_type]
      assert(has_res == has_res_goal, "Failure to set space_residential? for #{building_type}, #{template}, #{climate_zone}.")
    end
  end

  # Check envelope requirements lookups
  #
  # @param prototypes_base [Hash] Baseline prototypes
  #
  # TODO: Add residential and semi-heated spaces lookup
  def check_envelope(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join('_') unless mod.empty?

      # Define name of surfaces used for verification
      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod_str}"

      opaque_exterior_name = JSON.parse(File.read("#{@@json_dir}/envelope.json"))[run_id]['opaque_exterior_name']
      opaque_interior_name = JSON.parse(File.read("#{@@json_dir}/envelope.json"))[run_id]['opaque_interior_name']
      exterior_fenestration_name = JSON.parse(File.read("#{@@json_dir}/envelope.json"))[run_id]['exterior_fenestration_name']
      exterior_door_name = JSON.parse(File.read("#{@@json_dir}/envelope.json"))[run_id]['exterior_door_name']

      # Get U-value of envelope in baseline model
      std = Standard.build('90.1-PRM-2019')

      u_value_baseline = {}
      construction_baseline = {}
      opaque_exterior_name.each do |val|
        u_value_baseline[val[0]] = std.run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Opaque Exterior', val[0], 'U-Factor with Film', 'W/m2-K').to_f
        construction_baseline[val[0]] = std.run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Opaque Exterior', val[0], 'Construction', '').to_s
      end
      # @todo: we've identified an issue with the r-value for air film in EnergyPlus for semi-exterior surfaces:
      # https://github.com/NREL/EnergyPlus/issues/9470
      # todos were added in film_coefficients_r_value() since this is just a reporting issue, we're checking the
      # no film u-value for opaque interior surfaces
      opaque_interior_name.each do |val|
        u_value_baseline[val[0]] = std.run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Opaque Interior', val[0], 'U-Factor no Film', 'W/m2-K').to_f
        construction_baseline[val[0]] = std.run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Opaque Interior', val[0], 'Construction', '').to_s
      end
      exterior_fenestration_name.each do |val|
        u_value_baseline[val[0]] = std.run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Exterior Fenestration', val[0], 'Glass U-Factor', 'W/m2-K').to_f
        construction_baseline[val[0]] = std.run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Exterior Fenestration', val[0], 'Construction', '').to_s
      end
      exterior_door_name.each do |val|
        u_value_baseline[val[0]] = std.run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Exterior Door', val[0], 'U-Factor with Film', 'W/m2-K').to_f
        construction_baseline[val[0]] = std.run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Exterior Door', val[0], 'Construction', '').to_s
      end

      # Check U-value against expected U-value
      u_value_goal = opaque_exterior_name + opaque_interior_name + exterior_fenestration_name + exterior_door_name
      u_value_goal.each do |key, value|
        value_si = OpenStudio.convert(value, 'Btu/ft^2*hr*R', 'W/m^2*K').get
        assert(((u_value_baseline[key] - value_si).abs < 0.0015 || (u_value_baseline[key] - 5.835).abs < 0.01), "Baseline U-value for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The U-value of the #{key} is #{u_value_baseline[key]} but should be #{value_si.round(3)}.")
        assert((construction_baseline[key].include? 'PRM'), "Baseline U-value for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The construction of the #{key} is #{construction_baseline[key]}, which is not from PRM_Construction tab.")
      end
    end
  end

  def check_power_equipment_handling(prototypes_base)
    prototypes_base.each do |prototype_base, baseline_model|
      base_building_type, base_template, base_climate_Zone, base_user_data_dir, base_mod = prototype_base
      # user_data_dir match to identify matched propose and baseline
      if base_user_data_dir == 'userdata_pe_01'
        # test case 1, apply 5% RPC (0.5 * 0.1) to Office WholeBuilding -Sm Offie Elec Equip
        base_electric_equipment_schedules = baseline_model.getElectricEquipments[0].schedule.get.to_ScheduleRuleset.get.scheduleRules

        base_electric_equipment_schedules.each do |schedule_rule|
          receptacle_power_credits = schedule_rule.name.get.split('_')[1].to_f
          assert((0.05 - receptacle_power_credits).abs < 0.0001, "Building: #{base_building_type}; Template: #{base_template}; Climate: #{base_climate_Zone}. The receptacle_power_credits shall be 0.05 (5%) but get #{receptacle_power_credits}")
        end
      elsif base_user_data_dir == 'userdata_pe_02'
        # test case 2, apply 15% RPC (0.15) to Office WholeBuilding -Sm Offie Elec Equip
        base_electric_equipment_schedules = baseline_model.getElectricEquipments[0].schedule.get.to_ScheduleRuleset.get.scheduleRules

        base_electric_equipment_schedules.each do |schedule_rule|
          receptacle_power_credits = schedule_rule.name.get.split('_')[1].to_f
          assert((0.15 - receptacle_power_credits).abs < 0.0001, "Building: #{base_building_type}; Template: #{base_template}; Climate: #{base_climate_Zone}. The receptacle_power_credits shall be 0.15 (15%) but get #{receptacle_power_credits}")
        end
      elsif base_user_data_dir == 'userdata_pe_03'
        # test case 3, record motor horsepower, efficiency and whether it is exempt
        base_electric_equipment = baseline_model.getElectricEquipments[0]
        base_electric_equipment_ap = base_electric_equipment.additionalProperties
        assert(base_electric_equipment_ap.hasFeature('motor_horsepower') && base_electric_equipment_ap.getFeatureAsDouble('motor_horsepower').get == 10.0,
               "motor_horsepower data is missing or incorrect. The motor_horsepower for test case 3 shall be 10.0")
        assert(base_electric_equipment_ap.hasFeature('motor_efficiency') && base_electric_equipment_ap.getFeatureAsDouble('motor_efficiency').get == 0.72,
               "motor_efficiency data is missing or incorrect. The motor_efficiency for test case 3 shall be 0.72")
        assert(base_electric_equipment_ap.hasFeature('motor_is_exempt') && base_electric_equipment_ap.getFeatureAsString('motor_is_exempt').get == 'No',
               "motor_is_exempt data is missing or incorrect. The motor_is_exempt for test case 3 shall be No")
      elsif base_user_data_dir == 'userdata_pe_04'
        baseline_equipments = baseline_model.getElectricEquipments
        baseline_equipments.each do |equipment|
          baseline_equipment_name = equipment.name.get
          if baseline_equipment_name == 'Office WholeBuilding - Sm Office Elec Equip 4'
            base_electric_equipment_schedules = equipment.schedule.get.to_ScheduleRuleset.get.scheduleRules
            base_electric_equipment_schedules.each do |schedule_rule|
              receptacle_power_credits = schedule_rule.name.get.split('_')[1].to_f
              assert((0.025 - receptacle_power_credits).abs < 0.0001, "Building: #{base_building_type}; Template: #{base_template}; Climate: #{base_climate_Zone}. The receptacle_power_credits shall be 0.025 (5%) but get #{receptacle_power_credits}")
            end
          end
        end
      end
    end
  end

  # Implement multiple LPD handling from userdata by space, space type and default space_type
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_multi_lpd_handling(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype
      if user_data_dir == 'no_user_data'
        sub_prototypes_base = {}
        sub_prototypes_base[prototype] = model_baseline
        check_lpd(sub_prototypes_base)
      else
        if user_data_dir == 'userdata_lpd_01'
          space_name_to_lpd_target = {}
          space_name_to_lpd_target['Attic'] =15.06948107
          space_name_to_lpd_target['Perimeter_ZN_2'] =14.83267494
          space_name_to_lpd_target['Perimeter_ZN_1'] =15.26323154
          space_name_to_lpd_target['Perimeter_ZN_4'] =12.91669806

          model_baseline.getSpaces.each do |space|
            space_name = space.name.get
            target_lpd = 10.7639
            if space_name_to_lpd_target.key?(space_name)
              target_lpd = space_name_to_lpd_target[space_name]
            end
            lights_name = space.spaceType.get.additionalProperties.getFeatureAsString('regulated_lights_name').to_s
            lights_obj = model_baseline.getLightsByName(lights_name).get
            model_lpd = lights_obj.lightsDefinition.wattsperSpaceFloorArea.get
            # model_lpd = space.spaceType.get.lights[0].lightsDefinition.wattsperSpaceFloorArea.get
            assert((target_lpd - model_lpd).abs < 0.001, "Baseline LPD for the #{building_type}, #{template}, #{climate_zone} model with user data #{user_data_dir} is incorrect. The LPD of the #{space_name} is #{target_lpd} but should be #{model_lpd}.")
          end
        elsif user_data_dir == 'userdata_lpd_02'
          space_name_to_lpd_target = {}
          space_name_to_lpd_target['Attic'] = 0.0

          model_baseline.getSpaces.each do |space|
            space_name = space.name.get
            target_lpd = 12.2452724
            if space_name_to_lpd_target.key?(space_name)
              target_lpd = space_name_to_lpd_target[space_name]
            end
            lights_name = space.spaceType.get.additionalProperties.getFeatureAsString('regulated_lights_name').to_s
            lights_obj = model_baseline.getLightsByName(lights_name).get
            model_lpd = lights_obj.lightsDefinition.wattsperSpaceFloorArea.get
            assert((target_lpd - model_lpd).abs < 0.001, "Baseline U-value for the #{building_type}, #{template}, #{climate_zone} model with user data #{user_data_dir} is incorrect. The LPD of the #{space_name} is #{target_lpd} but should be #{model_lpd}.")
          end
        end
      end
    end
  end

  # Check LPD requirements lookups
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_lpd(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join('_') unless mod.empty?

      # Define name of spaces used for verification
      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod_str}"
      space_name = JSON.parse(File.read("#{@@json_dir}/lpd.json"))[run_id]

      std = Standard.build('90.1-PRM-2019')
      
      # Get LPD in baseline model
      lpd_baseline = {}
      space_name.each do |val|
        lpd_baseline[val[0]] = std.run_query_tabulardatawithstrings(model_baseline, 'LightingSummary', 'Interior Lighting', val[0], 'Lighting Power Density', 'W/m2').to_f
      end

      # Check LPD against expected LPD
      space_name.each do |key, value|
        value_si = OpenStudio.convert(value, 'W/ft^2', 'W/m^2').get
        assert(((lpd_baseline[key] - value_si).abs < 0.001), "Baseline U-value for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The LPD of the #{key} is #{lpd_baseline[key]} but should be #{value_si}.")
      end
    end
  end

  # Check exterior lighting via userdata
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_exterior_lighting(prototypes_base)

    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, mod = prototype

      if building_type == 'RetailStandalone'
        model.getExteriorLightss.each do |exterior_lights|
          ext_lights_def = exterior_lights.exteriorLightsDefinition
          if exterior_lights.name.get == "NonDimming Exterior Lights Def"
            design_power = ext_lights_def.designLevel.round(0)
            assert( design_power == 700, "The exterior lighting for 'NonDimming Exterior Lights Def' in #{building_type}-#{template} has incorrect power. Found: #{design_power}; expected 700.")
          end
          if exterior_lights.name.get == "Occ Sensing Exterior Lights Def"
            design_power = ext_lights_def.designLevel.round(0)
            assert(design_power == 4328, "The exterior lighting for 'Occ Sensing Exterior Lights Def' #{building_type}-#{template} has incorrect power. Found: #{design_power}; expected 4328.")
          end
        end

      end
    end
  end


  def check_lighting_exceptions(prototypes_base)
    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      if building_type == 'RetailStripmall'
        # check if nonregulate lights objects still exist
        found_obj_1 = false
        found_obj_2 = false
        model.getLightss.each do |lights|
          lights_def = lights.lightsDefinition
          actual_w_area = lights_def.wattsperSpaceFloorArea.to_f
          # Check if non-regulated lights objects have been removed
          if lights.name.get == "StripMall Strip mall - type 1 Additional Lights"
            found_obj_1 = true
          end
          if lights.name.get == "StripMall Strip mall - type 2 Additional Lights"
            found_obj_2 = true
          end

          # Check power level of regulated lights objects
          if lights.name.get == "StripMall Strip mall - type 1 Lights"
            expected_w_area = 16.1458656250646
            assert( expected_w_area.round(3) == actual_w_area.round(3), "The incorrect lighting power for #{lights.name.get} in #{building_type}-#{template}.")
          end
          if lights.name.get == "StripMall Strip mall - type 1 Lights"
            expected_w_area = 16.1458656250646
            assert( expected_w_area.round(3) == actual_w_area.round(3), "The incorrect lighting power for #{lights.name.get} in #{building_type}-#{template}.")
          end
          if lights.name.get == "StripMall Strip mall - type 2 Lights"
            expected_w_area = 16.1458656250646
            assert( expected_w_area.round(3) == actual_w_area.round(3), "The incorrect lighting power for #{lights.name.get} in #{building_type}-#{template}.")
          end
          if lights.name.get == "StripMall Strip mall - type 3 Lights"
            expected_w_area = 16.1458656250646
            assert( expected_w_area.round(3) == actual_w_area.round(3), "The incorrect lighting power for #{lights.name.get} in #{building_type}-#{template}.")
          end

        end
        assert( found_obj_1 == true, "The retail display lighting exception user data for in #{building_type}-#{template} has failed to preserve the lights object.")
        assert( found_obj_2 == true, "The unregulated lighting exception user data for in #{building_type}-#{template} has failed to preserve the lights object.")
      end
    end
  end

  #
  # testing method for night cycling control exceptions
  #
  # @param prototypes_base [Hash] Baseline prototypes
  #
  def check_nightcycle_exception(prototypes_base)
    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      if building_type == 'MediumOffice'
        # check for night cycle on lower level
        thermal_zone = model.getThermalZoneByName('Core_bottom ZN').get
        air_loop = thermal_zone.airLoopHVAC.get
        fan_schedule_name = air_loop.availabilitySchedule.name.get
        assert(fan_schedule_name.include?("Always"), "Night cycle exception failed for #{building_type}-#{template}.")
      end
    end
  end
 
  #
  # testing for exhaust air energy recovery requirement: general requirement and one exception
  #
  # @param prototypes_base [Hash] Baseline prototypes
  #
  def check_exhaust_air_energy(prototypes_base)
    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, user_data_dir, mod = prototype
        hxs = model.getHeatExchangerAirToAirSensibleAndLatents
        if hxs.length > 0
          assert(false, "The baseline model for #{building_type}-#{template}-#{climate_zone} should not contain ERVs.") unless user_data_dir == 'userdata_default_test'
          hxs.each do |hx|
            if climate_zone.include?('4A')
              assert(hx.sensibleEffectivenessat100HeatingAirFlow.round(2) == 0.67, "The baseline model for #{building_type}-#{template} does not have the correct effectiveness values.")
              assert(hx.sensibleEffectivenessat100CoolingAirFlow.round(2) == 0.66, "The baseline model for #{building_type}-#{template} does not have the correct effectiveness values.")
              assert(hx.latentEffectivenessat75HeatingAirFlow.round(2) == 0.50, "The baseline model for #{building_type}-#{template} does not have the correct effectiveness values.")
              assert(hx.latentEffectivenessat75CoolingAirFlow.round(2) == 0.45, "The baseline model for #{building_type}-#{template} does not have the correct effectiveness values.")
            elsif climate_zone.include?('8A')
              assert(hx.sensibleEffectivenessat100HeatingAirFlow.round(2) == 0.50, "The baseline model for #{building_type}-#{template} does not have the correct effectiveness values.")
              assert(hx.sensibleEffectivenessat100CoolingAirFlow.round(2) == 0.50, "The baseline model for #{building_type}-#{template} does not have the correct effectiveness values.")
              assert(hx.latentEffectivenessat75HeatingAirFlow.round(2) == 0.0, "The baseline model for #{building_type}-#{template} does not have the correct effectiveness values.")
              assert(hx.latentEffectivenessat75CoolingAirFlow.round(2) == 0.0, "The baseline model for #{building_type}-#{template} does not have the correct effectiveness values.")
            end
          end
        else
          assert(false, "The baseline model for #{building_type}-#{template}-#{climate_zone} should contain ERVs.") unless user_data_dir == 'userdata_erv_except_01'
        end
    end
  end

  #
  # testing baseline elevator implementation
  #
  # @param prototypes_base [Hash] Baseline prototypes
  #
  def check_elevators(prototypes_base)
    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      if building_type == 'MediumOffice'
        if user_data_dir.include?('hydraulic')
          elevators = model.getElectricEquipmentByName('2 Elevator Lift Motors').get.electricEquipmentDefinition
          elevators_power = elevators.designLevel.get.round(1)
          assert(elevators_power == 37976.6, "The baseline model elevator power for #{building_type}-#{template}-#{climate_zone} is incorrect, it was  #{elevators_power} instead of 37976.6.")
          elevators_process_loads = model.getElectricEquipmentByName('2 Elevator Lift Motors - Misc Process Loads').get.electricEquipmentDefinition
          elevators_process_loads_power = elevators_process_loads.designLevel.get.round(1)
          assert(elevators_process_loads_power == 408.5, "The baseline model elevator process loads power for #{building_type}-#{template}-#{climate_zone} is incorrect, it was  #{elevators_power} instead of 408.5.")
        else
          elevators = model.getElectricEquipmentByName('2 Elevator Lift Motors').get.electricEquipmentDefinition
          elevators_power = elevators.designLevel.get.round(1)
          assert(elevators_power == 8524.6, "The baseline model elevator power for #{building_type}-#{template}-#{climate_zone} is incorrect, it was  #{elevators_power} instead of 8524.6.")
        end
      end
    end
  end

  #
  # testing method for PRM 2019 baseline HVAC sizing, specific testing objectives are commented inline
  #
  # @param prototypes_base [Hash] Baseline prototypes
  #
  def check_hvac_sizing(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      # check sizing parameters (G3.1.2.2)
      sizing_parameters = model_baseline.getSizingParameters
      assert((sizing_parameters.coolingSizingFactor - 1.15).abs < 0.001, "Baseline cooling sizing parameters for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The cooling sizing parameter is #{sizing_parameters.coolingSizingFactor} but should be 1.15")
      assert((sizing_parameters.heatingSizingFactor - 1.25).abs < 0.001, "Baseline cooling sizing parameters for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The heating sizing parameter is #{sizing_parameters.heatingSizingFactor} but should be 1.25")

      # check sizing schedules for loads are correct (min/max) (G3.1.2.2.1 and exception)
      check_sizing_values(model_baseline, building_type, template, climate_zone)

      # check delta t between supply air temperature set point and room temperature set point are 20 deg (exception of 17 deg for laboratory spaces) (G3.1.2.8.1 and exception)
      # including checking unit heater supply air temperature set point of 105 deg (G3.1.2.8.2)
      check_sizing_delta_t(model_baseline, building_type, template, climate_zone)
    end
  end

  #
  # this checks the PRM baseline sizing requirement of supply air temperature delta T
  #
  # @param model [OpenStudio::Model::model] openstudio model object
  # @param building_type [String]  building type
  # @param template [String] template name
  # @param climate_zone [<Type>] climate zone name
  #
  def check_sizing_delta_t(model, building_type, template, climate_zone)
    std = Standard.build('90.1-PRM-2019')
    model.getThermalZones.each do |thermal_zone|
      delta_t_r = 20
      thermal_zone.spaces.each do |space|
        space_std_type = space.spaceType.get.standardsSpaceType.get
        if space_std_type == 'laboratory'
          delta_t_r = 17
        end
      end

      schedule_types = [
        'Ruleset',
        'Constant',
        'Compact'
      ]

      # cooling delta t
      if std.thermal_zone_cooled?(thermal_zone)
        case thermal_zone.sizingZone.zoneCoolingDesignSupplyAirTemperatureInputMethod
        when 'SupplyAirTemperatureDifference'
          assert((thermal_zone.sizingZone.zoneCoolingDesignSupplyAirTemperatureDifference - delta_t_r).abs < 0.001, "supply to room cooling temperature difference for #{thermal_zone.name} in the #{building_type}, #{template}, #{climate_zone} model is incorrect. It is #{thermal_zone.sizingZone.zoneCoolingDesignSupplyAirTemperatureDifference}, but should be #{delta_t_r}")
        when 'SupplyAirTemperature'
          setpoint_c = nil
          tstat = thermal_zone.thermostatSetpointDualSetpoint
          if tstat.is_initialized
            tstat = tstat.get
            setpoint_sch = tstat.coolingSetpointTemperatureSchedule
            if setpoint_sch.is_initialized
              setpoint_sch = setpoint_sch.get
              schedule_types.each do |schedule_type|
                full_objtype_name = "OS_Schedule_#{schedule_type}"
                if full_objtype_name == setpoint_sch.iddObjectType.valueName.to_s
                  setpoint_sch = setpoint_sch.public_send("to_Schedule#{schedule_type}").get
                  # reuse code in Standards.ThermalZone to find tstat max temperature
                  setpoint_c = std.public_send("schedule_#{schedule_type.downcase}_annual_min_max_value", setpoint_sch)['min']
                  break
                end
              end
            end
          end
          if setpoint_c.nil?
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "#{thermal_zone.name} does not have a valid cooling supply air temperature setpoint identified .")
          else
            assert(((thermal_zone.sizingZone.zoneCoolingDesignSupplyAirTemperature - setpoint_c).abs - delta_t_r / 9.0 * 5).abs < 0.001, "supply to room cooling temperature difference for #{thermal_zone.name} in the #{building_type} #{template}, #{climate_zone} model is incorrect. It is #{(thermal_zone.sizingZone.zoneCoolingDesignSupplyAirTemperature - setpoint_c).abs}, but should be #{delta_t_r}.")
          end
        end
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.Standards.ThermalZone', "#{thermal_zone.name} is not a cooled zone, skip cooling supply air temperature set point difference test.")
      end

      thermal_zone.equipment.each do |eqt|
        if eqt.to_ZoneHVACUnitHeater.is_initialized
          next # skip checking the heating delta t if the zone has a unit heater.
        end
      end

      # heating delta t
      if std.thermal_zone_heated?(thermal_zone)
        has_unit_heater = false
        # 90.1 Appendix G G3.1.2.8.2
        thermal_zone.equipment.each do |eqt|
          if eqt.to_ZoneHVACUnitHeater.is_initialized
            setpoint_c = OpenStudio.convert(105, 'F', 'C').get
            has_unit_heater = true
          end
        end
        if has_unit_heater
          assert((thermal_zone.sizingZone.zoneHeatingDesignSupplyAirTemperature - setpoint_c).abs < 0.001, "heating design supply air temperature for #{thermal_zone.name} in the #{building_type} #{template}, #{climate_zone} model is incorrect. For zones with unit heaters, heating design supply air temperature should be #{setpoint_c} (90.1 Appendix G3.1.2.8.2)")
        else
          case thermal_zone.sizingZone.zoneHeatingDesignSupplyAirTemperatureInputMethod
          when 'SupplyAirTemperatureDifference'
            assert((thermal_zone.sizingZone.zoneHeatingDesignSupplyAirTemperatureDifference - delta_t_r).abs < 0.001, "supply to room heating temperature difference for #{thermal_zone.name} in the #{building_type}, #{template}, #{climate_zone} model is incorrect. It is #{thermal_zone.sizingZone.zoneHeatingDesignSupplyAirTemperatureDifference}, but should be #{delta_t_r}.")
          when 'SupplyAirTemperature'
            setpoint_c = nil
            tstat = thermal_zone.thermostatSetpointDualSetpoint
            if tstat.is_initialized
              tstat = tstat.get
              setpoint_sch = tstat.heatingSetpointTemperatureSchedule
              if setpoint_sch.is_initialized
                setpoint_sch = setpoint_sch.get
                schedule_types.each do |schedule_type|
                  full_objtype_name = "OS_Schedule_#{schedule_type}"
                  if full_objtype_name == setpoint_sch.iddObjectType.valueName.to_s
                    setpoint_sch = setpoint_sch.public_send("to_Schedule#{schedule_type}").get
                    # reuse code in Standards.ThermalZone to find tstat max temperature
                    setpoint_c = std.public_send("schedule_#{schedule_type.downcase}_annual_min_max_value", setpoint_sch)['max']
                    break
                  end
                end
              end
            end
            if setpoint_c.nil?
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "#{thermal_zone.name} does not have a valid heating supply air temperature setpoint identified.")
            else
              assert(((thermal_zone.sizingZone.zoneHeatingDesignSupplyAirTemperature - setpoint_c).abs - delta_t_r / 9.0 * 5).abs < 0.001, "supply to room heating temperature difference for #{thermal_zone.name} in the #{building_type} #{template}, #{climate_zone} model is incorrect. It is #{(thermal_zone.sizingZone.zoneHeatingDesignSupplyAirTemperature - setpoint_c).abs}, but should be #{delta_t_r}.")
            end
          end
        end
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.Standards.ThermalZone', "#{thermal_zone.name} is not a heated zone, skip heating supply air temperature set point difference test.")
      end
    end
  end

  #
  # this check uses very similar code to the one that implements this requirement
  #
  # @param model [OpenStudio::model::Model] openstudio model object
  # @param building_type [String]  building type
  # @param template [String] template name
  # @param climate_zone [<Type>] climate zone name
  #
  def check_sizing_values(model, building_type, template, climate_zone)
    space_loads = model.getSpaceLoads
    loads = []
    space_loads.sort.each do |space_load|
      load_type = space_load.iddObjectType.valueName.sub('OS_', '').strip.sub('_', '')
      casting_method_name = "to_#{load_type}"
      if space_load.respond_to?(casting_method_name)
        casted_load = space_load.public_send(casting_method_name).get
        loads << casted_load
      else
        p 'Need Debug, casting method not found @JXL'
      end
    end

    std_prm = ASHRAE901PRM.build('90.1-PRM-2019')

    load_schedule_name_hash = {
      'People' => 'numberofPeopleSchedule',
      'Lights' => 'schedule',
      'ElectricEquipment' => 'schedule',
      'GasEquipment' => 'schedule',
      'SpaceInfiltration_DesignFlowRate' => 'schedule'
    }

    loads.each do |load|
      load_type = load.iddObjectType.valueName.sub('OS_', '').strip
      load_schedule_name = load_schedule_name_hash[load_type]
      next unless !load_schedule_name.nil?

      # check if the load is in a dwelling space
      if load.spaceType.is_initialized
        space_type = load.spaceType.get
      elsif load.space.is_initialized && load.space.get.spaceType.is_initialized
        space_type = load.space.get.spaceType.get
      else
        space_type = nil
        puts "No hosting space/spacetype found for load: #{load.name}"
      end
      if !space_type.nil? && /apartment/i =~ space_type.standardsSpaceType.to_s
        load_in_dwelling = true
      else
        load_in_dwelling = false
      end

      load_schedule = load.public_send(load_schedule_name).get
      schedule_type = load_schedule.iddObjectType.valueName.sub('OS_', '').strip.sub('_', '')
      load_schedule = load_schedule.public_send("to_#{schedule_type}").get

      case schedule_type
      when 'ScheduleRuleset'
        load_schmax = std_prm.get_8760_values_from_schedule(model, load_schedule).max
        load_schmin = std_prm.get_8760_values_from_schedule(model, load_schedule).min
        load_schmode = std_prm.get_weekday_values_from_8760(model,
                                                            Array(std_prm.get_8760_values_from_schedule(model, load_schedule)),
                                                            value_includes_holiday = true).mode[0]

        # AppendixG-2019 G3.1.2.2.1
        if load_type == 'SpaceInfiltration_DesignFlowRate'
          summer_value = load_schmax
          winter_value = load_schmax
        else
          summer_value = load_schmax
          winter_value = load_schmin
        end

        # AppendixG-2019 Exception to G3.1.2.2.1
        if load_in_dwelling
          summer_value = load_schmode
        end

        summer_dd_schedule = load_schedule.summerDesignDaySchedule
        assert((summer_dd_schedule.times[0] == OpenStudio::Time.new(1.0) && (summer_dd_schedule.values[0] - summer_value).abs < 0.001), "Baseline cooling sizing schedule for load #{load.name} in the #{building_type}, #{template}, #{climate_zone} model is incorrect.")

        winter_dd_schedule = load_schedule.winterDesignDaySchedule
        assert((winter_dd_schedule.times[0] == OpenStudio::Time.new(1.0) && (winter_dd_schedule.values[0] - winter_value).abs < 0.001), "Baseline heating sizing schedule for load #{load.name} in the #{building_type}, #{template}, #{climate_zone} model is incorrect.")

      when 'ScheduleConstant'
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Space load #{load.name} has schedule type of ScheduleConstant. Nothing to be done for ScheduleConstant")
        next
      end
    end
  end

  def check_dcv(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mods = prototype

      # to simplify testing procedures, for all test cases below, the following are true
      #   - zone area is larger than 500 sqft
      #   - air loop has economizer

      tc_ids = nil
      mods.each do |mod|
        if mod[0] == 'mark_test_case_no'
          tc_ids = mod[1]
        end
      end
      if tc_ids.nil?
        assert(false, 'mark_test_case_no mod not set, cannot proceed with DCV test check_dcv')
      end

      tc_ids.each do |tc_id|
        case tc_id
        when 1
          # test case 1:
          #   - DCV should be in the user model (zone ppl density > 25 ppl/ksqft, no user exception)
          #   - DCV should be in the baseline (air loop oa flow > 3000 cfm && zone ppl density > 100 ppl/ksqft)
          #   - DCV is implemented in user model
          # expected result: baseline implements DCV
          # test case setting:
          #   - Cafeteria
          #   - user model air loop oa flow 3153 cfm
          #   - no user data needed
          #   - zone ppl density 101 [through ppl density modifier]
          #   - DCV implemented in the user model
          #     - at the airloop level [through modifier]
          #     - at the zone level, zone oa spec per person 0.003539605824
          zone = model_baseline.getThermalZoneByName('Cafeteria_ZN_1_FLR_1 ZN').get
          airloop = zone.airLoopHVAC.get
          assert(dcv_is_on(zone, airloop))

        when 2
          # test case 2:
          #   - DCV should not be in the user model (zone ppl density > 25 ppl/ksqft, but has ZONE user exception)
          #   - DCV should be in the baseline (air loop oa flow > 3000 cfm && zone ppl density > 100 ppl/ksqft)
          #   - DCV is implemented in user model
          # expected result: baseline implements DCV but prompts warning (user model has DCV but meet exception)
          # test case setting:
          #   - Cafeteria
          #   - user model air loop oa flow 3153 cfm
          #   - zone ppl density 101 [through ppl density modifier]
          #   - user data specifies ZONE DCV exception is true
          #   - DCV implemented in the user model
          #     - at the airloop level [through modifier]
          #     - at the zone level, zone oa spec per person 0.003539605824
          zone = model_baseline.getThermalZoneByName('Cafeteria_ZN_1_FLR_1 ZN').get
          airloop = zone.airLoopHVAC.get
          # check warning
          assert(dcv_is_on(zone, airloop))

        when 3
          # test case 3:
          #   - DCV should be in the user model (zone ppl density > 25 ppl/ksqft, no user exception)
          #   - DCV should be in the baseline model (air loop oa flow > 3000 cfm && zone ppl density > 100 ppl/ksqft)
          #   - DCV is NOT implemented in user model
          # expected result: error and terminate
          # test case setting:
          #   - Cafeteria
          #   - user model air loop oa flow 3153 cfm
          #   - zone ppl density 101 [through ppl density modifier]
          #   - no user data
          #   - DCV not implemented in the user model
          #     - at the airloop level by default
          #     - at the zone level [through remove_zone_oa_per_person_spec modifier] (optional)
          zone = model_baseline.getThermalZoneByName('Cafeteria_ZN_1_FLR_1 ZN').get
          airloop = zone.airLoopHVAC.get
          # check error and terminate
          assert(!dcv_is_on(zone, airloop))

        when 4
          # test case 4:
          #   - DCV should not be in the user model (zone ppl density > 25 ppl/ksqft, but has AIR LOOP user exception)
          #   - DCV should be in the baseline model (air loop oa flow > 3000 cfm && zone ppl density > 100 ppl/ksqft)
          #   - DCV is NOT implemented in user model
          # expected result: no DCV in baseline model
          # test case setting:
          #   - Cafeteria
          #   - user model air loop oa flow 3153 cfm
          #   - zone ppl density 101 [through ppl density modifier]
          #   - user data specifies AIR LOOP DCV exception is true
          #   - DCV not implemented in the user model
          #     - at the airloop level by default
          #     - at the zone level [through remove_zone_oa_per_person_spec modifier] (optional)
          zone = model_baseline.getThermalZoneByName('Cafeteria_ZN_1_FLR_1 ZN').get
          airloop = zone.airLoopHVAC.get
          assert(!dcv_is_on(zone, airloop))

        when 5
          # test 5
          #   - DCV should be in the user model (zone ppl density > 25 ppl/ksqft, no user exception)
          #   - DCV should NOT be in the baseline model (air loop oa flow < 3000 cfm || zone ppl density < 100 ppl/ksqft)
          #   - DCV is implmented in user model
          # expected result: no DCV in baseline model
          # test case setting:
          #   - Cafeteria
          #   - user model air loop oa flow 3153 cfm
          #   - zone ppl density 99.99
          #   - no user exception
          #   - DCV implemented in the user model
          #     - at the airloop level [through modifier]
          #     - at the zone level, zone oa spec per person 0.003539605824
          zone = model_baseline.getThermalZoneByName('Cafeteria_ZN_1_FLR_1 ZN').get
          airloop = zone.airLoopHVAC.get
          assert(!dcv_is_on(zone, airloop))

        when 6
          # test 6
          #   - DCV should NOT be in the user model (zone ppl density > 25 ppl/ksqft, but has ZONE user exception)
          #   - DCV should NOT be in the baseline model (air loop oa flow < 3000 cfm || zone ppl density < 100 ppl/ksqft)
          #   - DCV is NOT implemented in user model
          # expected result: NO DCV in baseline model
          # test case setting:
          #   - Cafeteria
          #   - user model air loop oa flow 3153 cfm
          #   - zone ppl density 99.99
          #   - user data specifies ZONE DCV exception is true
          #   - DCV NOT implemented in the user model
          #     - at the airloop level by default
          #     - at the zone level [through remove_zone_oa_per_person_spec modifier] (optional)
          zone = model_baseline.getThermalZoneByName('Cafeteria_ZN_1_FLR_1 ZN').get
          airloop = zone.airLoopHVAC.get
          assert(!dcv_is_on(zone, airloop))

        when 7
          # test 7
          #   - DCV should NOT be in the user model (zone ppl density < 25 ppl/ksqft)
          #   - DCV should NOT be in the baseline model (air loop oa flow < 3000 cfm || zone ppl density < 100 ppl/ksqft)
          #   - DCV is implemented in user model
          # expected result: no DCV in baseline model
          # test case setting:
          #   - Kitchen
          #   - user model air loop oa flow 528 cfm
          #   - zone ppl density 14.93
          #   - no user exception
          #   - DCV implemented in the user model
          #     - at the airloop level [through modifier]
          #     - at the zone level, zone oa spec per person 0.003539605824
          zone = model_baseline.getThermalZoneByName('Kitchen_ZN_1_FLR_1 ZN').get
          airloop = zone.airLoopHVAC.get
          assert(!dcv_is_on(zone, airloop))

        when 8
          # test 8
          #   - DCV should NOT be in the user model (zone ppl denstiy < 25 ppl/ksqft)
          #   - DCV should NOT be in the baseline model (air loop oa flow < 3000 cfm || zone ppl density < 100 ppl/ksqft)
          #   - DCV is NOT implemented in user model
          # expected result: no DCV in baseline model
          # test case setting:
          #   - Kitchen
          #   - user model air loop oa flow 528 cfm
          #   - zone ppl density 14.93
          #   - no user exception
          #   - DCV not implemented in the user model
          #     - at the airloop level by default
          #     - at the zone level [through remove_zone_oa_per_person_spec modifier] (optional)
          zone = model_baseline.getThermalZoneByName('Kitchen_ZN_1_FLR_1 ZN').get
          airloop = zone.airLoopHVAC.get
          assert(!dcv_is_on(zone, airloop))
        else
          assert(false, "ERROR! #{tc_id} not a valid test case id for check_dcv")
        end
      end
    end
  end

  def dcv_is_on(thermal_zone, air_loop_hvac)
    # check air loop level DCV enabled
    return false unless air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized

    oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
    controller_oa = oa_system.getControllerOutdoorAir
    controller_mv = controller_oa.controllerMechanicalVentilation
    return false unless controller_mv.demandControlledVentilation == true

    # check zone OA flow per person > 0
    zone_dcv = false
    thermal_zone.spaces.each do |space|
      dsn_oa = space.designSpecificationOutdoorAir
      next if dsn_oa.empty?

      dsn_oa = dsn_oa.get
      next if dsn_oa.outdoorAirMethod == 'Maximum'

      if dsn_oa.outdoorAirFlowperPerson > 0
        # only in this case the thermal zone is considered to be implemented with DCV
        zone_dcv = true
      end
    end

    return zone_dcv
  end

  # This assigns the test case index for the DCV unit tests
  # @param arguments [array of string] list of test case identifiers
  def mark_test_case_no(model, arguments)
    arguments
    return model
  end

  def remove_zone_oa_per_person_spec(model, arguments)
    std = Standard.build('90.1-PRM-2019')
    # argument contains a list of zone names to remove oa per person specification
    arguments.each do |zone_name|
      thermal_zone = model.getThermalZoneByName(zone_name).get
      std.thermal_zone_convert_oa_req_to_per_area(thermal_zone)
    end
    return model
  end

  def enable_airloop_dcv(model, arguments)
    # arguments contains a list of air loop names to enable dcv
    arguments.each do |air_loop_name|
      air_loop_hvac = model.getAirLoopHVACByName(air_loop_name).get
      # following logic is adopted from Standard.air_loop_hvac_enable_demand_control_ventilation
      controller_oa = nil
      controller_mv = nil
      if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
        oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
        controller_oa = oa_system.getControllerOutdoorAir
        controller_mv = controller_oa.controllerMechanicalVentilation
      end
      # Change the min flow rate in the controller outdoor air
      controller_oa.setMinimumOutdoorAirFlowRate(0.0)

      # Enable DCV in the controller mechanical ventilation
      controller_mv.setDemandControlledVentilation(true)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Enabled DCV.")
    end
    return model
  end

  def change_zone_num_ppl(model, arguments)
    # arguments contains an array with two elements, of which the first element is thermal zone name,
    # the second element is the number of people this zone is modified to
    zone_name, num_ppl = arguments
    thermal_zone = model.getThermalZoneByName(zone_name).get
    space0 = thermal_zone.spaces[0] # assume only change number of people in the first space
    space0.setNumberOfPeople(num_ppl)
    return model
  end

  # Check lighting occ sensor
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_light_occ_sensor(prototypes, prototypes_base)
    light_sch = {}
    prototypes.each do |prototype, model_proto|
      building_type, template, climate_zone, user_data_dir, mod = prototype
      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod}"
      # Define name of spaces used for verification
      space_name = JSON.parse(File.read("#{@@json_dir}/light_occ_sensor.json"))[run_id]

      # Get lighting schedule in prototype model
      light_sch_model = {}
      model_proto.getLightss.sort.each do |lgts|
        light_sch_model_lgts = {}

        # get default schedule
        day_rule = lgts.schedule.get.to_ScheduleRuleset.get.defaultDaySchedule
        times = day_rule.times()
        light_sch_model_default_rule = {}
        times.each do |time|
          light_sch_model_default_rule[time.to_s] = day_rule.getValue(time)
        end
        light_sch_model_lgts['default schedule'] = light_sch_model_default_rule

        # get daily schedule
        lgts.schedule.get.to_ScheduleRuleset.get.scheduleRules.each do |week_rule|
          light_sch_model_week_rule = {}
          day_rule = week_rule.daySchedule
          times = day_rule.times()
          times.each do |time|
            light_sch_model_week_rule[time.to_s] = day_rule.getValue(time)
          end
          light_sch_model_lgts[week_rule.name.to_s] = light_sch_model_week_rule
        end
        light_sch_model[lgts.name.to_s] = light_sch_model_lgts
      end
      light_sch[run_id] = light_sch_model
    end

    light_sch_base = {}
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype
      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod}"
      # Define name of spaces used for verification
      space_name = JSON.parse(File.read("#{@@json_dir}/light_occ_sensor.json"))[run_id]

      # Get lighting schedule in baseline model
      model_baseline.getSpaceTypes.sort.each do |space_type|
        light_sch_model_base = {}
        space_type.lights.sort.each do |lgts|
          if lgts.schedule.get.to_ScheduleRuleset.is_initialized
            light_sch_model_lgts_base = {}
            light_sch_model_lgts_base['space_type'] = space_type.standardsSpaceType.to_s

            # get default schedule
            day_rule = lgts.schedule.get.to_ScheduleRuleset.get.defaultDaySchedule
            times = day_rule.times()
            light_sch_model_default_rule = {}
            times.each do |time|
              light_sch_model_default_rule[time.to_s] = day_rule.getValue(time)
            end
            light_sch_model_lgts_base['default schedule'] = light_sch_model_default_rule

            # get daily schedule
            lgts.schedule.get.to_ScheduleRuleset.get.scheduleRules.each do |week_rule|
              light_sch_model_week_rule_base = {}
              day_rule = week_rule.daySchedule
              times = day_rule.times()
              times.each do |time|
                light_sch_model_week_rule_base[time.to_s] = day_rule.getValue(time)
              end
              light_sch_model_lgts_base[week_rule.name.to_s] = light_sch_model_week_rule_base
            end
            light_sch_model_base[lgts.name.to_s] = light_sch_model_lgts_base
          end
        end

        # Check light schedule against expected light schedule
        light_sch_model_base.each do |key, value|
          value.each do |key1, value1|
            if key1 != 'space_type'
              value1.each do |key2, value2|
                space_type_var = 0
                # get the lpd for the space type from preset values
                space_name.each do |key3, value3|
                  if value['space_type'] == key3
                    space_type_var = value3
                  end
                end
                if value2 < 0
                  assert(((light_sch[run_id][key][key1][key2] - value2 * (1.0 - space_type_var)).abs < 0.001), "Lighting schedule for the #{building_type}, #{template}, #{climate_zone} model is incorrect.")
                end
              end
            end
          end
        end
      end
    end
  end

  # Check baseline infiltration calculations
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_infiltration(prototypes, prototypes_base)
    std = Standard.build('90.1-PRM-2019')
    space_env_areas = JSON.parse(File.read("#{@@json_dir}/space_envelope_areas.json"))

    # Check that the model_get_infiltration_method and
    # model_get_infiltration_coefficients method retrieve
    # the correct information
    model_blank = OpenStudio::Model::Model.new
    infil_object = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model_blank)
    infil_object.setFlowperExteriorWallArea(0.001)
    infil_object.setConstantTermCoefficient(0.002)
    infil_object.setTemperatureTermCoefficient(0.003)
    infil_object.setVelocityTermCoefficient(0.004)
    infil_object.setVelocitySquaredTermCoefficient(0.005)
    new_space = OpenStudio::Model::Space.new(model_blank)
    infil_object.setSpace(new_space)
    assert(infil_object.designFlowRateCalculationMethod.to_s == std.model_get_infiltration_method(model_blank), 'Error in infiltration method retrieval.')
    assert(std.model_get_infiltration_coefficients(model_blank) == [infil_object.constantTermCoefficient,
                                                                    infil_object.temperatureTermCoefficient,
                                                                    infil_object.velocityTermCoefficient,
                                                                    infil_object.velocitySquaredTermCoefficient], 'Error in infiltration coeffcient retrieval.')

    # Retrieve space envelope area for input prototypes
    prototypes_spc_area_calc = {}
    prototypes.each do |prototype, model|
      building_type, template, climate_zone, user_data_dir, mod = prototype
      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod}"

      # Get space envelope area
      spc_env_area = 0
      model.getSpaces.sort.each do |spc|
        spc_env_area += std.space_envelope_area(spc, climate_zone)
      end

      prototypes_spc_area_calc[prototype] = spc_env_area
    end

    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join('_') unless mod.empty?

      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod_str}"

      # Check if the space envelope area calculations
      spc_env_area = 0
      model.getSpaces.sort.each do |spc|
        spc_env_area += std.space_envelope_area(spc, climate_zone)
      end
      assert((space_env_areas[run_id].to_f - spc_env_area.round(2)).abs < 0.001, "Space envelope calculation is incorrect for the #{building_type}, #{template}, #{climate_zone} model: #{spc_env_area.round(2)} (model) vs. #{space_env_areas[run_id]} (expected).")

      # Check that infiltrations are not assigned at
      # the space type level
      model.getSpaceTypes.sort.each do |spc|
        assert(false, "The baseline for the #{building_type}, #{template}, #{climate_zone} model has infiltration specified at the space type level.") unless spc.spaceInfiltrationDesignFlowRates.empty?
      end

      # Back calculate the I_75 (cfm/ft2), expected value is 1 cfm/ft2 in 90.1-PRM-2019
      # Use input prototype's space envelope area because, even though the baseline model space
      # conditioning can be different, 90.1-2019 Appendix G specified that:
      # "The baseline building design shall be modeled with the same number of floors and
      # identical conditioned floor area as the proposed design."
      # So it is assumed that the baseline space conditioning category shall be the same as the proposed.
      conv_fact = OpenStudio.convert(1, 'm^3/s', 'ft^3/min').to_f / OpenStudio.convert(1, 'm^2', 'ft^2').to_f
      assert((std.model_current_building_envelope_infiltration_at_75pa(model, prototypes_spc_area_calc[prototype]) * conv_fact).round(2) == 1.0, 'The baseline air leakage rate of the building envelope at a fixed building pressure of 75 Pa is different that the requirement (1 cfm/ft2).')
    end
  end

  # Check if the hvac baseline system from 5 to 13 has the HW and CHW reset control
  # Expected outcome
  #@param prototypes_base[Hash] Baseline prototypes
  def check_hw_chw_reset(prototypes_base)

    # check if the numbers are correct
    chw_low_temp = 15.5
    chw_low_temp_reset = 12.2
    chw_high_temp = 26.7
    chw_high_temp_reset = 6.6
    hw_low_temp = -6.7
    hw_low_temp_reset = 82.2
    hw_high_temp = 10.0
    hw_high_temp_reset = 65.5

    prototypes_base.each do |prototype, baseline_model|
      building_type, template, climate_zone, user_data_dir, mode = prototype

      if baseline_model.getPlantLoops.empty?
        assert(building_type != "SmallOffice", "No Plant Loop found in the baseline model #{building_type}, #{template}, #{climate_zone}, failure to generate plant loop")
      end

      # first check if the baseline_model has water loops or not (SHW is not included)
      baseline_model.getPlantLoops.sort.each do |plant_loop|
        # Skip the SWH loops
        next if Standard.new.plant_loop_swh_loop?(plant_loop)
        baseline_model.getSetpointManagerOutdoorAirResets.each do |oa_reset|
          name = oa_reset.name.to_s
          if name.end_with?("CHW Temp Reset")
            low_temp = oa_reset.outdoorLowTemperature
            assert(((low_temp - chw_low_temp).abs < 0.1), "Baseline #{building_type}, #{template}, #{climate_zone} has incorrect temperature reset value. The outdoor low temperature for the loop #{name} shall be #{chw_low_temp}, but this value is #{low_temp}")
            low_temp_reset = oa_reset.setpointatOutdoorLowTemperature
            assert(((low_temp_reset - chw_low_temp_reset).abs < 0.1), "Baseline #{building_type}, #{template}, #{climate_zone} has incorrect temperature reset value. The setpoint at outdoor low temperature for the loop #{name} shall be #{chw_low_temp_reset}, but this value is #{low_temp_reset}")
            high_temp = oa_reset.outdoorHighTemperature
            assert(((high_temp - chw_high_temp).abs < 0.1), "Baseline #{building_type}, #{template}, #{climate_zone} has incorrect temperature reset value. The outdoor high temperature for the loop #{name} shall be #{chw_high_temp}, but this value is #{high_temp}")
            high_temp_reset = oa_reset.setpointatOutdoorHighTemperature
            assert(((high_temp_reset - chw_high_temp_reset).abs < 0.1), "Baseline #{building_type}, #{template}, #{climate_zone} has incorrect temperature reset value. The setpoint at outdoor high temperature for the loop #{name} shall be #{chw_high_temp_reset}, but this value is #{high_temp_reset}")
          elsif name.end_with?("HW Temp Reset")
            low_temp = oa_reset.outdoorLowTemperature
            assert(((low_temp - hw_low_temp).abs < 0.1), "Baseline #{building_type}, #{template}, #{climate_zone} has incorrect temperature reset value. The outdoor low temperature for the loop #{name} shall be #{hw_low_temp}, but this value is #{low_temp}")
            low_temp_reset = oa_reset.setpointatOutdoorLowTemperature
            assert(((low_temp_reset - hw_low_temp_reset).abs < 0.1), "Baseline #{building_type}, #{template}, #{climate_zone} has incorrect temperature reset value. The setpoint at outdoor low temperature for the loop #{name} shall be #{hw_low_temp_reset}, but this value is #{low_temp_reset}")
            high_temp = oa_reset.outdoorHighTemperature
            assert(((high_temp - hw_high_temp).abs < 0.1), "Baseline #{building_type}, #{template}, #{climate_zone} has incorrect temperature reset value. The outdoor high temperature for the loop #{name} shall be #{hw_high_temp}, but this value is #{high_temp}")
            high_temp_reset = oa_reset.setpointatOutdoorHighTemperature
            assert(((high_temp_reset - hw_high_temp_reset).abs < 0.1), "Baseline #{building_type}, #{template}, #{climate_zone} has incorrect temperature reset value. The setpoint at outdoor high temperature for the loop #{name} shall be #{hw_high_temp_reset}, but this value is #{high_temp_reset}")
          end
        end
      end
    end
  end

  # Check hvac baseline system type selections
  # Expected outcome depends on prototype name and 'mod' variation defined with
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_hvac(prototypes_base)
    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join('_') unless mod.empty?

      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod_str}"
      @bldg_type_alt_now = @bldg_type_alt[prototype]
      if ['0A', '0B', '1A', '1B', '2A', '2B', '3A'].include?(climate_zone.sub("ASHRAE 169-2013-", ""))
        energy_type = 'Electric' 
      else 
        energy_type = 'Fuel'
      end

      if building_type == 'MidriseApartment' && mod_str.nil?
        # Residential model should be ptac or pthp, depending on climate
        check_if_pkg_terminal(model, climate_zone, 'MidriseApartment')
      elsif @bldg_type_alt_now == 'Assembly' && building_type == 'MediumOffice'
        # This is a public assembly < 120 ksf, should be PSZ
        check_if_psz(model, 'Assembly < 120,000 sq ft.')
        check_heat_type(model, climate_zone, 'SZ', 'HeatPump')
      elsif @bldg_type_alt_now == 'Assembly' && building_type == 'LargeHotel'
        # This is a public assembly > 120 ksf, should be SZ-CV
        check_if_sz_cv(model, climate_zone, 'Assembly < 120,000 sq ft.')
      elsif building_type == 'RetailStripmall' && mod_str.nil?
        # System type should be PSZ
        check_if_psz(model, 'RetailStripmall, one story, any area')
      elsif @bldg_type_alt_now == 'Retail' && building_type == 'PrimarySchool'
        # Single story retail is PSZ, regardless of floor area
        check_if_psz(model, 'retail, one story, floor area > 25 ksf.')
      elsif building_type == 'RetailStripmall' && mod_str == 'set_zone_multiplier_3'
        # System type should be PVAV with 10 zones
        check_if_pvav(model, 'retail > 25,000 sq ft, 3 stories')
        check_terminal_type(model, energy_type, run_id)
      elsif building_type == 'SmallOffice' && mod_str.nil?
        # System type should be PSZ
        check_if_psz(model, 'non-res, one story, < 25 ksf')
        check_heat_type(model, climate_zone, 'SZ', 'HeatPump')
      elsif building_type == 'PrimarySchool' && mod_str == 'remove_transformer'
        # System type should be PVAV, some zones may be on PSZ systems
        check_if_pvav(model, 'nonres > 25,000 sq ft, < 150 ksf , 1 story')
        check_heat_type(model, climate_zone, 'MZ', energy_type)
        check_terminal_type(model, energy_type, run_id)
      elsif building_type == 'SecondarySchool' && mod_str == 'remove_transformer'
        # System type should be VAV/chiller
        check_if_vav_chiller(model, 'nonres > 150 ksf , 1 to 3 stories')
        check_heat_type(model, climate_zone, 'MZ', energy_type)
        check_terminal_type(model, energy_type, run_id)
      elsif building_type == 'MediumOffice' && mod_str == 'remove_transformer_return_relief_fan'
        # Check if baseline has return and relief fan and if fan power
        # distribution is correct
        check_return_reflief_fan_pwr_dist(model)
      elsif building_type == 'SmallOffice' && mod_str == 'set_zone_multiplier_4'
        # nonresidential, 4 to 5 stories, <= 25 ksf --> PVAV
        # System type should be PVAV with 10 zones, area is 22,012 sf
        check_if_pvav(model, 'other nonres > 4 to 5 stories, <= 25 ksf')
        check_terminal_type(model, energy_type, run_id)
      elsif building_type == 'SmallOffice' && mod_str == 'set_zone_multiplier_5'
        # nonresidential, 4 to 5 stories, <= 150 ksf --> PVAV
        # System type should be PVAV with 10 zones, area is 27,515 sf
        check_if_pvav(model, 'other nonres > 4 to 5 stories, <= 150 ksf')
        check_terminal_type(model, energy_type, run_id)
      elsif building_type == 'PrimarySchool' && mod_str.include?('set_zone_multiplier_4')
        # nonresidential, 4 to 5 stories, > 150 ksf --> VAV/chiller
        # System type should be PVAV with 10 zones, area is 22,012 sf
        check_if_vav_chiller(model, 'other nonres > 4 to 5 stories, > 150 ksf')
        check_terminal_type(model, energy_type, run_id)
      elsif building_type == 'SmallOffice' && mod_str == 'set_zone_multiplier_6'
        # 6+ stories, any floor area --> VAV/chiller
        # This test has floor area 33,018 sf
        check_if_vav_chiller(model, ' other nonres > 6 stories')
        check_terminal_type(model, energy_type, run_id)
      elsif @bldg_type_alt_now == 'Hospital' && building_type == 'SmallOffice'
        energy_type = 'Fuel' # Table G3.1.1-3 Note 4
        # Hospital < 25 ksf is PVAV; different rule than non-res
        check_if_pvav(model, 'hospital, floor area < 25 ksf.')
        check_terminal_type(model, energy_type, run_id)
      elsif building_type == 'Hospital' && mod_str.nil?
        energy_type = 'Fuel' # Table G3.1.1-3 Note 4
        # System type should be VAV/chiller, area is 241 ksf
        check_if_vav_chiller(model, 'hospital > 4 to 5 stories, > 150 ksf')
        check_heat_type(model, climate_zone, 'MZ', energy_type)
        check_terminal_type(model, energy_type, run_id)
      elsif building_type == 'Warehouse'
        # System type should be system 9, 10 but with no mechanical cooling
        check_if_heat_only(model, climate_zone, building_type)
      elsif mod_str == 'make_lab_high_distrib_zone_exh' || mod_str == 'make_lab_high_system_exh'
        # All labs on a given floor of the building should be on a separate MZ system
        model.getAirLoopHVACs.each do |air_loop|
          # identify hours of operation
          has_lab = false
          has_nonlab = false
          air_loop.thermalZones.each do |thermal_zone|
            thermal_zone.spaces.each do |space|
              space_type = space.spaceType.get.standardsSpaceType.get
              if space_type == 'laboratory'
                has_lab = true
              else
                has_nonlab = true
              end
            end
          end
          assert(!(has_lab == true && has_nonlab == true), "System #{air_loop.name} has lab and nonlab spaces and lab exhaust > 15,000 cfm.")
        end
      elsif mod_str == 'make_lab_low_distrib_zone_exh'
        # Labs on a given floor of the building should be mixed with other space types on the main MZ system
        model.getAirLoopHVACs.each do |air_loop|
          # identify hours of operation
          has_lab = false
          has_nonlab = false
          air_loop.thermalZones.each do |thermal_zone|
            thermal_zone.spaces.each do |space|
              space_type = space.spaceType.get.standardsSpaceType.get
              if space_type == 'laboratory'
                has_lab = true
              else
                has_nonlab = true
              end
            end
          end
          assert(!(has_lab == true && has_nonlab == false), "System #{air_loop.name} has only lab spaces and lab exhaust < 15,000 cfm.")
        end
      elsif building_type == 'LargeOffice' || building_type == 'MediumOffice'
        # Check that the datacenter basement is assigned to system 11, PSZ-VAV
        check_cmp_dtctr_system_type(model)
      end
    end
  end

  # Check whether heat type meets expectations
  # Electric if warm CZ, fuel if cold
  # Also check HP vs electric resistance depending on baseline system type
  # @param model, climate_zone, mz_or_sz, expected_elec_heat_type
  # mz_or_sz = MZ or SZ or PTU
  # expected_elec_heat_type = Electric or HeatPump
  def check_heat_type(model, climate_zone, mz_or_sz, expected_elec_heat_type)
    return false unless !model.getAirLoopHVACs.empty?

    model.getAirLoopHVACs.each do |air_loop|
      num_zones = air_loop.thermalZones.size
      if (num_zones > 1 && mz_or_sz == 'MZ') || (num_zones == 1 && mz_or_sz == 'SZ')
        # This is a multizone system, do the test
        heat_type = model.airloop_primary_heat_type(air_loop).to_s
        if climate_zone =~ /0A|0B|1A|1B|2A|2B|3A/
          # Heat type is electric or heat pump
          assert(heat_type == expected_elec_heat_type, "Incorrect heat type for #{air_loop.name.get}; expected #{expected_elec_heat_type}")
        else
          # Heat type is Fuel
          assert(heat_type == 'Fuel', "Incorrect heat type for #{air_loop.name.get}; expected Fuel")
        end
      end
    end

    # TODO: Also check zone equipment
    # if mz_or_sz == 'PTU' || mz_or_sz == 'SZ'
    # end
  end

  # Check if the system type is heat only and
  # check fan power for non mechanically cooled
  # system
  def check_if_heat_only(model, climate_zone, building_type)
    model.getAirLoopHVACs.each do |air_loop|
      system_type = air_loop.additionalProperties.getFeatureAsString('baseline_system_type').get
      assert(system_type == 'Electric_Furnace', "Baseline system for #{building_type} in climate zone #{climate_zone} should be Electric_Furnace, not #{system_type}.")
    end

    # check baseline system fan power
    std = Standard.build('90.1-PRM-2019')
    model.getFanOnOffs.sort.each do |fan|
      fan_power_si = std.fan_fanpower(fan) / std.fan_design_air_flow(fan)
      fan_power_ip = fan_power_si / OpenStudio.convert(1, 'm^3/s', 'cfm').get
      assert(fan_power_ip.round(3) == 0.054, "Fan power (nmc system) for #{building_type} in climate zone #{climate_zone} is #{fan_power_ip.round(1)} instead of 0.054.")
    end
    model.getFanConstantVolumes.sort.each do |fan|
      fan_power_si = std.fan_fanpower(fan) / std.fan_design_air_flow(fan)
      fan_power_ip = fan_power_si / OpenStudio.convert(1, 'm^3/s', 'cfm').get
      assert(fan_power_ip.round(1) == 0.3, "Fan power for #{building_type} in climate zone #{climate_zone} is #{fan_power_ip.round(1)} instead of 0.3.")
    end
  end

  # Check if all baseline system types are PSZ
  # @param model, sub_text for error messages
  def check_if_psz(model, sub_text, zone: nil)
    num_zones = 0
    num_dx_coils = 0
    num_dx_coils += model.getCoilCoolingDXSingleSpeeds.size
    num_dx_coils += model.getCoilCoolingDXTwoSpeeds.size
    num_dx_coils += model.getCoilCoolingDXMultiSpeeds.size
    has_chiller = model.getPlantLoopByName('Chilled Water Loop').is_initialized
    model.getAirLoopHVACs.each do |air_loop|
      if zone.nil?
        num_zones = air_loop.thermalZones.size
        # if num zones is greater than 1 for any system, then set as multizone
        assert(num_zones = 1 && num_dx_coils > 0 && has_chiller == false, "Baseline system selection failed for #{air_loop.name}; should be PSZ for " + sub_text)
      else
        th_zones = []
        air_loop.thermalZones.each { |th_zone| th_zones << th_zone.name.to_s }
        if th_zones.include? zone
          # If multizone system
          return false if air_loop.thermalZones.size > 1

          zone_system_check = false
          model.getAirLoopHVACUnitarySystems.each do |unit_system|
            # Check if airloop includes a unitary system with constant volume fan single speed DX cooling coil
            zone_system_check = true if unit_system.controllingZoneorThermostatLocation.get.name.to_s == zone.name.to_s &&
                                        unit_system.controlType == 'Load' &&
                                        unit_system.coolingCoil.get.to_CoilCoolingDXSingleSpeed.is_initialized &&
                                        unit_system.supplyFan.get.to_FanOnOff.is_initialized
          end
          return zone_system_check
        end
      end
    end

    # check baseline system fan power
    std = Standard.build('90.1-PRM-2019')
    model.getFanOnOffs.sort.each do |fan|
      fan_power_si = std.fan_fanpower(fan) / std.fan_design_air_flow(fan)
      fan_power_ip = fan_power_si / OpenStudio.convert(1, 'm^3/s', 'cfm').get
      fan_bhp_ip = fan_power_ip * fan.motorEfficiency / 746.0
      assert(fan_bhp_ip.round(5) == 0.00094, "Fan power for #{sub_text} is #{fan_bhp_ip.round(5)} instead of 0.00094.")
      if fan_bhp_ip * OpenStudio.convert(std.fan_design_air_flow(fan), 'm^3/s', 'cfm').get <= 1.0
        assert(fan.motorEfficiency == 0.825, "Fan motor efficiency for #{fan.name} in #{sub_text} is #{fan.motorEfficiency}, 0.825 is expected.")
      end
    end
  end

  # Check if any baseline system type is PVAV
  # @param model, sub_text for error messages
  def check_if_pvav(model, sub_text)
    num_zones = 0
    num_dx_coils = 0
    num_dx_coils += model.getCoilCoolingDXSingleSpeeds.size
    num_dx_coils += model.getCoilCoolingDXTwoSpeeds.size
    num_dx_coils += model.getCoilCoolingDXMultiSpeeds.size
    has_chiller = model.getPlantLoopByName('Chilled Water Loop').is_initialized
    has_multizone = false
    model.getAirLoopHVACs.each do |air_loop|
      num_zones = air_loop.thermalZones.size
      # if num zones is greater than 1 for any system, then set as multizone
      if num_zones > 1
        has_multizone = true
      end
    end
    assert(has_multizone && num_dx_coils > 0 && has_chiller == false, 'Baseline system selection failed; should be PVAV for ' + sub_text)

    # check baseline system fan power
    # central fans
    std = Standard.build('90.1-PRM-2019')
    model.getFanVariableVolumes.sort.each do |fan|
      fan_power_si = std.fan_fanpower(fan) / std.fan_design_air_flow(fan)
      fan_power_ip = fan_power_si / OpenStudio.convert(1, 'm^3/s', 'cfm').get
      fan_bhp_ip = fan_power_ip * fan.motorEfficiency / 746.0
      assert(fan_bhp_ip.round(4) == 0.0013, "Fan power for central fan in #{sub_text} is #{fan_bhp_ip.round(4)} instead of 0.0013.")
      fan_bhp_ip *= OpenStudio.convert(std.fan_design_air_flow(fan), 'm^3/s', 'cfm').get
      if fan_bhp_ip <= 20.0 && fan_bhp_ip > 15.0
        assert(fan.motorEfficiency == 0.91, "Fan motor efficiency for #{fan.name} in #{sub_text} is #{fan.motorEfficiency}, 0.91 is expected.")
      end
    end

    # PFP fans
    model.getFanConstantVolumes.sort.each do |fan|
      fan_power_si = std.fan_fanpower(fan) / std.fan_design_air_flow(fan)
      fan_power_ip = fan_power_si / OpenStudio.convert(1, 'm^3/s', 'cfm').get
      assert(fan_power_ip.round(2) == 0.35, "Fan power for terminal fan in #{sub_text} is #{fan_power_ip.round(1)} instead of 0.35.")
    end
  end

  def check_return_reflief_fan_pwr_dist(model)
    std = Standard.build('90.1-PRM-2019')
    model.getAirLoopHVACs.each do |air_loop|
      # Get supply fan
      supply_fan = air_loop.supplyFan.get
      if supply_fan.to_FanConstantVolume.is_initialized
        supply_fan = supply_fan.to_FanConstantVolume.get
      elsif supply_fan.to_FanVariableVolume.is_initialized
        supply_fan = supply_fan.to_FanVariableVolume.get
      elsif supply_fan.to_FanOnOff.is_initialized
        supply_fan = supply_fan.to_FanOnOff.get
      elsif supply_fan.to_FanSystemModel.is_initialized
        supply_fan = supply_fan.to_FanSystemModel.get
      end

      # Get return fan
      return_fan = air_loop.returnFan.get
      if return_fan.to_FanConstantVolume.is_initialized
        return_fan = return_fan.to_FanConstantVolume.get
      elsif return_fan.to_FanVariableVolume.is_initialized
        return_fan = return_fan.to_FanVariableVolume.get
      elsif return_fan.to_FanOnOff.is_initialized
        return_fan = return_fan.to_FanOnOff.get
      elsif return_fan.to_FanSystemModel.is_initialized
        return_fan = return_fan.to_FanSystemModel.get
      end

      # Get relief fan
      relief_fan = air_loop.reliefFan.get
      if relief_fan.to_FanConstantVolume.is_initialized
        relief_fan = relief_fan.to_FanConstantVolume.get
      elsif relief_fan.to_FanVariableVolume.is_initialized
        relief_fan = relief_fan.to_FanVariableVolume.get
      elsif relief_fan.to_FanOnOff.is_initialized
        relief_fan = relief_fan.to_FanOnOff.get
      elsif relief_fan.to_FanSystemModel.is_initialized
        relief_fan = relief_fan.to_FanSystemModel.get
      end

      # Fan power ratios
      return_to_supply_fan_power_ratio = std.fan_fanpower(return_fan) / std.fan_fanpower(supply_fan)
      relief_to_supply_fan_power_ratio = std.fan_fanpower(relief_fan) / std.fan_fanpower(supply_fan)

      assert(return_to_supply_fan_power_ratio.round(0) == 2, "Fan power ratio between return and supply is incorrect, got #{return_to_supply_fan_power_ratio.round(0)} instead 2.")
      assert(relief_to_supply_fan_power_ratio.round(0) == 3, "Fan power ratio between relief and supply is incorrect, got #{relief_to_supply_fan_power_ratio.round(0)} instead 3.")
    end
  end

  # Check if building has baseline VAV/chiller for at least one air loop
  # @param model, sub_text for error messages
  def check_if_vav_chiller(model, sub_text)
    num_zones = 0
    num_dx_coils = 0
    has_chiller = model.getPlantLoopByName('Chilled Water Loop').is_initialized
    has_multizone = false
    model.getAirLoopHVACs.each do |air_loop|
      num_zones = air_loop.thermalZones.size
      # if num zones is greater than 1 for any system, then set as multizone
      if num_zones > 1
        has_multizone = true
      end
    end
    assert(has_multizone && has_chiller, 'Baseline system selection failed; should be VAV/chiller for ' + sub_text)

    # check baseline system fan power
    # central fans
    std = Standard.build('90.1-PRM-2019')
    model.getFanVariableVolumes.sort.each do |fan|
      fan_power_si = std.fan_fanpower(fan) / std.fan_design_air_flow(fan)
      fan_power_ip = fan_power_si / OpenStudio.convert(1, 'm^3/s', 'cfm').get
      fan_bhp_ip = fan_power_ip * fan.motorEfficiency / 746.0
      assert(fan_bhp_ip.round(4) == 0.0013, "Fan power for central fan in #{sub_text} is #{fan_power_ip.round(4)} instead of 0.0013.")
      fan_bhp_ip *= OpenStudio.convert(std.fan_design_air_flow(fan), 'm^3/s', 'cfm').get
      if fan_bhp_ip <= 20.0 && fan_bhp_ip > 15.0
        assert(fan.motorEfficiency == 0.91, "Fan motor efficiency for #{fan.name} in #{sub_text} is #{fan.motorEfficiency}, 0.91 is expected.")
      end
    end

    # PFP fans
    model.getFanConstantVolumes.sort.each do |fan|
      fan_power_si = std.fan_fanpower(fan) / std.fan_design_air_flow(fan)
      fan_power_ip = fan_power_si / OpenStudio.convert(1, 'm^3/s', 'cfm').get
      assert(fan_power_ip.round(2) == 0.35, "Fan power for terminal fan in #{sub_text} is #{fan_power_ip.round(1)} instead of 0.35.")
    end
  end

  # Check if model uses standard VAV boxes of FP boxes
  # @param model [OpenStudio::Model::Model] OpenStudio model
  # @param energy_source [String] Energy source used for heating
  def check_terminal_type(model, energy_source, mod_str)
    model.getAirLoopHVACs.each do |airloop|
      airloop.thermalZones.each do |zone|
        zone.equipment.each do |equip|
          expected_results = false
          if equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
            expected_results = true if energy_source != 'Electric'
            assert(expected_results, "Standard VAV boxes are not expected for #{mod_str}.")
          elsif equip.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized
            expected_results = true if energy_source == 'Electric'
            terminal = equip.to_AirTerminalSingleDuctParallelPIUReheat.get
            assert(expected_results, "Fan powered boxes are not expected for #{mod_str}.")
            # check secondary flow fraction
            check_secondary_flow_fraction(terminal, mod_str)
          end
        end
      end
    end
  end

  # Check the model's secondary flow fraction
  # @param terminal [OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat] Parallel PIU terminal
  # @param mod_str [String] Run description
  def check_secondary_flow_fraction(terminal, mod_str)
    if terminal.maximumSecondaryAirFlowRate.is_initialized
      secondary_flow = terminal.maximumSecondaryAirFlowRate.get.to_f
    else
      secondary_flow = terminal.autosizedMaximumSecondaryAirFlowRate.get.to_f
    end
    if terminal.maximumPrimaryAirFlowRate.is_initialized
      primary_flow = terminal.maximumPrimaryAirFlowRate.get.to_f
    else
      primary_flow = terminal.autosizedMaximumPrimaryAirFlowRate.get.to_f
    end
    secondary_flow_frac = secondary_flow / primary_flow
    err = (secondary_flow_frac - 0.5).abs
    # need to allow some tolerance due to secondary flow getting set before final sizing run
    assert(err < 0.01, "Expected secondary flow fraction should be 0.5 but #{secondary_flow_frac} is used for #{mod_str}.")
  end

  # Check if baseline system type is PTAC or PTHP
  # @param model, sub_text for error messages
  def check_if_pkg_terminal(model, climate_zone, sub_text)
    pass_test = true
    # building fails if any zone is not packaged terminal unit
    # or if heat type is incorrect
    model.getThermalZones.sort.each do |thermal_zone|
      has_ptac = false
      has_pthp = false
      has_unitheater = false
      thermal_zone.equipment.each do |equip|
        # Skip HVAC components
        next unless equip.to_HVACComponent.is_initialized

        equip = equip.to_HVACComponent.get
        if equip.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
          has_ptac = true
        elsif equip.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          has_pthp = true
        elsif equip.to_ZoneHVACUnitHeater.is_initialized
          has_unitheater = true
        end
      end
      # Test for hvac type by climate
      if climate_zone =~ /0A|0B|1A|1B|2A|2B|3A/
        if has_pthp == false
          pass_test = false
        end
      else
        if has_ptac == false
          pass_test = false
        end
      end
    end
    if climate_zone =~ /0A|0B|1A|1B|2A|2B|3A/
      assert(pass_test, "Baseline system selection failed for climate #{climate_zone}: should be PTHP for " + sub_text)
    else
      assert(pass_test, "Baseline system selection failed for climate #{climate_zone}: should be PTAC for " + sub_text)
    end

    # check baseline system fan power
    std = Standard.build('90.1-PRM-2019')
    model.getFanConstantVolumes.sort.each do |fan|
      fan_power_si = std.fan_fanpower(fan) / std.fan_design_air_flow(fan)
      fan_power_ip = fan_power_si / OpenStudio.convert(1, 'm^3/s', 'cfm').get
      assert(fan_power_ip.round(1) == 0.3, "Fan power for #{sub_text} is #{fan_power_ip.round(1)} instead of 0.3.")
    end
  end

  # Check if baseline system type is four pipe fan coil/ constant speed
  # @param model, sub_text for error messages
  def check_if_sz_cv(model, climate_zone, sub_text)
    # building fails if any zone is not packaged terminal unit
    # or if heat type is incorrect
    model.getThermalZones.sort.each do |thermal_zone|
      pass_test = false
      is_fpfc = false
      heat_type = ''
      thermal_zone.equipment.each do |equip|
        # Skip HVAC components
        next unless equip.to_HVACComponent.is_initialized

        equip = equip.to_HVACComponent.get
        is_fpfc = equip.to_ZoneHVACFourPipeFanCoil.is_initialized

        if is_fpfc
          # pass test for FPFC if at least one zone equip is FPFC; others may be exhaust fan, or possibly something else
          pass_test = true
        end
        if is_fpfc
          # Also check heat type
          equip = equip.to_ZoneHVACFourPipeFanCoil.get
          heat_type = model.coil_heat_type(equip.heatingCoil)
          if climate_zone =~ /0A|0B|1A|1B|2A|2B|3A/
            assert(heat_type == 'Electric', "Baseline system selection failed for climate #{climate_zone}: FPFC should have electric heat for " + sub_text)
          else
            assert(heat_type == 'Fuel', "Baseline system selection failed for climate #{climate_zone}: FPFC should have hot water heat for " + sub_text)
          end
        end
      end
      assert(pass_test, 'Baseline system selection failed: should be FPFC for ' + sub_text)
    end

    # check baseline system fan power
    std = Standard.build('90.1-PRM-2019')
    model.getFanOnOffs.sort.each do |fan|
      fan_power_si = std.fan_fanpower(fan) / std.fan_design_air_flow(fan)
      fan_power_ip = fan_power_si / OpenStudio.convert(1, 'm^3/s', 'cfm').get
      fan_bhp_ip = fan_power_ip * fan.motorEfficiency / 746.0
      assert(fan_bhp_ip.round(5) == 0.00094, "Fan power for #{sub_text} is #{fan_bhp_ip.round(5)} instead of 0.00094.")
      if fan_bhp_ip * OpenStudio.convert(std.fan_design_air_flow(fan), 'm^3/s', 'cfm').get <= 1.0
        assert(fan.motorEfficiency == 0.825, "Fan motor efficiency for #{fan.name} in #{sub_text} is #{fan.motorEfficiency}, 0.825 is expected.")
      end
    end
  end

  # Check if baseline system type is a single-zone system with variable-air-volume fan
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  def check_cmp_dtctr_system_type(model)
    zone_load_s = 0
    # Individual zone load check
    model.getThermalZones.each do |zone|
      # Get design cooling load of computer rooms
      zone.spaces.each do |space|
        if space.spaceType.get.standardsSpaceType.get == 'computer room'
          zone_load_w = zone.coolingDesignLoad.to_f
          zone_load_w *= zone.floorArea * zone.multiplier
          zone_load = OpenStudio.convert(zone_load_w, 'W', 'Btu/hr').get
          zone_load_s += zone_load
          if zone_load >= 600000
            # System 11 (PSZ-VAV) is required
            assert(check_if_sz_vav(model, zone), "Zone #{zone.name} should be served by a packaged single zone VAV system (system 11).")
          elsif zone_load < 600000
            # System 3 or 4 is required
            assert(check_if_psz(model, '', zone: zone), "Zone #{zone.name} should be served by a packaged single zone CAV system (system 3 or 4).")
          end
        end
      end
    end

    # Building load check
    return false unless zone_load_s > 3000000

    model.getThermalZones.each do |zone|
      zone.spaces.each do |space|
        if space.spaceType.get.standardsSpaceType.get == 'computer room'
          # System 11 is required
          assert(check_if_sz_vav(model, zone), "Zone #{zone.name} should be served by a packaged single zone VAV system (system 11) because building computer rooms peak load exceed 3,000, 000 Btu/h.")
        end
      end
    end
  end

  def check_if_sz_vav(model, zone)
    zone_system_check = false
    model.getAirLoopHVACUnitarySystems.each do |unit_system|
      # Check if the system is system 11 by checking if the load control type is SingleZoneVAV
      zone_system_check = true if unit_system.controllingZoneorThermostatLocation.get.name.to_s == zone.name.to_s &&
                                  unit_system.controlType == 'SingleZoneVAV' &&
                                  unit_system.coolingCoil.get.to_CoilCoolingWater.is_initialized
    end
    return zone_system_check
  end

  def check_multi_bldg_handling(baseline_base)
    baseline_base.each do |baseline, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = baseline
      if building_type == 'SmallOffice'
        # Get WWR of baseline model
        std = Standard.build('90.1-PRM-2019')
        wwr_baseline = std.run_query_tabulardatawithstrings(model_baseline, 'InputVerificationandResultsSummary', 'Conditioned Window-Wall Ratio', 'Gross Window-Wall Ratio', 'Total', '%').to_f
        # Check WWR against expected WWR
        wwr_goal = 100 * @@wwr_values[building_type].to_f
        assert(wwr_baseline > wwr_goal, "Baseline WWR for the #{building_type}, #{template}, #{climate_zone} model with user data is incorrect. The WWR of the baseline model is #{wwr_baseline} but should be greater than the WWR goal #{wwr_goal}")
      end
      # TODO adding more tests to check if zones are assigned correctly
      if building_type == 'LargeHotel'
        model_baseline.getThermalZones.each do |thermal_zone|
          thermal_zone_name = thermal_zone.name.get
          # assert(thermal_zone.additionalProperties.hasFeature('building_type_for_hvac'), "Baseline zone #{thermal_zone_name} does not have building_type_for_hvac assigned.")
          if thermal_zone.additionalProperties.hasFeature('building_type_for_hvac')
            bldg_hvac_type = thermal_zone.additionalProperties.getFeatureAsString('building_type_for_hvac').get
            if /_1 ZN/i =~ thermal_zone_name
              # first floor hvac type shall be "retail"
              assert(bldg_hvac_type == 'retail', "Baseline zone #{thermal_zone_name} has incorrect building_type_for_hvac. It should be retail but get #{bldg_hvac_type}")
            else
              # other floors hvac type shall be "residential"
              assert(bldg_hvac_type == 'residential', "Baseline zone #{thermal_zone_name} has incorrect building_type_for_hvac. It should be residential but get #{bldg_hvac_type}")
            end
          end
        end
      end
    end
  end

  # Check if preheat coil control for system 5 through 8 are implemented
  #
  # @param baseline_base [Hash] Baseline
  def check_preheat_coil_ctrl(baseline_base)
    baseline_base.each do |baseline, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = baseline

      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join('_') unless mod.empty?

      htg_coil_node_list = []
      model_baseline.getAirLoopHVACs.each do |airloop|
        # Baseline system type identified based on airloop HVAC name
        system_type = airloop.additionalProperties.getFeatureAsString('baseline_system_type').get
        if system_type == 'PVAV_Reheat' || system_type == 'PVAV_PFP_Boxes' || system_type == 'VAV_Reheat' || system_type == 'VAV_PFP_Boxes'
          # Get all Heating Coil in the airloop.
          heating_coil_outlet_node = nil
          airloop.supplyComponents.each do |equip|
            if equip.to_CoilHeatingWater.is_initialized
              htg_coil = equip.to_CoilHeatingWater.get
              heating_coil_outlet_node = htg_coil.airOutletModelObject.get.to_Node.get
            elsif equip.to_CoilHeatingElectric.is_initialized
              htg_coil = equip.to_CoilHeatingElectric.get
              heating_coil_outlet_node = htg_coil.outletModelObject.get.to_Node.get
            elsif equip.to_CoilHeatingGas.is_initialized
              # in this case the test should failed because preheat coil should be either hydronic or eletric
              assert(false, 'Preheat coil shall only be hydronic or electric coils. Coil type: Natural gas')
            else
              next
            end
            # get heating coil spm
            spms = heating_coil_outlet_node.setpointManagers

            # Report if multiple setpoint managers have been assigned to the air loop supply outlet node
            assert(false, 'Multiple setpoint manager have been assigned to the heating coil outlet node.') unless spms.size == 1

            spms.each do |spm|
              if spm.to_SetpointManagerScheduled.is_initialized
                # Get SPM
                spm_s = spm.to_SetpointManagerScheduled.get
                schedule_name = spm_s.schedule.name.to_s
                setpoint_temp_str = schedule_name.split("-")[-1].strip
                # remove the F unit
                setpoint_temp = setpoint_temp_str[0, -1].to_f
                assert((setpoint_temp-50).abs > 1, "The scheduled temperature is not equal to 50F, instead it is #{setpoint_temp}F")
              else
                assert(false, "The sepoint manager for preheat coil is not setpointManager:Scheduled.")
              end
            end
          end
        end
      end
    end
  end

  # Check if SAT requirements for system 5 through 8 are implemented
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_sat_ctrl(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join('_') unless mod.empty?

      model_baseline.getAirLoopHVACs.each do |airloop|
        # Baseline system type identified based on airloop HVAC name
        if airloop.name.to_s.include?('Sys5') ||
           airloop.name.to_s.include?('Sys6') ||
           airloop.name.to_s.include?('Sys7') ||
           airloop.name.to_s.include?('Sys8')
          # Get all SPM assigned to supply outlet node of the airloop
          spms = airloop.supplyOutletNode.setpointManagers
          spm_check = false

          # Report if multiple setpoint managers have been assigned to the air loop supply outlet node
          assert(false, 'Multiple setpoint manager have been assigned to the air loop supply outlet node.') unless spms.size == 1

          spms.each do |spm|
            if spm.to_SetpointManagerWarmest.is_initialized

              # Get SPM
              spm_w = spm.to_SetpointManagerWarmest.get

              # Retrieve SAT and SAT reset
              max = spm_w.maximumSetpointTemperature
              min = spm_w.minimumSetpointTemperature

              # Calculate difference
              dt_ip = max - min

              # Convert to dT F
              dt_si = OpenStudio.convert(dt_ip, 'K', 'R').get

              # Check if requirement is met for SPM
              spm_check = true if dt_si.round(0) == 5.0
              puts dt_si
            end
          end

          # Check if requirement is met for airloop
          assert(spm_check)
        end
      end
    end
  end

  # Check if split of zones to PSZ from multizone baselines is working correctly

  def check_psz_split_from_mz(prototypes_base)
    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, user_data_dir, mod = prototype

      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join('_') unless mod.empty?

      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod_str}"
      @bldg_type_alt_now = @bldg_type_alt[prototype]

      if building_type == 'MediumOffice' && mod_str == 'remove_transformer_change_zone_epd_Perimeter_bot_ZN_1 ZN_70'
        # This mod should isolate Perimeter_bot_ZN_1 ZN to PSZ
        # Fan schedule for the PSZ should be same as the MZ system fan schedule (92 hrs/wk)
        # MZ system will have the zone Core_bottom ZN on it
        # Review all air loops and check zones and fan schedules
        num_zones_target = 0
        num_zones_mz = 0
        fan_hrs_per_week_target = 0
        fan_hrs_per_week_mz = 0
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.thermalZones.each do |zone|
            zone_name = zone.name.get
            if zone.name.get == 'Perimeter_bot_ZN_1 ZN'
              # Get fan hours and num zones
              num_zones_target = air_loop.thermalZones.size
              fan_hrs_per_week_target = get_fan_hours_per_week(model, air_loop)
            elsif zone.name.get == 'Core_bottom ZN'
              num_zones_mz = air_loop.thermalZones.size
              fan_hrs_per_week_mz = get_fan_hours_per_week(model, air_loop)
            end
          end
        end

        assert((num_zones_target == 1 && num_zones_mz > 1 && (fan_hrs_per_week_target - fan_hrs_per_week_mz).abs < 5), 'Split PSZ from MZ system fails for high internal gain zone.')
      elsif building_type == 'MediumOffice' && mod_str == 'remove_transformer_change_to_long_occ_sch_Perimeter_bot_ZN_1 ZN'
        # This mod should isolate Perimeter_bot_ZN_1 ZN to PSZ
        # Fan schedule for the PSZ should be 24/7, while fan schedule for MZ system should be 92 hrs/wk
        num_zones_target = 0
        num_zones_mz = 0
        fan_hrs_per_week_target = 0
        fan_hrs_per_week_mz = 0
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.thermalZones.each do |zone|
            if zone.name.get == 'Perimeter_bot_ZN_1 ZN'
              # Get fan hours and num zones
              num_zones_target = air_loop.thermalZones.size
              fan_hrs_per_week_target = get_fan_hours_per_week(model, air_loop)
            elsif zone.name.get == 'Core_bottom ZN'
              num_zones_mz = air_loop.thermalZones.size
              fan_hrs_per_week_mz = get_fan_hours_per_week(model, air_loop)
            end
          end
        end

        assert((num_zones_target == 1 && num_zones_mz > 1 && fan_hrs_per_week_target > fan_hrs_per_week_mz), "Split PSZ from MZ system fails for high internal gain zone. Target zone fan hrs/wk = #{fan_hrs_per_week_target}; MZ fan hrs/wk = #{fan_hrs_per_week_mz}")
      end
    end
  end

  def get_fan_hours_per_week(model, air_loop)
    fan_schedule = air_loop.availabilitySchedule
    fan_hours_8760 = @prototype_creator.get_8760_values_from_schedule(model, fan_schedule)
    fan_hours_52 = []

    hr_of_yr = -1
    (0..51).each do |iweek|
      week_sum = 0
      (0..167).each do |hr_of_wk|
        hr_of_yr += 1
        week_sum += fan_hours_8760[hr_of_yr]
      end
      fan_hours_52 << week_sum
    end
    max_fan_hours = fan_hours_52.max
    return max_fan_hours
  end

  # Check if number of chillers is correct
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_number_of_chillers(prototypes_base)
    # Find plant loops with chillers and ensure the meet the requirement laid out by G3.1.3.7 of Appendix G 2019
    #
    # Electric chillers shall be used in the baseline building design regardless of the cooling
    # energy source, e.g. direct-fired absorption or absorption from purchased steam. The
    # baseline building design’s chiller plant shall be modeled with chillers having the number
    # and type as indicated in Table G3.1.3.7 as a function of building peak cooling load.
    #
    # Building Peak Cooling Load Number and Type of Chillers
    # <=300 tons: 1 water-cooled screw chiller
    # >300 tons, <600 tons:  2 water-cooled screw chillers sized equally
    # >=600 tons:  2 water-cooled centrifugal chillers minimum with chillers added so that no chiller is larger than 800 tons, all sized equally

    prototypes_base.each do |prototype, model|
      model.getPlantLoops.each do |plant_loop|
        n_chillers = plant_loop.supplyComponents(OpenStudio::Model::ChillerElectricEIR.iddObjectType).length

        # Skip plant loops with no chillers
        next if n_chillers == 0

        # Check for Autosized chillers. Chillers should have had their capacity set already. Faile
        plant_loop.supplyComponents.each do |sc|
          # ChillerElectricEIR
          if sc.to_ChillerElectricEIR.is_initialized
            chiller = sc.to_ChillerElectricEIR.get

            # Check to make sure chiller is not autosized
            assert(!chiller.isReferenceCapacityAutosized,
                   "Chiller named #{chiller.name} is autosized. The 90.1 PRM model should not have any autosized chillers
                        as this causes issues when finding a chilled plant loop's capacity. Check if the cooling plant sizing run failed.")
          end
        end

        # Initialize Standard class
        standard = Standard.build('90.1-PRM-2019')
        cap_w = standard.plant_loop_total_cooling_capacity(plant_loop)
        cap_tons = OpenStudio.convert(cap_w, 'W', 'ton').get

        if cap_tons <= 300
          n_expected_chillers = 1
        elsif cap_tons > 300 && cap_tons < 600
          n_expected_chillers = 2
        else
          # Max capacity of a single chiller
          max_cap_ton = 800.0
          n_expected_chillers = (cap_tons / max_cap_ton).floor + 1
          # Must be at least 2 chillers
          n_expected_chillers += 1 if n_expected_chillers == 1
        end

        assert(n_chillers == n_expected_chillers,
               msg = "Baseline system failed. Number of chillers equaled #{n_chillers} when it should be #{n_expected_chillers}.
                    Please review section G3.1.3.7 of Appendix G for guidance.")
      end
    end
  end

  # Check if number of boilers is correct
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_number_of_boilers(prototypes_base)
    # Find plant loops with boilers and ensure the meet the requirement laid out by G3.1.3.2 of Appendix G 2019
    #
    # G3.1.3.2 Type and Number of Boilers (Systems 1, 5, 7, 11, and 12)
    # The boiler plant shall be natural draft, except as noted in Section G3.1.1.1. The baseline
    # building design boiler plant shall be modeled as having a single boiler if the baseline
    # building design plant serves a conditioned floor area of 15,000 ft2 or less, and as having
    # two equally sized boilers for plants serving more than 15,000 ft2.

    prototypes_base.each do |prototype, model|
      model.getPlantLoops.each do |plant_loop|
        n_boilers = plant_loop.supplyComponents(OpenStudio::Model::BoilerHotWater.iddObjectType).length

        # Skip plant loops with no boilers
        next if n_boilers == 0

        # Find area served by this loop
        standard = Standard.build('90.1-PRM-2019')
        area_served_m2 = standard.plant_loop_total_floor_area_served(plant_loop)
        area_served_ft2 = OpenStudio.convert(area_served_m2, 'm^2', 'ft^2').get

        # check that the number of boilers equals the amount specified by the standard based on the conditioned floor area
        n_expected_boilers = area_served_ft2 < 15000 ? 1 : 2

        assert(n_boilers == n_expected_boilers,
               msg = "Baseline system failed. Number of boilers equaled #{n_boilers} when it should be #{n_expected_boilers}.
                    Please review section G3.1.3.2 of Appendix G for guidance.")
      end
    end
  end

  # Check if number of towers is correct
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_number_of_cooling_towers(prototypes_base)
    # Find plant loops with chillers + cooling towers and ensure the meet the requirement laid out by Appendix G 2019
    #
    # 3.7.3 Cooling Towers;
    # Only one tower in baseline, regardless of number of chillers
    prototypes_base.each do |prototype, model|
      n_chillers = model.getChillerElectricEIRs.size

      n_cooling_towers = model.getCoolingTowerSingleSpeeds.size
      n_cooling_towers += model.getCoolingTowerTwoSpeeds.size
      n_cooling_towers += model.getCoolingTowerVariableSpeeds.size

      if n_cooling_towers > 0
        assert(n_cooling_towers == 1,
               msg = "Baseline system failed for Appendix G 2019 requirements. Number of cooling towers > 1.
                        The number of chillers equaled #{n_chillers} and the number of cooling towers equaled #{n_cooling_towers}.")
      end
    end
  end

  def check_economizer_exception(baseline_base)
    baseline_base.each do |baseline, baseline_model|
      building_type, template, climate_zone, user_data_dir, mod = baseline
      baseline_model.getAirLoopHVACs.each do |air_loop|
        economizer_activated_target = false
        temperature_highlimit_target = 23.89
        air_loop_name = air_loop.name.get
        baseline_system_type = air_loop.additionalProperties.getFeatureAsString("baseline_system_type")
        if ['Building Story 3 VAV_PFP_Boxes (Sys8)', 'DataCenter_basement_ZN_6 ZN PSZ-VAV' ,'Basement Story 0 VAV_PFP_Boxes (Sys8)'].include?(air_loop_name) and climate_zone.end_with?("2B")
          economizer_activated_target = true
        end

        economizer_activated_model = false
        temperature_highlimit_model = 23.89
        oa_sys = air_loop.airLoopHVACOutdoorAirSystem
        if oa_sys.is_initialized
          economizer_activated_model = true unless oa_sys.get.getControllerOutdoorAir.getEconomizerControlType == 'NoEconomizer'
          if economizer_activated_model
            temperature_highlimit_model = oa_sys.get.getControllerOutdoorAir.getEconomizerMaximumLimitDryBulbTemperature.get
          end
        end

        assert(economizer_activated_model == economizer_activated_target,
               "#{building_type}_#{template} is in #{climate_zone}. Air loop #{air_loop.name.get} system type is #{baseline_system_type}. The target economizer flag should be #{economizer_activated_target} but get #{economizer_activated_model}")
        
        temp_diff = temperature_highlimit_model - temperature_highlimit_target
        assert(temp_diff.abs <= 0.01,
               "#{building_type}_#{template} is in #{climate_zone}. Air loop #{air_loop.name.get} system type is #{baseline_system_type}. The target economizer temperature high limit setpoint is #{temperature_highlimit_target} but get #{temperature_highlimit_model}")
      end
    end
    return true
  end

  def check_unenclosed_spaces(baseline_base)
    baseline_base.each do |baseline, baseline_model|
      building_type, template, climate_zone, user_data_dir, mod = baseline
      if building_type == 'SmallOffice'
        cons_name = baseline_model.getSurfaceByName('Core_ZN_ceiling').get.construction.get.name.to_s
        assert(cons_name == 'PRM IEAD Roof R-15.87', "The #{building_type} baseline model created for check_unenclosed_spaces() does not contain the expected constructions for surface adjacent to an unconditioned space. Expected: PRM IEAD Roof R-15.87; In the model #{cons_name}.")
        cons_name = baseline_model.getSurfaceByName('Core_ZN_ceiling').get.construction.get.name.to_s
        assert(cons_name == 'PRM IEAD Roof R-15.87', "The #{building_type} baseline model created for check_unenclosed_spaces() does not contain the expected constructions for surface adjacent to an unconditioned space. Expected: PRM IEAD Roof R-15.87; In the model #{cons_name}.")
      end
    end
    return true
  end

  def check_f_c_factors(baseline_base)
    baseline_base.each do |baseline, baseline_model|
      building_type, template, climate_zone, user_data_dir, mod = baseline
      # Check that the appropriate ground temperature profile object has been added to the model
      assert(!baseline_model.getSiteGroundTemperatureFCfactorMethod.nil?, "No FCfactorMethod ground temperature profile were found in the #{building_type} baseline model.")

      if building_type == 'LargeOffice'
        # Check ground temperature profile temperatures
        assert(baseline_model.getSiteGroundTemperatureFCfactorMethod.januaryGroundTemperature.to_f.round(1) == 24.2, "Wrong temperature in the FCfactorMethod ground temperature profile for the  #{building_type} baseline model.")
        assert(baseline_model.getSiteGroundTemperatureFCfactorMethod.julyGroundTemperature.to_f.round(1) == 21.2, "Wrong temperature in the FCfactorMethod ground temperature profile for the  #{building_type} baseline model.")

        # F-factor
        # Check outside boundary condition
        surface = baseline_model.getSurfaceByName('Basement_Floor').get
        assert(surface.outsideBoundaryCondition.to_s == 'GroundFCfactorMethod', "The #{building_type} baseline model created for check_f_c_factors() does not use the correct outside boundary condition for the slab on grade.")
        # Check construction type
        construction = surface.construction.get.to_FFactorGroundFloorConstruction.get
        assert(construction.iddObjectType.valueName.to_s == 'OS_Construction_FfactorGroundFloor', "The #{building_type} baseline model created for check_f_c_factors() does not use the correct construction type for the slab on grade.")
        # Check F-factor abd other params
        assert(construction.fFactor.round(2) == 1.26, "The #{building_type} baseline model created for check_f_c_factors() does not use the correct F-factor type for the slab on grade.")
        assert(construction.area.round(2) == 2779.43, "The #{building_type} baseline model created for check_f_c_factors() does not use the correct area for the slab on grade.")
        assert(construction.perimeterExposed == 0, "The #{building_type} baseline model created for check_f_c_factors() does not use the correct exposed perimeter for the slab on grade.")
        # C-factor
        # Check outside boundary condition
        surface = baseline_model.getSurfaceByName('Basement_Wall_East').get
        assert(surface.outsideBoundaryCondition.to_s == 'GroundFCfactorMethod', "The #{building_type} baseline model created for check_f_c_factors() does not use the correct outside boundary condition for the basement walls.")
        # Check construction type
        construction = surface.construction.get.to_CFactorUndergroundWallConstruction.get
        assert(construction.iddObjectType.valueName.to_s == 'OS_Construction_CfactorUndergroundWall', "The #{building_type} baseline model created for check_f_c_factors() does not use the correct construction type for the basement walls.")
        # Check F-factor abd other params
        assert(construction.cFactor.round(2) == 6.47, "The #{building_type} baseline model created for check_f_c_factors() does not use the correct C-factor type for the basement walls.")
        assert(construction.height.round(2) == 2.44, "The #{building_type} baseline model created for check_f_c_factors() does not use the correct height for the basement walls.")
      elsif building_type == 'SmallOffice'
        # F-factor
        # Check outside boundary condition
        surface = baseline_model.getSurfaceByName('Core_ZN_floor').get
        assert(surface.outsideBoundaryCondition.to_s == 'GroundFCfactorMethod', "The #{building_type} baseline model created for check_f_c_factors() does not use the correct outside boundary condition for the core slab on grade.")
        # Check construction type
        construction = surface.construction.get.to_FFactorGroundFloorConstruction.get
        assert(construction.iddObjectType.valueName.to_s == 'OS_Construction_FfactorGroundFloor', "The #{building_type} baseline model created for check_f_c_factors() does not use the correct construction type for the core slab on grade.")
        # Check F-factor abd other params
        assert(construction.fFactor.round(2) == 1.26, "The #{building_type} baseline model created for check_f_c_factors() does not use the correct F-factor type for the core slab on grade.")
        assert(construction.area.round(2) == 149.66, "The #{building_type} baseline model created for check_f_c_factors() does not use the correct area for the core slab on grade.")
        assert(construction.perimeterExposed == 0, "The #{building_type} baseline model created for check_f_c_factors() does not use the correct exposed perimeter for the core slab on grade.")
        # Check outside boundary condition
        surface = baseline_model.getSurfaceByName('Perimeter_ZN_1_floor').get
        assert(surface.outsideBoundaryCondition.to_s == 'GroundFCfactorMethod', "The #{building_type} baseline model created for check_f_c_factors() does not use the correct outside boundary condition for the perimeter slab on grade.")
        # Check construction type
        construction = surface.construction.get.to_FFactorGroundFloorConstruction.get
        assert(construction.iddObjectType.valueName.to_s == 'OS_Construction_FfactorGroundFloor', "The #{building_type} baseline model created for check_f_c_factors() does not use the correct construction type for the perimeter slab on grade.")
        # Check F-factor abd other params
        assert(construction.fFactor.round(2) == 1.26, "The #{building_type} baseline model created for check_f_c_factors() does not use the correct F-factor type for the perimeter slab on grade.")
        assert(construction.area.round(2) == 113.45, "The #{building_type} baseline model created for check_f_c_factors() does not use the correct area for the perimeter slab on grade.")
        assert(construction.perimeterExposed.round(2) == 27.69, "The #{building_type} baseline model created for check_f_c_factors() does not use the correct exposed perimeter for the perimeter slab on grade.")
      end
    end
  end

  # Set ZoneMultiplier to passed value for all zones
  # Check if coefficients of part-load power curve is correct per G3.1.3.15
  def check_variable_speed_fan_power(prototypes_base)
    prototypes_base.each do |prototype, model|
      model.getFanVariableVolumes.each do |supply_fan|
        supply_fan_name = supply_fan.name.get.to_s
        # check fan curves
        # Skip single-zone VAV fans
        next if supply_fan.airLoopHVAC.get.thermalZones.size == 1
        # coefficient 1
        if supply_fan.fanPowerCoefficient1.is_initialized
          expected_coefficient = 0.0013
          coefficient = supply_fan.fanPowerCoefficient1.get
          assert(((coefficient - expected_coefficient)/expected_coefficient).abs < 0.01, "Expected Coefficient 1 for #{supply_fan_name} to be equal to #{expected_coefficient}; found #{coefficient} instead")
        end
        # coefficient 2
        if supply_fan.fanPowerCoefficient2.is_initialized
          expected_coefficient = 0.1470
          coefficient = supply_fan.fanPowerCoefficient2.get
          assert(((coefficient - expected_coefficient)/expected_coefficient).abs < 0.01, "Expected Coefficient 1 for #{supply_fan_name} to be equal to #{expected_coefficient}; found #{coefficient} instead")
        end
        # coefficient 3
        if supply_fan.fanPowerCoefficient4.is_initialized
          expected_coefficient = 0.9506
          coefficient = supply_fan.fanPowerCoefficient3.get
          assert(((coefficient - expected_coefficient)/expected_coefficient).abs < 0.01, "Expected Coefficient 1 for #{supply_fan_name} to be equal to #{expected_coefficient}; found #{coefficient} instead")
        end
        # coefficient 4
        if supply_fan.fanPowerCoefficient4.is_initialized
          expected_coefficient = -0.0998
          coefficient = supply_fan.fanPowerCoefficient4.get
          assert(((coefficient - expected_coefficient)/expected_coefficient).abs < 0.01, "Expected Coefficient 1 for #{supply_fan_name} to be equal to #{expected_coefficient}; found #{coefficient} instead")
        end
        # coefficient 5
        if supply_fan.fanPowerCoefficient5.is_initialized
          expected_coefficient = 0
          coefficient = supply_fan.fanPowerCoefficient5.get
          assert((coefficient - expected_coefficient).abs < 0.01, "Expected Coefficient 1 for #{supply_fan_name} to be equal to #{expected_coefficient}; found #{coefficient} instead")
        end
      end  
    end
  end

  # Check if the VAV box minimum flow setpoint are
  # assigned following the rules in Appendix G
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_vav_min_sp(prototypes_base)
    standard = Standard.build('90.1-PRM-2019')
    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, mod = prototype
      model.getAirLoopHVACs.each do |air_loop|
        air_loop.thermalZones.each do |zone|
          zone.equipment.each do |equip|
            if equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
              zone_oa = standard.thermal_zone_outdoor_airflow_rate(zone)
              vav_terminal = equip.to_AirTerminalSingleDuctVAVReheat.get
              expected_mdp = [zone_oa / vav_terminal.autosizedMaximumAirFlowRate.get, 0.3].max.round(2)
              actual_mdp = vav_terminal.constantMinimumAirFlowFraction.get.round(2)
              assert(expected_mdp == actual_mdp , "Minimum MDP for #{building_type} for #{template} in #{climate_zone} should be #{expected_mdp} but #{actual_mdp} is used in the model.")
            elsif equip.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized
              zone_oa = standard.thermal_zone_outdoor_airflow_rate(zone)
              fp_vav_terminal = equip.to_AirTerminalSingleDuctParallelPIUReheat.get
              expected_prim_frac = [zone_oa / fp_vav_terminal.autosizedMaximumPrimaryAirFlowRate.get, 0.3].max.round(2)
              actual_prim_frac = fp_vav_terminal.minimumPrimaryAirFlowFraction.get
              assert(expected_prim_frac == actual_prim_frac , "Minimum primary air flow fraction for #{building_type} for #{template} in #{climate_zone} should be #{expected_prim_frac} but #{actual_prim_frac} is used in the model.")
            end
          end
        end
      end
    end
  end

  # Check fan power credits calculations
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_fan_power_credits(prototypes_base)
    standard = Standard.build('90.1-PRM-2019')
    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, mod = prototype
      std = Standard.build('90.1-PRM-2019')

      if building_type == 'SmallOffice'
        model.getFanVariableVolumes.sort.each do |fan|
          fan_power_si = std.fan_fanpower(fan) / std.fan_design_air_flow(fan)
          fan_power_ip = fan_power_si / OpenStudio.convert(1, 'm^3/s', 'cfm').get
          fan_bhp_ip = fan_power_ip * fan.motorEfficiency / 746.0
          assert(fan_bhp_ip.round(4) == 0.0017, "Fan power for #{fan.name.to_s} fan in #{building_type} #{template} #{climate_zone} #{mod} is #{fan_bhp_ip.round(4)} instead of 0.0017.")
        end
      end

      if building_type == 'RetailStandalone'
        model.getFanOnOffs.sort.each do |fan|
          if fan.name.to_s.include?('Front_Entry ZN')
            fan_power_si = std.fan_fanpower(fan) / std.fan_design_air_flow(fan)
            fan_power_ip = fan_power_si / OpenStudio.convert(1, 'm^3/s', 'cfm').get
            fan_bhp_ip = fan_power_ip * fan.motorEfficiency / 746.0
            assert(fan_bhp_ip.round(4) == 0.0012, "Fan power for  #{fan.name.to_s} fan in #{building_type} #{template} #{climate_zone} #{mod} is #{fan_bhp_ip.round(4)} instead of 0.0012.")
          end
        end
      end
    end
  end

  # Verify if return air plenums are generated
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_return_air_type(prototypes_base)
    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, mod = prototype

      if building_type == 'LargeOffice'
        assert(model.getAirLoopHVACReturnPlenums.length == 3, "The expected return air plenums in the large office baseline model have not been created.")
      end

      if building_type == 'PrimarySchool'
        assert(model.getAirLoopHVACReturnPlenums.length == 0, "Return air plenums are being modeled in the primary school baseline model, they are not expected.")
      end
    end
  end

  # Check model unmet load hours
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_unmet_load_hours(prototypes_base)
    standard = Standard.build('90.1-PRM-2019')
    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, mod = prototype

      assert(standard.model_get_unmet_load_hours(model) < 300, "The #{building_type} prototype building model has more than 300 unmet load hours.")
    end
  end

  # Placeholder method to indicate that we want to check unmet
  # load hours
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param arguments [Array] Not used
  def unmet_load_hours(model, arguments)
    return model
  end

  # Multiply the zone outdoor air flow rate per area
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param arguments [Array] Multiplier
  def mult_oa_per_area(model, arguments)
    # Get multiplier
    mult = arguments[0]

    # Multiply the outdoor air flow rate per area
    model.getDesignSpecificationOutdoorAirs.each do |dsn_oa|
      dsn_oa.setOutdoorAirFlowperFloorArea(dsn_oa.outdoorAirFlowperFloorArea * mult)
    end

    return model
  end

  # Add a AirLoopHVACDedicatedOutdoorAirSystem in the model
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param arguments [Array] Not used
  def add_ahu_doas(model, arguments)
    # Create new objects
    oa_ctrl = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_sys = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_ctrl)
    ahu_doas = OpenStudio::Model::AirLoopHVACDedicatedOutdoorAirSystem.new(oa_sys)
    ahu_doas.setName('AHU_DOAS')
    fan = OpenStudio::Model::FanSystemModel.new(model)

    # Assign fan and air loops
    fan.addToNode(oa_sys.outboardOANode.get)
    model.getAirLoopHVACs.each do |air_loop|
      ahu_doas.addAirLoop(air_loop)
    end

    return model
  end

  # Change cooling thermostat to 24C
  # This is used to converted a heated only zone to heated and cooled
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param arguments [Array] Not used
  def change_clg_therm(model, arguments)
    std = Standard.build("90.1-2019")
    thermal_zone = model.getThermalZoneByName(arguments[0]).get    
    tstat = thermal_zone.thermostat.get
    tstat = tstat.to_ThermostatSetpointDualSetpoint.get
    tstat.setCoolingSetpointTemperatureSchedule(std.model_add_constant_schedule_ruleset(model, 24, name = "#{thermal_zone.name.to_s} Cooling Schedule."))
    
    return model
  end

  # Set ZoneMultiplier to passed value for all zones
  #
  # @param model, arguments[]
  def set_zone_multiplier(model, arguments)
    mult = arguments[0]
    model.getAirLoopHVACs.each do |air_loop|
      air_loop.thermalZones.each do |thermal_zone|
        thermal_zone.setMultiplier(mult)
      end
    end
    return model
  end

  # Change classroom space types to laboratory
  # Resulting in > 15,000 cfm lab exhaust
  # Add an exhaust fan to each zone
  # @param model, arguments[]
  def make_lab_high_distrib_zone_exh(model, arguments)
    # Convert all classrooms to laboratory
    convert_spaces_from_to(model, ['PrimarySchoolClassroom', 'laboratory'])

    # add exhaust fans to lab zones
    add_exhaust_fan_per_lab_zone(model)

    return model
  end

  # Change computer classroom space types to laboratory
  # Resulting in < 15,000 cfm lab exhaust
  # Add an exhaust fan to each zone
  # @param model, arguments[]
  def make_lab_low_distrib_zone_exh(model, arguments)
    convert_spaces_from_to(model, ['PrimarySchoolComputerRoom', 'laboratory'])
    # Populate hash to allow this space type to persist when protoype space types are replaced later
    # add exhaust fans to lab zones
    add_exhaust_fan_per_lab_zone(model)

    return model
  end

  # Change classroom space types to laboratory
  # Resulting in > 15,000 cfm lab exhaust
  # @param model, arguments[]
  def make_lab_high_system_exh(model, arguments)
    # Convert all classrooms to laboratory
    convert_spaces_from_to(model, ['PrimarySchoolClassroom', 'laboratory'])

    # reset OA make lab space OA exceed 17,000 cfm
    oa_name = 'PrimarySchool Classroom Ventilation'
    model.getDesignSpecificationOutdoorAirs.sort.each do |oa_def|
      if oa_def.name.to_s == oa_name
        oa_area = oa_def.outdoorAirFlowperFloorArea
        oa_def.setOutdoorAirFlowperFloorArea(0.0029)
      end
    end
    return model
  end

  # Convert specified space types to laboratory space type
  # @param model, from_bldg_space is name of existing space type to convert to laboratory
  def convert_spaces_from_to(model, arguments)
    from_bldg_space, to_bldg_space = arguments
    # Convert all spaces of type to convert to laboratory
    model.getSpaceTypes.sort.each do |space_type|
      next if space_type.floorArea == 0

      standards_space_type = if space_type.standardsSpaceType.is_initialized
                               space_type.standardsSpaceType.get
                             end
      std_bldg_type = space_type.standardsBuildingType.get
      bldg_type_space_type = std_bldg_type + space_type.standardsSpaceType.get
      if bldg_type_space_type == from_bldg_space
        space_type.setStandardsSpaceType(to_bldg_space)
        # Populate hash to allow this space type to persist when protoype space types are replaced later
        @lpd_space_types_alt[std_bldg_type + to_bldg_space] = to_bldg_space
      end
    end
    return model
  end

  # Change (medium) office space types to computer room
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param arguments [Array] Not used
  def convert_spaces_to_cmp_rms(model, arguments)
    convert_spaces_from_to(model, ['OfficeWholeBuilding - Md Office', 'computer room'])
    return model
  end

  # Add exhaust fan object to each lab zone in model
  # @param model
  def add_exhaust_fan_per_lab_zone(model)
    model.getThermalZones.sort.each do |thermal_zone|
      lab_is_found = false
      zone_area = 0
      thermal_zone.spaces.each do |space|
        space_type = space.spaceType.get.standardsSpaceType.get
        if space_type == 'laboratory'
          lab_is_found = true
          zone_area += space.floorArea
        end
      end
      if lab_is_found
        # add an exhaust fan
        zone_exhaust_fan = OpenStudio::Model::FanZoneExhaust.new(model)
        zone_exhaust_fan.setName(thermal_zone.name.to_s + ' Exhaust Fan')
        zone_exhaust_fan.setFanEfficiency(0.6)
        zone_exhaust_fan.setPressureRise(200)

        # set air flow above threshold for isolation of lab spaces on separate hvac system
        # A rate of 0.5 cfm/sf gives 17,730 cfm total exhaust
        exhaust_cfm = 0.5 * zone_area
        maximum_flow_rate = OpenStudio.convert(exhaust_cfm, 'cfm', 'm^3/s').get
        zone_exhaust_fan.setMaximumFlowRate(maximum_flow_rate)
        zone_exhaust_fan.setEndUseSubcategory('Zone Exhaust Fans')
        zone_exhaust_fan.addToThermalZone(thermal_zone)
      end
    end
  end

  # Change fenestration area in a model
  # This function will remove the fenestration in all orientations and add new windows by defined WWR
  #
  # @param [OpenStudio::Model::Model] model
  # @param [Float] window to wall ratio
  def change_wwr_model(model, arguments)
    target_wwr_north = arguments[0]
    target_wwr_south = arguments[1]
    target_wwr_east = arguments[2]
    target_wwr_west = arguments[3]

    model.getSurfaces.each do |ss|
      # determine orientation
      space = ss.space.get
      # Get model object
      model = ss.model
      # Calculate azimuth
      surface_azimuth_rel_space = OpenStudio.convert(ss.azimuth, 'rad', 'deg').get
      space_dir_rel_north = space.directionofRelativeNorth
      building_dir_rel_north = model.getBuilding.northAxis
      surface_abs_azimuth = surface_azimuth_rel_space + space_dir_rel_north + building_dir_rel_north
      surface_abs_azimuth -= 360.0 until surface_abs_azimuth < 360.0

      unless ss.subSurfaces.empty?
        # get subsurface construction
        orig_construction = nil
        door_list = []
        ss.subSurfaces.sort.each do |sub|
          if sub.subSurfaceType == 'Door'
            door = {}
            door['name'] = sub.name.get
            door['vertices'] = sub.vertices()
            door['construction'] = sub.construction.get
            door_list << door
          else
            orig_construction = sub.construction.get
          end
        end
        # remove all existing surfaces
        ss.subSurfaces.sort.each(&:remove)
        # Determine the surface's cardinal direction
        if surface_abs_azimuth >= 0 && surface_abs_azimuth <= 45
          helper_add_window_to_wwr_with_door(target_wwr_north, ss, orig_construction, door_list, model)
        elsif surface_abs_azimuth > 315 && surface_abs_azimuth <= 360
          helper_add_window_to_wwr_with_door(target_wwr_north, ss, orig_construction, door_list, model)
        elsif surface_abs_azimuth > 45 && surface_abs_azimuth <= 135 &&
          helper_add_window_to_wwr_with_door(target_wwr_east, ss, orig_construction, door_list, model)
        elsif surface_abs_azimuth > 135 && surface_abs_azimuth <= 225
          helper_add_window_to_wwr_with_door(target_wwr_south, ss, orig_construction, door_list, model)
        elsif surface_abs_azimuth > 225 && surface_abs_azimuth <= 315 && target_wwr_west > 0.0
          helper_add_window_to_wwr_with_door(target_wwr_west, ss, orig_construction, door_list, model)
        end
      end
    end
    return model
  end

  def helper_add_window_to_wwr_with_door(target_wwr, surface, construction, door_list, model)
    if target_wwr > 0.0
      new_window = surface.setWindowToWallRatio(target_wwr, 0.6, true).get
      new_window.setConstruction(construction) unless construction.nil?
    end
    # add door back.
    unless door_list.empty?
      door_list.each do |door|
        os_door = OpenStudio::Model::SubSurface.new(door['vertices'], model)
        os_door.setName(door['name'])
        os_door.setConstruction(door['construction'])
        os_door.setSurface(surface)
      end
    end
  end
  # Change model to different building type
  # @param model, arguments => new building type
  def change_bldg_type(model, arguments)
    bldg_type_new = arguments[0]
    @bldg_type_alt_now = bldg_type_new
    return model
  end

  # Remove transformer from model
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param arguments [Array] List of arguments
  def remove_transformer(model, arguments)
    model.getElectricLoadCenterTransformers.each(&:remove)
    return model
  end

  # Increase the size of the skylights in a model
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param arguments [Array] List of arguments
  def increase_skylight_size(model, arguments)
    mult = arguments[0]
    model.getSpaces.sort.each do |space|
      next if @prototype_creator.space_conditioning_category(space) == 'Unconditioned'

      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'

        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'

        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'Skylight'

          # increase the size of the skylight
          @prototype_creator.sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid(ss, mult)
        end
      end
    end

    return model
  end

  # Applies a multipler to increase the design cooling load of datacenters
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param epd_multiplier [Array] EPD multiplier
  # @returns [OpenStudio::model::Model]
  def increase_computer_rooms_epd(model, epd_multiplier)
    model.getThermalZones.each do |zone|
      zone.spaces.each do |space|
        if space.spaceType.get.standardsSpaceType.get.to_s.downcase.include?('data center') ||
           space.spaceType.get.standardsSpaceType.get.to_s.downcase.include?('computer room')
          elec_eqp = space.spaceType.get.electricEquipment
          elec_eqp[0].setMultiplier(epd_multiplier[0])
        end
      end
    end
    return model
  end

  # Change equipment power density of a specific zone in a model to a specific value
  # @author Doug Maddox, PNNL
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param params [Array] zone_name, new equipment power density
  # @return [OpenStudio::model::Model]
  def change_zone_epd(model, params)
    zone_name = params[0]
    new_epd = params[1]

    model.getThermalZones.each do |zone|
      if zone.name.get == zone_name
        zone.spaces.each do |space|
          elec_eqp = space.spaceType.get.electricEquipment
          elec_sch = space.spaceType.get.defaultScheduleSet.get.electricEquipmentSchedule.get
          elec_name = 'special_plug_load'

          # elec_eqp[0].electricEquipmentDefinition.setWattsperSpaceFloorArea(new_epd)
          eqp_before = elec_eqp[0].getDesignLevel(space.floorArea, 0)
          # elec_eqp[0].electricEquipmentDefinition.setWattsperSpaceFloorArea(new_epd)
          elecdef = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
          elecdef.setWattsperSpaceFloorArea(new_epd)
          elecdef.setName(elec_name + '-def')
          elec = OpenStudio::Model::ElectricEquipment.new(elecdef)
          elec.setSpace(space)
          elec.setName(elec_name)
          elec.setMultiplier(1)
          elec.setSchedule(elec_sch)
          eqp_after = elec_eqp[0].getDesignLevel(space.floorArea, 0)
          istop = 1
        end
      end
    end
    return model
  end

  # Remove cooling coil from air loops in model
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param params [Array] zone_name, new equipment power density
  # @return [OpenStudio::model::Model]
  def remove_cooling_coils(model, params)
    model.getAirLoopHVACs.each do |air_loop|
      air_loop.supplyComponents.each do |supply_comp|
        if supply_comp.iddObjectType.valueName.to_s.include?('OS_Coil_Cooling')
          supply_comp.remove
        elsif supply_comp.iddObjectType.valueName.to_s.include?('OS_AirLoopHVAC_UnitarySystem')
          unitary_sys = supply_comp.to_AirLoopHVACUnitarySystem.get
          cooling_coil = unitary_sys.coolingCoil
          if cooling_coil.is_initialized
            cooling_coil = cooling_coil.get
            unitary_sys.resetCoolingCoil
            cooling_coil.remove
            controller_oa = air_loop.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir
            controller_oa.setEconomizerControlType('FixedDryBulb')
          end
        end
      end
    end
    return model
  end

  # Add return and relief fans to air loops
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param params [Array] zone_name, new equipment power density
  # @return [OpenStudio::model::Model]
  def return_relief_fan(model, params)
    std = Standard.build('90.1-PRM-2019')
    model.getAirLoopHVACs.each do |air_loop|
      # Add return fan
      return_fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule)
      return_fan.setName("#{air_loop.name} return fan")
      return_fan.addToNode(air_loop.returnAirNode.get)

      # Add relief fan
      relief_fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule)
      relief_fan.setName("#{air_loop.name} relief fan")
      relief_fan.addToNode(air_loop.reliefAirNode.get)

      # Get supply fan
      supply_fan = air_loop.supplyFan.get
      if supply_fan.to_FanConstantVolume.is_initialized
        supply_fan = supply_fan.to_FanConstantVolume.get
      elsif supply_fan.to_FanVariableVolume.is_initialized
        supply_fan = supply_fan.to_FanVariableVolume.get
      elsif supply_fan.to_FanOnOff.is_initialized
        supply_fan = supply_fan.to_FanOnOff.get
      elsif supply_fan.to_FanSystemModel.is_initialized
        supply_fan = supply_fan.to_FanSystemModel.get
      end

      # Adjust return and relief fan power
      # Get the current pressure rise (Pa)
      return_fan.setPressureRise(supply_fan.pressureRise * 2)
      relief_fan.setPressureRise(supply_fan.pressureRise * 3)

      # Get the total fan efficiency
      return_fan.setFanEfficiency(supply_fan.fanEfficiency)
      relief_fan.setFanEfficiency(supply_fan.fanEfficiency)
    end
    return model
  end

  # Add people object to a specific zone with a long occupancy schedule
  # for testing 40 EFLH check of zones that differ for multizone systems
  # @author Doug Maddox, PNNL
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @param params [Array] zone_name, new equipment power density
  # @return [OpenStudio::model::Model]
  def change_to_long_occ_sch(model, params)
    zone_name = params[0]
    # Create new long schedule for occupancy for each space in the zone
    # and assign to the spaces
    act_sch = nil
    ppl_sch_type_limits = nil
    model.getThermalZones.each do |zone|
      if zone.name.get == zone_name
        zone.spaces.each do |space|
          # Get existing activity schedule to use for new schedule
          space.spaceType.get.people.each do |people|
            act_sch = people.activityLevelSchedule
            if act_sch.is_initialized
              if act_sch.get.to_ScheduleRuleset.is_initialized
                act_sch = act_sch.get.to_ScheduleRuleset.get
              end
            end
            # Get existing schedule type limits to use for new schedule
            occ_sch = people.numberofPeopleSchedule
            if people.isNumberofPeopleScheduleDefaulted
              # Check default schedule set
              unless space.spaceType.get.defaultScheduleSet.empty?
                unless space.spaceType.get.defaultScheduleSet.get.numberofPeopleSchedule.empty?
                  occ_sch = space.spaceType.get.defaultScheduleSet.get.numberofPeopleSchedule
                end
              end
            end
            ppl_sch_type_limits = occ_sch.get.scheduleTypeLimits.get
          end

          # Create new schedule always occupied
          ppl_values = Array.new(8760, 1)
          ppl_sch_name = space.name.get + 'ppl_sch_long'
          ppl_long_sch = @prototype_creator.make_ruleset_sched_from_8760(model, ppl_values, ppl_sch_name, ppl_sch_type_limits)

          # Create new people object and apply to the space
          peopledef = OpenStudio::Model::PeopleDefinition.new(model)
          peopledef.setName(space.name.get + 'ppl-long-def')
          peopledef.setNumberofPeople(10)
          peopledef.setFractionRadiant(0.3000)
          people = OpenStudio::Model::People.new(peopledef)
          people.setName(space.name.get + 'ppl-long')
          people.setMultiplier(1)
          people.setActivityLevelSchedule(act_sch)
          people.setNumberofPeopleSchedule(ppl_long_sch)
          people.setSpace(space)
        end
      end
    end

    # Also need to set the fan of the system serving that zone to run 24/7

    model.getAirLoopHVACs.each do |air_loop|
      air_loop.thermalZones.each do |zone|
        if zone.name.get == zone_name
          air_loop.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
        end
      end
    end

    return model
  end

  # Check hvac baseline system efficiencies
  def check_hvac_efficiency(prototypes_base)
    # No.1 PTAC
    # cooling: CoilCoolingDXSingleSpeed
    # heating: CoilHeatingWater
    # hash = {capacity:cop}
    capacity_cop_cool = {100000=>3.1}
    capacity_cop_cool.each do |key_cool, value_cool|
      std = Standard.build('90.1-PRM-2019')
      prototypes_base.each do |prototype, model_base|
        building_type, template, climate_zone, user_data_dir, mod = prototype
        if building_type == 'SmallOffice' && climate_zone == 'ASHRAE 169-2013-2A'
          # Create a deep copy of the proposed model
          model_ptac = BTAP::FileIO.deep_copy(model_base)
          # Remove all HVAC from model, excluding service water heating
          std.model_remove_prm_hvac(model_ptac)
          hot_water_loop = std.model_add_hw_loop(model_ptac, 'DistrictHeating')
          model_ptac.getPumpVariableSpeeds.each do |pump|
            pump.setRatedFlowRate(100)
          end
          zones = model_ptac.getThermalZones
          zones.each do |zone|
            zone.additionalProperties.setFeature('baseline_system_type', 'PTAC')
          end
          std.model_add_ptac(model_ptac,
                             zones,
                             cooling_type: 'Single Speed DX AC',
                             heating_type: 'Water',
                             hot_water_loop: hot_water_loop,
                             fan_type: 'ConstantVolume')
          zones.each do |zone|
            zone.equipment.each do |zone_equipment|
              ptac = zone_equipment.to_ZoneHVACPackagedTerminalAirConditioner.get
              ptac.supplyAirFan.to_FanConstantVolume.get.setMaximumFlowRate(100)
              clg_coil = ptac.coolingCoil.to_CoilCoolingDXSingleSpeed.get
              capacity_cool_w = OpenStudio.convert(key_cool, 'Btu/hr', 'W'). get
              clg_coil.setRatedTotalCoolingCapacity(capacity_cool_w)
            end
          end
          std.model_apply_hvac_efficiency_standard(model_ptac, climate_zone)
          assert((model_ptac.getCoilCoolingDXSingleSpeeds[0].ratedCOP.to_f - value_cool).abs < 0.001, 'Error in efficiency setting for cooling DX single coil (PTAC).')
        end
      end
    end

    # No.2 PTHP
    # cooling: CoilCoolingDXSingleSpeed
    # heating: CoilHeatingDXSingleSpeed
    # hash = {capacity:cop}
    capacity_cop_cool = {100000=>3.1}
    capacity_eff_heat = {100000=>3.1}
    capacity_cop_cool.each do |key_cool, value_cool|
      capacity_eff_heat.each do |key_heat, value_heat|
        std = Standard.build('90.1-PRM-2019')
        prototypes_base.each do |prototype, model_base|
          building_type, template, climate_zone, user_data_dir, mod = prototype
          if building_type == 'SmallOffice' && climate_zone == 'ASHRAE 169-2013-2A'
            # Create a deep copy of the proposed model
            model_pthp = BTAP::FileIO.deep_copy(model_base)
            # Remove all HVAC from model, excluding service water heating
            std.model_remove_prm_hvac(model_pthp)
            zones = model_pthp.getThermalZones
            zones.each do |zone|
              zone.additionalProperties.setFeature('baseline_system_type', 'PTHP')
            end
            std.model_add_pthp(model_pthp,
                               zones,
                               fan_type: 'ConstantVolume')
            zones.each do |zone|
              zone.equipment.each do |zone_equipment|
                pthp = zone_equipment.to_ZoneHVACPackagedTerminalHeatPump.get
                pthp.supplyAirFan.to_FanConstantVolume.get.setMaximumFlowRate(100)
                clg_coil = pthp.coolingCoil.to_CoilCoolingDXSingleSpeed.get
                capacity_cool_w = OpenStudio.convert(key_cool, 'Btu/hr', 'W'). get
                clg_coil.setRatedTotalCoolingCapacity(capacity_cool_w)
                htg_coil = pthp.heatingCoil.to_CoilHeatingDXSingleSpeed.get
                capacity_heat_w = OpenStudio.convert(key_heat, 'Btu/hr', 'W'). get
                htg_coil.setRatedTotalHeatingCapacity(capacity_heat_w)
              end
            end
            std.model_apply_hvac_efficiency_standard(model_pthp, climate_zone)
            assert((model_pthp.getCoilCoolingDXSingleSpeeds[0].ratedCOP.to_f - value_cool).abs < 0.001, 'Error in efficiency setting for cooling DX single coil (PTHP).')
            assert((model_pthp.getCoilHeatingDXSingleSpeeds[0].ratedCOP.to_f - value_heat).abs < 0.001, 'Error in efficiency setting for heating DX single coil (PTHP).')
          end
        end
      end
    end

    # No.3 PSZ_AC
    # cooling: CoilCoolingDXSingleSpeed
    # heating: CoilHeatingGas
    # hash = {capacity:cop}
    capacity_cop_cool = {10000=>3.0,
                         300000=>3.5}
    capacity_cop_heat = {10000=>0.8,
                         300000=>0.793}
    capacity_cop_cool.each do |key_cool, value_cool|
      capacity_cop_heat.each do |key_heat, value_heat|
        std = Standard.build('90.1-PRM-2019')
        prototypes_base.each do |prototype, model_base|
          building_type, template, climate_zone, user_data_dir, mod = prototype
          if building_type == 'SmallOffice' && climate_zone == 'ASHRAE 169-2013-8A'
            # Create a deep copy of the proposed model
            model_psz_ac = BTAP::FileIO.deep_copy(model_base)
            # Remove all HVAC from model, excluding service water heating
            std.model_remove_prm_hvac(model_psz_ac)
            # Remove all EMS objects from the model
            std.model_remove_prm_ems_objects(model_psz_ac)
            zones = model_psz_ac.getThermalZones
            std.model_add_psz_ac(model_psz_ac,
                                 zones,
                                 cooling_type: 'Single Speed DX AC',
                                 chilled_water_loop: nil,
                                 heating_type: 'Gas',
                                 supplemental_heating_type: nil,
                                 hot_water_loop: nil,
                                 fan_location: 'DrawThrough',
                                 fan_type: 'ConstantVolume')
            capacity_cool_w = OpenStudio.convert(key_cool, 'Btu/hr', 'W'). get
            model_psz_ac.getCoilCoolingDXSingleSpeeds.sort.each do |clg_coil|
              clg_coil.setRatedTotalCoolingCapacity(capacity_cool_w)
            end
            capacity_heat_w = OpenStudio.convert(key_heat, 'Btu/hr', 'W'). get
            model_psz_ac.getCoilHeatingGass.sort.each do |htg_coil|
              htg_coil.setNominalCapacity(capacity_heat_w)
            end
            model_psz_ac.getAirLoopHVACs.each do |air_loop_hvac|
              air_loop_hvac.additionalProperties.setFeature('baseline_system_type', 'PSZ_AC')
              air_loop_hvac.setDesignSupplyAirFlowRate(0.01)
            end
            model_psz_ac.getFanOnOffs.each do |fan_on_off|
              fan_on_off.setMaximumFlowRate(0.01)
            end
            std.model_apply_hvac_efficiency_standard(model_psz_ac, climate_zone)
            assert((model_psz_ac.getCoilCoolingDXSingleSpeeds[0].ratedCOP.to_f - value_cool).abs < 0.001, 'Error in efficiency setting for cooling DX single coil (PSZ-AC).')
            assert((model_psz_ac.getCoilHeatingGass[0].gasBurnerEfficiency.to_f - value_heat).abs < 0.001, 'Error in efficiency setting for heating gas coil (PSZ-AC).')
          end
        end
      end
    end

    # No.4 PSZ_HP
    # cooling: CoilCoolingDXSingleSpeed
    # heating: CoilHeatingDXSingleSpeed
    # hash = {capacity:cop}
    capacity_cop_cool = {10000=>3.0,
                         300000=>3.1}
    capacity_cop_heat = {10000=>3.4,
                         300000=>3.4}
    capacity_cop_cool.each do |key_cool, value_cool|
      capacity_cop_heat.each do |key_heat, value_heat|
        std = Standard.build('90.1-PRM-2019')
        prototypes_base.each do |prototype, model_base|
          building_type, template, climate_zone, user_data_dir, mod = prototype
          if building_type == 'SmallOffice' && climate_zone == 'ASHRAE 169-2013-2A'
            # Create a deep copy of the proposed model
            model_psz_hp = BTAP::FileIO.deep_copy(model_base)
            capacity_cool_w = OpenStudio.convert(key_cool, 'Btu/hr', 'W'). get
            model_psz_hp.getCoilCoolingDXSingleSpeeds.sort.each do |clg_coil|
              clg_coil.setRatedTotalCoolingCapacity(capacity_cool_w)
            end
            capacity_heat_w = OpenStudio.convert(key_heat, 'Btu/hr', 'W'). get
            model_psz_hp.getCoilHeatingDXSingleSpeeds.sort.each do |htg_coil|
              htg_coil.setRatedTotalHeatingCapacity(capacity_heat_w)
            end
            std.model_apply_hvac_efficiency_standard(model_psz_hp, climate_zone)
            assert((model_psz_hp.getCoilCoolingDXSingleSpeeds[0].ratedCOP.to_f - value_cool).abs < 0.001, 'Error in efficiency setting for cooling DX single coil (PSZ-HP).')
            assert((model_psz_hp.getCoilHeatingDXSingleSpeeds[0].ratedCOP.to_f - value_heat).abs < 0.001, 'Error in efficiency setting for heating DX single coil (PSZ-HP).')
          end
        end
      end
    end

    # No.5 PVAV_Reheat
    # cooling: CoilCoolingDXTwoSpeed
    # heating: Boiler
    # hash = {capacity:cop}
    capacity_cop_cool = {10000=>3.0,
                         300000=>3.5}
    boiler_capacity_eff = {100000=>0.8,
                           1000000=>0.75}
    capacity_cop_cool.each do |key_cool, value_cool|
      boiler_capacity_eff.each do |key_heat, value_heat|
        std = Standard.build('90.1-PRM-2019')
        prototypes_base.each do |prototype, model_base|
          building_type, template, climate_zone, user_data_dir, mod = prototype
          if building_type == 'MediumOffice' && template == "90.1-2013" && climate_zone == 'ASHRAE 169-2013-8A'
            # Create a deep copy of the proposed model
            model_pvav_reheat = BTAP::FileIO.deep_copy(model_base)
            capacity_cool_w = OpenStudio.convert(key_cool, 'Btu/hr', 'W'). get
            model_pvav_reheat.getCoilCoolingDXTwoSpeeds.sort.each do |clg_coil|
              clg_coil.setRatedHighSpeedTotalCoolingCapacity(capacity_cool_w)
              clg_coil.setRatedLowSpeedTotalCoolingCapacity(capacity_cool_w)
            end
            capacity_heat_w = OpenStudio.convert(key_heat, 'Btu/hr', 'W'). get
            model_pvav_reheat.getBoilerHotWaters.sort.each do |boiler|
              boiler.setNominalCapacity(capacity_heat_w)
            end
            std.model_apply_hvac_efficiency_standard(model_pvav_reheat, climate_zone)
            assert((model_pvav_reheat.getCoilCoolingDXTwoSpeeds[0].ratedHighSpeedCOP.to_f - value_cool).abs < 0.001, 'Error in efficiency setting for cooling DX two speed coil (PVAV_Reheat).')
            assert((model_pvav_reheat.getCoilCoolingDXTwoSpeeds[0].ratedLowSpeedCOP.to_f - value_cool).abs < 0.001, 'Error in efficiency setting for cooling DX two speed coil (PVAV_Reheat).')
            assert((model_pvav_reheat.getBoilerHotWaters[0].nominalThermalEfficiency.to_f - value_heat).abs < 0.001, 'Error in efficiency setting for boiler (PVAV_Reheat).')
          end
        end
      end
    end

    # No.6 PVAV_PFP_Boxes
    # cooling: CoilCoolingDXTwoSpeed
    # heating: CoilHeatingElectric
    # hash = {capacity:cop}
    capacity_cop_cool = {10000=>3.0,
                         300000=>3.5}
    capacity_cop_cool.each do |key_cool, value_cool|
      boiler_capacity_eff.each do |key_heat, value_heat|
        std = Standard.build('90.1-PRM-2019')
        prototypes_base.each do |prototype, model_base|
          building_type, template, climate_zone, user_data_dir, mod = prototype
          if building_type == 'MediumOffice' && template == "90.1-2013" && climate_zone == 'ASHRAE 169-2013-2A'
            # Create a deep copy of the proposed model
            model_pvav_pfp_boxes = BTAP::FileIO.deep_copy(model_base)
            capacity_cool_w = OpenStudio.convert(key_cool, 'Btu/hr', 'W'). get
            model_pvav_pfp_boxes.getCoilCoolingDXTwoSpeeds.sort.each do |clg_coil|
              clg_coil.setRatedHighSpeedTotalCoolingCapacity(capacity_cool_w)
              clg_coil.setRatedLowSpeedTotalCoolingCapacity(capacity_cool_w)
            end
            std.model_apply_hvac_efficiency_standard(model_pvav_pfp_boxes, climate_zone)
            assert((model_pvav_pfp_boxes.getCoilCoolingDXTwoSpeeds[0].ratedHighSpeedCOP.to_f - value_cool).abs < 0.001, 'Error in efficiency setting for cooling DX two speed coil (PVAV_PFP_Boxes).')
            assert((model_pvav_pfp_boxes.getCoilCoolingDXTwoSpeeds[0].ratedLowSpeedCOP.to_f - value_cool).abs < 0.001, 'Error in efficiency setting for cooling DX two speed coil (PVAV_PFP_Boxes).')
          end
        end
      end
    end

    # No.7 VAV_Reheat
    # cooling: Chiller/CoolingTower
    # heating: Boiler
    # hash = {capacity:cop}
    chiller_capacity_eff = {100=>0.79,
                            200=>0.718}
    boiler_capacity_eff = {100000=>0.8,
                           1000000=>0.75}
    chiller_capacity_eff.each do |key_cool, value_cool|
      boiler_capacity_eff.each do |key_heat, value_heat|
        std = Standard.build('90.1-PRM-2019')
        prototypes_base.each do |prototype, model_base|
          building_type, template, climate_zone, user_data_dir, mod = prototype
          if building_type == 'MediumOffice' && template == '90.1-2004'
            # Create a deep copy of the proposed model
            model_vav_reheat = BTAP::FileIO.deep_copy(model_base)
            capacity_cool_w = OpenStudio.convert(key_cool, 'ton', 'W'). get
            model_vav_reheat.getChillerElectricEIRs.sort.each do |chiller|
              chiller.setReferenceCapacity(capacity_cool_w)
            end
            capacity_heat_w = OpenStudio.convert(key_heat, 'Btu/hr', 'W'). get
            model_vav_reheat.getBoilerHotWaters.sort.each do |boiler|
              boiler.setNominalCapacity(capacity_heat_w)
            end
            std.model_apply_hvac_efficiency_standard(model_vav_reheat, climate_zone)
            assert((model_vav_reheat.getChillerElectricEIRs[0].referenceCOP.to_f - 3.517 / value_cool).abs < 0.001, 'Error in efficiency setting for chiller (VAV_Reheat).')
            assert((model_vav_reheat.getBoilerHotWaters[0].nominalThermalEfficiency.to_f - value_heat).abs < 0.001, 'Error in efficiency setting for boiler (VAV_Reheat).')
          end
        end
      end
    end

    # check cooling tower heat rejection
    std = Standard.build('90.1-PRM-2019')
    prototypes_base.each do |prototype, model_base|
      building_type, template, climate_zone, user_data_dir, mod = prototype
      if building_type == 'MediumOffice' && template == '90.1-2004'
        # Create a deep copy of the proposed model
        model_vav_reheat_coolingtower = BTAP::FileIO.deep_copy(model_base)
        design_water_flow_gpm = 1000
        design_water_flow_m3_per_s = OpenStudio.convert(design_water_flow_gpm, 'gal/min', 'm^3/s').get
        model_vav_reheat_coolingtower.getCoolingTowerVariableSpeeds[0].setDesignWaterFlowRate(design_water_flow_m3_per_s)
        design_water_flow_gpm = OpenStudio.convert(design_water_flow_m3_per_s, 'm^3/s', 'gal/min').get
        fan_motor_nameplate_hp = design_water_flow_gpm / 38.2
        fan_bhp = 0.9 * fan_motor_nameplate_hp
        fan_motor_eff = 0.924
        fan_motor_actual_power_hp = fan_bhp / fan_motor_eff
        fan_motor_actual_power_w = fan_motor_actual_power_hp * 745.7
        std.model_apply_hvac_efficiency_standard(model_vav_reheat_coolingtower, climate_zone)
        assert((model_vav_reheat_coolingtower.getCoolingTowerVariableSpeeds[0].designFanPower.to_f - fan_motor_actual_power_w).abs < 0.001, 'Error in setting for cooling tower heat rejection (VAV_Reheat).')
      end
    end

    # No.8 VAV_PFP_Boxes
    # cooling: Chiller/CoolingTower
    # heating: Boiler
    # hash = {capacity:cop}
    chiller_capacity_eff = {100=>0.703,
                            200=>0.634}
    chiller_capacity_eff.each do |key_cool, value_cool|
      std = Standard.build('90.1-PRM-2019')
      prototypes_base.each do |prototype, model_base|
        building_type, template, climate_zone, user_data_dir, mod = prototype
        if building_type == 'LargeOffice' && template == '90.1-2004'
          # Create a deep copy of the proposed model
          model_vav_pfp = BTAP::FileIO.deep_copy(model_base)
          capacity_cool_w = OpenStudio.convert(key_cool, 'ton', 'W'). get
          model_vav_pfp.getChillerElectricEIRs.sort.each do |chiller|
            chiller.setReferenceCapacity(capacity_cool_w)
          end
          std.model_apply_hvac_efficiency_standard(model_vav_pfp, climate_zone)
          assert((model_vav_pfp.getChillerElectricEIRs[0].referenceCOP.to_f - 3.517 / value_cool).abs < 0.001, 'Error in efficiency setting for chiller (VAV_Reheat).')
        end
      end
    end

    # No.9 Gas_Furnace
    # heating: CoilHeatingGas
    # hash = {capacity:cop}
    capacity_cop_heat = {10000=>0.793}
    capacity_cop_heat.each do |key_heat, value_heat|
      std = Standard.build('90.1-PRM-2019')
      prototypes_base.each do |prototype, model_base|
        building_type, template, climate_zone, user_data_dir, mod = prototype
        if building_type == 'SmallOffice' && climate_zone == 'ASHRAE 169-2013-2A'
          # Create a deep copy of the proposed model
          model_gas_furnace = BTAP::FileIO.deep_copy(model_base)
          # Remove all HVAC from model, excluding service water heating
          std.model_remove_prm_hvac(model_gas_furnace)
          # Remove all EMS objects from the model
          std.model_remove_prm_ems_objects(model_gas_furnace)
          zones = model_gas_furnace.getThermalZones
          zones.each do |zone|
            zone.additionalProperties.setFeature('baseline_system_type', 'Gas_Furnace')
          end
          std.model_add_unitheater(model_gas_furnace,
                                   zones,
                                   fan_control_type: 'ConstantVolume',
                                   fan_pressure_rise: 0.2,
                                   heating_type: 'Gas',
                                   hot_water_loop: nil)
          capacity_heat_w = OpenStudio.convert(key_heat, 'Btu/hr', 'W'). get
          model_gas_furnace.getCoilHeatingGass.sort.each do |htg_coil|
            htg_coil.setNominalCapacity(capacity_heat_w)
          end
          model_gas_furnace.getFanConstantVolumes.each do |fan_constant_volume|
            fan_constant_volume.setMaximumFlowRate(0.01)
          end
          std.model_apply_hvac_efficiency_standard(model_gas_furnace, climate_zone)
          assert((model_gas_furnace.getCoilHeatingGass[0].gasBurnerEfficiency.to_f - value_heat).abs < 0.001, 'Error in efficiency setting for gas furnace (Gas Furnace).')
        end
      end
    end
  end

  # Add piping insulation to service heating water systems
  def add_piping_insulation(model, arguments)
    std = Standard.build('90.1-PRM-2019')
    model.getPlantLoops.each do |plantloop|
      if std.plant_loop_swh_loop?(plantloop)
        std.model_add_piping_losses_to_swh_system(model, plantloop, true)
      end
    end

    return model
  end

  # Change the weather used in the model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param arguments [Array] List of arguments
  # return [OpenStudio::Model::Model] OpenStudio model object
  def change_weather_file(model, arguments)
    # Define new weather file
    weather_file = File.join(@@json_dir, "USA_VA_Arlington-Ronald.Reagan.Washington.Natl.AP.724050_TMY3.epw")
    epw_file = OpenStudio::EpwFile.new(weather_file)

    # Assign new weather file
    OpenStudio::Model::WeatherFile.setWeatherFile(model, epw_file).get

    return model

  end

  # Check that no pipe insulation is modeled in the baseline models
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_pipe_insulation(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype
      # Check if the model include PipeIndoor or PipeOutdoor objects
      model_baseline.getPlantLoops.each do |plant_loop|
        existing_pipe_insulation = ''
        a = plant_loop.supplyComponents
        b = plant_loop.demandComponents
        plantloopComponents = a += b
        plantloopComponents.each do |component|
          # Get the object type
          obj_type = component.iddObjectType.valueName.to_s
          next if !['OS_Pipe_Indoor', 'OS_Pipe_Outdoor'].include?(obj_type)
          existing_pipe_insulation = existing_pipe_insulation
        end
        assert(existing_pipe_insulation.empty?, "The baseline model for the #{building_type}-#{template} in #{climate_zone} has no pipe insulation.")
      end
    end
  end

  def check_num_systems_in_zone(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, user_data_dir, mod = prototype
      model_baseline.getAirLoopHVACs.each do |air_loop|
        if air_loop.name.get.downcase == 'core_retail'
          # Normally core retail is > 65 kbtuh
          # With number_of_systems = 30, it will be < 65 kbtuh
          air_loop.supplyComponents.each do |sc|
            # CoilCoolingDXSingleSpeed
            if sc.to_CoilCoolingDXSingleSpeed.is_initialized
              coil = sc.to_CoilCoolingDXSingleSpeed.get
              cop = coil.ratedCOP.to_f
              diff = (cop - 3.0).abs
              assert(diff < 0.1,"Cooling COP for the #{building_type}, #{template}, #{climate_zone} model is incorrect. Expected: 3.0, got: #{cop}.")
            end
          end
        end
      end
    end
  end

  def test_wwr
    model_hash = prm_test_helper('wwr', require_prototype=false, require_baseline=true)
    check_wwr(model_hash['baseline'])

  end

  def test_srr
    model_hash = prm_test_helper('srr', require_prototype=false, require_baseline=true)
    check_srr(model_hash['baseline'])
  end

  def test_lpd_userdata_handling
    model_hash = prm_test_helper('lpd_userdata_handling', require_prototype=false, require_baseline=true)
    check_multi_lpd_handling(model_hash['baseline'])
  end

  def test_fan_power_credits
    model_hash = prm_test_helper('fan_power_credits', require_prototype=false, require_baseline=true)
    check_fan_power_credits(model_hash['baseline'])
  end

  def test_envelope
    model_hash = prm_test_helper('envelope', require_prototype=false, require_baseline=true)
    check_envelope(model_hash['baseline'])
  end

  def test_lpd
    model_hash = prm_test_helper('lpd', require_prototype=false, require_baseline=true)
    check_lpd(model_hash['baseline'])
  end

  def test_isresidential
    model_hash = prm_test_helper('isresidential', require_prototype=false, require_baseline=true)
    check_residential_flag(model_hash['baseline'])
  end

  def test_daylighting_control
    model_hash = prm_test_helper('daylighting_control', require_prototype=false, require_baseline=true)
    check_daylighting_control(model_hash['baseline'])
  end

  def test_light_occ_sensor
    model_hash = prm_test_helper('light_occ_sensor', require_prototype=true, require_baseline=true)
    check_light_occ_sensor(model_hash['prototype'], model_hash['baseline'])
  end

  def test_infiltration
    model_hash = prm_test_helper('infiltration', require_prototype=true, require_baseline=true)
    check_infiltration(model_hash['prototype'], model_hash['baseline'])
  end

  def test_vav_fan_curve
    model_hash = prm_test_helper('vav_fan_curve', require_prototype=false, require_baseline=true)
    check_variable_speed_fan_power(model_hash['baseline'])
  end

  def test_pipe_insulation
    model_hash = prm_test_helper('pipe_insulation', require_prototype=false, require_baseline=true)
    check_pipe_insulation(model_hash['baseline'])
  end

  def test_hvac_baseline_01
    model_hash = prm_test_helper('hvac_baseline_01', require_prototype=false, require_baseline=true)
    check_hvac(model_hash['baseline'])
  end

  def test_hvac_baseline_02
    model_hash = prm_test_helper('hvac_baseline_02', require_prototype=false, require_baseline=true)
    check_hvac(model_hash['baseline'])
  end

  def test_hvac_baseline_03
    model_hash = prm_test_helper('hvac_baseline_03', require_prototype=false, require_baseline=true)
    check_hvac(model_hash['baseline'])
  end

  def test_hvac_baseline_04
    model_hash = prm_test_helper('hvac_baseline_04', require_prototype=false, require_baseline=true)
    check_hvac(model_hash['baseline'])
  end

  def test_hvac_baseline_05
    model_hash = prm_test_helper('hvac_baseline_05', require_prototype=false, require_baseline=true)
    check_hvac(model_hash['baseline'])
  end

  def test_hvac_psz_split_from_mz
    model_hash = prm_test_helper('hvac_psz_split_from_mz', require_prototype=false, require_baseline=true)
    check_psz_split_from_mz(model_hash['baseline'])
  end

  def test_plant_temp_reset_ctrl
    model_hash = prm_test_helper('plant_temp_reset_ctrl', require_prototype=false, require_baseline=true)
    check_hw_chw_reset(model_hash['baseline'])
  end

  def test_sat_ctrl
    model_hash = prm_test_helper('sat_ctrl', require_prototype=false, require_baseline=true)
    check_sat_ctrl(model_hash['baseline'])
  end

  def test_number_of_boilers
    model_hash = prm_test_helper('number_of_boilers', require_prototype=false, require_baseline=true)
    check_number_of_boilers(model_hash['baseline'])
  end

  def test_number_of_chillers
    model_hash = prm_test_helper('number_of_chillers', require_prototype=false, require_baseline=true)
    check_number_of_chillers(model_hash['baseline'])
  end

  def test_number_of_cooling_towers
    model_hash = prm_test_helper('number_of_cooling_towers', require_prototype=false, require_baseline=true)
    check_number_of_cooling_towers(model_hash['baseline'])
  end

  def test_hvac_sizing
    model_hash = prm_test_helper('hvac_sizing', require_prototype=false, require_baseline=true)
    check_hvac_sizing(model_hash['baseline'])
  end

  def test_preheat_coil_ctrl
    model_hash = prm_test_helper('preheat_coil_ctrl', require_prototype=false, require_baseline=true)
    check_preheat_coil_ctrl(model_hash['baseline'])
  end

  def test_vav_min_sp
    model_hash = prm_test_helper('vav_min_sp', require_prototype=false, require_baseline=true)
    check_vav_min_sp(model_hash['baseline'])
  end

  def test_multi_bldg_handling
    model_hash = prm_test_helper('multi_bldg_handling', require_prototype=false, require_baseline=true)
    check_multi_bldg_handling(model_hash['baseline'])
  end

  def test_economizer_exception
    model_hash = prm_test_helper('economizer_exception', require_prototype=false, require_baseline=true)
    check_economizer_exception(model_hash['baseline'])
  end

  def test_hvac_efficiency
    model_hash = prm_test_helper('hvac_efficiency', require_prototype=false, require_baseline=true)
    check_hvac_efficiency(model_hash['baseline'])
  end

  def test_unenclosed_spaces
    model_hash = prm_test_helper('unenclosed_spaces', require_prototype=false, require_baseline=true)
    check_unenclosed_spaces(model_hash['baseline'])
  end

  def test_f_c_factors
    model_hash = prm_test_helper('f_c_factors', require_prototype=false, require_baseline=true)
    check_f_c_factors(model_hash['baseline'])
  end

  def test_building_rotation_check
    model_hash = prm_test_helper('building_rotation_check', require_prototype=false, require_baseline=true)
    check_building_rotation_exception(model_hash['baseline'], 'building_rotation_check')
  end

  def test_pe_userdata_handling
    model_hash = prm_test_helper('pe_userdata_handling', require_prototype=false, require_baseline=true)
    check_power_equipment_handling(model_hash['baseline'])
  end

  def test_unmet_load_hours
    model_hash = prm_test_helper('unmet_load_hours', require_prototype=false, require_baseline=true)
    check_unmet_load_hours(model_hash['baseline'])
  end

  def test_dcv
    model_hash = prm_test_helper('dcv', require_prototype=false, require_baseline=true)
    check_dcv(model_hash['baseline'])
  end

  def test_return_air_type
    model_hash = prm_test_helper('return_air_type', require_prototype=false, require_baseline=true)
    check_return_air_type(model_hash['baseline'])
  end

  def test_lighting_exceptions
    model_hash = prm_test_helper('lighting_exceptions', require_prototype=false, require_baseline=true)
    check_lighting_exceptions(model_hash['baseline'])
  end

  def test_night_cycle_exception
    model_hash = prm_test_helper('night_cycle_exception', require_prototype=false, require_baseline=true)
    check_nightcycle_exception(model_hash['baseline'])
  end

  def test_num_systems_in_zone
    model_hash = prm_test_helper('number_of_systems_in_zone', require_prototype=false, require_baseline=true)
    check_num_systems_in_zone(model_hash['baseline'])
  end

  def test_exhaust_air_energy
    model_hash = prm_test_helper('exhaust_air_energy', require_prototype=false, require_baseline=true)
    check_exhaust_air_energy(model_hash['baseline'])
  end

  def test_elevators
    model_hash = prm_test_helper('elevators', require_prototype=false, require_baseline=true)
    check_elevators(model_hash['baseline'])
  end
end