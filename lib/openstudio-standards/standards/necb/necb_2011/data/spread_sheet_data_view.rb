require 'json'
require 'rubyXL'
require 'yaml'

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

  def merge_recursively(a, b)
    a.merge(b) {|key, a_item, b_item| merge_recursively(a_item, b_item)}
  end

  def json_to_excel(standards_json_file = 'standards.json')
    necb_standards_data = JSON.parse(File.read(standards_json_file))
    xlsx_file = 'standards.xlsx'
    necb_2011_workbook = RubyXL::Workbook.new
    necb_2011_workbook.worksheets.delete(necb_2011_workbook['Sheet1'])

    #Write Values
    values_sheet = necb_2011_workbook.add_worksheet('values')
    values_array = necb_standards_data.select {|key, value| value['data_type'] == 'value'}
    header_row = 0
    ['key', 'value', 'units', 'refs', 'notes'].each_with_index do |header, index|
      values_sheet.add_cell(header_row, index, header).change_font_bold(true)
    end
    row = 1
    values_array.each_pair do |key, value|
      values_sheet.add_cell(row, 0, key)
      values_sheet.add_cell(row, 1, value['value'])
      values_sheet.add_cell(row, 2, value['units'])
      values_sheet.add_cell(row, 3, value['refs'])
      values_sheet.add_cell(row, 4, value['notes'])
      row += 1
    end

    #Write Formulas
    formula_sheet = necb_2011_workbook.add_worksheet('formulas')
    formula_array = necb_standards_data.select {|key, value| value['data_type'] == 'formula'}
    row = 0
    formula_array.each_pair do |key, value|
      formula_sheet.add_cell(row, 0, key)
      formula_sheet.add_cell(row, 1, value['formula'])
      formula_sheet.add_cell(row, 2, value['refs'])
      formula_sheet.add_cell(row, 3, value['units'])
      formula_sheet.add_cell(row, 3, value['notes'])
      row += 1
    end

    #WriteTables

    table_array = necb_standards_data.select {|key, value| value['data_type'] == 'table'}
    row = 0
    table_array.each_pair do |key, value|
      header_row = value.keys.size
      sheet = necb_2011_workbook.add_worksheet(key)
      counter = 0
      value.keys.each_with_index do |key|
        unless (key == 'table')
          sheet.add_cell(counter, 0, key).change_font_bold(true)
          sheet.add_cell(counter, 1, value[key])
          counter += 1
        end
      end
      sheet.add_cell((header_row-1), 0, 'Table').change_font_bold(true)
      value['table'].first.keys().each_with_index do |header, index|
        sheet.add_cell(header_row, index, header).change_font_bold(true)
        sheet.change_column_width(index, (header.size() * 3 / 2).to_i)
      end
      #table header
      table_row = header_row + 1
      max_size_of_cols = []
      value['table'].each do |row|
        row.keys.each_with_index do |item, index|
          sheet.add_cell(table_row, index, row[item])
          if sheet.get_column_width(index) < (row[item].to_s.size() * 3 / 2).to_i
            sheet.change_column_width(index, (row[item].to_s.size() * 3 / 2).to_i)
          end
        end
        table_row += 1
      end
    end

    necb_2011_workbook.write(xlsx_file)
    return xlsx_file
  end

  def excel_to_json(xlsx_file = 'standards.xlsx')
    output_hash = {}
    workbook = RubyXL::Parser.parse(xlsx_file)
    workbook.worksheets.each do |sheet|
      unless ['values', 'formulas'].include?(sheet.sheet_name)
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
          if row.cells[0].value != 'Table' and row.cells[0].value != '' and not row.cells[0].value.nil? and in_table == false
            table_hash[row.cells[0].value ] = jsonify_cell(row.cells[1])
          end
          if row.cells[0].value == 'Table'
            next_row_is_header = true
            in_table = true
            next
          elsif next_row_is_header == true
            row && row.cells.each do |cell|
              val = cell && cell.value
              table_header << val
            end
            next_row_is_header = false
            next_row_is_table_data = true
          elsif next_row_is_table_data == true
            new_hash = {}
            row && row.cells.each_with_index do |cell, index|
              val = jsonify_cell(cell)
              new_hash[table_header[index]] = val
            end
            table_array_of_hashes << new_hash
            next
          end
        end
        table_hash['table'] = table_array_of_hashes
        output_hash = output_hash.merge(parent_hash)
      end
    end
    File.write('new_standards.json',JSON.pretty_generate(output_hash))
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