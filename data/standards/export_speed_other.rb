
# Path to the xlsx file
base_path = File.dirname(__FILE__)
xlsx_path = File.join(base_path, 'InputJSONData.xlsx')

puts "Parsing #{xlsx_path}"

# List of worksheets
worksheets = []
worksheets << 'ProjectInformation'
worksheets << 'SiteContext'
worksheets << 'Geometry'
worksheets << 'Envelope'
worksheets << 'SpaceLayout'
worksheets << 'HVAC'
worksheets << 'SizingLoadFactors'
worksheets << 'Daylighting'
worksheets << 'Photovoltaics'

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

  option = all_data[i][j]
  option = all_data[i][j - 1] if option.nil? || option.empty?
  option = 'Default' if option == 'A'
  option = 'Options' if option == 'Option'

  return option
end

def process_column(all_data, cell_data, option_row, j, num_rows, indent)

  option = get_option(all_data, option_row, j)

  puts "#{indent}#{option}"

  if option == 'Default'
    cell_data[option] = all_data[option_row + 1][j]
  elsif option == 'Options'
    options = []
    ((option_row+1)...num_rows).each do |i|
      value = all_data[i][j] if all_data[i]
      options << value if value
    end
    cell_data[option] = options
  elsif option == 'Num_Zones' || option == 'Type'
    cell_data[option] = all_data[option_row + 1][j]
  elsif option.nil? || option.empty?
    # no-op
  else
    cell_data[option] = {} if cell_data[option].nil?
    process_column(all_data, cell_data[option], option_row + 1, j, num_rows, indent + '  ')
  end
end

workbook.worksheets.each do |worksheet|
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

    puts "  #{key}"

    sheet_data[key] = {} if sheet_data[key].nil?

    process_column(all_data, sheet_data[key], option_row, j, num_rows, '    ')

  end

  other_data[sheet_name] = sheet_data
end

# additional data

other_data['Project_Information']['Units'] = { "Default"=>"IP", "Options"=>["IP"] }

# Inputs JSON
File.open(File.join(base_path, 'other_inputs_new.json'), 'w') do |f|
  f.write(JSON.pretty_generate(other_data))
end