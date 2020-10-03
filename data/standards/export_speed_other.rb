
# Path to the xlsx file
base_path = File.dirname(__FILE__)
xlsx_path = File.join(base_path, 'InputJSONData.xlsx')

puts "Parsing #{xlsx_path}"

# Open workbook
workbook = RubyXL::Parser.parse(xlsx_path)

other_data = {}

class String
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_")
  end
end

def get_option(all_data, i, j)

  option = nil
  offset = 0
  while option.nil? || option.empty?
    option = all_data[i][j-offset]
    offset += 1
  end

  option = 'Default' if option == 'A'
  option = 'Options' if option == 'Option'

  return option
end

def process_column(all_data, cell_data, option_row, j, num_rows, indent)

  option = get_option(all_data, option_row, j)

  #puts "#{indent}#{option}"

  if option == 'Default'
    cell_data[option] = all_data[option_row + 1][j]
  elsif option == 'Options'
    options = []
    ((option_row+1)...num_rows).each do |i|
      value = all_data[i][j] if all_data[i]
      options << value if value
    end
    cell_data[option] = options
  elsif option == 'Footprint_Dimensions'
    cell_data[option] = {}

    num = 0
    while true
      key_1 = all_data[option_row + 3*num + 1][j]
      key_2 = all_data[option_row + 3*num + 2][j]
      val_3 = all_data[option_row + 3*num + 3][j]

      if key_1.nil? || key_1.empty? || key_2.nil? || key_2.empty? || val_3.nil? || val_3.empty?
        break
      end

      #puts "#{key_1}, #{key_2}, #{val_3}"

      cell_data[option][key_1] = {key_2 => val_3}
      num += 1
    end

  elsif option == 'Num_Zones' || option == 'Type'
    cell_data[option] = all_data[option_row + 1][j]
  elsif option == 'Footprint_Shape_Details' || option == 'Relationship'
    cell_data[option] = [{}] if cell_data[option].nil?
    process_column(all_data, cell_data[option][0], option_row + 1, j, num_rows, indent + '  ')
  elsif option.nil? || option.empty?
    STDOUT.flush
    raise "This should not happen"
  else
    cell_data[option] = {} if cell_data[option].nil?
    process_column(all_data, cell_data[option], option_row + 1, j, num_rows, indent + '  ')
  end
end

workbook.worksheets.each do |worksheet|
  #next unless worksheet.sheet_name == 'Geometry'

  sheet_data = {}
  sheet_name = worksheet.sheet_name.underscore
  puts "Processing #{sheet_name}"

  header_row = 0
  option_row = 1

  # Get all data
  all_data = rubyxl_extract_data(worksheet)

  num_rows = all_data.size
  num_cols = all_data[header_row].size
  (0...num_cols).each do |j|
    key = nil
    offset = 0
    while key.nil? || key.empty?
      key = all_data[header_row][j-offset]
      offset += 1
    end

    #puts "  #{key}"

    sheet_data[key] = {} if sheet_data[key].nil?

    process_column(all_data, sheet_data[key], option_row, j, num_rows, '    ')

  end

  other_data[sheet_name] = sheet_data
end

# additional data

#other_data['Project_Information']['Units'] = { "Default"=>"IP", "Options"=>["IP"] }

# Inputs JSON
File.open(File.join(base_path, 'other_inputs_new.json'), 'w') do |f|
  f.write(JSON.pretty_generate(other_data))
end