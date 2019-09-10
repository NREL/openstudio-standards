# This script reads OpenStudio_standards.xlsx
# and creates a JSON file containing all the information

require 'json'
require 'rubyXL'
require 'csv'

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
        # Sort by the set of unique properties
        uniq_props = unique_properties(key)
        if uniq_props.size > 0
          # Temporarily replace real values with placeholders for sorting
          nil_placeholder = 'zzzz'
          true_placeholder = 'TRUETRUETRUE'
          false_placeholder = 'FALSEFALSEFALSE'
          seed[key].each do |item|
            item.keys.each do |key2|
              if item[key2].nil?
                item[key2] = nil_placeholder
              elsif [true].include?(item[key2])
                item[key2] = true_placeholder
              elsif [false].include?(item[key2])
                item[key2] = false_placeholder
              elsif item[key2].is_a?(String) && /(\d|\.)+E\d/.match(item[key2])
                # Replace scientific notation strings with floats
                item[key2] = item[key2].to_f
              end
            end
          end

          # Sort
          seed[key] = seed[key].sort_by do |hsh|
            sort_order = []
            uniq_props.each do |prop|
              if hsh.has_key?(prop)
                sort_order << hsh[prop]
              end
            end
            sort_order
          end

          # Replace placeholders with real values
          seed[key].each do |item|
            item.keys.each do |key2|
              if item[key2] == nil_placeholder
                item[key2] = nil
              elsif item[key2] == true_placeholder
                item[key2] = true
              elsif item[key2] == false_placeholder
                item[key2] = false
              end
            end
          end
        else
          seed[key] = seed[key]
        end
      end
      seed
    end
  end

end

# Defines the set of properties that should be unique across all objects of the same type.
# This set is used for checking for duplicate objects and for sorting objects in the JSON files.
def unique_properties(sheet_name)
  return case sheet_name
         when 'templates', 'standards', 'climate_zone_sets', 'constructions', 'curves', 'fans'
           ['name']
         when 'materials'
           ['name', 'code_category']
         when 'space_types', 'space_types_lighting', 'space_types_ventilation', 'space_types_occupancy', 'space_types_infiltration', 'space_types_equipment', 'space_types_thermostats', 'space_types_swh', 'space_types_exhaust'
           ['template', 'building_type', 'space_type']
         when 'exterior_lighting'
           ['exterior_lighting_zone_number', 'template']
         when 'schedules'
           ['name', 'day_types', 'start_date', 'end_date']
         when 'construction_properties'
           ['template', 'climate_zone_set', 'operation_type', 'intended_surface_type', 'standards_construction_type', 'building_category', 'orientation', 'minimum_percent_of_surface', 'maximum_percent_of_surface']
         when 'boilers'
           ['template', 'fluid_type', 'fuel_type', 'condensing', 'condensing_control', 'minimum_capacity', 'maximum_capacity', 'start_date', 'end_date']
         when 'chillers'
           ['template', 'cooling_type', 'condenser_type', 'compressor_type', 'absorption_type', 'variable_speed_drive', 'minimum_capacity', 'maximum_capacity', 'start_date', 'end_date']
         when 'heat_rejection'
           ['template', 'equipment_type', 'fan_type', 'start_date', 'end_date']
         when 'heat_pumps'
           ['template', 'cooling_type', 'heating_type', 'subcategory', 'minimum_capacity', 'maximum_capacity', 'start_date', 'end_date']
         when 'heat_pumps_heating'
           ['template', 'cooling_type', 'subcategory', 'minimum_capacity', 'maximum_capacity', 'start_date', 'end_date']
         when 'unitary_acs'
           ['template', 'cooling_type', 'heating_type', 'subcategory', 'minimum_capacity', 'maximum_capacity', 'start_date', 'end_date']
         when 'water_heaters'
           ['template', 'fuel_type', 'minimum_capacity', 'maximum_capacity', 'start_date', 'end_date']
         when 'elevators'
           ['template', 'building_type']
         when 'refrigeration_system_lineup', 'refrigeration_system'
           ['template', 'building_type', 'size_category', 'system_type']
         when 'refrigerated_cases'
           ['template', 'size_category', 'case_type', 'case_category']
         when 'refrigeration_condenser'
           ['template', 'building_type', 'system_type', 'size_category']
         when 'refrigeration_walkins'
           ['template', 'size_category', 'walkin_type']
         when 'refrigeration_compressors'
           ['template', 'compressor_name', 'compressor_type']
         when 'economizers'
           ['template', 'climate_zone', 'data_center']
         when 'motors'
           ['template', 'number_of_poles', 'type', 'synchronous_speed', 'minimum_capacity', 'maximum_capacity']
         when 'ground_temperatures'
           ['building_type', 'template', 'climate_zone']
         when 'hvac_inference'
           ['template', 'size_category', 'heating_source', 'cooling_source', 'delivery_type']
         when 'size_category'
           ['template', 'building_category', 'minimum_floors', 'maximum_floors', 'minimum_area', 'maximum_area']
         when 'construction_sets'
           ['template', 'building_type', 'space_type', 'is_residential']
         when 'parking', 'entryways'
           ['building_type']
         when 'prototype_inputs'
           ['template', 'building_type', 'hvac_system']
         when 'climate_zones'
           ['name', 'standard']
         else
           []
         end
