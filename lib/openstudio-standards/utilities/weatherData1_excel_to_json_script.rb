require 'csv'
require 'json'
require 'rubyXL'

begin

csv_file = "#{File.dirname(__FILE__)}/../btap/csvFile1.csv"

input_file = "#{File.dirname(__FILE__)}/../btap/WeatherData1.xlsx"

CSV.open(csv_file, "wb") do |csv|
  workbook = RubyXL::Parser.parse input_file
  worksheet = workbook[0]

  worksheet.each_with_index do |row, row_idx|
    row_data = []
    (0...row.size).each do |col_idx|
      begin
        cell = row[col_idx]
        val = cell.value
        row_data << val
      rescue NoMethodError
        row_data << ""
      end
    end
    csv << row_data
  end
end

rescue; 
end

data_json_hash = CSV.open(csv_file, :headers => true).map { |x| x.to_h }.to_json

File.write("#{File.dirname(__FILE__)}/../btap/csvToJsonUpdate.json",data_json_hash)

data_hash = JSON.parse(File.read("#{File.dirname(__FILE__)}/../btap/csvToJsonUpdate.json"))

data_hash.each do |info|
  info['hdd18'] = info['hdd18'].to_i
  info['hdd15'] = info['hdd15'].to_i
  info['cdd18'] = info['cdd18'].to_i
  info['latitude'] = info['latitude'].to_f
  info['longitude'] = info['longitude'].to_f
  info['elevation'] = info['elevation'].to_i
  info['deltadb'] = info['deltadb'].to_f

end

pretty_output = JSON.pretty_generate(data_hash)

File.delete("#{File.dirname(__FILE__)}/../btap/csvToJsonUpdate.json")

File.write("#{File.dirname(__FILE__)}/../btap/WeatherData1.json", pretty_output)
