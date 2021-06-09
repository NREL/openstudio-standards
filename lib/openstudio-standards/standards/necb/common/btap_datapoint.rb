require 'openstudio'
require 'openstudio-standards'
require 'aws-sdk'
require 'securerandom'
require 'optparse'
require 'yaml'
require 'git-revision'
resource_folder = File.join(__dir__, '..', '..', 'measures/btap_results/resources')
require_relative File.join(__dir__, 'btap_data.rb')
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

class BTAPDatapoint
  def initialize(input_folder: nil,
                 output_folder: nil,
                 input_folder_cache: File.join(__dir__, 'input_cache')
  )
    @failed = false

    #set default input folder.
    if input_folder.nil?
      input_folder = File.join(__dir__, 'input')
    end
    if output_folder.nil?
      output_folder = File.join(__dir__, 'output')
    end

    puts("INPUT FOLDER:#{input_folder}")
    puts("OUTPUT FOLDER:#{output_folder}")


    # Set local temp cache folders. These are created new for each datapoint.
    # Location of the datapoint input folder. Could be local, cloud, or VM host.
    @dp_input_folder = File.join(input_folder)
    # Location of temp folder, it is always local.
    @dp_temp_folder = File.join(__dir__, 'temp_folder')


    # Make sure temp folder is always clean.
    FileUtils.rm_rf(@dp_temp_folder) if Dir.exist?(@dp_temp_folder)
    FileUtils.mkdir_p(@dp_temp_folder)



    # Create local cache for datapoint folder. Makes everything faster an easier to have a local copy. Mirroring logic
    # even if running locally to be consistent.
    FileUtils.rm_rf(input_folder_cache) if Dir.exist?(input_folder_cache)
    FileUtils.mkdir_p(input_folder_cache)

    # Check if input where input is from.
    if @dp_input_folder.start_with?('s3:')
      # Lets dissect the information from the s3 path.
      m = @dp_input_folder.match(/s3:\/\/(.*?)\/(.*)/)
      @s3_bucket = m[1]
      @s3_input_folder_object = m[2]
      m = output_folder.match(/s3:\/\/(.*?)\/(.*)/)
      @s3_output_folder_object = m[2]
      puts("s3_bucket:#{@s3_bucket}")
      puts("s3_input_folder_object:#{@s3_input_folder_object}")
      puts("s3_output_folder_object:#{@s3_output_folder_object}")

      self.s3_copy(source_folder: @dp_input_folder , target_folder: input_folder_cache )
    else
      if Dir.exist?(@dp_input_folder)
        puts @dp_input_folder
        puts input_folder_cache
        FileUtils.cp_r(File.join(@dp_input_folder,'.'), input_folder_cache)
      else
        raise("input folder dne:#{@dp_input_folder}")
      end
    end
    run_options_path = File.join(input_folder_cache, 'run_options.yml')
    if File.file?(run_options_path)
      @options = YAML.load_file(run_options_path)
    else
      raise("Could not read input from #{run_options_path}")
    end

    # Location of datapoint output folder. Could be local, cloud, or VM host.
    @dp_output_folder = File.join(output_folder, @options[:datapoint_id])

    # Show versions in yml file.
    @options[:btap_costing_git_revision] = Git::Revision.commit_short
    @options[:os_git_revision] = OpenstudioStandards::git_revision

    # Save configuration to temp folder.
    File.open(File.join(@dp_temp_folder, 'run_options.yml'), 'w') { |file| file.write(@options.to_yaml) }
    begin

      #set up basic model.
      # This dynamically creates a class by string using the factory method design pattern.
      @standard = Standard.build(@options[:template])

      # This allows you to select the skeleton model from our built in starting points. You can add a custom file as
      # it will search the libary first,.
      #model = load_osm(@options[:building_type]) # loads skeleton file from path.
      model = @standard.load_building_type_from_library(building_type: @options[:building_type])
      if false == model
        osm_model_path = File.absolute_path(File.join(input_folder, @options[:building_type] + ".osm"))
        raise("File #{osm_model_path} not found") unless File.exists?(osm_model_path)
        model = BTAP::FileIO::load_osm(osm_model_path)
      end
      @standard.model_apply_standard(model: model,
                                     epw_file: @options[:epw_file],
                                     sizing_run_dir: File.join(@dp_temp_folder, 'sizing_folder'),
                                     primary_heating_fuel: @options[:primary_heating_fuel],
                                     dcv_type: @options[:dcv_type], # Four options: @options[: (1) 'NECB_Default', (2) 'No DCV', (3) 'Occupancy-based DCV' , (4) 'CO2-based DCV'
                                     lights_type: @options[:lights_type], # Two options: @options[: (1) 'NECB_Default', (2) 'LED'
                                     lights_scale: @options[:lights_scale],
                                     daylighting_type: @options[:daylighting_type], # Two options: @options[: (1) 'NECB_Default', (2) 'add_daylighting_controls'
                                     ecm_system_name: @options[:ecm_system_name],
                                     erv_package: @options[:erv_package],
                                     boiler_eff: @options[:boiler_eff],
                                     # Inconsistent naming Todo Chris K.
                                     unitary_cop: @options[:adv_dx_units],
                                     furnace_eff: @options[:furnace_eff],
                                     shw_eff: @options[:shw_eff],
                                     ext_wall_cond: @options[:ext_wall_cond],
                                     ext_floor_cond: @options[:ext_floor_cond],
                                     ext_roof_cond: @options[:ext_roof_cond],
                                     ground_wall_cond: @options[:ground_wall_cond],
                                     ground_floor_cond: @options[:ground_floor_cond],
                                     ground_roof_cond: @options[:ground_roof_cond],
                                     door_construction_cond: @options[:door_construction_cond],
                                     fixed_window_cond: @options[:fixed_window_cond],
                                     glass_door_cond: @options[:glass_door_cond],
                                     overhead_door_cond: @options[:overhead_door_cond],
                                     skylight_cond: @options[:skylight_cond],
                                     glass_door_solar_trans: @options[:glass_door_solar_trans],
                                     fixed_wind_solar_trans: @options[:fixed_wind_solar_trans],
                                     skylight_solar_trans: @options[:skylight_solar_trans],
                                     fdwr_set: @options[:fdwr_set],
                                     srr_set: @options[:srr_set],
                                     rotation_degrees: @options[:rotation_degrees],
                                     scale_x: @options[:scale_x],
                                     scale_y: @options[:scale_y],
                                     scale_z: @options[:scale_z],
                                     pv_ground_type: @options[:pv_ground_type],
                                     pv_ground_total_area_pv_panels_m2: @options[:pv_ground_total_area_pv_panels_m2],
                                     pv_ground_tilt_angle: @options[:pv_ground_tilt_angle],
                                     pv_ground_azimuth_angle: @options[:pv_ground_azimuth_angle],
                                     pv_ground_module_description: @options[:pv_ground_module_description],
                                     nv_type: @options[:nv_type],
                                     nv_opening_fraction: @options[:nv_opening_fraction],
                                     nv_temp_out_min: @options[:nv_temp_out_min],
                                     nv_delta_temp_in_out: @options[:nv_delta_temp_in_out],
                                     occupancy_loads_scale: @options[:occupancy_loads_scale],
                                     electrical_loads_scale: @options[:electrical_loads_scale],
                                     oa_scale: @options[:oa_scale],
                                     infiltration_scale: @options[:infiltration_scale],
                                     chiller_type: @options[:chiller_type]

      )

      # Save model to to disk.
      puts "saving model to #{File.join(@dp_temp_folder, 'output.osm')}"
      BTAP::FileIO::save_osm(model, File.join(@dp_temp_folder, 'output.osm'))

      # Run annual simulation of model.
      if @options[:run_annual_simulation]
        @run_dir = File.join(@dp_temp_folder, 'run_dir')
        puts "running simulation in #{@run_dir}"
        @standard.model_run_simulation_and_log_errors(model, @run_dir)

        #Create qaqc file and save it.
        @qaqc = @standard.init_qaqc(model)
        command = "SELECT Value
                  FROM TabularDataWithStrings
                  WHERE ReportName='LEEDsummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Sec1.1A-General Information'
                  AND RowName = 'Principal Heating Source'
                  AND ColumnName='Data'"
        value = model.sqlFile().get.execAndReturnFirstString(command)
        # make sure all the data are availalbe
        if value.empty?
          raise("Could not determine primary heating source from sql file #{@model.building.get.name.get}")
        else
          @qaqc[:building][:principal_heating_source] = value.get
          if value.get == "Additional Fuel"
            model.getPlantLoops.sort.each do |iplantloop|
              boilers = iplantloop.components.select { |icomponent| icomponent.to_BoilerHotWater.is_initialized }
              @qaqc[:building][:principal_heating_source] = "FuelOilNo2" unless boilers.select { |boiler| boiler.to_BoilerHotWater.get.fuelType.to_s == "FuelOilNo2" }.empty?
            end
          end
        end

        @qaqc[:aws_datapoint_id] = @options[:datapoint_id]
        @qaqc[:aws_analysis_id] = @options[:analysis_id]

        # Load the sql file into model
        sql_path = OpenStudio::Path.new(File.join(@run_dir, 'run/eplusout.sql'))
        if OpenStudio.exists(sql_path)
          sql = OpenStudio::SqlFile.new(sql_path)
          # Check to make sure the sql file is readable,
          # which won't be true if EnergyPlus crashed during simulation.
          unless sql.connectionOpen
            raise(OpenStudio::Error, 'openstudio.model.Model', "The run failed.  Look at the eplusout.err file in #{File.dirname(sql_path.to_s)} to see the cause.")
            return false
          end
          # Attach the sql file from the run to the sizing model
          model.setSqlFile(sql)
        else
          raise(OpenStudio::Error, 'openstudio.model.Model', "Results for the sizing run couldn't be found here: #{sql_path}.")
        end

        @cost_result = nil
        if @options[:enable_costing] == true
          # Perform costing
          costing = BTAPCosting.new()
          costing.load_database()
          @cost_result, @btap_items = costing.cost_audit_all(model: model, prototype_creator: @standard, template_type: @options[:template])
          @qaqc[:costing_information] = @cost_result
          File.open(File.join(@dp_temp_folder, 'cost_results.json'), 'w') { |f| f.write(JSON.pretty_generate(@cost_result, :allow_nan => true)) }
          puts "Wrote File cost_results.json in #{Dir.pwd()} "
        end


        @qaqc[:options] = @options # This is options sent on the command line
        #BTAPData
        @btap_data = BTAPData.new(model: model,
                                  runner: nil,
                                  cost_result: @cost_result,
                                  qaqc: @qaqc).btap_data


        # Write Files
        File.open(File.join(@dp_temp_folder, 'btap_data.json'), 'w') { |f| f.write(JSON.pretty_generate(@btap_data.sort.to_h, :allow_nan => true)) }
        puts "Wrote File btap_data.json in #{Dir.pwd()} "



        File.open(File.join(@dp_temp_folder, 'qaqc.json'), 'w') { |f| f.write(JSON.pretty_generate(@qaqc, :allow_nan => true)) }
        puts "Wrote File qaqc.json in #{Dir.pwd()} "
      end

    rescue StandardError => bang
      puts "Error occured: #{bang}"
      @bang = bang
      File.open(File.join(@dp_temp_folder, 'error.txt'), 'w') { |f| f.write(@bang.message + "\n" + @bang.backtrace.join("\n")) }
      @failed = true

    ensure # will always get executed


      if @dp_output_folder.start_with?('s3://')
        @dp_output_folder = File.join(@s3_output_folder_object, @options[:datapoint_id])
        self.s3_copy_folder_to_s3(bucket_name: @s3_bucket,
                             source_folder: @dp_temp_folder,
                             target_folder: @dp_output_folder)
      else
        # Copy results to datapoint output folder.
        @dp_output_folder = File.join(output_folder, @options[:datapoint_id])
        FileUtils.rm_rf(@dp_output_folder) if Dir.exist?(@dp_output_folder)
        FileUtils.mkdir_p(@dp_output_folder)
        FileUtils.cp_r(File.join(@dp_temp_folder,'.'), @dp_output_folder) # Needs dot otherwise will copy temp folder and not just contents.
        puts "Copied output to your designated output folder in the #{@options[:datapoint_id]} subfolder."
      end

      #clean temp/cache folder up.
      FileUtils.rm_rf(input_folder_cache)
      FileUtils.rm_rf(@dp_temp_folder)
      if @failed == true
        raise(@bang)
      end
    end

  end




  def s3_copy_file_to_s3( bucket_name:, source_file:, target_file:,n: 0)
    require 'aws-sdk-s3'
    s3_resource = Aws::S3::Resource.new(region: 'ca-central-1')

    puts("Copying File to S3. source_file:#{source_file} bucket:#{bucket_name} target_folder:#{target_file}")
    response = nil
    begin
      obj = s3_resource.bucket(bucket_name).object(target_file)

      #passing the TempFile object's path is massively faster than passing the TempFile object itself
      result = obj.upload_file(source_file)

      if result == true
        puts "Object '#{source_file}' uploaded to bucket '#{bucket_name}'."
      else
        puts response
        raise("Error:Object '#{source_file}' not uploaded to bucket '#{bucket_name}'.")
      end

    rescue StandardError => bang
      #Implementing exponential backoff
      # Tried 7 times.. give up.
      if n == 8
        raise("Giving Up. Failed to submit send file #{source_file} #{target_file} in 8 tries while using exponential backoff. Error was:#{bang}.")
      end
      # Exponential wait time
      wait_time = 2 ** n + rand()
      puts "Implementing exponential backoff for sending #{target_file} for #{wait_time}s. #{n}th try"
      sleep(wait_time)
      # Do recursive function.
      return self.s3_copy_file_to_s3(bucket_name: bucket_name, source_file: source_file, target_file: target_file, n: n + 1 )
    end
    return response
  end


  def s3_copy_folder_to_s3(bucket_name:,
                           source_folder:,
                           target_folder:)

    puts("Copying Folder to S3. source_folder:#{source_folder} bucket:#{bucket_name} target_folder:#{target_folder}")

    # Iterate over files in folder.
    Dir[File.join(source_folder,'**/*')].reject {|fn| File.directory?(fn) }.each do |source_file|
      # Convert to s3 path. Removing source parent folders and replacing with s3 output folder.
      target_file = File.join(target_folder, source_file.gsub(source_folder,''))
      self.s3_copy_file_to_s3(bucket_name: bucket_name,
                         source_file: source_file,
                         target_file: target_file)
    end
  end

  def s3_copy(source_folder:,
              target_folder:)
    require 'open3'
    exit_code = nil
    error = nil
    Open3.popen2e('aws', 's3', 'cp', source_folder, target_folder, '--recursive') do |stdin, stdout_stderr, wait_thread|
      error = stdout_stderr.read
      exit_code = wait_thread.value
    end
    if exit_code != 0
      raise(error)
    end
    return exit_code
  end

end




