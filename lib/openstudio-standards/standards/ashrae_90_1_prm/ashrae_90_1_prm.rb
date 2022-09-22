require 'csv'

# This abstract class holds methods that many versions of ASHRAE 90.1 share.
# If a method in this class is redefined by a subclass,
# the implementation in the subclass is used.
# @abstract
class ASHRAE901PRM < Standard
  def initialize
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end

  # Convert user data csv files to json format and save to project folder
  # Method will create the json_folder in the project_path
  # @author Doug Maddox, PNNL
  # @param user_data_folder [string] path to folder containing csv files
  # @param project_folder [string] path to project folder
  # @return [string] path to json files
  def convert_userdata_csv_to_json(user_data_path, project_path)
    # Get list of possible files from lib\openstudio-standards\standards\ashrae_90_1_prm\userdata_csv
    stds_dir = __dir__
    src_csv_dir = "#{stds_dir}/userdata_csv/*.csv"
    json_objs = {}
    Dir.glob(src_csv_dir) do |csv_full_name|
      json_rows = []
      csv_file_name = File.basename(csv_full_name, File.extname(csv_full_name))
      json_objs[csv_file_name] = json_rows
    end

    # Read all valid files in user_data_folder and load into json array
    unless user_data_path == ''
      user_data_validation_outcome = true
      Dir.glob("#{user_data_path}/*.csv") do |csv_full_name|
        csv_file_name = File.basename(csv_full_name, File.extname(csv_full_name))
        if json_objs.key?(csv_file_name)
          # Load csv file into array of hashes
          json_rows = CSV.foreach(csv_full_name, headers: true).map { |row| user_data_preprocessor(row) }
          next if json_rows.empty?

          # validate the user_data in json_rows
          unless user_data_validation(csv_file_name, json_rows)
            user_data_validation_outcome = false
          end

          # remove file extension
          file_name = File.basename(csv_full_name, File.extname(csv_full_name))
          json_objs[file_name] = json_rows
        end
      end
      unless user_data_validation_outcome
        terminate_prm_write_log('Error found in the user data. Check output log to see detail error messages', project_path, false)
      end
    end

    # Make folder for json files; remove pre-existing first, if needed
    json_path = "#{project_path}/user_data_json"
    if !Dir.exist?(json_path)
      Dir.mkdir(json_path)
    else
      FileUtils.rm_rf(json_path)
      Dir.mkdir(json_path)
    end

    # Write all json files
    json_objs.each do |file_name, json_rows|
      json_obj = {}
      json_obj[file_name] = json_rows
      json_path_file = "#{json_path}/#{file_name}.json"
      File.open(json_path_file, 'w:UTF-8') do |file|
        file << JSON.pretty_generate(json_obj)
      end
    end

    return json_path
  end

  # Load user data from project folder into standards database data structure
  # Each user data object type is a new item in the @standards_data hash
  # @author Doug Maddox, PNNL
  # @param json_path [string] path to folder containing json files
  def load_userdata_to_standards_database(json_path)
    files = Dir.glob("#{json_path}/*.json").select { |e| File.file? e }
    files.each do |file|
      data = JSON.parse(File.read(file))
      data.each_pair do |key, objs|
        # Override the template in inherited files to match the instantiated template
        if @standards_data[key].nil?
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.standard', "Adding #{key} from #{File.basename(file)}")
        else
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.standard', "Overriding #{key} with #{File.basename(file)}")
        end
        @standards_data[key] = objs
      end
    end
  end

  # Perform user data preprocessing
  # @param [CSV::ROW] row 2D array for each row.
  def user_data_preprocessor(row)
    new_array = []

    # Strip the strings in the value
    row.each do |sub_array|
      new_array << sub_array.collect { |e| e ? e.strip : e }
    end
    # TODO: Future expansion can added to here.
    # Convert the 2d array to hash
    return new_array.to_h
  end

  # Perform user data validation

  # @param object_name [String] name of user data csv file to check
  # @param user_data [Hash] hash of data from user data csv file

  # @return [Boolean] true if data is valid, false if error found
  def user_data_validation(object_name, user_data)
    # 1. Check user_spacetype and user_space LPD total % = 1.0
    case object_name
    when 'userdata_space', 'userdata_spacetype'
      return check_userdata_space_and_spacetype(object_name, user_data)
    when 'user_electric_equipment'
      return check_userdata_electric_equipment(object_name, user_data)
    else
      return true
    end
  end

  # Check for incorrect data in electric equipment user data

  # @param object_name [String] name of user data csv file to check
  # @param user_data [Hash] hash of data from user data csv file

  # @return [Boolean] true if data is valid, false if error found
  def check_userdata_electric_equipment(object_name, user_data)
    userdata_valid = true
    user_data.each do |electric_row|
      if electric_row['motor_horsepower'].nil? || electric_row['motor_efficiency'].nil? || electric_row['motor_is_exempt'].nil?
        unless electric_row['motor_horsepower'].nil? && electric_row['motor_efficiency'].nil? && electric_row['motor_is_exempt'].nil?
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: One or more motor data are not available for electric equipment #{electric_row['name']}. motor_horsepower: #{electric_row['motor_horsepower']}; motor_efficiency: #{electric_row['motor_efficiency']}; motor_is_exempt: #{electric_row['motor_is_exempt']}")
        end
      else
        # check for data type
        if electric_row['motor_horsepower'].to_f == 0.0
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: Motor #{electric_row['name']}'s horsepower data is either 0.0 or unavailable. Check the inputs.")
        end
        if electric_row['motor_efficiency'].to_f == 0.0
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: Motor #{electric_row['name']}'s efficiency data is either 0.0 or unavailable. Check the inputs.")
        end
        if electric_row['motor_is_exempt'].casecmp?('yes') || electric_row['motor_is_exempt'].casecmp?('no')
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: Motor #{electric_row['name']} is exempt data should be either Yes or No. But get data #{electric_row['motor_is_exempt']}")
        end
      end
      # We may need to do the same for refrigeration and elevator?
      # Check elevator
      if electric_row['elevator_weight_of_car'].nil? || electric_row['elevator_rated_load'].nil? || electric_row['elevator_counter_weight_of_car'].nil? || electric_row['elevator_speed_of_car'].nil? || electric_row['elevator_number_of_stories'].nil?
        if electric_row['elevator_weight_of_car'].nil? && electric_row['elevator_rated_load'].nil? && electric_row['elevator_counter_weight_of_car'].nil? && electric_row['elevator_speed_of_car'].nil? && electric_row['elevator_number_of_stories'].nil?
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: One or more elevator data is not available for electric equipment #{electric_row['name']}. elevator_weight_of_car: #{electric_row['elevator_weight_of_car']}; elevator_rated_load: #{electric_row['elevator_rated_load']}; elevator_counter_weight_of_car: #{electric_row['elevator_counter_weight_of_car']}; elevator_speed_of_car: #{electric_row['elevator_speed_of_car']}; elevator_number_of_stories: #{electric_row['elevator_number_of_stories']}")
        end
      else
        # check for data type
        if electric_row['elevator_weight_of_car'].to_f == 0.0
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: Elevator #{electric_row['name']}'s weight of car data is either 0.0 or unavailable. Check the inputs.")
        end
        if electric_row['elevator_rated_load'].to_f == 0.0
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: Elevator #{electric_row['name']}'s rated load data is either 0.0 or unavailable. Check the inputs.")
        end
        if electric_row['elevator_counter_weight_of_car'].to_f == 0.0
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: Elevator #{electric_row['name']}'s counter weight of car data is either 0.0 or unavailable. Check the inputs.")
        end
        if electric_row['elevator_speed_of_car'].to_f == 0.0
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: Elevator #{electric_row['name']}'s speed of car data is either 0.0 or unavailable. Check the inputs.")
        end
        if electric_row['elevator_number_of_stories'].to_i > 1
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: Elevator #{electric_row['name']}'s serves number of stories data is either smaller or equal to 1 or unavailable. Check the inputs.")
        end
      end
      # Check refrigeration
      if electric_row['refrigeration_equipment_class'].nil? || electric_row['refrigeration_equipment_volume'].nil? || electric_row['refrigeration_equipment_total_display_area'].nil?
        if electric_row['refrigeration_equipment_class'].nil? && electric_row['refrigeration_equipment_volume'].nil? && electric_row['refrigeration_equipment_total_display_area'].nil?
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: One or more refrigeration data is not available for electric equipment #{electric_row['name']}. refrigeration_equipment_class: #{electric_row['refrigeration_equipment_class']}; refrigeration_equipment_volume: #{electric_row['refrigeration_equipment_volume']}; refrigeration_equipment_total_display_area: #{electric_row['refrigeration_equipment_total_display_area']}")
        end
      else
        # Check data type
        # The equipment class shall be verified at the implementation level
        if electric_row['refrigeration_equipment_volume'].to_f == 0.0
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: Refrigeration #{electric_row['name']}'s equipment volume data is either 0.0 or unavailable. Check the inputs.")
        end
        if electric_row['refrigeration_equipment_total_display_area'].to_f == 0.0
          userdata_valid = false
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data: #{object_name}: Refrigeration #{electric_row['name']}'s total display area data is either 0.0 or unavailable. Check the inputs.")
        end
      end
    end
    return userdata_valid
  end

  # Check for incorrect data in space and spacetype user data

  # @param object_name [String] name of user data csv file to check
  # @param user_data [Hash] hash of data from user data csv file

  # @return [Boolean] true if data is valid, false if error found
  def check_userdata_space_and_spacetype(object_name, user_data)
    userdata_valid = true
    user_data.each do |lpd_row|
      unless lpd_row['num_std_ltg_types'].to_i == 0
        num_ltg_type = lpd_row['num_std_ltg_types'].to_i
        total_ltg_percent = 0.0
        std_ltg_index = 0
        while std_ltg_index < num_ltg_type
          frac_key = format('std_ltg_type_frac%02d', (std_ltg_index + 1))
          total_ltg_percent += lpd_row[frac_key].to_f
          std_ltg_index += 1
        end
        if (total_ltg_percent - 1.0).abs > 0.01
          OpenStudio.logFree(OpenStudio::Error, 'User Data Error', "User data #{object_name}: The fraction of user defined lighting types in Space/SpaceType: #{lpd_row['name']} does not add up to 1.0. The calculated fraction is #{total_ltg_percent}.")
          userdata_valid = false
        end
      end
    end
    return userdata_valid
  end
end
