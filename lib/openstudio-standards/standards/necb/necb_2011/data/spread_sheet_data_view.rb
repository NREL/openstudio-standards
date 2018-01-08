require 'json'
require 'rubyXL'
require 'yaml'
require 'deep_merge'

class Hash
  def sort_by_key(recursive = false, &block)
    self.keys.sort(&block).reduce({}) do |seed, key|
      seed[key] = self[key]
      if recursive && seed[key].is_a?(Hash)
        seed[key] = seed[key].sort_by_key(true, &block)
      end
      seed
    end
  end
end

class SpreadSheetDataView

  def load_json()

    necb_standards_data = {}
    # Load NECB data files.
    ['necb_2015_table_c1.json',
     'regional_fuel_use.json',
     'surface_thermal_transmittance.json'
    ].each do |file|
      file = "#{File.dirname(__FILE__)}/#{file}"
      necb_standards_data = necb_standards_data.merge (JSON.parse(File.read(file)))
    end
    puts necb_standards_data
    File.write('input.json', JSON.pretty_generate(necb_standards_data))
    return necb_standards_data
  end


  def array_of_hashes_to_excel_sheet(sheet, array, starting_row = 0)
    #get all possible headers
    headers = []
    array.each {|value| headers.concat(value.keys)}
    #print unique headers
    headers.uniq!
    headers.each_with_index do |header, index|
      cell = sheet.add_cell(starting_row, index, header)
      cell.change_font_bold(true)
    end
    row = starting_row +1
    array.each do |item|
      headers.each_with_index do |header, index|
        sheet.add_cell(row, index, item[header])
      end
      row += 1
    end
  end

  def json_to_excel()
    files = Dir.glob("#{File.dirname(__FILE__)}/**/*.json").select{ |e| File.file? e }
    necb_standards_data = {}
    files.each do |file|
      necb_standards_data = necb_standards_data.deep_merge (JSON.parse(File.read(file)))
    end
    xlsx_file = 'standards.xlsx'
    necb_2011_workbook = RubyXL::Workbook.new
    necb_2011_workbook.worksheets.delete(necb_2011_workbook['Sheet1'])
    #Write Constants Sheet.
    self.array_of_hashes_to_excel_sheet(necb_2011_workbook.add_worksheet('constants'), necb_standards_data['constants'])
    self.array_of_hashes_to_excel_sheet(necb_2011_workbook.add_worksheet('formulas'), necb_standards_data['formulas'])
    necb_standards_data['tables'].each do |table|
      sheet = necb_2011_workbook.add_worksheet(table['name'])
      row = 0
      table.each do |key, value|
        unless key == 'table'
          sheet.add_cell(row, 0, key).change_font_bold(true)
          sheet.add_cell(row, 1, value)
          row += 1
        end
      end
      row += 1
      sheet.add_cell(row, 0, 'Table').change_font_bold(true)
      self.array_of_hashes_to_excel_sheet(sheet, table['table'], (row + 1))
    end
    necb_2011_workbook.write(xlsx_file)
    return xlsx_file
  end

  def excel_to_json(xlsx_file = 'standards.xlsx')
    output_hash = {}
    workbook = RubyXL::Parser.parse(xlsx_file)
    workbook.worksheets.each do |sheet|
      unless ['values', 'formulas'].include?(sheet.sheet_name)

        puts sheet.sheet_name
        parent_hash = {}
        table_hash = {}
        parent_hash[sheet.sheet_name] = table_hash
        table_array_of_hashes = []
        table_header = []
        table_header_found = false
        next_row_is_header = false
        next_row_is_table_data = false
        in_table = false
        sheet.each do |row|
          if row.nil?
            #skip blank rows
            next
          end
          #Get Non-table information.
          if row.cells[0].value != 'Table' and #we are not in a table
              row.cells[0].value.to_s.strip != '' and # cell is not empty
              not row.cells[0].value.nil? and #is not nil
              in_table == false # we are not in the middle of a table processing.
            #Jsonify the cell and store in by name into table hash.
            table_hash[row.cells[0].value] = jsonify_cell(row.cells[1])
          end
          #check flag to indicate start of table data
          if row.cells[0].value == 'Table'
            next_row_is_header = true
            in_table = true
            next
          elsif next_row_is_header == true
            #collect headers of table
            row && row.cells.each do |cell|
              val = cell && cell.value
              table_header << val
            end
            #change flags to tell we are in table next
            next_row_is_header = false
            next_row_is_table_data = true
            next
          elsif next_row_is_table_data == true
            #collect table row info using header info already collected.
            row_hash = {}
            row && row.cells.each_with_index do |cell, index|
              val = jsonify_cell(cell)
              row_hash[table_header[index]] = val
            end
            table_array_of_hashes << row_hash
            next
          end
        end
        table_hash['table'] = table_array_of_hashes
        table_hash_array = {}
        table_hash_array['tables'] = [table_hash]
        File.write("#{sheet.sheet_name}.json", JSON.pretty_generate(table_hash_array.sort_by_key(true)))
        output_hash = output_hash.merge(parent_hash)
      else
        puts "still have to implement formulas and constants"
      end
    end
  end

  #this method will try to see if there is json content in the cell.. if not it will return the raw cell data.
  def jsonify_cell(cell)
    val = nil
    begin
      val = JSON.parse(cell.value)
    rescue
      val = cell && cell.value
      case val
        when 'true'
          val = true
        when 'false'
          val = false
      end
    end
    return val
  end
end


spreader = SpreadSheetDataView.new
spreader.json_to_excel()
spreader.excel_to_json()