end

# Determine the directory of the data based on the spreadsheet name
def standard_parent_directory_from_spreadsheet_title(spreadsheet_title)
  data_directory = spreadsheet_title.downcase.gsub('openstudio_standards-', '').gsub(/\(\w*\)/, '').split('-').first
  # puts "Extracting standard parent directory from spreadsheet title #{spreadsheet_title} = #{data_directory}"

  return data_directory
end

# Determine the directory name from the template
def standard_directory_name_from_template(template)
  directory_name = template.downcase.gsub(/\W/, '_').gsub('90_1', 'ashrae_90_1')
  # puts "Extracting standard directory from template #{template} = #{directory_name}"

  return directory_name
end

# Downloads the OpenStudio_Standards.xlsx
# from Google Drive
# @note This requires you to have a client_secret.json file saved in your
# username/.credentials folder.  To get one of these files, please contact
# andrew.parker@nrel.gov
def download_google_spreadsheets(spreadsheet_titles)

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
  client_secret_path = File.join(Dir.home, '.credentials', "client_secret.json")

  credentials_path = File.join(Dir.home, '.credentials', "openstudio-standards-google-drive.json")
  client = Google::APIClient.new(:application_name => 'openstudio-standards')
  client.authorization = authorize(credentials_path, client_secret_path)
  drive_api = client.discovered_api('drive', 'v2')

  # List the 100 most recently modified files.
  results = client.execute!(
      :api_method => drive_api.files.list,
      :parameters => {:maxResults => 100})
  puts "No files found" if results.data.items.empty?

  # Find the OpenStudio_Standards google spreadsheet
  # and save it.
  results.data.items.each do |file|
    if spreadsheet_titles.include?(file.title)
      puts "Found #{file.title}"
      download_xlsx_spreadsheet(client, file, "#{File.dirname(__FILE__)}/#{file.title}.xlsx")
    end
  end

end

