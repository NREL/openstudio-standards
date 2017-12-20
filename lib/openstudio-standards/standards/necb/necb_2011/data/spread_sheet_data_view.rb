require 'json'
require 'rubyXL'

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
    File.write(JSON.pretty_generate('input.json', necb_standards_data  ) )
    return necb_standards_data
  end

  def merge_recursively(a, b)
    a.merge(b) {|key, a_item, b_item| merge_recursively(a_item, b_item)}
  end

  def json_to_excel(necb_standards_data)
    xlsx_file = 'standards.xlsx'
    necb_2011_workbook = RubyXL::Workbook.new

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
      value['table'].first.keys().each_with_index do |header, index|
        sheet.add_cell(header_row, index, header).change_font_bold(true)
      end
      #table header
      table_row = header_row + 1
      value['table'].each do |row|
        row.keys.each_with_index do |item, index|
          sheet.add_cell(table_row, index, row[item])
        end
        table_row += 1
      end
    end
    necb_2011_workbook.write(xlsx_file)
    return xlsx_file
  end

  def excel_to_json(xlsx_file)
    workbook = RubyXL::Parser.parse(xlsx_file)
    workbook['values'].each_with_index { |row|
      puts row
    }
  end

end

spreader = SpreadSheetDataView.new
spreader.json_to_excel(spreader.load_json())