require_relative '../helpers/minitest_helper'

class TSPRTests < Minitest::Test

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


  def test_tspr_model_base(user_model_input='tspr/model_baseline_25496.osm')
    building_type = 'MediumOffice'
    climate_zone = 'ASHRAE 169-2013-2A'
    @test_dir = "#{File.dirname(__FILE__)}/output"
    @prototype_creator = Standard.build('90.1-PRM-2019')
    model_name = "#{building_type}-#{climate_zone}-#{user_model_input}-tsprbaseline".sub("/", "_").sub(".osm", "")
    proto_run_dir = "#{@test_dir}/#{model_name}"
    proto_run_dir = proto_run_dir.length > MAX_PATH_CHAR ? "#{proto_run_dir[0...MAX_PATH_CHAR]}" : proto_run_dir

    # Define run directory and run name, delete existing folder if it exists
    run_dir_baseline = "#{proto_run_dir}-Baseline"
    if Dir.exist?(run_dir_baseline)
      FileUtils.rm_rf(run_dir_baseline)
    end

    osm_model_path = "../../data/#{user_model_input}"
    abs_path = File.join(File.dirname(__FILE__), osm_model_path)
    version_translator = OpenStudio::OSVersion::VersionTranslator.new
    model = version_translator.loadModel(abs_path)
    model = model.get

    # Create baseline model
    model_baseline = @prototype_creator.model_create_prm_stable_baseline_building(model, climate_zone,
                                                                                  @@hvac_building_types[building_type],
                                                                                  @@wwr_building_types[building_type],
                                                                                  @@swh_building_types[building_type],
                                                                                  run_dir_baseline, false, GENERATE_PRM_LOG)

    # Check if baseline could be created
    assert(model_baseline, "Baseline model could not be generated for #{building_type}, #{climate_zone}.")
  end

  def test_tspr_model_prop_base(user_model_input='tspr/model_baseline_25496.osm')
    template = '90.1-2019'
    building_type = 'MediumOffice'
    climate_zone = 'ASHRAE 169-2013-2A'
    epw_file = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'

    # Proposed
    @test_dir = "#{File.dirname(__FILE__)}/output"
    @prototype_creator = Standard.build("#{template}_#{building_type}")
    @prototype_creator.geometry_file = user_model_input
    model_name = "#{building_type}-#{template}-#{climate_zone}-#{user_model_input}-tsprproposed".sub("/", "_").sub(".osm", "")
    run_dir = "#{@test_dir}/#{model_name}"
    run_dir = run_dir.length > MAX_PATH_CHAR ? "#{run_dir[0...MAX_PATH_CHAR]}" : run_dir
    if !Dir.exist?(run_dir)
      Dir.mkdir(run_dir)
    else
      FileUtils.rm_rf(run_dir)
      Dir.mkdir(run_dir)
    end
    model = @prototype_creator.model_create_prototype_model(climate_zone, epw_file, run_dir)

    assert(model, "Proposed model for #{model_name} cannot be generated.")
    # Save prototype OSM file
    osm_path = OpenStudio::Path.new("#{run_dir}/#{model_name}.osm")
    model.save(osm_path, true)

    # Translate prototype model to an IDF file
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf_path = OpenStudio::Path.new("#{run_dir}/#{model_name}.idf")
    idf = forward_translator.translateModel(model)
    idf.save(idf_path, true)


    # Baseline
    @prototype_creator = Standard.build('90.1-PRM-2019')
    model_name = "#{building_type}-#{template}-#{climate_zone}-#{user_model_input}-tsprbaseline".sub("/", "_").sub(".osm", "")
    proto_run_dir = "#{@test_dir}/#{model_name}"
    proto_run_dir = proto_run_dir.length > MAX_PATH_CHAR ? "#{proto_run_dir[0...MAX_PATH_CHAR]}" : proto_run_dir

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
  end
end