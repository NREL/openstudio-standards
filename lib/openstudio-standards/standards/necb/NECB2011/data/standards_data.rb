require 'json'
require 'yaml'
require 'deep_merge'
require 'rubyXL'
#Note this script is no longer nor updated since the team now prefers to use JSON directly than excel.
# This file is only kept for reference if it is needed.

#monkey patch for recursive hash sorting.
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

class StandardsData
  attr_accessor :standards_data

  def get_standards_constant(name)
    object = @standards_data['constants'].detect {|constant| constant['name'] == name}
    raise("could not find #{name} in standards constants database. ") if object.nil? or object['value'].nil?
    return object['value']
  end

  def get_standards_formula(name)
    object = @standards_data['formulas'].detect {|formula| formula['name'] == name}
    raise("could not find #{name} in standards formual database. ") if object.nil? or object['value'].nil?
    return object['value']
  end

  def get_standards_table_row(table_name, search_criteria = nil)
    return_objects = nil
    object = @standards_data['tables'].detect {|table| table['name'] == table_name}
    raise("could not find #{table_name} in standards table database. ") if object.nil? or object['table'].nil?
    if search_criteria.nil?
      return object['table']
    else
      return_objects = self.model_find_object(object['table'], search_criteria)
      return return_object
    end
  end

  def get_standards_table_rows(table_name, search_criteria = nil)
    return_objects = nil
    object = @standards_data['tables'].detect {|table| table['name'] == table_name}
    raise("could not find #{table_name} in standards table database. ") if object.nil? or object['table'].nil?
    if search_criteria.nil?
      return object['table']
    else
      return_objects = self.model_find_objects(object['table'], search_criteria)
      return return_objects
    end
  end


  def json_to_excel(data_folder = __dir__, xlsx_file = 'standards.xlsx')
    standards_data = self.load_standards_data(data_folder)
    workbook = RubyXL::Workbook.new
    workbook.worksheets.delete(workbook['Sheet1'])
    #Write Constants Sheet.
    #self.array_of_hashes_to_excel_sheet(workbook.add_worksheet('constants'), standards_data['constants'])
    #self.array_of_hashes_to_excel_sheet(workbook.add_worksheet('formulas'), standards_data['formulas'])
    standards_data['tables'].each do |table|
      #puts table
      puts table[0]
      sheet = workbook.add_worksheet(table[0])
      row = 0
      table[1].each do |key, value|
        unless key == 'table'
          sheet.add_cell(row, 0, key).change_font_bold(true)
          sheet.add_cell(row, 1, value)
          row += 1
        end
      end
      row += 1
      sheet.add_cell(row, 0, 'Table').change_font_bold(true)
      self.array_of_hashes_to_excel_sheet(sheet, table[1]['table'], (row + 1))
    end
    workbook.write(xlsx_file)
    return xlsx_file
  end

  def excel_to_json(xlsx_file = 'standards.xlsx', output_folder = File.dirname(__FILE__))
    self.extract_excel_tables(xlsx_file, output_folder)
    self.extract_excel_constants_and_formulas(xlsx_file, output_folder)
  end

  def load_standards_data(datafolder = File.dirname(__FILE__))
    @standards_data = {}
    if __dir__[0] == ':' # Running from OpenStudio CLI
      files = embedded_files_relative('./', /.*\.json/)
      files.each do |file|
        @standards_data = standards_data.deep_merge(JSON.parse(EmbeddedScripting.getFileAsString(file)))
      end
    else
      files = Dir.glob("#{datafolder}/**/*.json").select {|e| File.file? e}
      files.each do |file|
        @standards_data = standards_data.deep_merge (JSON.parse(File.read(file)))
      end
    end
    @standards_data = @standards_data.sort_by_key(true)
    return @standards_data
  end


  protected


  # Method to search through a hash for the objects that meets the
  # desired search criteria, as passed via a hash.
  # Returns an Array (empty if nothing found) of matching objects.
  #
  # @param hash_of_objects [Hash] hash of objects to search through
  # @param search_criteria [Hash] hash of search criteria
  # @param capacity [Double] capacity of the object in question.  If capacity is supplied,
  #   the objects will only be returned if the specified capacity is between
  #   the minimum_capacity and maximum_capacity values.
  # @return [Array] returns an array of hashes, one hash per object.  Array is empty if no results.
  # @example Find all the schedule rules that match the name
  #   rules = model_find_objects(self, standards_data['schedules'], {'name'=>schedule_name})
  #   if rules.size == 0
  #     OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for schedule: #{schedule_name}, will not be created.")
  #     return false #TODO change to return empty optional schedule:ruleset?
  #   end
  def model_find_objects(table_name: , search_criteria: {}, capacity:nil)
    #    matching_objects = hash_of_objects.clone
    #    #new
    #    puts "searching"
    #    puts search_criteria
    #    raise ("hash of objects is nil or empty. #{hash_of_objects}") if hash_of_objects.nil? || hash_of_objects.empty? || matching_objects[0].nil?
    #
    #    search_criteria.each do |key,value|
    #      puts "#{key}-#{value}"
    #      puts matching_objects.size
    #      #if size has already reduced to zero. Get out of loop.
    #      break if matching_objects.size == 0
    #      #if there are no keys that match, skip search... (This seems odd)
    #      next unless  matching_objects[0].has_key?(key)
    #      matching_objects.select!{ |k| k[key] == value }
    #    end
    #    if not capacity.nil?
    #      puts "Capacity = #{capacity}"
    #      capacity = capacity + (capacity * 0.01) if capacity == capacity.round
    #      matching_objects.select!{|k| capacity.to_f > k['minimum_capacity'].to_f}
    #      matching_objects.select!{|k| capacity.to_f <= k['maximum_capacity'].to_f}
    #    end
    #
    #
    #    # Check the number of matching objects found
    #    if matching_objects.size == 0
    #      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find objects search criteria returned no results. Search criteria: #{search_criteria}, capacity = #{capacity}.  Called from #{caller(0)[1]}.")
    #
    #    end
    #    new_matching_objects =  matching_objects

    # old
    desired_object = nil
    search_criteria_matching_objects = []
    matching_objects = []

    if hash_of_objects.is_a?(Hash) and hash_of_objects.key?('table')
      hash_of_objects = hash_of_objects['table']
    end

    # Compare each of the objects against the search criteria
    hash_of_objects.each do |object|
      meets_all_search_criteria = true
      search_criteria.each do |key, value|
        # Don't check non-existent search criteria
        next unless object.key?(key)
        # Stop as soon as one of the search criteria is not met
        if object[key] != value
          meets_all_search_criteria = false
          break
        end
      end
      # Skip objects that don't meet all search criteria
      next if meets_all_search_criteria == false
      # If made it here, object matches all search criteria
      search_criteria_matching_objects << object
    end

    # If capacity was specified, narrow down the matching objects
    if capacity.nil?
      matching_objects = search_criteria_matching_objects
    else
      # Round up if capacity is an integer
      if capacity == capacity.round
        capacity += (capacity * 0.01)
      end
      search_criteria_matching_objects.each do |object|
        # Skip objects that don't have fields for minimum_capacity and maximum_capacity
        next if !object.key?('minimum_capacity') || !object.key?('maximum_capacity')
        # Skip objects that don't have values specified for minimum_capacity and maximum_capacity
        next if object['minimum_capacity'].nil? || object['maximum_capacity'].nil?
        # Skip objects whose the minimum capacity is below the specified capacity
        next if capacity.to_f <= object['minimum_capacity'].to_f
        # Skip objects whose max
        next if capacity.to_f > object['maximum_capacity'].to_f
        # Found a matching object
        matching_objects << object
      end
      # If no object was found, round the capacity down a little
      # to avoid issues where the number fell between the limits
      # in the json file.
      if matching_objects.size.zero?
        capacity *= 0.99
        search_criteria_matching_objects.each do |object|
          # Skip objects that don't have fields for minimum_capacity and maximum_capacity
          next if !object.key?('minimum_capacity') || !object.key?('maximum_capacity')
          # Skip objects that don't have values specified for minimum_capacity and maximum_capacity
          next if object['minimum_capacity'].nil? || object['maximum_capacity'].nil?
          # Skip objects whose the minimum capacity is below the specified capacity
          next if capacity <= object['minimum_capacity'].to_f
          # Skip objects whose max
          next if capacity > object['maximum_capacity'].to_f
          # Found a matching object
          matching_objects << object
        end
      end
    end

    # Check the number of matching objects found
    if matching_objects.size.zero?
      desired_object = nil
      # OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find objects search criteria returned no results. Search criteria: #{search_criteria}, capacity = #{capacity}.  Called from #{caller(0)[1]}.")
    end

    #    if new_matching_objects != matching_objects
    #      puts "new..."
    #      puts new_matching_objects
    #      puts "is not.."
    #      puts matching_objects
    #      raise ("Hell")
    #    end
    return matching_objects
  end

  # Method to search through a hash for an object that meets the
  # desired search criteria, as passed via a hash.  If capacity is supplied,
  # the object will only be returned if the specified capacity is between
  # the minimum_capacity and maximum_capacity values.
  #
  #
  # @param hash_of_objects [Hash] hash of objects to search through
  # @param search_criteria [Hash] hash of search criteria
  # @param capacity [Double] capacity of the object in question.  If capacity is supplied,
  #   the objects will only be returned if the specified capacity is between
  #   the minimum_capacity and maximum_capacity values.
  # @return [Hash] Return tbe first matching object hash if successful, nil if not.
  # @example Find the motor that meets these size criteria
  #   search_criteria = {
  #   'template' => template,
  #   'number_of_poles' => 4.0,
  #   'type' => 'Enclosed',
  #   }
  #   motor_properties = self.model.find_object(motors, search_criteria, 2.5)
  def model_find_object(table_name: , search_criteria: {}, capacity: nil, date: nil)
    #    new_matching_objects = model_find_objects(self, hash_of_objects, search_criteria, capacity)
    hash_of_objects = @standards_data[table_name]
    if hash_of_objects.is_a?(Hash) and hash_of_objects.key?('table')
      hash_of_objects = hash_of_objects['table']
    end
    desired_object = nil
    search_criteria_matching_objects = []
    matching_objects = []

    # Compare each of the objects against the search criteria
    hash_of_objects.each do |object|
      meets_all_search_criteria = true
      search_criteria.each do |key, value|
        # Don't check non-existent search criteria
        next unless object.key?(key)
        # Stop as soon as one of the search criteria is not met
        if object[key] != value
          meets_all_search_criteria = false
          break
        end
      end
      # Skip objects that don't meet all search criteria
      next unless meets_all_search_criteria
      # If made it here, object matches all search criteria
      search_criteria_matching_objects << object
    end

    # If capacity was specified, narrow down the matching objects
    if capacity.nil?
      matching_objects = search_criteria_matching_objects
    else
      # Round up if capacity is an integer
      if capacity == capacity.round
        capacity += (capacity * 0.01)
      end
      search_criteria_matching_objects.each do |object|
        # Skip objects that don't have fields for minimum_capacity and maximum_capacity
        next if !object.key?('minimum_capacity') || !object.key?('maximum_capacity')
        # Skip objects that don't have values specified for minimum_capacity and maximum_capacity
        next if object['minimum_capacity'].nil? || object['maximum_capacity'].nil?
        # Skip objects whose the minimum capacity is below the specified capacity
        next if capacity <= object['minimum_capacity'].to_f
        # Skip objects whose max
        next if capacity > object['maximum_capacity'].to_f
        # Found a matching object
        matching_objects << object
      end
      # If no object was found, round the capacity down a little
      # to avoid issues where the number fell between the limits
      # in the json file.
      if matching_objects.size.zero?
        capacity *= 0.99
        search_criteria_matching_objects.each do |object|
          # Skip objects that don't have fields for minimum_capacity and maximum_capacity
          next if !object.key?('minimum_capacity') || !object.key?('maximum_capacity')
          # Skip objects that don't have values specified for minimum_capacity and maximum_capacity
          next if object['minimum_capacity'].nil? || object['maximum_capacity'].nil?
          # Skip objects whose the minimum capacity is below the specified capacity
          next if capacity <= object['minimum_capacity'].to_f
          # Skip objects whose max
          next if capacity > object['maximum_capacity'].to_f
          # Found a matching object
          matching_objects << object
        end
      end
    end

    # If date was specified, narrow down the matching objects
    unless date.nil?
      date_matching_objects = []
      matching_objects.each do |object|
        # Skip objects that don't have fields for minimum_capacity and maximum_capacity
        next if !object.key?('start_date') || !object.key?('end_date')
        # Skip objects whose the start date is earlier than the specified date
        next if date <= Date.parse(object['start_date'])
        # Skip objects whose end date is beyond the specified date
        next if date > Date.parse(object['end_date'])
        # Found a matching object
        date_matching_objects << object
      end
      matching_objects = date_matching_objects
    end

    # Check the number of matching objects found
    if matching_objects.size.zero?
      desired_object = nil
      # OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned no results. Search criteria: #{search_criteria}, capacity = #{capacity}.  Called from #{caller(0)[1]}")
    elsif matching_objects.size == 1
      desired_object = matching_objects[0]
    else
      desired_object = matching_objects[0]
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned #{matching_objects.size} results, the first one will be returned. Called from #{caller(0)[1]}. \n Search criteria: \n #{search_criteria}, capacity = #{capacity} \n  All results: \n #{matching_objects.join("\n")}")
    end

    return desired_object
  end


  def array_of_hashes_to_excel_sheet(sheet, array, starting_row = 0)
    #get all possible headers
    headers = []
    colunm_to_char_ratio = 7.0 / 4.0
    array.each {|value| headers.concat(value.keys)}
    #print unique headers
    headers.uniq!

    headers.each_with_index do |header, index|
      cell = sheet.add_cell(starting_row, index, header)
      cell.change_font_bold(true)
      cell.change_font_italics(true)
      #resize column
      if sheet.get_column_width(index) < (cell.to_s.size() * colunm_to_char_ratio).to_i
        sheet.change_column_width(index, (cell.to_s.size() * colunm_to_char_ratio).to_i)
      end
    end
    row = starting_row + 1
    array.each do |item|
      headers.each_with_index do |header, index|
        cell = sheet.add_cell(row, index, item[header])
        #resize column
        if sheet.get_column_width(index) < (cell.to_s.size() * colunm_to_char_ratio).to_i
          sheet.change_column_width(index, (cell.to_s.size() * colunm_to_char_ratio).to_i)
        end
      end
      row += 1
    end
  end

  def extract_excel_constants_and_formulas(xlsx_file, output_folder)
    workbook = RubyXL::Parser.parse(xlsx_file)
    workbook.worksheets.each do |sheet|
      table_header = []
      table_array_of_hashes = []
      headers_collected = false
      if ['constants', 'formulas'].include?(sheet.sheet_name)
        sheet.each_with_index do |row|
          if row.nil?
            #skip blank rows
            next
          end
          if headers_collected == false
            #collect headers of table
            row && row.cells.each do |cell|
              val = cell && cell.value
              table_header << val
            end
            headers_collected = true
            next
          else
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
        sheet_hash = {}
        sheet_hash[sheet.sheet_name] = table_array_of_hashes
        File.write("#{output_folder}/#{sheet.sheet_name}.json", JSON.pretty_generate(sheet_hash.sort_by_key(true)))
      end
    end
  end


  def extract_excel_tables( xlsx_file, output_folder )
    output_hash = {}
    workbook = RubyXL::Parser.parse(xlsx_file)
    workbook.worksheets.each do |sheet|
      unless ['constants', 'formulas'].include?(sheet.sheet_name)
        parent_hash = {}
        table_hash = {}
        parent_hash[sheet.sheet_name] = table_hash
        table_array_of_hashes = []
        table_header = []
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
              #make all empty cells nil instead of ''
              if val == ''
                val = nil
              end
              row_hash[table_header[index]] = val
            end
            table_array_of_hashes << row_hash
            next
          end
        end
        table_hash['table'] = table_array_of_hashes
        table_hash_array = {}
        table_hash_array['tables'] = [table_hash]
        File.write("#{output_folder}/#{sheet.sheet_name}.json", JSON.pretty_generate({'tables':parent_hash.sort_by_key(true)}))
        output_hash = output_hash.merge(parent_hash)
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


spreader = StandardsData.new
spreader.json_to_excel()
spreader.excel_to_json()