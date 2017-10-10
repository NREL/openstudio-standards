# This script reads OpenStudio_standards.xlsx
# and creates a JSON file containing all the information

require 'rubygems'
require 'json'
require 'rubyXL'

class String

  def snake_case
    downcase.gsub(' ', '_').gsub('-', '_')
  end

end

# Convert OpenStudio_Standards.xlsx to a series
# of JSON files for easier consumption.
class Hash
  
  def sort_by_key_updated(recursive = false, &block)
    self.keys.sort(&block).reduce({}) do |seed, key|
      seed[key] = self[key]
      if recursive && seed[key].is_a?(Hash)
        seed[key] = seed[key].sort_by_key(true, &block)
      elsif recursive && seed[key].is_a?(Array) && seed[key][0].is_a?(Hash)
        # Sort logic depends on the tab
        frst = seed[key][0]
        if key == 'space_types' # Don't have names
          seed[key] = seed[key].sort_by { |hsh| [ hsh['template'], hsh['climate_zone_set'], hsh['building_type'], hsh['space_type'] ] }
        elsif key == 'schedules' # Names are not unique, sort by name then day types
          seed[key] = seed[key].sort_by { |hsh| [ hsh['name'], hsh['start_date'], hsh['day_types'] ] }
        elsif key == 'construction_sets'
          # Replace nil values with 'zzzz' temorarily for sorting
          seed[key].each do |item|
            item.keys.each do |key2|
              if item[key2].nil?
                item[key2] = 'zzzz'
              end
            end
          end
          seed[key] = seed[key].sort_by { |hsh| [ hsh['template'], hsh['building_type'], hsh['climate_zone_set'], hsh['space_type'], hsh['exterior_walls'], hsh['exterior_roofs'], hsh['exterior_floors'] ] }
          # Replace 'zzzz' back to nil        
          seed[key].each do |item|
            item.keys.each do |key2|
              if item[key2] == 'zzzz'
                item[key2] = nil
              end
            end
          end
        elsif frst.has_key?('name') # For all other tabs, names should be unique
          seed[key] = seed[key].sort_by { |hsh| hsh['name'] }  
        else
          seed[key] = seed[key]
        end
      end
      seed
    end
  end
 
end

