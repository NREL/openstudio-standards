require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class DOEPrototypeBaseline < CreateDOEPrototypeBuildingTest

  def self.generate_prototype_model_and_baseline(building_type, template, climate_zone, hvac_building_type = 'All others', wwr_building_type = 'All others', swh_building_type = 'All others', lpd_space_types)
      # Initialize weather file, necessary but not used
      epw_file = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'

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

      lpd_space_types = {
        'AnyPlenum' => 'plenum',
        'FullServiceRestaurantKitchen' => 'kitchen',
        'FullServiceRestaurantDining' => 'dining - family',
        'FullServiceRestaurantAttic' => 'attic - unoccupied',
        'HighriseApartmentApartment' => 'apartment - hardwired',
        'HighriseApartmentApartment_topfloor_NS' => 'apartment - hardwired',
        'HighriseApartmentApartment_topfloor_WE' => 'apartment - hardwired',
        'HighriseApartmentCorridor' => 'corridor - all other',
        'HighriseApartmentCorridor_topfloor' => 'corridor - all other',
        'HighriseApartmentOffice' => 'office - enclosed <= 250 sf',
        'HospitalBasement' => 'office - whole building',
        'HospitalCorridor' => 'corridor - hospital',
        'HospitalDining' => 'dining - all other',
        'HospitalER_Exam' => 'emergency room',
        'HospitalER_NurseStn' => 'nurses station',
        'HospitalER_Trauma' => 'emergency room',
        'HospitalER_Triage' => 'emergency room',
        'HospitalICU_NurseStn' => 'nurses station',
        'HospitalICU_Open' => 'recovery',
        'HospitalICU_PatRm' => 'patient room',
        'HospitalLab' => 'laboratory',
        'HospitalLobby' => 'lobby - all other',
        'HospitalNurseStn' => 'nurses station',
        'HospitalOR' => 'operating room',
        'HospitalPatCorridor' => 'corridor - hospital',
        'HospitalPatRoom' => 'patient room',
        'HospitalPhysTherapy' => 'physical therapy',
        'HospitalRadiology' => 'laboratory',
        'HospitalKitchen' => 'kitchen',
        'HospitalOffice' => 'office - enclosed <= 250 sf',
        'LaboratoryLab with fume hood' => 'laboratory',
        'LaboratoryEquipment corridor' => 'corridor - all other',
        'LaboratoryOpen lab' => 'laboratory',
        'LaboratoryOffice' => 'office - open',
        'LargeDataCenterHighITEStandaloneDataCenter' => 'office - open',
        'LargeDataCenterLowITEStandaloneDataCenter' => 'office - open',
        'LargeHotelCafe' => 'dining - bar/lounge/leisure',
        'LargeHotelCorridor' => 'corridor - all other',
        'LargeHotelGuestRoom' => 'guest room',
        'LargeHotelLaundry' => 'laundry/washing',
        'LargeHotelLobby' => 'lobby - hotel',
        'LargeHotelMechanical' => 'electrical/mechanical',
        'LargeHotelStorage' => 'storage 50 to 1000 sf - all other',
        'LargeHotelKitchen' => 'kitchen',
        'LargeHotelBanquet' => 'dining - bar/lounge/leisure',
        'LargeHotelBasement' => 'office - whole building',
        'LargeHotelCorridor2' => 'corridor - all other',
        'LargeHotelGuestRoom2' => 'guest room',
        'LargeHotelGuestRoom3' => 'guest room',
        'LargeHotelGuestRoom4' => 'guest room',
        'LargeHotelRetail' => 'retail - whole building',
        'LargeHotelRetail2' => 'retail - whole building',
        'LargeOfficeRetail' => 'sales',
        'MidriseApartmentApartment' => 'apartment - hardwired',
        'MidriseApartmentApartment_topfloor_NS' => 'apartment - hardwired',
        'MidriseApartmentApartment_topfloor_WE' => 'apartment - hardwired',
        'MidriseApartmentCorridor' => 'corridor - all other',
        'MidriseApartmentCorridor_topfloor' => 'corridor - all other',
        'MidriseApartmentOffice' => 'office - enclosed <= 250 sf',
        'OfficeWholeBuilding - Sm Office' => 'office - whole building',
        'OfficeWholeBuilding - Md Office' => 'office - whole building',
        'OfficeWholeBuilding - Lg Office' => 'office - whole building',
        'OfficeVending' => 'corridor - all other',
        'OfficeStorage' => 'storage 50 to 1000 sf - all other',
        'OfficeStair' => 'stairwell',
        'OfficeRestroom' => 'restroom - all other',
        'OfficePrintRoom' => 'office - enclosed <= 250 sf',
        'OfficeOpenOffice' => 'office - open',
        'OfficeLobby' => 'lobby - all other',
        'OfficeIT_Room' => 'office - enclosed <= 250 sf',
        'OfficeElec/MechRoom' => 'electrical/mechanical',
        'OfficeCorridor' => 'corridor - all other',
        'OfficeConference' => 'conference/meeting/multipurpose',
        'OfficeClosedOffice' => 'office - enclosed <= 250 sf',
        'OfficeBreakRoom' => 'lounge/breakroom - all other',
        'OfficeAttic' => 'attic - unoccupied',
        'OfficeOfficeLarge Data Center' => 'office - open',
        'OfficeOfficeLarge Main Data Center' => 'office - open',
        'OfficeDining' => 'dining - all other',
        'OfficeClassroom' => 'classroom/lecture/training - all other',
        'OfficeMediumOffice - Storage' => 'storage 50 to 1000 sf - all other',
        'OfficeMediumOffice - Stair' => 'stairwell',
        'OfficeMediumOffice - Restroom' => 'restroom - all other',
        'OfficeMediumOffice - OpenOffice' => 'office - open',
        'OfficeMediumOffice - Lobby' => 'lobby - all other',
        'OfficeMediumOffice - Elec/MechRoom' => 'electrical/mechanical',
        'OfficeMediumOffice - Corridor' => 'corridor - all other',
        'OfficeMediumOffice - Conference' => 'conference/meeting/multipurpose',
        'OfficeMediumOffice - ClosedOffice' => 'office - enclosed <= 250 sf',
        'OfficeMediumOffice - Breakroom' => 'lounge/breakroom - all other',
        'OfficeMediumOffice - Dining' => 'dining - all other',
        'OfficeMediumOffice - Classroom' => 'classroom/lecture/training - all other',
        'OfficeSmallOffice - Attic' => 'attic - unoccupied',
        'OfficeSmallOffice - Storage' => 'storage 50 to 1000 sf - all other',
        'OfficeSmallOffice - Stair' => 'stairwell',
        'OfficeSmallOffice - Restroom' => 'restroom - all other',
        'OfficeSmallOffice - OpenOffice' => 'office - open',
        'OfficeSmallOffice - Lobby' => 'lobby - all other',
        'OfficeSmallOffice - Elec/MechRoom' => 'electrical/mechanical',
        'OfficeSmallOffice - Corridor' => 'corridor - all other',
        'OfficeSmallOffice - Conference' => 'conference/meeting/multipurpose',
        'OfficeSmallOffice - ClosedOffice' => 'office - enclosed <= 250 sf',
        'OfficeSmallOffice - Breakroom' => 'lounge/breakroom - all other',
        'OfficeSmallOffice - Dining' => 'dining - all other',
        'OfficeSmallOffice - Classroom' => 'classroom/lecture/training - all other',
        'OfficeWholeBuilding - Lg Office-others' => 'office - whole building',
        'OfficeWholeBuilding - Lg Office-basement' => 'office - whole building',
        'OutpatientAnesthesia' => 'exam/treatment',
        'OutpatientBioHazard' => 'storage 50 to 1000 sf - hospital',
        'OutpatientCafe' => 'dining - all other',
        'OutpatientCleanWork' => 'exam/treatment',
        'OutpatientConference' => 'conference/meeting/multipurpose',
        'OutpatientDressingRoom' => 'office - enclosed <= 250 sf',
        'OutpatientElec/MechRoom' => 'electrical/mechanical',
        'OutpatientElevatorPumpRoom' => 'electrical/mechanical',
        'OutpatientExam' => 'exam/treatment',
        'OutpatientHall' => 'corridor - hospital',
        'OutpatientHall_infil' => 'corridor - hospital',
        'OutpatientIT_Room' => 'office - enclosed <= 250 sf',
        'OutpatientJanitor' => 'storage 50 to 1000 sf - hospital',
        'OutpatientLobby' => 'lobby - all other',
        'OutpatientLockerRoom' => 'lounge/breakroom - healthcare facility',
        'OutpatientLounge' => 'lounge/breakroom - healthcare facility',
        'OutpatientMedGas' => 'storage 50 to 1000 sf - hospital',
        'OutpatientMRI' => 'laboratory',
        'OutpatientMRI_Control' => 'laboratory',
        'OutpatientNurseStation' => 'nurses station',
        'OutpatientOffice' => 'office - enclosed <= 250 sf',
        'OutpatientOR' => 'operating room',
        'OutpatientPACU' => 'recovery',
        'OutpatientPhysicalTherapy' => 'physical therapy',
        'OutpatientPreOp' => 'patient room',
        'OutpatientProcedureRoom' => 'emergency room',
        'OutpatientReception' => 'lobby - all other',
        'OutpatientStair' => 'corridor - hospital',
        'OutpatientToilet' => 'restroom - all other',
        'OutpatientUndeveloped' => 'storage 50 to 1000 sf - hospital',
        'OutpatientXray' => 'laboratory',
        'OutpatientSoil Work' => 'exam/treatment',
        'PrimarySchoolCafeteria' => 'dining - all other',
        'PrimarySchoolClassroom' => 'classroom/lecture/training - all other',
        'PrimarySchoolComputerRoom' => 'classroom/lecture/training - all other',
        'PrimarySchoolCorridor' => 'corridor - all other',
        'PrimarySchoolGym' => 'gymnsasium exercise area',
        'PrimarySchoolKitchen' => 'kitchen',
        'PrimarySchoolLibrary' => 'library - whole building',
        'PrimarySchoolLobby' => 'lobby - all other',
        'PrimarySchoolMechanical' => 'electrical/mechanical',
        'PrimarySchoolOffice' => 'office - enclosed <= 250 sf',
        'PrimarySchoolRestroom' => 'restroom - all other',
        'QuickServiceRestaurantDining' => 'dining - family',
        'QuickServiceRestaurantAttic' => 'attic - unoccupied',
        'QuickServiceRestaurantKitchen' => 'kitchen',
        'RetailBack_Space' => 'storage 50 to 1000 sf - all other',
        'RetailEntry' => 'lobby - all other',
        'RetailPoint_of_Sale' => 'sales',
        'RetailRetail' => 'sales',
        'SecondarySchoolAuditorium' => 'audience seating - auditorium',
        'SecondarySchoolCafeteria' => 'dining - all other',
        'SecondarySchoolClassroom' => 'classroom/lecture/training - all other',
        'SecondarySchoolComputerRoom' => 'classroom/lecture/training - all other',
        'SecondarySchoolCorridor' => 'corridor - all other',
        'SecondarySchoolGym' => 'gymnasium playing area',
        'SecondarySchoolLibrary' => 'library - whole building',
        'SecondarySchoolLobby' => 'lobby - all other',
        'SecondarySchoolOffice' => 'office - enclosed <= 250 sf',
        'SecondarySchoolRestroom' => 'restroom - all other',
        'SecondarySchoolKitchen' => 'kitchen',
        'SecondarySchoolMechanical' => 'electrical/mechanical',
        'SmallDataCenterHighITEComputerRoom' => 'office - open',
        'SmallDataCenterLowITEComputerRoom' => 'office - open',
        'SmallHotelCorridor' => 'corridor - all other',
        'SmallHotelCorridor4' => 'corridor - all other',
        'SmallHotelElec/MechRoom' => 'electrical/mechanical',
        'SmallHotelElevatorCore' => 'elevator core',
        'SmallHotelElevatorCore4' => 'elevator core',
        'SmallHotelExercise' => 'gymnsasium exercise area',
        'SmallHotelGuestRoom123Occ' => 'guest room',
        'SmallHotelGuestRoom123Vac' => 'guest room',
        'SmallHotelGuestRoom4Occ' => 'guest room',
        'SmallHotelGuestRoom4Vac' => 'guest room',
        'SmallHotelLaundry' => 'laundry/washing',
        'SmallHotelMechanical' => 'electrical/mechanical',
        'SmallHotelMeeting' => 'conference/meeting/multipurpose',
        'SmallHotelOffice' => 'office - enclosed <= 250 sf',
        'SmallHotelPublicRestroom' => 'restroom - all other',
        'SmallHotelStaffLounge' => 'lounge/breakroom - all other',
        'SmallHotelStair' => 'stairwell',
        'SmallHotelStair4' => 'stairwell',
        'SmallHotelStorage' => 'storage 50 to 1000 sf - all other',
        'SmallHotelStorage4Front' => 'storage 50 to 1000 sf - all other',
        'SmallHotelStorage4Rear' => 'storage 50 to 1000 sf - all other',
        'SmallHotelGuestLounge' => 'lobby - hotel',
        'StripMallStrip mall - type 1' => 'retail - whole building',
        'StripMallStrip mall - type 2' => 'retail - whole building',
        'StripMallStrip mall - type 3' => 'retail - whole building',
        'SuperMarketMeeting' => 'conference/meeting/multipurpose',
        'SuperMarketDining' => 'dining - cafeteria/fast food',
        'SuperMarketRestroom' => 'restroom - all other',
        'SuperMarketElec/MechRoom' => 'electrical/mechanical',
        'SuperMarketCorridor' => 'corridor - all other',
        'SuperMarketDeli' => 'kitchen',
        'SuperMarketBakery' => 'kitchen',
        'SuperMarketVestibule' => 'lobby - all other',
        'SuperMarketSales' => 'sales',
        'SuperMarketProduce' => 'sales',
        'SuperMarketDryStorage' => 'storage 50 to 1000 sf - all other',
        'SuperMarketOffice' => 'office - enclosed <= 250 sf',
        'WarehouseOffice' => 'office - enclosed <= 250 sf',
        'WarehouseFine' => 'warehouse - fine storage',
        'WarehouseBulk' => 'warehouse - bulk storage'
      }

      all_comp =  @building_types.product @templates, @climate_zones
      all_comp.each do |building_type, template, climate_zone|

        # Generate prototype building models and associated baselines
        model_baseline, model = DOEPrototypeBaseline.generate_prototype_model_and_baseline(building_type, template, climate_zone, hvac_building_types[building_type], wwr_building_types[building_type], swh_building_types[building_type],lpd_space_types)
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