def export_spreadsheet_to_json(spreadsheet_titles)

  warnings = []
  duplicate_data = []
  spreadsheet_titles.each do |spreadsheet_title|

    # Path to the xlsx file
    xlsx_path = "#{__dir__}/#{spreadsheet_title}.xlsx"

    unless File.exist?(xlsx_path)
      warnings << "could not find spreadsheet called #{spreadsheet_title}"
      next
    end

    puts "Parsing #{xlsx_path}"

    # List of worksheets to skip
    worksheets_to_skip = []
    worksheets_to_skip << 'templates'
    worksheets_to_skip << 'standards'
    worksheets_to_skip << 'ventilation'
    worksheets_to_skip << 'occupancy'
    worksheets_to_skip << 'interior_lighting'
    worksheets_to_skip << 'lookups'
    worksheets_to_skip << 'sheetmap'
    worksheets_to_skip << 'deer_lighting_fractions'
    worksheets_to_skip << 'window_types_and_weights'

    # List of columns to skip
    cols_to_skip = []
    cols_to_skip << 'lookup'
    cols_to_skip << 'lookupcolumn'
    cols_to_skip << 'vlookupcolumn'
    cols_to_skip << 'osm_lighting_per_person'
    cols_to_skip << 'osm_lighting_per_area'
    cols_to_skip << 'lighting_per_length'
    cols_to_skip << 'exhaust_per_unit'
    cols_to_skip << 'exhaust_fan_power_per_area'
    cols_to_skip << 'occupancy_standard'
    cols_to_skip << 'occupancy_primary_space_type'
    cols_to_skip << 'occupancy_secondary_space_type'

    # List of columns that are boolean
    # (rubyXL returns 0 or 1, will translate to true/false)
    bool_cols = []
    bool_cols << 'hx'
    bool_cols << 'data_center'
    bool_cols << 'u_value_includes_interior_film_coefficient'
    bool_cols << 'u_value_includes_exterior_film_coefficient'

    # Open workbook
    workbook = RubyXL::Parser.parse(xlsx_path)

    # Find all the template directories that match the search criteria embedded in the spreadsheet title
    standards_dir = File.expand_path("#{__dir__}/../../lib/openstudio-standards/standards")
    dirs = spreadsheet_title.gsub('OpenStudio_Standards-', '').gsub(/\(\w*\)/, '').split('-')
    new_dirs = []
    dirs.each { |d| d == 'ALL' ? new_dirs << '*' : new_dirs << "*#{d}*" }
    glob_string = "#{standards_dir}/#{new_dirs.join('/')}"
    puts "--spreadsheet title embedded search criteria: #{glob_string} yields:"
    template_dirs = Dir.glob(glob_string).select { |f| File.directory?(f) && !f.include?('data') }
    template_dirs.each do |template_dir|
      puts "----#{template_dir}"
    end

    # Export each tab to a hash, where the key is the sheet name
    # and the value is an array of objects
    standards_data = {}
    workbook.worksheets.each do |worksheet|
      sheet_name = worksheet.sheet_name.snake_case

      # Skip the specified worksheets
      if worksheets_to_skip.include?(sheet_name)
        puts "Skipping #{sheet_name}"
        next
      else
        puts "Processing #{sheet_name}"
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
        header["name"] = header_string.gsub(/\(.*\)/, '').strip.snake_case
        header_unit_parens = header_string.scan(/\(.*\)/)[0]
        if header_unit_parens.nil?
          header["units"] = nil
        else
          header["units"] = header_unit_parens.gsub(/\(|\)/, '').strip
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
          # Flip the switch if a value is found
          unless row[j].nil?
            all_null = false
          end
        end

        # Skip recording empty rows
        next if all_null == true

        # Store values from appropriate columns
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
          # Convert date columns to standard format
          if headers[j]['name'].include?('_date')
            if val.is_a?(DateTime)
              val = val.to_s
            else
              begin
                val = DateTime.parse(val).to_s
              rescue ArgumentError, TypeError
                puts "ERROR - value '#{val}', class #{val.class} in #{sheet_name}, row #{i}, col #{j} is not a valid date"
                return false
              end
            end
          end

          # Record the value
          obj[headers[j]['name']] = val
          # Skip recording units for unitless values
          next if headers[j]['units'].nil?
          # Record the units
          # obj["#{headers[j]['name']}_units"] = headers[j]['units']
        end

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

      # Skip to the next sheet if no objects were found
      if objs.size.zero?
        warnings << "did not export #{sheet_name} in #{spreadsheet_title} because no rows were found"
        next
      end

      # Save the objects to the hash
      standards_data[sheet_name] = objs
    end

    # Check for duplicate data in space_types_* sheets
    standards_data.each_pair do |sheet_name, objs|
      skip_duplicate_check = []
      next if skip_duplicate_check.include?(sheet_name)

      # Defines the set of properties that should be unique across all objects of the same type
      unique_props = unique_properties(sheet_name)
      # Ensure that a set of properties was defined
      if unique_props.empty?
        puts "--ERROR no unique set of properties was defined for #{sheet_name}, cannot check for duplicates"
        return false
      end

      # Check for duplicates using unique property set
      puts "Checking #{sheet_name} for duplicates based on columns: #{unique_props.join(', ')}"
      found_objs = {}
      objs.each_with_index do |obj, i|
        unique_aspects = []
        unique_props.each { |prop| unique_aspects << obj[prop] }
        unique_aspect = unique_aspects.join('|')
        if found_objs.include?(unique_aspect)
          status = 'different'
          status = 'same' if obj.to_s == found_objs[unique_aspect]
          duplicate_data << [spreadsheet_title, sheet_name, i, status, unique_aspect]
        end
        found_objs[unique_aspect] = obj.to_s
      end
    end

    # Merge all space_types_* sheets into a single space_types sheet
    space_types = {}
    standards_data.each_pair do |sheet_name, objs|
      next unless sheet_name.include?('space_types_')
      puts "Merging #{sheet_name} into space_types"
      objs.each do |obj|
        name = "#{obj['template']}|#{obj['building_type']}|#{obj['space_type']}"
        if space_types[name].nil?
          space_types[name] = obj
        else
          space_types[name].merge!(obj)
        end
      end

      # Remove space_types_* from the standards_data
      standards_data.delete(sheet_name)
    end
    standards_data['space_types'] = space_types.values unless space_types.empty?

    # Export each set of objects to a JSON file
    standards_data.each_pair do |sheet_name, objs|
      puts "Writing #{sheet_name} which has #{objs.size} objects"

      # Record the number of files that were exported for error checking
      jsons_written = 0

      # Split template-specific datasets into separate files.
      # Store common/shared datasets under a higher-level folder
      parent_dir = standard_parent_directory_from_spreadsheet_title(spreadsheet_title)
      if objs.first.has_key?('template')
        puts '--template-specific, writing a file for each template with just that templates objects'

        # Split objects by template
        templates_to_objects = {}
        objs.each do |obj|
          temp = obj['template']
          if templates_to_objects[temp]
            templates_to_objects[temp] << obj
          else
            templates_to_objects[temp] = [obj]
          end
        end

        # Write out a file for each template with the objects for that template.
        templates_to_objects.each_pair do |template, objs|
          next if template == 'Any'
          template_dir_name = standard_directory_name_from_template(template)
          # Sort the objects
          sorted_objs = {sheet_name => objs}.sort_by_key_updated(true) {|x, y| x.to_s <=> y.to_s}

          # Also check directly underneath the parent directory
          child_dir = "#{standards_dir}/#{parent_dir}/#{template_dir_name}"
          additional_dirs = []
          additional_dirs << child_dir if Dir.exist?(child_dir)
          possible_template_dirs = template_dirs + additional_dirs

          wrote_json = false
          possible_template_dirs.each do |template_dir|
            last_dir = template_dir.split('/').last
            next unless last_dir == template_dir_name
            data_dir = "#{template_dir}/data"
            Dir.mkdir(data_dir) unless Dir.exist?(data_dir)
            json_path = "#{data_dir}/#{template_dir_name}.#{sheet_name}.json"
            if json_path.size > 256
              puts "--ERROR the JSON path is #{json_path.size - 256} characters longer than the Window 256 character limit, cannot write to #{json_path}"
              return false
            end
            File.open(json_path, 'w:UTF-8') do |file|
              file << JSON.pretty_generate(sorted_objs)
            end
            puts "--successfully generated #{json_path}"
            jsons_written += 1
            wrote_json = true
          end

          unless wrote_json
            warnings << "did not export data for template #{template} from #{sheet_name} in #{spreadsheet_title} because there was no valid directory matching '#{template_dir_name}' based on the spreadsheet title embedded search criteria"
          end
        end

        # Stop if no objects on this sheet list the template called 'Any'
        next if templates_to_objects['Any'].nil?

        # Sort the objects
        sorted_objs = {sheet_name => templates_to_objects['Any']}.sort_by_key_updated(true) {|x, y| x.to_s <=> y.to_s}

        # Write all objects that use the 'Any' template to the parent directories
        wrote_any_template_json = false
        template_dirs.uniq.each do |template_dir|
          data_dir = "#{template_dir}/data"
          Dir.mkdir(data_dir) unless Dir.exist?(data_dir)
          json_path = "#{data_dir}/Any.#{sheet_name}.json"
          if json_path.size > 256
            puts "--ERROR the JSON path is #{json_path.size - 256} characters longer than the Window 256 character limit, cannot write to #{json_path}"
            return false
          end
          File.open(json_path, 'w:UTF-8') do |file|
            file << JSON.pretty_generate(sorted_objs)
          end
          puts "--successfully generated #{json_path}"
          jsons_written += 1
          wrote_any_template_json = true
        end

        unless wrote_any_template_json
          warnings << "did not export data for template 'Any' from #{sheet_name} in #{spreadsheet_title} because there was no valid directory to store 'Any' template data."
        end
      else
        puts '--not template-specific, writing a file with all objects for each template specified by search criteria'

        # Sort the objects
        sorted_objs = {sheet_name => objs}.sort_by_key_updated(true) {|x, y| x.to_s <=> y.to_s}

        # Write out a file for each template with all objects on the sheet
        template_dirs.each do |template_dir|
          data_dir = "#{template_dir}/data"
          Dir.mkdir(data_dir) unless Dir.exist?(data_dir)
          json_path = "#{data_dir}/#{parent_dir}.#{sheet_name}.json"
          if json_path.size > 256
            puts "--ERROR the JSON path is #{json_path.size - 256} characters longer than the Window 256 character limit, cannot write to #{json_path}"
            return false
          end
          File.open(json_path, 'w:UTF-8') do |file|
            file << JSON.pretty_generate(sorted_objs)
          end
          puts "--successfully generated #{json_path}"
          jsons_written += 1
        end
      end

      # Confirm that at least 1 JSON file was written per sheet
      if jsons_written.zero?
        puts "--ERROR no JSON files were written for #{sheet_name} even though objects were found.  Check sheet contents or delete rows."
        # return false
      end
    end
  end

  # Print out all the warnings in one place
  puts "\n**** WARNINGS ****"
  warnings.each { |w| puts "WARNING #{w}" }

  # Write duplicates out to file
  if duplicate_data.size > 0
    duplicate_log_path = "#{__dir__}/openstudio_standards_duplicates_log.csv"
    puts "\n**** DUPLICATES ****"
    puts "There were #{duplicate_data.size} duplicate objects found.  See detail in: #{duplicate_log_path}"
    CSV.open(duplicate_log_path, 'wb') do |csv|
      csv << ['Spreadsheet Name', 'Worksheet Name', 'Object Index in Worksheet', 'Similarity of Duplicate', 'Duplicate Object']
      duplicate_data.each do |duplicate|
        csv << duplicate
      end
    end
    # Open the duplicates csv file
    if Gem.win_platform?
      system("start #{File.expand_path(duplicate_log_path)}")
    else
      system("open #{File.expand_path(duplicate_log_path)}")
    end
  end

  return true
end
