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


require "#{File.dirname(__FILE__)}/btap"
require 'fileutils'
require 'csv'

module BTAP
  module Reporting
    #This method will take the folder name and write out a result files to the input folder.
    #@author phylroy.lopez@nrcan.gc.ca
    #@param folder [String] Path too a folder where to write result files to.
    def self.get_all_annual_results_from_runmanger(folder)
      #output file name
      osmfiles = BTAP::FileIO::get_find_files_from_folder_by_extension(folder,".osm")
      self.get_all_annual_results_from_runmanger_by_files(folder,osmfiles)
    end

    #This method will take the folder name and write out a result files to the input folder.
    #@author phylroy.lopez@nrcan.gc.ca
    #@param folder [String] Path too a folder where to write result files to.
    def self.get_all_annual_results_from_runmanger_by_files(folder,osm_files)
      #output file name
      result_file_path = folder + "/annual_result_table.csv"
      File.delete(result_file_path) if File.exist?(result_file_path)
      error_file_path = folder + "/failed simulations.txt"
      File.delete(error_file_path) if File.exist?(error_file_path)
      annual_results = File.new( result_file_path,'a')
      error_file = File.new( error_file_path,'a')
      header_printed = false
      array = Array.new
      counter = 0
      osm_files.each do |osm|
        puts "Processing #{osm} results"
        simulation_folder = File.basename( osm, ".*" )
        sql = BTAP::FileIO::get_find_files_from_folder_by_extension("#{folder}/#{simulation_folder}",".sql").first
        htm = BTAP::FileIO::get_find_files_from_folder_by_extension("#{folder}/#{simulation_folder}",".htm").first
        unless sql.nil? or osm.nil? or htm.nil?
          puts "Processing #{osm} results with #{sql} and #{htm}."
          array = BTAP::SimManager::ProcessManager::old_get_annual_results_model_results( osm, sql )
          if header_printed == false
            header_printed = true
            header = ""
            array.each do |value|
              header = header + "#{value[1]} #{value[2]},"
            end
            annual_results.puts(header)
          end
          row_data = ""
          array.each do |value|
            row_data = row_data + "#{value[0]},"
          end
          annual_results.puts(row_data)
          puts "#{counter} of #{osm_files.size} remaining." 
          counter = counter + 1
          puts "annual results have been processed and added to #{result_file_path} for #{osm}. "
        else
          puts "***************************************ERROR!: #{osm} simulation failed to produce results\n"
          error_file.puts("ERROR!: #{osm} simulation failed to produce results\n Here is the resulting eplusout.err file:\n")
          err = BTAP::FileIO::get_find_files_from_folder_by_extension("#{folder}/#{simulation_folder}","eplusout.err").first
          if err != nil and File.exist?(err)
            errfile = File.open(err, "rb")
            errfile.readlines.each do |line|
              puts line
              error_file.puts( line )
              error_file.puts("\n")
            end
            errfile.close
          else
            error_file.puts("ERROR!: #{osm} simulation failed to produce results\n eplusout.err file not found:\n")
          end
            
        end
      end
      annual_results.close
      error_file.close
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

      conditionedFloorArea = current_building.conditionedFloorArea()#m2
      exteriorSurface_area = current_building.exteriorSurfaceArea() #m2
      air_volume = current_building.airVolume() #m3



      #Average loads
      annual_results_array.push( [ current_building.peoplePerFloorArea(),"Number of People per Area","Persons/M2"])       
      annual_results_array.push( [ current_building.lightingPowerPerFloorArea(),"Lighting Power Density","W/M2"])
      annual_results_array.push( [ current_building.electricEquipmentPowerPerFloorArea(),"Electric Equipment Power Density","W/M2"])
      annual_results_array.push( [ current_building.gasEquipmentPowerPerFloorArea(),"Gas Equipment Power Density","W/M2"])
        
        
      #Site / Source Energy Intensity
      annual_results_array.push( [ current_facility.totalSiteEnergy() / conditionedFloorArea , "Total Site Energy Intensity", "GJ/M2"])
      annual_results_array.push( [ current_facility.netSiteEnergy()  / conditionedFloorArea , "Net Site Energy Intensity", "GJ/M2"])
      annual_results_array.push( [ current_facility.totalSourceEnergy() / conditionedFloorArea , "Total Source Energy Intensity", "GJ/M2"])
      annual_results_array.push( [ current_facility.netSourceEnergy() / conditionedFloorArea, "Net Source Energy Intensity", "GJ/M2"])

      #unmet hours
      annual_results_array.push( [ current_facility.hoursHeatingSetpointNotMet(),"Unmet Hours Heating ", "Hours"])
      annual_results_array.push( [ current_facility.hoursCoolingSetpointNotMet(),"Unmet Hours Cooling ", "Hours"])

      #cost information
      annual_results_array.push( [ current_facility.annualTotalCostPerNetConditionedBldgArea(OpenStudio::FuelType.new("NaturalGas")), "Natural Gas Total Cost Intensity", "$/M2"])
      annual_results_array.push( [ current_facility.economicsVirtualRateGas(), "NaturalGas Virtual Rate", "$/GJ"])
      annual_results_array.push( [ current_facility.annualTotalCostPerNetConditionedBldgArea(OpenStudio::FuelType.new("Electricity")), "Electricity Total Cost Intensity", "$/M2"])
      annual_results_array.push( [ current_facility.economicsVirtualRateElec(), "Electricity  Virtual Rate", "$/GJ"])
      annual_results_array.push( [ current_facility.economicsVirtualRateCombined(), "Elec-Gas-Combined Virtual Rate", "$/GJ"])
      annual_results_array.push( [ current_facility.annualTotalCostPerNetConditionedBldgArea(OpenStudio::FuelType.new("DistrictCooling")), "DistrictCooling Total Cost Intensity", "$/M2"])
      annual_results_array.push( [ current_facility.annualTotalCostPerNetConditionedBldgArea(OpenStudio::FuelType.new("DistrictHeating")), "DistrictHeating Total Cost Intensity", "$/M2"])
      annual_results_array.push( [ current_facility.annualTotalUtilityCost() / conditionedFloorArea , "Total Utility Cost Intensity", "$"])
      annual_results_array.push( [ current_facility.economicsCapitalCost() / conditionedFloorArea , "Capitol Costs Intensity", "$/M2"])
      annual_results_array.push( [ current_facility.economicsSPB(), "economics Simple Pay Back", "Years"])
      annual_results_array.push( [ current_facility.economicsIRR(), "economics Internal Rate of Return", "%"])

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
      annual_results_array.push( [ BTAP::Geometry::get_fwdr(model) * 100.0, "Fenestration To Wall Ratio", "%"])
      annual_results_array.push( [ BTAP::Geometry::get_srr(model)* 100.0, "Skylight to Roof Ratio", "%"])

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
  
      def end_use_intensity(use_type,fuel_type)
        fuel_name = fuel_type[0]
        fuel_units = fuel_type[1]
        value = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_name}' AND Units='#{fuel_units}'")
        if value.empty?
          value = 0.0
        else
          value = value.get
        end
        annual_results_array.push( [ value, "#{fuel_name}-#{use_type}", fuel_units])
        annual_results_array.push( [ value / current_building.floorArea() , "#{fuel_name}-#{use_type}  Intensity", "#{fuel_units}/m2"] )
      end
      #Heating Energy
      end_use_intensity("Heating",['Electricity', 'GJ'] )
      end_use_intensity("Heating",['Natural Gas', 'GJ'] )
      end_use_intensity("Heating",['District Heating', 'GJ'] )
      #Cooling Energy
      end_use_intensity('Cooling',['Electricity', 'GJ'] )
      end_use_intensity("Cooling",['District Cooling', 'GJ'] )
      #Lighting Energy
      end_use_intensity('Interior Lighting',['Electricity', 'GJ'] )
      end_use_intensity('Exterior Lighting',['Electricity', 'GJ'] )
      #Equipment Energy
      end_use_intensity('Interior Equipment',['Electricity', 'GJ'] )
      end_use_intensity('Exterior Equipment',['Electricity', 'GJ'] )
      end_use_intensity('Interior Equipment',['Natural Gas', 'GJ'] )
      end_use_intensity('Exterior Equipment',['Natural Gas', 'GJ'] )
      #Fans/Pumps
      end_use_intensity('Fans',['Electricity', 'GJ'] )
      end_use_intensity('Pumps',['Electricity', 'GJ'] )
      #Heat Rejection
      end_use_intensity('Heat Rejection',['Electricity', 'GJ'] )
      end_use_intensity('Heat Rejection',['Natural Gas', 'GJ'] )
      #Humidification
      end_use_intensity('Humidification',['Electricity', 'GJ'] )
      end_use_intensity('Humidification',['Natural Gas', 'GJ'] )
      #Heat Recovery
      end_use_intensity('Heat Recovery',['Electricity', 'GJ'] )
      end_use_intensity('Heat Recovery',['Natural Gas', 'GJ'] )
      #Water Systems	
      end_use_intensity('Water Systems',['Electricity', 'GJ'] )
      end_use_intensity('Water Systems',['Natural Gas', 'GJ'] )
      #Refrigeration	
      end_use_intensity('Refrigeration',['Electricity', 'GJ'] )
      #Generators	
      end_use_intensity('Generators',['Electricity', 'GJ'] )
      end_use_intensity('Generators',['Natural Gas', 'GJ'] )
      
      return annual_results_array
    end
    
    
    
    
    
    

  end
end
