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
    stds_dir = File.expand_path(File.dirname(__FILE__))
    src_csv_dir = "#{stds_dir}/userdata_csv/*.csv"
    #csv_files = []
    json_objs = {}
    Dir.glob(src_csv_dir) do |csv_full_name|
      #csv_files << csv_file_name
      #json_obj = {}
      #json_obj[csv_file_name] = []
      json_rows = []
      csv_file_name = File.basename(csv_full_name, File.extname(csv_full_name))
      json_objs[csv_file_name] = json_rows
    end

    # Read all valid files in user_data_folder and load into json array
    unless user_data_path == ''
      Dir.glob("#{user_data_path}/*.csv") do |csv_full_name|
        csv_file_name = File.basename(csv_full_name, File.extname(csv_full_name))
        if json_objs.has_key?(csv_file_name)
          # Load csv file into array of hashes
          # csv_full_name = "#{user_data_path}/#{csv_file_name}"
          json_rows = CSV.foreach(csv_full_name, headers: true).map{ |row| row.to_h }
          #csv_data = CSV.read(csv_full_name, headers:true)
          next if json_rows.size == 0
          #json_rows = []
          #csv_data.each do |row|
          #  json_rows << row
          #end
          # remove file extension
          file_name = File.basename(csv_full_name, File.extname(csv_full_name))
          json_objs[file_name] = json_rows
        end
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

end
