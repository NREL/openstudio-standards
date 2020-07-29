# *********************************************************************
# *  Copyright (c) 2008-2015, Natural Resources Canada
# *  All rights reserved.
# *
# *  This library is free software; you can redistribute it and/or
# *  modify it under the terms of the GNU Lesser General Public
# *  License as published by the Free Software Foundation; either
# *  version 2.1 of the License, or (at your option) any later version.
# *
# *  This library is distributed in the hope that it will be useful,
# *  but WITHOUT ANY WARRANTY; without even the implied warranty of
# *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# *  Lesser General Public License for more details.
# *
# *  You should have received a copy of the GNU Lesser General Public
# *  License along with this library; if not, write to the Free Software
# *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
# **********************************************************************/

#require "SecureRandom"

module BTAP

  module SimManager

    #This method will simulate all files in a folder.
    #@author phylroy.lopez@nrcan.gc.ca
    #@param folder [String] folder
    def self.simulate_all_files_in_folder(folder)
      osm_files = BTAP::FileIO::get_find_files_from_folder_by_extension(folder, ".osm")
      self.simulate_files(folder,osm_files)
    end
    
 #This method will simulate all files in a array.
    #@author phylroy.lopez@nrcan.gc.ca
    #@param folder Array[String] folder
    def self.simulate_files(folder,osm_files)

      co = OpenStudio::Runmanager::ConfigOptions.new()
      co.fastFindEnergyPlus() 
      rm = OpenStudio::Runmanager::RunManager.new("SecureRandom.hex.db", true)
      rm.setPaused(false)
      counter = 0
      
      osm_files.each do |model_path|
        counter = counter + 1
        work_items = OpenStudio::Runmanager::WorkItemVector.new
        work_items << OpenStudio::Runmanager::WorkItem.new("ModelToIdf".to_JobType)
        work_items << OpenStudio::Runmanager::WorkItem.new("ExpandObjects".to_JobType)
        #    ruby_job = OpenStudio::Runmanager::RubyJobBuilder.new(cost_injection)
        #    ruby_job.setIncludeDir(OpenStudio::Path.new("#{$OpenStudio_Dir}"))
        #    work_items << ruby_job.toWorkItem
        work_items << OpenStudio::Runmanager::WorkItem.new("EnergyPlus".to_JobType)
        #work_items << OpenStudio::Runmanager::WorkItem.new("ReadVars".to_JobType)
        work_items << OpenStudio::Runmanager::WorkItem.new("OpenStudioPostProcess".to_JobType)
        workflow = OpenStudio::Runmanager::Workflow.new(work_items)
        params = OpenStudio::Runmanager::JobParams.new;
        params.append("cleanoutfiles", "standard");
        workflow.add(params)
        workflow.add(co.getTools())
        rm.enqueue( workflow.create( OpenStudio::Path.new("#{folder}/#{File.basename(model_path, ".osm")}"), OpenStudio::Path.new(model_path)),false)
        # puts "#{model_path} enqueued. #{counter} of #{osm_files.size}"
      end
      #rm.showStatusDialog()
      rm.waitForFinished()
    end

    
    
    #This method will run the simulation. You must provide a folder where you wish
    #to run the simulation, and if not previously defined, the weather file. This will delete and recreate the folder provided to ensure that it is clean.
    #@author Phylroy A. Lopez
    #@param model [OpenStudio::model::Model] A model object
    #@param folder_name [String] a simple string of the simulation folder path, remember to escape the slashes..(i.e. // not / )
    #@param epw_path [String] a simple string of the epw file path, remember to escape the slashes..(i.e. // not / )
    #@return [OpenStudio::Model::Model] the OpenStudio model object (self reference).
    def self.run_simulation( model, folder_name,epw_path = "" )

      if not File.exists?(epw_path) and not File.exists?(model.getWeatherFile.path.get.to_s)
        raise ("Error: Weather file not set. Cannot run. Please set weather file using the OpenStudio::Model::WeatherFile::setWeatherFile(model,filepath) command ")
      else if epw_path != ""
          BTAP::Site::set_weather_file(model,epw_path)
        end
        #Create RunManager
        Dir::mkdir(folder_name) unless File.exists?( folder_name )
        process_manager = BTAP::SimManager::ProcessManager.new( folder_name )
        process_manager.addModel(model)
        process_manager.start_sims
      end
      return model
    end



    class ProcessManager

      attr_accessor :run_manager
      attr_accessor :workflow
      attr_accessor :model_array
      attr_accessor :results_folder


      def getPaths
        #set the Energyplus.exe path variable
        @ep_path = OpenStudio.getEnergyPlusExecutable
        #set the root folder for E+
        @ep_parent_path = OpenStudio.getEnergyPlusDirectory

        #find IDD path
        idd_path = @ep_parent_path.to_s + "/Energy+.idd"

        if (not File.exists?(idd_path))
          raise("Cannot locate the input data dictionary (IDD) in the EnergyPlus directory #{idd_path}.  Correct the EXE path and try again.")
          return(false)
        end

        #Find the expand object exe.
        expandobjects_path = ''
        expandobjects_path = @ep_parent_path.to_s + '/ExpandObjects.exe'
        if (not File.exists?(expandobjects_path))
          UI.messagebox("Cannot locate ExpandObjects in the EnergyPlus directory.  Correct the EXE path and try again.")
        end

        #Find the ReadVarsESO.exe

        @readvars_path = ""
        if (/mswin/.match(RUBY_PLATFORM) or /mingw/.match(RUBY_PLATFORM))
          @readvars_path = @ep_parent_path.to_s + "/PostProcess/ReadVarsESO.exe"
        else
          @readvars_path = @ep_parent_path.to_s + '/readvars'
        end


        if (not File.exists?(@readvars_path))
          @readvars_path = @ep_parent_path.to_s + '/readvars.exe'
        end
        if (not File.exists?(@readvars_path))
          UI.messagebox("Cannot locate ReadVarsESO in the EnergyPlus directory.  Correct the EXE path and try again.")
          return(false)
        end
      end

      #This method finds the energyplus folder and returns the path string.
      #@author Phylroy A. Lopez
      #@return [String] a simple string of the epw file path, remember to escape the slashes..(i.e. // not / )
      def self.find_energyplus_folder()
        return OpenStudio.getEnergyPlusDirectory.to_s
      end

      #This method finds the eReadVarsESO.exe and returns the path string.
      #@author Phylroy A. Lopez
      #@return [String] readvars_path a simple string of the eReadVarsESO.exe file path, remember to escape the slashes..(i.e. // not / )
      def self.find_read_vars_eso()
        #Find the ReadVarsESO.exe
        readvars_path = ""
        ep_parent_path =  self.find_energyplus_folder()
        if (/mswin/.match(RUBY_PLATFORM) or /mingw/.match(RUBY_PLATFORM))
          readvars_path = ep_parent_path.to_s + "/PostProcess/ReadVarsESO.exe"
        else
          readvars_path = ep_parent_path.to_s + '/readvars'
        end
        if (not File.exists?(readvars_path))
          readvars_path = ep_parent_path.to_s + '/readvars.exe'
        end
        if (not File.exists?(readvars_path))
          raise("Cannot locate ReadVarsESO in the EnergyPlus directory #{ep_parent_path}.  Correct the EXE path and try again.")
        end
        return readvars_path
      end

      #This method initializes the Analysis Folder.
      #@author Phylroy A. Lopez
      #@param analysisFolder [String] a simple string of the Analysis Folder file path, remember to escape the slashes..(i.e. // not / )
      def initialize(analysisFolder)

        @model_array = Array
        #set Analysis Folder.
        @analysisFolder = analysisFolder
        #FileUtils.rm_rf(@analysisFolder)
        FileUtils.mkdir_p("#{@analysisFolder}")
        FileUtils.mkdir_p("#{@analysisFolder}/simulations") unless File.exists?("#{@analysisFolder}/simulations")
        FileUtils.mkdir_p("#{@analysisFolder}/results") unless File.exists?("#{@analysisFolder}/results")
        #create Runmanager
        runmanager_db_path = OpenStudio::Path.new(@analysisFolder + "\\runmanager.sql")
        #FileUtils.rm(runmanager_db_path.to_s) if OpenStudio::exists(runmanager_db_path)
        #OpenStudio::Runmanager::ConfigOptions::setMaxLocalJobs(6)
        @run_manager = OpenStudio::Runmanager::RunManager.new(runmanager_db_path, true)


        #create Workflow.
        @workflow = OpenStudio::Runmanager::Workflow.new();

        #Set up tools for workflow.
        self.getPaths
        tools = OpenStudio::Runmanager::Tools.new()
        tools.append(OpenStudio::Runmanager::ToolInfo.new("readvars", OpenStudio::Runmanager::ToolVersion.new(), OpenStudio::Path.new(@readvars_path)))
        expand   = OpenStudio::Runmanager::JobFactory::createExpandObjectsJob(tools, OpenStudio::Runmanager::JobParams.new(), OpenStudio::Runmanager::Files.new())
        #readvars = OpenStudio::Runmanager::JobFactory::createReadVarsJob(tools, OpenStudio::Runmanager::JobParams.new(), OpenStudio::Runmanager::Files.new())

        #Create ModeltoIDF->Expand->EnergyPlus->ReadVars workflow.
        @workflow.addJob(OpenStudio::Runmanager::JobType.new("ModelToIdf"));
        @workflow.addJob( OpenStudio::Runmanager::JobType.new("ExpandObjects") )
        @workflow.addJob(OpenStudio::Runmanager::JobType.new("EnergyPlus"));
        #@workflow.addJob(OpenStudio::Runmanager::JobType.new("OpenStudioPostProcess"));
        #@workflow.addJob(OpenStudio::Runmanager::JobType.new("ReadVars"))
        @workflow.add(OpenStudio::Runmanager::ConfigOptions::makeTools(
            @ep_parent_path,
            OpenStudio::Path.new,
            OpenStudio::Path.new,
            $OpenStudio_RubyExeDir,
            OpenStudio::Path.new))
        tools.append(OpenStudio::Runmanager::ToolInfo.new("readvars", OpenStudio::Runmanager::ToolVersion.new(), OpenStudio::Path.new(@readvars_path)))
        #create Project Database
        #create the project database
        @projectPath = OpenStudio::Path.new(@analysisFolder + "\\projectdb.osp")
        FileUtils.rm(@projectPath.to_s) if OpenStudio::exists(@projectPath)
        database = OpenStudio::Project::ProjectDatabase.new(@projectPath, @run_manager)
      end

      #This method adds the model to the folder.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object
      #@param folder [String] 
      #@return [String] self
      def addModel(model, folder = @analysisFolder  )

        run_name = model.building.get.name.get.to_s
        working_folder = OpenStudio::Path.new(folder.to_s + "\\simulations\\" + run_name )
        osm_save_path = OpenStudio::Path.new(folder.to_s + "\\simulations\\" + run_name + "\\" + run_name + ".osm" )
        model.save(OpenStudio::Path.new(osm_save_path), true);
        @run_manager.enqueue(@workflow.create(working_folder, osm_save_path, model.getWeatherFile.path.get),true)
        return self
      end

      #This method simulates all files in a folder.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param folder [String]
      def simulate_all_files_in_folder(folder)
        co = OpenStudio::Runmanager::ConfigOptions.new()
        co.fastFindEnergyPlus()
        @run_manager.showStatusDialog()
        @workflow = OpenStudio::Runmanager::Workflow.new("ModelToIdf->ExpandObjects->EnergyPlus")

        @workflow.add(co.getTools())

        BTAP::FileIO::get_find_files_from_folder_by_extension(folder, ".osm").each do |model_path|
          basename = File.basename(model_path, ".osm")
          proc_folder = "#{folder}/#{basename}"
          @run_manager.enqueue( @workflow.create( OpenStudio::Path.new(proc_folder), OpenStudio::Path.new(model_path)),true)
          @run_manager.setPaused(false)
          GC.start()
        end
        @run_manager.showStatusDialog()
        @run_manager.waitForFinished()

      end



      def start_sims
        unless File.exist?(@analysisFolder)
          Dir.mkdir(@analysisFolder)
        end
        @run_manager.showStatusDialog()
        @run_manager.waitForFinished()
      end

      class SummaryReport
        # End Uses data
        End_use_report_name = 'AnnualBuildingUtilityPerformanceSummary'
        End_use_reportForString = 'Entire Facility'
        End_use_table_name = 'End Uses'
        Fuel_types = [
          ['Electricity', 'GJ'],
          ['Natural Gas', 'GJ'],
          ['Other Fuel', 'GJ'],
          ['District Cooling', 'GJ'],
          ['District Heating', 'GJ'],
          ['Water', 'm3']]
        End_use_types = [
          'Heating',
          'Cooling',
          'Interior Lighting',
          'Exterior Lighting',
          'Interior Equipment',
          'Exterior Equipment',
          'Fans',
          'Pumps',
          'Heat Rejection',
          'Humidification',
          'Heat Recovery',
          'Water Systems',
          'Refrigeration',
          'Generators'
        ]


        def get_header
          end_use_header_array = ""
          #Print Header
          end_use_header = end_use_header + "OSM File,"
          end_use_header = end_use_header + "SQL File,"
          end_use_header = end_use_header + "Conditioned Building Area m2,"
          end_use_header = end_use_header + "Average Wall Conductance,"
          end_use_header = end_use_header + "Average Roof Conductance,"
          #End Uses
          End_use_types.each do |end_use|
            Fuel_types.each do |fuel_type|
              end_use_header_array = end_use_header_array +  "#{end_use} #{fuel_type[0]} (#{fuel_type[1]}),"
            end
          end
        end

        def initialize()
          header = get_header()

        end
      end

      #This method will return an array of common annual data results. With header and unit information and returns an annual results string array.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param osm_file [String]
      #@param sql_path [String] 
      #@return [annual_results_array<String>]
      def self.old_get_annual_results_model_results(osm_file,sql_path)

        #load Osm file.
        model = BTAP::FileIO::load_osm(osm_file)
        #construct sql path.
        basename = File.basename(osm_file,".osm")
        sql_file = OpenStudio::SqlFile.new(OpenStudio::Path.new(sql_path))

        #link sql output
        model.setSqlFile(sql_file)

        current_building = model.building.get
        current_facility = model.getFacility
        weather_object = model.getWeatherFile

        #Create hash of results.
        annual_results_array = Array.new()

        if match = current_building.name.get.match(/(^.*)~(.*)~(.*)/)
          building_name, vintage_name, ecm_name = match.captures
          annual_results_array.push( [ building_name,"building_type",""])
          annual_results_array.push( [ vintage_name,"vintage_name",""])
          annual_results_array.push( [ ecm_name,"measure_id",""])
        else
          annual_results_array.push( [ current_building.name,"building_name",""])
        end
        annual_results_array.push( [ osm_file,"OSM file",""])
        annual_results_array.push( [ sql_path,"SQL file",""])
        #Weather file
        annual_results_array.push( [ weather_object.city, "City","-"])
        annual_results_array.push( [ weather_object.stateProvinceRegion, "Province","-"])
        annual_results_array.push( [ weather_object.country, "Country","-"])
        annual_results_array.push( [ weather_object.dataSource, "Data Source","-"])
        annual_results_array.push( [ weather_object.wMONumber, "wMONumber","-"])
        annual_results_array.push( [ weather_object.latitude, "Latitude","-"])
        annual_results_array.push( [ weather_object.longitude, "Longitude","-"])

        hdd = BTAP::Environment::WeatherFile.new( weather_object.path.get.to_s ).hdd18
        cdd = BTAP::Environment::WeatherFile.new( weather_object.path.get.to_s ).cdd18
        annual_results_array.push( [ hdd, "Heating Degree Days","deg*Day"])
        annual_results_array.push( [ cdd, "Cooling Degree Days","deg*Day"])
        annual_results_array.push( [ NECB2011.new().get_climate_zone_name(hdd), "NECB Climate Zone",""])


        annual_results_array.push( [ current_building.floorArea(),"Total Floor Area", "M2"])
        annual_results_array.push( [ current_building.conditionedFloorArea(),"Conditioned Floor Area", "M2"])
        annual_results_array.push( [ current_building.exteriorSurfaceArea,"Exterior Surface Area", "M2"])
        annual_results_array.push( [ current_building.exteriorWallArea,"Exterior Wall Area", "M2"])
        annual_results_array.push( [ current_building.airVolume,"Building Air Volume", "M3"])
        annual_results_array.push( [ current_building.numberOfPeople(),"Number of People","Persons"])

        annual_results_array.push( [ current_building.peoplePerFloorArea(),"Number of People per Area","Persons/M2"])
        annual_results_array.push( [ current_building.lightingPower ,"Lighting Power","W"])
        annual_results_array.push( [ current_building.lightingPowerPerFloorArea(),"Lighting Power Density","W/M2"])
        annual_results_array.push( [ current_building.lightingPowerPerPerson() ,"Lighting Power Per Person","W/Person"])
        annual_results_array.push( [ current_building.electricEquipmentPower(),"Electric Equipment Power","W"])
        annual_results_array.push( [ current_building.electricEquipmentPowerPerFloorArea(),"Electric Equipment Power per Floor Area","W/M2"])
        annual_results_array.push( [ current_building.electricEquipmentPowerPerPerson(), "Electric Equipment Power Per Person","W/person"])
        annual_results_array.push( [ current_building.gasEquipmentPower(), "Gas Equipment Power","W"])
        annual_results_array.push( [ current_building.gasEquipmentPowerPerFloorArea(),"Gas Equipment Power per Floor Area","W/M2"])
        annual_results_array.push( [ current_building.gasEquipmentPowerPerPerson(), "Gas Equipment Power Per Person","W/person"] )
        annual_results_array.push( [ model.getBuildingStorys.size, "Number of Stories", ""])

        annual_results_array.push( [ current_facility.totalSiteEnergy(), "Total Site Energy", "GJ"])
        annual_results_array.push( [ current_facility.netSiteEnergy(), "Net Site Energy", "GJ"])
        annual_results_array.push( [ current_facility.totalSourceEnergy(), "Total Source Energy", "GJ"])
        annual_results_array.push( [ current_facility.netSourceEnergy(), "Net Source Energy", "GJ"])

        annual_results_array.push( [ current_facility.hoursHeatingSetpointNotMet(),"Hours Heating Setpoint Not Met", "Hours"])
        annual_results_array.push( [ current_facility.hoursCoolingSetpointNotMet(),"Hours Cooling Setpoint Not Met", "Hours"])

        #cost information
        #        annual_results_array.push( [ current_facility.annualTotalCost(OpenStudio::FuelType.new("NaturalGas")), "Annual Natural Gas Total Cost", "$"])
        #        annual_results_array.push( [ current_facility.annualTotalCostPerBldgArea(OpenStudio::FuelType.new("NaturalGas")),"Annual Natural Gas Total Cost per Bldg Area", "$/M2"])
        #        annual_results_array.push( [ current_facility.annualTotalCostPerNetConditionedBldgArea(OpenStudio::FuelType.new("NaturalGas")), "Annual Natural Gas Total Cost per Conditioned Bldg Area", "$/M2"])
        #        annual_results_array.push( [ current_facility.annualTotalUtilityCost(), "Annual Total Utility Cost", "$"])
        #        annual_results_array.push( [ current_facility.annualElectricTotalCost() , "Annual Total Electric Utility Cost", "$"])
        #        annual_results_array.push( [ current_facility.annualGasTotalCost(), "Annual Total Gas Utility Cost", "$"])
        #        annual_results_array.push( [ current_facility.annualDistrictCoolingTotalCost(), "Annual Total District Cooling Utility Cost", "$"])
        #        annual_results_array.push( [ current_facility.annualDistrictHeatingTotalCost(), "Annual Total District Heating Utility Cost", "$"])
        #        annual_results_array.push( [ current_facility.annualWaterTotalCost(), "Annual Total Water Cost", "$"])
        #        annual_results_array.push( [ current_facility.totalEnergyTimeDependentValuation(), "Annual Total Water Cost", "$"])
        #        annual_results_array.push( [ current_facility.totalCostTimeDependentValuation(), "Annual Total Water Cost", "$"])
        #        annual_results_array.push( [ current_facility.electricityEnergyTimeDependentValuation(), "electricityEnergyTimeDependentValuation", "J"])
        #        annual_results_array.push( [ current_facility.electricityCostTimeDependentValuation(), "electricityCostTimeDependentValuation", "$"])
        #        annual_results_array.push( [ current_facility.fossilFuelEnergyTimeDependentValuation(),"fossilFuelEnergyTimeDependentValuation", "J"])
        #        annual_results_array.push( [ current_facility.fossilFuelCostTimeDependentValuation(), "fossilFuelCostTimeDependentValuation", "$"])
        #        annual_results_array.push( [ current_facility.economicsCapitalCost(), "economics Capitol Costs", "$"])
        #        annual_results_array.push( [ current_facility.economicsEnergyCost(), "economics Energy Costs", "$"])
        #        annual_results_array.push( [ current_facility.economicsTLCC(), "economics Total Life Cycle Costs", "$"])


        value = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM tabulardatawithstrings WHERE ReportName='Life-Cycle Cost Report' AND ReportForString='Entire Facility' AND TableName='Present Value by Category' AND RowName='Grand Total' AND ColumnName='Present Value'")
                 
        if value.empty?
          value = 0.0
        else
          value = value.get
        end
        annual_results_array.push( [ value, "Total Capitol Costs", "$"])




        #        annual_results_array.push( [ current_facility.economicsVirtualRateGas(), "economics Virtual Rate Gas", "$/GJ"])
        #        annual_results_array.push( [ current_facility.economicsVirtualRateElec(), "economics Virtual Rate Electric", "$/GJ"])
        #        annual_results_array.push( [ current_facility.economicsVirtualRateCombined(), "economics Virtual Rate Combined", "$/GJ"])
        #        annual_results_array.push( [ current_facility.economicsSPB(), "economics Simple Pay Back", "Years"])
        #        annual_results_array.push( [ current_facility.economicsDPB(), "economics Discounted Payback", "Years"])
        #        annual_results_array.push( [ current_facility.economicsNPV(), "economics Net Present Value", "$"])
        #        annual_results_array.push( [ current_facility.economicsIRR(), "economics Internal Rate of Return", "%"])

        # annual_results_array.each {|result| puts "#{result[0]}, #{result[1]}, #{result[2]}, #{basename}" }
        #Determine weighted area average conductances
        outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces(), "Outdoors")
        outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
        outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")
        outdoor_floors = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Floor")
        outdoor_subsurfaces = BTAP::Geometry::Surfaces::get_subsurfaces_from_surfaces(outdoor_surfaces)
        windows = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["FixedWindow" , "OperableWindow" ])
        skylights = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Skylight", "TubularDaylightDiffuser","TubularDaylightDome" ])
        doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Door" , "GlassDoor" ])
        overhead_doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["OverheadDoor" ])
        outdoor_walls_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_walls)
        outdoor_roofs_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_roofs)
        outdoor_floors_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_floors)
        windows_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(windows)
        skylights_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(skylights)
        doors_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(doors)
        overhead_doors_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(overhead_doors)
        #Store Values
        annual_results_array.push( [ outdoor_walls_average_conductance ,"outdoor_walls_average_conductance", "?"])
        annual_results_array.push( [ outdoor_roofs_average_conductance ,"outdoor_roofs_average_conductance", "?"])
        annual_results_array.push( [ outdoor_floors_average_conductance ,"outdoor_floors_average_conductance", "?"])
        annual_results_array.push( [ windows_average_conductance ,"outdoor_windows_average_conductance", "?"])
        annual_results_array.push( [ doors_average_conductance ,"outdoor_doors_average_conductance", "?"])
        annual_results_array.push( [ overhead_doors_average_conductance ,"outdoor_overhead_doors_average_conductance", "?"])
        annual_results_array.push( [ skylights_average_conductance ,"skylights_average_conductance", "?"])
        annual_results_array.push( [ BTAP::Geometry::get_fwdr(model), "Fenestration To Wall Ratio", "-"])
        annual_results_array.push( [ BTAP::Geometry::get_srr(model), "Skylight to Roof Ratio", "-"])

        #Get peak watts for gas and elec
        electric_peak  = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM tabulardatawithstrings WHERE ReportName='EnergyMeters'" +
            " AND ReportForString='Entire Facility' AND TableName='Annual and Peak Values - Electricity' AND RowName='Electricity:Facility'" +
            " AND ColumnName='Electricity Maximum Value' AND Units='W'")
        if electric_peak.empty?
          electric_peak = 0.0
        end

        natural_gas_peak = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM tabulardatawithstrings WHERE ReportName='EnergyMeters'" +
            " AND ReportForString='Entire Facility' AND TableName='Annual and Peak Values - Gas' AND RowName='Gas:Facility'" +
            " AND ColumnName='Gas Maximum Value' AND Units='W'")
        if natural_gas_peak.empty?
          natural_gas_peak = 0.0
        end

        annual_results_array.push( [ electric_peak ,"Peak Electricity", "W"])
        annual_results_array.push( [ natural_gas_peak ,"Peak Gas", "W"])

        #Get End Uses by fuel type.
        fuel_types = [
          ['Electricity', 'GJ'],
          ['Natural Gas', 'GJ'],
          ['Other Fuel', 'GJ'],
          ['District Cooling', 'GJ'],
          ['District Heating', 'GJ'],
          ['Water', 'm3']]
        use_types = [
          'Heating',
          'Cooling',
          'Interior Lighting',
          'Exterior Lighting',
          'Interior Equipment',
          'Exterior Equipment',
          'Fans',
          'Pumps',
          'Heat Rejection',
          'Humidification',
          'Heat Recovery',
          'Water Systems',
          'Refrigeration',
          'Generators'
        ]
        use_types.each do |use_type|
          fuel_types.each do |fuel_type|
            fuel_name = fuel_type[0]
            fuel_units = fuel_type[1]
            value = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'")
            if value.empty?
              value = 0.0
            else
              value = value.get
            end
            annual_results_array.push( [ value, "#{fuel_name}-#{use_type}", fuel_units])
            annual_results_array.push( [ value / current_building.floorArea() , "#{fuel_name}-#{use_type} Total Floor Area Intensity", "#{fuel_units}/m2"] )
          end
        end
        return annual_results_array
      end

      #This method will return an array of common annual data results. With header and unit information and returns an annual results string array.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param osm_file [String]
      #@param sql_path [String] 
      #@return [annual_results_array<String>]
      def self.get_annual_results_model_results(osm_file,sql_path)

        #load Osm file.
        model = BTAP::FileIO::load_osm(osm_file)
        #link sql output
        model.setSqlFile(OpenStudio::SqlFile.new(OpenStudio::Path.new(sql_path)))

        #Create hash of results.
        annual_results_array = Array.new()
        annual_results_array.push( [ osm_file,"osm_file",""])
        annual_results_array.push( [ sql_path,"sql_path",""])
        if match = model.building.get.name.get.match(/(^.*)~(.*)~(.*)/)
          building_name, vintage_name, ecm_name = match.captures
          annual_results_array.push( [ building_name,"building_name",""])
          annual_results_array.push( [ vintage_name,"vintage_name",""])
          annual_results_array.push( [ ecm_name,"measure_id",""])
        else
          annual_results_array.push( [ model.building.get.name,"building_name",""])
        end

        #Capitol Costs
        value = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM tabulardatawithstrings WHERE ReportName='Life-Cycle Cost Report' AND ReportForString='Entire Facility' AND TableName='Present Value by Category' AND RowName='Grand Total' AND ColumnName='Present Value'")
        if value.empty?
          value = 0.0
        else
          value = value.get
        end
        annual_results_array.push( [ value, "Simulation Total Capitol Costs", "$"])


        #Total floor Areas
        annual_results_array.push( [ model.building.get.floorArea(),"Total Floor Area", "M2"])
        #Conditioned floor area
        annual_results_array.push( [ model.building.get.conditionedFloorArea(),"Conditioned Floor Area", "M2"])

        
        #District Heating
        fuel_name,use_type,fuel_units = "District Heating","Heating", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [  model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"])

        #District Cooling
        fuel_name,use_type,fuel_units = "District Cooling","Cooling", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [  model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"])

        
        #Electrical Heating
        fuel_name,use_type,fuel_units = "Electricity","Heating", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [  model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"])

        #Natural Gas Heating
        fuel_name,use_type,fuel_units = "Natural Gas","Heating", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [  model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"]) 

        #Electric Cooling
        fuel_name,use_type,fuel_units = "Electricity","Cooling", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [  model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"])

        #Electric Water systems
        fuel_name,use_type,fuel_units = "Electricity","Water Systems", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [  model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"]) 

        #NG Water systems
        fuel_name,use_type,fuel_units = "Natural Gas","Water Systems", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [  model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"]) 

        fuel_name,use_type,fuel_units = "Electricity","Interior Lighting", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [  model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"])

        fuel_name,use_type,fuel_units = "Electricity","Interior Equipment", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [  model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"])

        fuel_name,use_type,fuel_units = "District Heating","Interior Equipment", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [ model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"])


        fuel_name,use_type,fuel_units = "Electricity","Fans", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [ model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"])

        fuel_name,use_type,fuel_units = "Electricity","Pumps", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [  model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"])

        fuel_name,use_type,fuel_units = "Electricity","Heat Recovery", 'GJ'
        sql_query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'"
        annual_results_array.push( [ model.sqlFile().get().execAndReturnFirstDouble(sql_query).get ? model.sqlFile().get().execAndReturnFirstDouble(sql_query).get * 277.778 : 0.0, "#{fuel_name}-#{use_type}", "KWh"])


        return annual_results_array
      end

      #This method will convert eso to cvs.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param eso_file_path [String] 
      def self.convert_eso_to_csv(eso_file_path)
        #Run ESO Vars command must be run in folder.
        root_folder = Dir.getwd()
        # puts File.dirname(eso_file_path)
        Dir.chdir(File.dirname(eso_file_path))
        system(self.find_read_vars_eso())
        #get name of run from html file. This is faster than loading OSM file.
        runname = ""
        f = File.open("eplustbl.htm")
        f.each_line do |line|
          if line =~ /<p>Building: <b>(.*)<\/b><\/p>/
            runname = $1
            break
          end
        end
        f.close
        #copy files over with distinct names
        FileUtils.cp("eplusout.csv","#{runname}_eplusout.csv")
        FileUtils.cp("eplustbl.htm","#{runname}_eplustbl.htm")
        FileUtils.cp("eplusout.sql","#{runname}_eplusout.sql")
        Dir.chdir(root_folder)
      end

      #This method will copy results to a folder.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param in_folder [String]
      #@param out_folder [String]
      def copy_results_to_folder(in_folder,out_folder)
        #find all csv hourly output
        BTAP::FILEIO::get_find_files_from_folder_by_extension(in_folder, "_eplusout.csv").each {|file| FileUtils.cp(file,out_folder)}
        BTAP::FILEIO::get_find_files_from_folder_by_extension(in_folder, "_eplustbl.htm").each {|file| FileUtils.cp(file,out_folder)}
        BTAP::FILEIO::get_find_files_from_folder_by_extension(in_folder, "_eplusout.sql").each {|file| FileUtils.cp(file,out_folder)}

      end


      #This method copies report files to a single folder for convenience.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param run_name [String]
      #@return [OpenStudio::model::Model] A model object
      def processResults(run_name)
        #make sql folder
        Dir.mkdir(@outdir.to_s+"\\sqlresults") unless File.exists?(@outdir.to_s+"\\sqlresults")
        #make html folder
        Dir.mkdir(@outdir.to_s+"\\htmlresults") unless File.exists?(@outdir.to_s+"\\htmlresults")
        #puts "processing results for " + run_name

        #load sql file
        # see if we can find sql file
        sql_path = OpenStudio::Path.new(@outdir.to_s+"\\" + run_name + "_osm\\ModelToIdf\\ExpandObjects-0\\EnergyPlus-0\\eplusout.sql")
        html_path = OpenStudio::Path.new(@outdir.to_s+"\\" + run_name + "_osm\\ModelToIdf\\ExpandObjects-0\\EnergyPlus-0\\eplustbl.htm")
        FileUtils.cp(sql_path.to_s,@outdir.to_s+"/sqlresults/" + run_name + ".sql")
        FileUtils.cp(html_path.to_s,@outdir.to_s+"/htmlresults/" + run_name + ".htm")

        #load osm file to attach sql file
        model_path = OpenStudio::Path.new(@outdir.to_s+"\\"+ run_name + ".osm")
        if OpenStudio::exists(model_path)
          model = BTAP::FileIO::load_osm(model_path)
        end


        #attach sql file
        if OpenStudio::exists(sql_path)
          # translate the results and load them into the model
          sqlFile = OpenStudio::SqlFile.new(sql_path)
          model.setSqlFile(sqlFile)
        else
          #puts "could not load sql file" + sql_path
        end


        #construct path to E+ run.
        ep_project_folder = @outdir.to_s+"\\" + run_name + "_osm\\ModelToIdf\\ExpandObjects-0\\EnergyPlus-0\\"
        eso_file = ep_project_folder + "\\eplusout.eso"
        #create csv folder at top of folder hieracrhy.
        cvs_results_folder = @outdir.to_s+"/csvresults/"
        Dir.mkdir(cvs_results_folder) unless File.exists?(cvs_results_folder)
        #create path to e+ csv file and copy it to folder.


        #Run ESO Vars command must be run in folder.
        root_folder = Dir.getwd()
        Dir.chdir(ep_project_folder)
        system(@readvars_path)
        csv_file = ep_project_folder + "\\eplusout.csv"
        FileUtils.cp(csv_file, cvs_results_folder + run_name + ".csv")
        Dir.chdir(root_folder)
        return model
      end
      
      #This method will fix underheated hours
      #@author Phylroy A. Lopez
      #@param model [OpenStudio::model::Model] A model object
      #@param folder_name [String] a simple string of the simulation folder path, remember to escape the slashes..(i.e. // not / )
      #@param epw_path [String] a simple string of the epw file path, remember to escape the slashes..(i.e. // not / )    
      def fix_underheated_hours(model,epw_path,folder_name = "c:/temp/")

        #Run model. 
        BTAP::SimManager::run_simulation(model, folder_name, epw_path)

        #Look at hours unmet per zone table in eplusout.htm file
        #Make sure that the zone with the problem is not a slave zone on a single-zone VAV system.
        #Check your thermostat setpoint schedules for this zone to make sure values are reasonable
        #Check that design days are for the same location as the weather file
        #Open the .osm in a text editor to look at this.
        #Check the tolerance for reporting unmet hours
        #Try 2F and re-run. If tolerance is too tight, you can get false alarms.
        #Check design/sizing temperature for each plant loop.
        #This is found by clicking the dashed line in the center of a plant loop.
        #Check the operational temperature in the plant loop's setpoint manager.
        #It should match up with the design/sizing temperature for that loop.
        #If you size the loop for 180F water but tell it to operate at 150F, the equipment won't be big enough during peak times.
        #Check design/sizing heating and cooling supply air temperatures for air loop.
        #This is found by clicking the dashed line in the center of the air loop.
        #Check the operational temperature in the air loop's setpoint manager.
        #It should match up with the design/sizing temperature for that loop.
        #If you size the loop for 55F supply air but tell it to operate at 60F, the equipment might not be big enough during peak times.
        #Check that sizing design day thermostat is using a constant setpoint schedule with no setback.
        #This is a 90.1 requirement. If your design day has a setback, your system will be oversized in an attempt to be able to go from setback to setup in a single timestep.
        #Equipment that is significantly oversized might not operate properly at low load conditions.
      end

    end

  end
end