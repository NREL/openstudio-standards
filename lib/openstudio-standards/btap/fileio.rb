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



require 'fileutils'
require 'csv'
require 'securerandom'


module BTAP
  module FileIO

    #Test Constructions Module
    if __FILE__ == $0
      require 'test/unit'
      class FileIOTests < Test::Unit::TestCase

        def setup
        end

        def test_load_save_DOE_file()
          BTAP::FileIO::load_e_quest(BTAP::OS_RUBY_PATH + '\Resources\eQuest_3.64\4StoreyBuilding.inp')
        end


      end
    end
    # Get the name of the model.
    # @author Phylroy A. Lopez
    # @return [String] the name of the model.
    def self.get_name(model)
      unless model.building.get.name.empty?
        return model.building.get.name.get.to_s
      else
        return ""
      end
    end

    # @author Phylroy A. Lopez
    # Get the name of the model.
    # @author Phylroy A. Lopez
    # @return [String] the name of the model.
    def self.set_name(model,name)
      unless model.building.empty?
        model.building.get.setName(name)
      end
    end

    # @author Phylroy A. Lopez
    # Get the name of the model.
    # @author Phylroy A. Lopez
    # @return [String] the name of the model.
    def self.set_sql_file(model,sql_path)
      model.setSqlFile(OpenStudio::Path.new( sql_path) )
    end
    #@author Phylroy A. Lopez
    # Get the filepath of all files with extention
    # @param folder [String} the path to the folder to be scanned.
    # @param ext [String] the file extension name, ex ".epw"
    def self.get_find_files_from_folder_by_extension(folder, ext)
      Dir.glob("#{folder}/**/*#{ext}")
    end

    def self.delete_files_in_folder_by_extention(folder,ext)
      BTAP::FileIO::get_find_files_from_folder_by_extension(folder, ext).each do |file|
        FileUtils.rm(file)
        #puts "#{file} deleted."
      end
    end

    def self.find_file_in_folder_by_filename(folder,filename)
      Dir.glob("#{folder}/**/*#{filename}")
    end

    def self.fix_url_to_path(url_string)
      if  url_string =~/\/([a-zA-Z]:.*)/
        return $1
      else
        return url_string
      end
    end


    # This method loads an Openstudio file into the model.
    # @author Phylroy A. Lopez
    # @param filepath [String] path to the OSM file.
    # @param name [String] optional model name to be set to model.
    # @return [OpenStudio::Model::Model] an OpenStudio model object.
    def self.load_idf(filepath, name = "")
      #load file
      unless File.exist?(filepath)
        raise 'File does not exist: ' + filepath.to_s
      end
      #puts "loading file #{filepath}..."
      model_path = OpenStudio::Path.new(filepath.to_s)
      #Upgrade version if required.
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      model = OpenStudio::EnergyPlus::loadAndTranslateIdf(model_path)
      version_translator.errors.each {|error| puts "Error: #{error.logMessage}\n\n"}
      version_translator.warnings.each {|warning| puts "Warning: #{warning.logMessage}\n\n"}
      #If model did not load correctly.
      if model.empty?
        raise 'something went wrong'
      end
      model = model.get
      if name != ""
        self.set_name(model,name)
      end
      #puts "File #{filepath} loaded."
      return model
    end

    def self.replace_model(model,new_model,runner = nil)
      # pull original weather file object over
      weather_file = new_model.getOptionalWeatherFile
      if not weather_file.empty?
        weather_file.get.remove
        BTAP::runner_register("Info", "Removed alternate model's weather file object.",runner)
      end
      original_weather_file = model.getOptionalWeatherFile
      if not original_weather_file.empty?
        original_weather_file.get.clone(new_model)
      end

      # pull original design days over
      new_model.getDesignDays.sort.each { |designDay|
        designDay.remove
      }
      model.getDesignDays.sort.each { |designDay|
        designDay.clone(new_model)
      }

      # swap underlying data in model with underlying data in new_model
      # remove existing objects from model
      handles = OpenStudio::UUIDVector.new
      model.objects.each do |obj|
        handles << obj.handle
      end
      model.removeObjects(handles)
      # add new file to empty model
      model.addObjects( new_model.toIdfFile.objects )
      BTAP::runner_register("Info",  "Model name is now #{model.building.get.name}.", runner)
    end





    # This method loads an Openstudio file into the model.
    # @author Phylroy A. Lopez
    # @param filepath [String] path to the OSM file.
    # @param name [String] optional model name to be set to model.
    # @return [OpenStudio::Model::Model] an OpenStudio model object.
    def self.load_osm(filepath, name = "")

      #load file
      unless File.exist?(filepath)
        raise 'File does not exist: ' + filepath.to_s
      end
      #puts "loading file #{filepath}..."
      model_path = OpenStudio::Path.new(filepath.to_s)
      #Upgrade version if required.
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      model = version_translator.loadModel(model_path)
      version_translator.errors.each {|error| puts "Error: #{error.logMessage}\n\n"}
      version_translator.warnings.each {|warning| puts "Warning: #{warning.logMessage}\n\n"}
      #If model did not load correctly.
      if model.empty?
        raise "could not load #{filepath}"
      end
      model = model.get
      if name != "" and not name.nil?
        self.set_name(model,name)
      end
      #puts "File #{filepath} loaded."

      return model
    end

    # This method loads an *Quest file into the model.
    # @author Phylroy A. Lopez
    # @param filepath [String] path to the OSM file.
    # @return [OpenStudio::Model::Model] an OpenStudio model object.
    def self.load_e_quest(filepath)
      #load file
      unless File.exist?(filepath)
        raise 'File does not exist: ' + filepath.to_s
      end
      #puts "loading equest file #{filepath}. This will only convert geometry."
      #Create an instancse of a DOE model
      doe_model = BTAP::EQuest::DOEBuilding.new()
      #Load the inp data into the DOE model.
      doe_model.load_inp(filepath)

      #Convert the model to a OSM format.
      model = doe_model.create_openstudio_model_new()
      return model
    end

    #This method will inject OSM objects from a OSM file/library into the current
    # model.
    # @author Phylroy A. Lopez
    # @param filepath [String] path to the OSM library file.
    # @return [OpenStudio::Model::Model] an OpenStudio model object (self reference).
    def self.inject_osm_file(model, filepath)
      osm_data = BTAP::FileIO::load_osm(filepath)
      model.addObjects(osm_data.objects);
      return model
    end

    # This method will return a deep copy of the model.
    # Simply because I don't trust the clone method yet.
    # @author Phylroy A. Lopez
    # @return [OpenStudio::Model::Model] a copy of the OpenStudio model object.
    def self.deep_copy(model,bool = true)
      return model.clone(bool).to_Model

      # pull original weather file object over
      weather_file = new_model.getOptionalWeatherFile
      if not weather_file.empty?
        weather_file.get.remove
        BTAP::runner_register("Info", "Removed alternate model's weather file object.",runner)
      end
      original_weather_file = model.getOptionalWeatherFile
      if not original_weather_file.empty?
        original_weather_file.get.clone(new_model)
      end

      # pull original design days over
      new_model.getDesignDays.sort.each { |designDay|
        designDay.remove
      }
      model.getDesignDays.sort.each { |designDay|
        designDay.clone(new_model)
      }

      # swap underlying data in model with underlying data in new_model
      # remove existing objects from model
      handles = OpenStudio::UUIDVector.new
      model.objects.each do |obj|
        handles << obj.handle
      end
      model.removeObjects(handles)
      # add new file to empty model
      model.addObjects( new_model.toIdfFile.objects )
      BTAP::runner_register("Info",  "Model name is now #{model.building.get.name}.", runner)




    end

    # This method will save the model to an osm file.
    # @author Phylroy A. Lopez
    # @param model
    # @param filename The full path to save to.
    # @return [OpenStudio::Model::Model] a copy of the OpenStudio model object.
    def self.save_osm(model,filename)
      FileUtils.mkdir_p(File.dirname(filename))
      File.delete(filename) if File.exist?(filename)
      model.save(OpenStudio::Path.new(filename))
      #puts "File #{filename} saved."
    end

    # This method will translate to an E+ IDF format and save the model to an idf file.
    # @author Phylroy A. Lopez
    # @param model
    # @param filename The full path to save to.
    # @return [OpenStudio::Model::Model] a copy of the OpenStudio model object.
    def self.save_idf(model,filename)
      OpenStudio::EnergyPlus::ForwardTranslator.new().translateModel(model).toIdfFile().save(OpenStudio::Path.new(filename),true)
    end

    # This method will recursively translate all IDFs in a folder to OSMs, and save them to the OSM_-No_Space_Types folder
    # @author Brendan Coughlin
    # @param filepath The directory that holds the IDFs - usually DOEArchetypes\Original
    # @return nil
    def self.convert_idf_to_osm(filepath)
      Find.find(filepath) { |file|
        if file[-4..-1] == ".idf"
          model = FileIO.load_idf(file)
          # this is a bit ugly but it works properly when called on a recursive folder structure
          FileIO.save_osm(model, (File.expand_path("..\\OSM-No_Space_Types\\", filepath) << "\\" << Pathname.new(file).basename.to_s)[0..-5])
          #puts # empty line break
        end
      }
    end





    def self.get_timestep_data(osm_file,sql_file,variable_name_array, env_period = nil, hourly_time_step = nil )
      column_data = get_timeseries_arrays(sql, env_period, hourly_time_step, "Boiler Fan Coil Part Load Ratio")
    end


    def self.convert_all_eso_to_csv(in_folder,out_folder)
      list_of_csv_files = Array.new
      FileUtils.mkdir_p(out_folder)
      osmfiles = BTAP::FileIO::get_find_files_from_folder_by_extension(in_folder,".eso")

      osmfiles.each do |eso_file_path|

        #Run ESO Vars command must be run in folder.
        root_folder = Dir.getwd()
        #puts File.dirname(eso_file_path)
        Dir.chdir(File.dirname(eso_file_path))
        if File.exist?("eplustbl.htm")
          File.open("dummy.rvi", 'w') {|f| f.write("") }


          system("#{BTAP::SimManager::ProcessManager::find_read_vars_eso()} dummy.rvi unlimited")
          #get name of run from html file.
          runname = ""
          f = File.open("eplustbl.htm")
          f.each_line do |line|
            if line =~ /<p>Building: <b>(.*)<\/b><\/p>/
              #puts  "Found name: #{$1}"
              runname = $1
              break
            end
          end
          f.close
          #copy files over with distinct names
          #puts "copy hourly results to #{out_folder}/#{runname}_eplusout.csv"
          FileUtils.cp("eplusout.csv","#{out_folder}/#{runname}_eplusout.csv")
          #puts "copy html results to #{out_folder}/#{runname}_eplustbl.htm"
          FileUtils.cp("eplustbl.htm","#{out_folder}/#{runname}_eplustbl.htm")
          #puts "copy sql results to #{out_folder}/#{runname}_eplusout.sql"
          FileUtils.cp("eplusout.sql","#{out_folder}/#{runname}_eplusout.sql")


          list_of_csv_files << "#{out_folder}/#{runname}_eplusout.csv"
        end
        Dir.chdir(root_folder)
      end
      return list_of_csv_files
    end


    # This method will read a CSV file and return rows as hashes based on the selection given.
    # @author Phylroy Lopez
    # @param file The path to the csv file.
    # @param searchHash
    # @return matches A Array of rows that match the searchHash. The row is a Hash itself.
    def self.csv_look_up_rows(file, searchHash)
      options = {
          :headers =>       true,
          :converters =>     :numeric }
      table = CSV.read( file, options )
      # we'll save the matches here
      matches = nil
      # save a copy of the headers
      matches = table.find_all do |row|
        row
        match = true
        searchHash.keys.each do |key|
          match = match && ( row[key] == searchHash[key] )
        end
        match
      end
      return matches
    end

    def self.csv_look_up_unique_row(file, searchHash)
      #Load Vintage database information.
      matches = BTAP::FileIO::csv_look_up_rows(file, searchHash)
      raise( "Error:  CSV lookup found more than one row that met criteria #{searchHash} in #{@file} ") if matches.size() > 1
      raise( "Error:  CSV lookup found no rows that met criteria #{searchHash} in #{@file}") if matches.size() < 1
      return matches[0]
    end


    # This method will read a CSV file and return the unique values in a given column header.
    # @author Phylroy Lopez
    # @param file The path to the csv file.
    # @param colHeader The header name in teh csv file.
    # @return matches A Array of rows that match the searchHash. The row is a Hash itself.
    def self.csv_look_up_unique_col_data(file, colHeader)
      column_data = Array.new
      CSV.foreach( file, :headers => true ) do |row|
        column_data << row[colHeader] # For each row, give me the cell that is under the colHeader column
      end
      return column_data.sort!.uniq
    end

    def self.sum_row_headers(row,headers)
      total = 0.0
      headers.each { |header| total = total + row[header] }
      return total
    end

    def self.terminus_hourly_output(csv_file)
      #puts "Starting Terminus output processing."
      #puts "reading #{csv_file} being processed"
      #reads csv file into memory.
      original = CSV.read(csv_file,
                          {
                              :headers =>       true, #This flag tell the parser that there are headers.
                              :converters =>     :numeric  #This tell it to convert string data into numeric when possible.
                          }
      )
      #puts "done reading #{csv_file} being processed"
      # We are going to collect the header names  that fit a pattern. But first we need to
      # create array containers to save the header name. In ruby we can use the string header names
      # as the array index.

      #Create arrays to store the header names for each type.
      waterheater_gas_rate_headers = Array.new()
      waterheater_electric_rate_headers = Array.new()
      waterheater_heating_rate_headers = Array.new()
      cooling_coil_electric_power_headers = Array.new()
      cooling_coil_total_cooling_rate_headers = Array.new()
      heating_coil_air_heating_rate_headers = Array.new()
      heating_coil_gas_rate_headers = Array.new()
      plant_supply_heating_demand_rate_headers = Array.new()
      facility_total_electrical_demand_headers = Array.new()
      boiler_gas_rate_headers = Array.new()
      time_index  = Array.new()
      boiler_gas_rate_headers = Array.new()
      heating_coil_electric_power_headers = Array.new()


      #remove rows 2-169 (or 1-168 in computer array terms)
      original = self.remove_rows_from_csv_table(0,72,original)


      #Scan the CSV file to file all the headers that match the pattern. This will go through all the headers and find
      # any header that matches our regular expression if a match is made, the header name is stuffed into the string array.
      original.headers.each do |header|
        stripped_header = header.strip
        waterheater_electric_rate_headers                      << header if stripped_header =~/^.*:Water Heater Electric Power \[W\]\(Hourly\)$/
        waterheater_gas_rate_headers                           << header if stripped_header =~/^.*:Water Heater Gas Rate \[W\]\(Hourly\)$/
        waterheater_heating_rate_headers                       << header if stripped_header =~/^.*:Water Heater Heating Rate \[W\]\(Hourly\)$/
        cooling_coil_electric_power_headers                    << header if stripped_header =~/^.*:Cooling Coil Electric Power \[W\]\(Hourly\)$/
        cooling_coil_total_cooling_rate_headers                << header if stripped_header =~/^.*:Cooling Coil Total Cooling Rate \[W\]\(Hourly\)$/
        heating_coil_air_heating_rate_headers                  << header if stripped_header =~/^.*:Heating Coil Air Heating Rate \[W\]\(Hourly\)$/
        heating_coil_gas_rate_headers                          << header if stripped_header =~/^.*:Heating Coil Gas Rate \[W\]\(Hourly\)$/
        heating_coil_electric_power_headers                     << header if stripped_header =~/^.*:Heating Coil Electric Power \[W\]\(Hourly\)$/
        plant_supply_heating_demand_rate_headers               << header if stripped_header =~/^(?!SWH PLANT LOOP).*:Plant Supply Side Heating Demand Rate \[W\]\(Hourly\)$/
        facility_total_electrical_demand_headers               << header if stripped_header =~/^.*:Facility Total Electric Demand Power \[W\]\(Hourly\)$/
        boiler_gas_rate_headers                                << header if stripped_header =~/^.*:Boiler Gas Rate \[W\]\(Hourly\)/

      end
      #Debug printout stuff. Make sure the output it captures the headers you want otherwise modify the regex above
      #puts waterheater_gas_rate_headers
      #puts waterheater_electric_rate_headers
      #puts waterheater_heating_rate_headers

      #puts cooling_coil_electric_power_headers
      #puts cooling_coil_total_cooling_rate_headers

      #puts heating_coil_air_heating_rate_headers
      #puts heating_coil_gas_rate_headers

      #puts plant_supply_heating_demand_rate_headers
      #puts facility_total_electrical_demand_headers
      #puts boiler_gas_rate_headers
      #puts heating_coil_electric_power_headers


      #open up a new file to save the file to..Note: This will fail it the file is open in EXCEL.
      CSV.open("#{csv_file}.terminus_hourly.csv", 'w') do |csv|
        #Create header row for new terminus hourly file.
        csv << [
            "Date/Time",
            "water_heater_gas_rate_total",
            "water_heater_electric_rate_total",
            "water_heater_heating_rate_total",
            "cooling_coil_electric_power_total",
            "cooling_coil_total_cooling_rate_total",
            "heating_coil_air_heating_rate_total",
            "heating_coil_gas_rate_total",
            "heating_coil_electric_power_total",
            "plant_supply_heating_demand_rate_total",
            "facility_total_electrical_demand_total",
            "boiler_gas_rate_total"
        ]
        original.each do |row|

          # We are now writing data to the new csv file. This is where we can manipulate the data, row by row.
          # sum the headers collected above and store in specific *_total variables.
          # This is done via a small function self.sum_row_headers. There may only be a single
          # header collected.. That is fine. It is better to be flexible than hardcode anything.
          water_heater_gas_rate_total = self.sum_row_headers(row,waterheater_gas_rate_headers)
          water_heater_electric_rate_total = self.sum_row_headers(row,waterheater_electric_rate_headers)
          water_heater_heating_rate_total  = self.sum_row_headers(row,waterheater_heating_rate_headers)
          cooling_coil_electric_power_total = self.sum_row_headers(row, cooling_coil_electric_power_headers)
          cooling_coil_total_cooling_rate_total = self.sum_row_headers(row, cooling_coil_total_cooling_rate_headers)
          heating_coil_air_heating_rate_total = self.sum_row_headers(row, heating_coil_air_heating_rate_headers)
          heating_coil_gas_rate_total = self.sum_row_headers(row, heating_coil_gas_rate_headers)
          heating_coil_electric_power_total = self.sum_row_headers(row, heating_coil_electric_power_headers)
          plant_supply_heating_demand_rate_total = self.sum_row_headers(row, plant_supply_heating_demand_rate_headers)
          facility_total_electrical_demand_total = self.sum_row_headers(row, facility_total_electrical_demand_headers)
          boiler_gas_rate_headers_total = self.sum_row_headers(row, boiler_gas_rate_headers)



          #Write the data out. Should match header row as above.
          csv << [
              row["Date/Time"], #Time index is hardcoded because every file will have a "Date/Time" column header.
              water_heater_gas_rate_total,
              water_heater_electric_rate_total,
              water_heater_heating_rate_total,
              cooling_coil_electric_power_total,
              cooling_coil_total_cooling_rate_total,
              heating_coil_air_heating_rate_total,
              heating_coil_gas_rate_total,
              heating_coil_electric_power_total,
              plant_supply_heating_demand_rate_total,
              facility_total_electrical_demand_total,
              boiler_gas_rate_headers_total
          ]
        end
      end
      #puts "Ending Terminus output processing."
    end

    def self.remove_rows_from_csv_table(start_index,stop_index,table)
      total_rows_to_remove = stop_index - start_index
      (0..total_rows_to_remove-1).each do |counter|
        table.delete(start_index)
      end
      return table
    end


    #load a model into OS & version translates, exiting and erroring if a problem is found
    def self.safe_load_model(model_path_string)
      model_path = OpenStudio::Path.new(model_path_string)
      if OpenStudio::exists(model_path)
        versionTranslator = OpenStudio::OSVersion::VersionTranslator.new
        model = versionTranslator.loadModel(model_path)
        if model.empty?
          raise "Version translation failed for #{model_path_string}"
        else
          model = model.get
        end
      else
        raise "#{model_path_string} couldn't be found"
      end
      return model
    end

    #load a sql file, exiting and erroring if a problem is found
    def safe_load_sql(sql_path_string)
      sql_path = OpenStudio::Path.new(sql_path_string)
      if OpenStudio::exists(sql_path)
        sql = OpenStudio::SqlFile.new(sql_path)
      else
        puts "Error: #{sql_path} couldn't be found"
        exit
      end
      return sql
    end

    #function to wrap debug == true puts
    def debug_puts(puts_text)
      if Debug_Mode == true
        puts "#{puts_text}"
      end
    end

    def get_timeseries_arrays(openstudio_sql_file, timestep, variable_name_array, regex_name_filter = /.*/, env_period = nil)
      returnArray = Array.new()
      variable_name_array.each do |variable_name|
        possible_key_values = openstudio_sql_file.availableKeyValues(env_period,timestep,variable_name)
        possible_variable_names = openstudio_sql_file.availableVariableNames(env_period,timestep).include?(variable_name)
        if not possible_variable_names.nil?  and  possible_variable_names.include?(variable_name) and not possible_key_values.nil?
          possible_key_values.get.sort.each do |key_value|
            unless regex_name_filter.match(key_value).nil?
              returnArray << get_timeseries_array(openstudio_sql_file, timestep, variable_name, key_value)
            end
          end
        end
        return returnArray
      end
    end




    #gets a time series data vector from the sql file and puts the values into a standard array of numbers
    def get_timeseries_array(openstudio_sql_file, timestep, variable_name, key_value)
      zone_time_step = "Zone Timestep"
      hourly_time_step = "Hourly"
      hvac_time_step = "HVAC System Timestep"
      timestep = hourly_time_step
      env_period = openstudio_sql_file.availableEnvPeriods[0]
      #puts openstudio_sql_file.class
      #puts env_period.class
      #puts timestep.class
      #puts variable_name.class
      #puts key_value.class
      key_value = key_value.upcase  #upper cases the key_value b/c it is always uppercased in the sql file.
      #timestep = timestep.capitalize  #capitalize the timestep b/c it is always capitalized in the sql file
      #timestep = timestep.split(" ").each{|word| word.capitalize!}.join(" ")
      #returns an array of all keyValues matching the variable name, envPeriod, and reportingFrequency
      #we'll use this to check if the query will work before we send it.
      puts "*#{env_period}*#{timestep}*#{variable_name}"
      time_series_array = []
      puts env_period.class
      if env_period.nil?

        time_series_array = [nil]
        return time_series_array
      end
      possible_env_periods = openstudio_sql_file.availableEnvPeriods()
      if possible_env_periods.nil?
        time_series_array = [nil]
        return time_series_array
      end
      possible_timesteps = openstudio_sql_file.availableReportingFrequencies(env_period)
      if possible_timesteps.nil?
        time_series_array = [nil]
        return time_series_array
      end
      possible_variable_names = openstudio_sql_file.availableVariableNames(env_period,timestep)
      if possible_variable_names.nil?
        time_series_array = [nil]
        return time_series_array
      end
      possible_key_values = openstudio_sql_file.availableKeyValues(env_period,timestep,variable_name)
      if possible_key_values.nil?
        time_series_array = [nil]
        return time_series_array
      end

      if possible_key_values.include? key_value and
          possible_variable_names.include? variable_name and
          possible_env_periods.include? env_period and
          possible_timesteps.include? timestep
        #the query is valid
        time_series = openstudio_sql_file.timeSeries(env_period, timestep, variable_name, key_value)
        if time_series #checks to see if time_series exists
          time_series = time_series.get.values
          debug_puts "  #{key_value} time series length = #{time_series.size}"
          for i in 0..(time_series.size - 1)
            #puts "#{i.to_s} -- #{time_series[i]}"
            time_series_array << time_series[i]
          end
        end
      else
        #do this if the query is not valid.  The comments might help troubleshoot.
        time_series_array = [nil]
        debug_puts "***The pieces below do NOT make a valid query***"
        debug_puts "  *#{key_value}* - this key value might not exist for the variable you are looking for"
        debug_puts "  *#{timestep}* - this value should be Hourly, Monthly, Zone Timestep, HVAC System Timestep, etc"
        debug_puts "  *#{variable_name}* - every word should be capitalized EG:  Refrigeration System Total Compressor Electric Energy "
        debug_puts "  *#{env_period}* - you can get an array of all the valid env periods by using the sql_file.availableEnvPeriods() method "
        debug_puts "  Possible key values: #{possible_key_values}"
        debug_puts "  Possible Variable Names: #{possible_variable_names}"
        debug_puts "  Possible run periods:  #{possible_env_periods}"
        debug_puts "  Possible timesteps:  #{possible_timesteps}"
      end
      return time_series_array
    end

    #gets the average of the numbers in an array
    def non_zero_array_average(arr)
      debug_puts "average of the entire array = #{arr.inject{ |sum, el| sum + el }.to_f / arr.size}"
      arr.delete(0)
      debug_puts "average of the non-zero numbers in the array = #{arr.inject{ |sum, el| sum + el }.to_f / arr.size}"
      return arr.inject{ |sum, el| sum + el }.to_f / arr.size
    end

    #method for converting from IP to SI if you know the strings of the input and the output
    def ip_to_si(number, ip_unit_string, si_unit_string)
      ip_unit = OpenStudio::createUnit(ip_unit_string, "IP".to_UnitSystem).get
      si_unit = OpenStudio::createUnit(si_unit_string, "SI".to_UnitSystem).get
      #puts "#{ip_unit} --> #{si_unit}"
      ip_quantity = OpenStudio::Quantity.new(number, ip_unit)
      si_quantity = OpenStudio::convert(ip_quantity, si_unit).get
      #puts "#{ip_quantity} = #{si_quantity}"
      return si_quantity.value
    end

    def self.compile_qaqc_results(output_folder)
      full_json = []
      Dir.foreach("#{output_folder}") do |folder|
        next if folder == '.' or folder == '..'
        Dir.glob("#{output_folder}/#{folder}/qaqc.json") { |item|
          puts "Reading #{output_folder}/#{folder}/qaqc.json"
          json = JSON.parse(File.read(item))
          json['eplusout_err']['warnings'] = json['eplusout_err']['warnings'].size
          json['eplusout_err']['severe'] = json['eplusout_err']['warnings'].size
          json['eplusout_err']['fatal'] = json['eplusout_err']['warnings'].size
          json['run_uuid'] = SecureRandom.uuid
          bldg = json['building']['name'].split('-')
          json['building_type'] = bldg[1]
          json['template'] = bldg[0]
          full_json << json
        }
      end
      File.open("#{output_folder}/../RESULTS-#{Time.now.strftime("%m-%d-%Y")}.json", 'w') {|f| f.write(JSON.pretty_generate(full_json)) }
    end

    def self.compare_osm_files(model_true, model_compare)
      only_model_true = [] # objects only found in the true model
      only_model_compare = [] # objects only found in the compare model
      both_models = [] # objects found in both models
      diffs = [] # differences between the two models
      num_ignored = 0 # objects not compared because they don't have names

      # Define types of objects to skip entirely during the comparison
      object_types_to_skip = [
          'OS:EnergyManagementSystem:Sensor', # Names are UIDs
          'OS:EnergyManagementSystem:Program', # Names are UIDs
          'OS:EnergyManagementSystem:Actuator', # Names are UIDs
          'OS:Connection', # Names are UIDs
          'OS:PortList', # Names are UIDs
          'OS:Building', # Name includes timestamp of creation
          'OS:ModelObjectList' # Names are UIDs
      ]

      # Find objects in the true model only or in both models
      model_true.getModelObjects.sort.each do |true_object|

        # Skip comparison of certain object types
        next if object_types_to_skip.include?(true_object.iddObject.name)

        # Skip comparison for objects with no name
        unless true_object.iddObject.hasNameField
          num_ignored += 1
          next
        end

        # Find the object with the same name in the other model
        compare_object = model_compare.getObjectByTypeAndName(true_object.iddObject.type, true_object.name.to_s)
        if compare_object.empty?
          only_model_true << true_object
        else
          both_models << [true_object, compare_object.get]
        end
      end

      # Report a diff for each object found in only the true model
      only_model_true.each do |true_object|
        diffs << "A #{true_object.iddObject.name} called '#{true_object.name}' was found only in the before model"
      end

      # Find objects in compare model only
      model_compare.getModelObjects.sort.each do |compare_object|

        # Skip comparison of certain object types
        next if object_types_to_skip.include?(compare_object.iddObject.name)

        # Skip comparison for objects with no name
        unless compare_object.iddObject.hasNameField
          num_ignored += 1
          next
        end

        # Find the object with the same name in the other model
        true_object = model_true.getObjectByTypeAndName(compare_object.iddObject.type, compare_object.name.to_s)
        if true_object.empty?
          only_model_compare << compare_object
        end
      end

      # Report a diff for each object found in only the compare model
      only_model_compare.each do |compare_object|
        #diffs << "An object called #{compare_object.name} of type #{compare_object.iddObject.name} was found only in the compare model"
        diffs << "A #{compare_object.iddObject.name} called '#{compare_object.name}' was found only in the after model"
      end

      # Compare objects found in both models field by field
      both_models.each do |b|
        true_object = b[0]
        compare_object = b[1]
        idd_object = true_object.iddObject

        true_object_num_fields = true_object.numFields
        compare_object_num_fields = compare_object.numFields

        # loop over fields skipping handle
        (1...[true_object_num_fields, compare_object_num_fields].max).each do |i|

          field_name = idd_object.getField(i).get.name

          # Don't compare node, branch, or port names because they are populated with IDs
          next if field_name.include?('Node Name')
          next if field_name.include?('Branch Name')
          next if field_name.include?('Inlet Port')
          next if field_name.include?('Outlet Port')
          next if field_name.include?('Inlet Node')
          next if field_name.include?('Outlet Node')
          next if field_name.include?('Port List')
          next if field_name.include?('Cooling Control Zone or Zone List Name')
          next if field_name.include?('Heating Control Zone or Zone List Name')
          next if field_name.include?('Heating Zone Fans Only Zone or Zone List Name')

          # Don't compare the names of schedule type limits
          # because they appear to be created non-deteministically
          next if field_name.include?('Schedule Type Limits Name')

          # Get the value from the true object
          true_value = ""
          if i < true_object_num_fields
            true_value = true_object.getString(i).to_s
          end
          true_value = "-" if true_value.empty?

          # Get the same value from the compare object
          compare_value = ""
          if i < compare_object_num_fields
            compare_value = compare_object.getString(i).to_s
          end
          compare_value = "-" if compare_value.empty?

          # Round long numeric fields
          true_value = true_value.to_f.round(5) unless true_value.to_f.zero?
          compare_value = compare_value.to_f.round(5) unless compare_value.to_f.zero?

          # Move to the next field if no difference was found
          next if true_value == compare_value

          # Report the difference
          diffs << "For #{true_object.iddObject.name} called '#{true_object.name}' field '#{field_name}': before model = #{true_value}, after model = #{compare_value}"

        end

      end

      return diffs
    end

  end #FileIO





end #BTAP