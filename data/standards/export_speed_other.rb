
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
    key = all_data[header_row][j]
    key = all_data[header_row][j - 1] if key.nil? || key.empty?

    puts "  #{key}"

    sheet_data[key] = {} if sheet_data[key].nil?

    option = all_data[option_row][j]
    option = 'Default' if option == 'A'
    option = 'Options' if option == 'Option'

    next if option.nil? || option.empty?

    puts "    #{option}"

    if option == 'Default'
      sheet_data[key][option] = all_data[option_row + 1][j]
    elsif option = 'Options'
      options = []
      ((option_row+1)...num_rows).each do |i|
        if key == 'Site_Orientation'
          puts "#{i}, #{j}, #{all_data[i][j]}"
        end
        options << all_data[i][j] if all_data[i]
      end
      sheet_data[key][option] = options
      if key == 'Site_Orientation'
        puts "#{sheet_data[key][option]}"
      end
    else
      puts "Unknown option #{option}"
    end
  end

  other_data[sheet_name] = sheet_data
end

# Inputs JSON
File.open(File.join(base_path, 'other_inputs_new.json'), 'w') do |f|
  f.write(JSON.pretty_generate(other_data))
end