# Downloads the OpenStudio_Standards.xlsx
# from Google Drive
# @note This requires you to have a client_secret.json file saved in your
# username/.credentials folder.  To get one of these files, please contact
# andrew.parker@nrel.gov
def download_google_spreadsheet

  require 'google/api_client'
  require 'google/api_client/client_secrets'
  require 'google/api_client/auth/installed_app'
  require 'google/api_client/auth/storage'
  require 'google/api_client/auth/storages/file_store'
  require 'fileutils'

  #APPLICATION_NAME = 'openstudio-standards'
  #CLIENT_SECRETS_PATH = 'client_secret_857202529887-mlov2utaq9apq699789gh4o1f9u2eipr.apps.googleusercontent.com.json'

  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization request via InstalledAppFlow.
  # If authorization is required, the user's default browser will be launched
  # to approve the request.
  #
  # @return [Signet::OAuth2::Client] OAuth2 credentials
  def authorize(credentials_path, client_secret_path)
    FileUtils.mkdir_p(File.dirname(credentials_path))

    file_store = Google::APIClient::FileStore.new(credentials_path)
    storage = Google::APIClient::Storage.new(file_store)
    auth = storage.authorize

    if auth.nil? || (auth.expired? && auth.refresh_token.nil?)
      app_info = Google::APIClient::ClientSecrets.load(client_secret_path)
      flow = Google::APIClient::InstalledAppFlow.new({
        :client_id => app_info.client_id,
        :client_secret => app_info.client_secret,
        :scope => 'https://www.googleapis.com/auth/drive'})
      auth = flow.authorize(storage)
      puts "Credentials saved to #{credentials_path}" unless auth.nil?
    end
    auth
  end

  ##
  # Download a file's content
  #
  # @param [Google::APIClient] client
  #   Authorized client instance
  # @param [Google::APIClient::Schema::Drive::V2::File]
  #   Drive File instance
  # @return 
  #   File's content if successful, nil otherwise
  def download_xlsx_spreadsheet(client, google_spreadsheet, path)
    file_name = google_spreadsheet.title
    export_url = google_spreadsheet.export_links['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
    #export_url = google_spreadsheet.export_links['text/csv']
    if export_url
      result = client.execute(:uri => export_url)
      if result.status == 200
        File.open(path, "wb") do |f|
          f.write(result.body)
        end
        puts "Successfully downloaded #{file_name} to .xlsx"
        return true
      else
        puts "An error occurred: #{result.data['error']['message']}"
        return false
      end
    else
      puts "#{file_name} can't be downloaded as an .xlsx file."
      return false
    end
  end

  # Initialize the API
  client_secret_path = File.join(Dir.home, '.credentials',"client_secret.json")
	
  credentials_path = File.join(Dir.home, '.credentials',"openstudio-standards-google-drive.json")
  client = Google::APIClient.new(:application_name => 'openstudio-standards')
  client.authorization = authorize(credentials_path, client_secret_path)
  drive_api = client.discovered_api('drive', 'v2')

  # List the 100 most recently modified files.
  results = client.execute!(
    :api_method => drive_api.files.list,
    :parameters => { :maxResults => 100 })
  puts "No files found" if results.data.items.empty?

  # Find the OpenStudio_Standards google spreadsheet
  # and save it.
  results.data.items.each do |file|
    if file.title == 'OpenStudio_Standards'
      puts "Found OpenStudio_Standards"
      download_xlsx_spreadsheet(client, file, "#{File.dirname(__FILE__)}/OpenStudio_Standards.xlsx")
    end
  end

end

def export_spreadsheet_to_json

  # Path to the xlsx file
  xlsx_path = "#{File.dirname(__FILE__)}/OpenStudio_Standards.xlsx"

  # List of worksheets to skip
  worksheets_to_skip = []
  worksheets_to_skip << 'ventilation'
  worksheets_to_skip << 'occupancy'
  worksheets_to_skip << 'interior_lighting'
  worksheets_to_skip << 'lookups'
  worksheets_to_skip << 'sheetmap'
  worksheets_to_skip << 'deer_lighting_fractions'
  
  # List of columns to skip
  cols_to_skip = []
  cols_to_skip << 'lookup'
  cols_to_skip << 'lookupcolumn'
  cols_to_skip << 'vlookupcolumn'
  cols_to_skip << 'osm_lighting_per_person'
  cols_to_skip << 'osm_lighting_per_area'
  cols_to_skip << 'lighting_per_length'
  # cols_to_skip << 'lighting_fraction_to_return_air'
  # cols_to_skip << 'lighting_fraction_radiant'
  # cols_to_skip << 'lighting_fraction_visible'
  # cols_to_skip << 'gas_equipment_fraction_latent'
  # cols_to_skip << 'gas_equipment_fraction_radiant'
  # cols_to_skip << 'gas_equipment_fraction_lost'
  # cols_to_skip << 'electric_equipment_fraction_latent'
  # cols_to_skip << 'electric_equipment_fraction_radiant'
  # cols_to_skip << 'electric_equipment_fraction_lost'
  # cols_to_skip << 'service_water_heating_peak_flow_rate'
  # cols_to_skip << 'service_water_heating_area'
  # cols_to_skip << 'service_water_heating_peak_flow_per_area'
  # cols_to_skip << 'service_water_heating_target_temperature'
  # cols_to_skip << 'service_water_heating_fraction_sensible'
  # cols_to_skip << 'service_water_heating_fraction_latent'
  # cols_to_skip << 'service_water_heating_schedule'
  # cols_to_skip << 'exhaust_per_area'
  cols_to_skip << 'exhaust_per_unit'
  cols_to_skip << 'exhaust_fan_power_per_area'
  
  # List of columns that are boolean
  # (rubyXL returns 0 or 1, will translate to true/false)
  bool_cols = []
  bool_cols << 'hx'  
  
  # Open workbook
  workbook = RubyXL::Parser.parse(xlsx_path)

  # Loop through and export each tab to a separate JSON file
  workbook.worksheets.each do |worksheet|
    sheet_name = worksheet.sheet_name.snake_case

    standards_data = {}
    
    # Skip the specified worksheets
    if worksheets_to_skip.include?(sheet_name)
      puts "Skipping #{sheet_name}"
      next
    else
      puts "Exporting #{sheet_name}"
    end
    
    # All spreadsheets must have headers in row 3
    # and data from roworksheet 4 onward.
    header_row = 2 # Base 0

    # Get all data
    all_data = worksheet.extract_data

    # Get the header row data
    header_data = all_data[header_row]

    # Format the headers and parse out units (in parentheses)
    headers = []
    header_data.each do |header_string|
      break if header_string.nil?
      header = {}
      header["name"] = header_string.gsub(/\(.*\)/,'').strip.snake_case
      header_unit_parens = header_string.scan(/\(.*\)/)[0]
      if header_unit_parens.nil?
        header["units"] = nil
      else
        header["units"] = header_unit_parens.gsub(/\(|\)/,'').strip
      end
      headers << header
    end
    puts "--found #{headers.size} columns"
    
    # Loop through all rows and export
    # data for the row to a hash.
    objs = []
    for i in (header_row + 1)..(all_data.size - 1)
      row = all_data[i]
      # Stop when reach a blank row
      break if row.nil?
      # puts "------row #{i} = #{row}"
      obj = {}
      # Check if all cells in the row are null
      all_null = true
      for j in 0..headers.size - 1
        val = row[j]
        # Don't record nil values
        # next if val.nil?
        # Flip the switch if a value is found
        unless val.nil?
          all_null = false
        end
        # Skip specified columns
        next if cols_to_skip.include?(headers[j]['name'])
        # Convert specified columns to boolean
        if bool_cols.include?(headers[j]['name'])
          if val == 1
            val = true
          elsif val == 0
            val = false
          else
            val = nil
          end
        end
        # Record the value
        obj[headers[j]['name']] = val
        # Skip recording units for unitless values
        next if headers[j]['units'].nil?
        # Record the units
        # obj["#{headers[j]['name']}_units"] = headers[j]['units']
      end

      # Skip recording empty rows
      next if all_null == true

      # Store the array of objects
      # special cases for some types
      if sheet_name == 'climate_zone_sets'
        new_obj = {}
        new_obj['name'] = obj['name']
        items = []
        obj.each do |key, val2|
          # Skip the key
          next if key == 'name'
          # Skip blank climate zone values
          next if val2.nil?
          items << val2
        end
        new_obj['climate_zones'] = items
        objs << new_obj
      elsif sheet_name == 'constructions'
        new_obj = {}
        new_obj['name'] = obj['name']
        items = []
        obj.each do |key, val2|
          # Skip the key
          next if key == 'name'
          # Put materials into an array,
          # record other fields normally
          if key.include?('material')
            # Skip blank material values
            next if val2.nil?
            items << val2
          else
            new_obj[key] = val2
          end
        end
        new_obj['materials'] = items
        objs << new_obj
      elsif sheet_name == 'schedules'
        new_obj = {}
        new_obj['name'] = obj['name']
        items = []
        obj.each do |key, val2|
          # Skip the key
          next if key == 'name'
          # Put materials into an array,
          # record other fields normally
          if key.include?('hr')
            # Skip blank hourly values
            next if val2.nil?
            items << val2
          else
            new_obj[key] = val2
          end
        end
        new_obj['values'] = items
        objs << new_obj
      else
        objs << obj
      end

    end
          
    # Report how many objects were found
    puts "--found #{objs.size} rows"
    
    # Save this hash 
    standards_data[sheet_name] = objs

    # Sort the standard data so it can be diffed easily
    sorted_standards_data = standards_data.sort_by_key_updated(true) {|x,y| x.to_s <=> y.to_s}

    # Write the hash to a JSON file
    File.open("#{File.dirname(__FILE__)}/OpenStudio_Standards_#{sheet_name}.json", 'w:UTF-8') do |file|
      file << JSON::pretty_generate(sorted_standards_data)
    end
    puts "Successfully generated OpenStudio_Standards_#{sheet_name}.json"    
    
    
  end

end
