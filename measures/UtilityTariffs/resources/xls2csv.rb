require 'win32ole'
require 'csv'
t1 = Time.now
# configure a workbook, turn off excel alarms
xl = WIN32OLE.new('excel.application')
book = xl.workbooks.open("#{File.dirname(__FILE__)}/utility_tariffs.xlsx")
xl.displayalerts = false

# loop through all worksheets in the excel file
book.worksheets.each do |sheet|
  last_row = sheet.cells.find(what: '*', searchorder: 1, searchdirection: 2).row
  last_col = sheet.cells.find(what: '*', searchorder: 2, searchdirection: 2).column
  export = File.new("#{File.dirname(__FILE__)}/"+ sheet.name + '.csv', 'w+')
  csv_row = []

  # loop through each column in each row and write to CSV
  (1..last_row).each do |xlrow|
    (1..last_col).each do |xlcol|
      csv_row << sheet.cells(xlrow, xlcol).value
    end
    export << CSV.generate_line(csv_row)
    #puts CSV.generate_line(csv_row)
    csv_row = []
  end
  puts " Wrote #{File.dirname(__FILE__)}/" + sheet.name + '.csv'
end

# clean up
puts "close books"
book.close(savechanges: 'false')
xl.displayalerts = true
xl.Quit
puts "#{(Time.now - t1)/60.0} minutes"