# Utility which takes schedules from the NECB 2015 tables spreadsheet and puts them into a JSON file which somewhat
# matches the NECB 2011 schedules.json file.

require 'rubyXL'
require 'json'

class Sched_create
  # Set a bunch of variables which generally remain static and are added to the new schedulesNECB2015.json file because
  # that was how they were in the NECB2011 schedules.json file.

  template = 'NECB2015'
  name = 'NECB-'
  name_pre_mod = ['', '', '-Electric', '', '', '', '']
  name_post_mod = ['', '', '', '', '-Cooling', '-Heating', '']
  category = ['Occupancy', 'Lighting', 'Equipment', 'Fan', 'Thermostat Setpoint', 'Thermostat Setpoint', 'Service Water Heating']
  units = ['FRACTION', 'FRACTION', 'FRACTION', 'ON_OFF', 'TEMPERATURE', 'TEMPERATURE', 'FRACTION']
  day_types = ['Default|Wkdy', 'Sat', 'Sun|Hol']
  start_date = '2014-01-01T00:00:00+00:00'
  end_date = '2014-12-31T00:00:00+00:00'
  type = 'Hourly'
  notes = nil
  table_array = []
  entry_array = []
  json_array = []
  refs = ['assumption']

  # Open Excel file containing schdeules and look for the schedlues worksheet.

  workbook = RubyXL::Parser.parse('./NECB2015_tables-171121.xlsx')
  worksheet = workbook['A-8.4.3.2.(1)']

  # Determine how many rows are used in the schedules worksheet.  Had to do this because there were some nil lines
  # between each schedule in the worksheet.  This would cause the .each do command to break early.

  sheetlength = worksheet.dimension.ref.row_range.end
  table_index = 0

  # Start looping through each schedule in the worksheet.  RubyXL reads a few lines after the end of the schedules in
  # the worksheet.  The -32 is there to make sure that there is actually another schedule (or enough room for one) in
  # the worksheet thus preventing errors due to manipulating nulls.

  while table_index < (sheetlength - 32)
    curr_loc = 5
    cat_index = 0

    # Loop through each category defined above (order of categories should match how they are presented in the worksheet).

    category.each_with_index do |cat, cat_index|
      # Build the schedule name using the category and some prefixes and suffixes because the nomenclature was not
      # consistent.  Mostly trying to match what is in the NECB2011 schedules.json file.

      table_name = name + worksheet[table_index + 1][0].value.to_s[-1] + name_pre_mod[cat_index] + '-' + cat + name_post_mod[cat_index]

      # Loop through each day type: Weekdays/default, Saturdays, and Sundays/holidays.

      day_types.each do |day_type|
        line_values = []
        values = []

        # Need special if statements to handle Fans which are "On" and "Off" in the workbook but BTAP represents as 1 and 0.
        # Also need to handle when cooling is "off" in the workbook but which BTAP represents as setting the setpoint
        # really high.  The normal case (just a fraction) is at the end

        if cat == 'Fan'
          worksheet[table_index + curr_loc].cells.drop(1).each do |fan_val|
            if fan_val.value == 'On'
              line_values << 1.0
            else
              line_values << 0.0
            end
          end
        elsif name_post_mod[cat_index] == '-Cooling'
          worksheet[table_index + curr_loc].cells.drop(1).each do |cool_val|
            if cool_val.value == 'Off'
              line_values << 35
            else
              line_values << cool_val.value
            end
          end
        else
          worksheet[table_index + curr_loc].cells.drop(1).each { |col_ref| line_values << col_ref.value }
        end

        # The workbook lists the schedules started at 1:00 am and ending at 12:00 am (not sure why).  OpenStudio
        # schedules start at 12:00 am and end at 11:00 pm (which makes more sense to me).  I'm not sure if the to_f
        # statements need to be there but I added them anyway so all of the values in the .json file would be to at
        # least 1 decimal place (like the originial NECB2011 schedules.json file).

        values << line_values[23].to_f
        line_values.each { |ln_value| values << ln_value.to_f }
        values.pop

        # Put everything for this day in a hash (the order according to the original NECB2011 schedules.json file).

        entry_array = {
          'template' => template,
          'name' => table_name,
          'category' => cat,
          'units' => units[cat_index],
          'day_types' => day_type,
          'start_date' => start_date,
          'end_date' => end_date,
          'type' => type,
          'notes' => notes,
          'values' => values
        }

        # Add this day's hash to all of the others (I was calling them arrays but they were hashes).

        json_array << entry_array

        # Go to the next line for the next day.

        curr_loc += 1
      end

      # Go to the next line for the next category.

      curr_loc += 1
    end

    # End of the table set the location of the next table (which starts immediately after the preceding one)

    table_index += curr_loc - 1
  end

  # Add a few hashes to the hash containing all of the schedules in the worksheet.  This is to match the formatting
  # found in the original NECB2011 schedules.json file.

  table_array = {
    'tables' => [
      'name' => 'schedules',
      'data_type' => 'table',
      'refs' => refs,
      'table' => json_array
    ]
  }

  # Turn the big hash in memory into a .json format and save it to file.  The pretty part is so the json file is nicely
  # ordered and relatively easy to follow.

  File.open('./schedulesNECB2015.json', 'w') do |each_file|
    each_file.write(JSON.pretty_generate(table_array))
  end
end
