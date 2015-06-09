# this script reads the OpenStudio_space_types_and_standards.xlsx spreadsheet
# and creates a JSON file containing all the information on the SpaceTypes tab

require 'rubygems'
require 'json'
require 'rubyXL'

class String
  def snake_case
    downcase.gsub(' ', '_').gsub('-', '_')
  end
end

class Hash
  def sort_by_key_updated(recursive = false, &block)
    keys.sort(&block).reduce({}) do |seed, key|
      seed[key] = self[key]
      if recursive && seed[key].is_a?(Hash)
        seed[key] = seed[key].sort_by_key(true, &block)
      elsif recursive && seed[key].is_a?(Array) && seed[key][0].is_a?(Hash)
        puts "sorting #{key}"
        # Sort logic depends on the tab
        frst = seed[key][0]
        if key == 'space_types' # Don't have names
          seed[key] = seed[key].sort_by { |hsh| [hsh['template'], hsh['climate_zone_set'], hsh['building_type'], hsh['space_type']] }
        elsif key == 'schedules' # Names are not unique, sort by name then day types
          seed[key] = seed[key].sort_by { |hsh| [hsh['name'], hsh['start_date'], hsh['day_types']] }
        elsif key == 'construction_sets'
          # Replace nil values with 'zzzz' temorarily for sorting
          seed[key].each do |item|
            item.keys.each do |key|
              if item[key].nil?
                item[key] = 'zzzz'
              end
            end
          end
          seed[key] = seed[key].sort_by { |hsh| [hsh['template'], hsh['building_type'], hsh['space_type']] } #, hsh['exterior_walls'], hsh['exterior_roofs'], hsh['exterior_floors']] }
          # Replace 'zzzz' back to nil
          seed[key].each do |item|
            item.keys.each do |key|
              if item[key] == 'zzzz'
                item[key] = nil
              end
            end
          end
        elsif frst.key?('name') # For all other tabs, names should be unique
          seed[key] = seed[key].sort_by { |hsh| hsh['name'] }
        else
          seed[key] = seed[key]
        end
      end
      seed
    end
  end
end

module OpenStudio
  class StandardsJson
    def self.export_json
      # Path to the xlsx file
      xlsx_path = 'resources/OpenStudio_Standards.xlsx'

      # List of worksheets to skip
      worksheets_to_skip = []
      worksheets_to_skip << 'ventilation'
      worksheets_to_skip << 'occupancy'
      worksheets_to_skip << 'interior_lighting'
      worksheets_to_skip << 'lookups'

      # List of columns to skip
      cols_to_skip = []
      cols_to_skip << 'lookup'
      cols_to_skip << 'lookupcolumn'
      cols_to_skip << 'vlookupcolumn'
      cols_to_skip << 'osm_lighting_per_person'
      cols_to_skip << 'osm_lighting_per_area'
      cols_to_skip << 'lighting_per_length'
      cols_to_skip << 'lighting_fraction_to_return_air'
      cols_to_skip << 'lighting_fraction_radiant'
      cols_to_skip << 'lighting_fraction_visible'
      cols_to_skip << 'gas_equipment_fraction_latent'
      cols_to_skip << 'gas_equipment_fraction_radiant'
      cols_to_skip << 'gas_equipment_fraction_lost'
      cols_to_skip << 'electric_equipment_fraction_latent'
      cols_to_skip << 'electric_equipment_fraction_radiant'
      cols_to_skip << 'electric_equipment_fraction_lost'
      cols_to_skip << 'service_water_heating_peak_flow_rate'
      cols_to_skip << 'service_water_heating_area'
      cols_to_skip << 'service_water_heating_peak_flow_per_area'
      cols_to_skip << 'service_water_heating_target_temperature'
      cols_to_skip << 'service_water_heating_fraction_sensible'
      cols_to_skip << 'service_water_heating_fraction_latent'
      cols_to_skip << 'service_water_heating_schedule'
      cols_to_skip << 'exhaust_per_area'
      cols_to_skip << 'exhaust_per_unit'
      cols_to_skip << 'exhaust_fan_efficiency'
      cols_to_skip << 'exhaust_fan_pressure_rise'
      cols_to_skip << 'exhaust_fan_power'
      cols_to_skip << 'exhaust_fan_power_per_area'
      cols_to_skip << 'exhaust_schedule'

      # List of columns that are boolean
      # (rubyXL returns 0 or 1, will translate to true/false)
      bool_cols = []
      bool_cols << 'solar_diffusing'

      # Open workbook
      workbook = RubyXL::Parser.parse(xlsx_path)

      standards_data = {}
      standards_data['file_version'] = 3
      workbook.worksheets.each do |worksheet|
        sheet_name = worksheet.sheet_name.snake_case

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
          # Stop when reach a blank header
          break if header_string.nil?
          header = {}
          header['name'] = header_string.gsub(/\(.*\)/, '').strip.snake_case
          header_unit_parens = header_string.scan(/\(.*\)/)[0]
          if header_unit_parens.nil?
            header['units'] = nil
          else
            header['units'] = header_unit_parens.gsub(/\(|\)/, '').strip
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
            obj.each do |key, val|
              # Skip the key
              next if key == 'name'
              # Skip blank climate zone values
              next if val.nil?
              items << val
            end
            new_obj['climate_zones'] = items
            objs << new_obj
          elsif sheet_name == 'constructions'
            new_obj = {}
            new_obj['name'] = obj['name']
            items = []
            obj.each do |key, val|
              # Skip the key
              next if key == 'name'
              # Put materials into an array,
              # record other fields normally
              if key.include?('material')
                # Skip blank material values
                next if val.nil?
                items << val
              else
                new_obj[key] = val
              end
            end
            new_obj['materials'] = items
            objs << new_obj
          elsif sheet_name == 'schedules'
            new_obj = {}
            new_obj['name'] = obj['name']
            items = []
            obj.each do |key, val|
              # Skip the key
              next if key == 'name'
              # Put materials into an array,
              # record other fields normally
              if key.include?('hr')
                # Skip blank hourly values
                next if val.nil?
                items << val
              else
                new_obj[key] = val
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
      end

      # Sort the standard data so it can be diffed easily
      standards_data = standards_data.sort_by_key_updated(true) { |x, y| x.to_s <=> y.to_s }

      # Write the hash to a JSON file
      #File.open('build/openstudio_standards.json', 'w') do |file|
      File.open('C:/GitRepos/OpenStudio-Prototype-Buildings/create_DOE_prototype_building/resources/openstudio_standards.json', 'w') do |file|
        file << JSON.pretty_generate(standards_data)
      end
      puts 'Successfully generated openstudio_standards.json'
    end
  end
end
