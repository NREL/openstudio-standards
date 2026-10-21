# BTAP Database
#
# Singleton class to centralize all database operations.

module BTAP
  class Database
    include Singleton

    def initialize
      @db = Hash.new # Stores all database information

      # Load the costing data.
      # Note CSV::Table doesn't work with mutative `map!()`,
      # resorting to regular `map()`.
      @db["costs"] = CSV.read(Paths.costs_path, headers: true)
      ["materialOpCost", "laborOpCost", "equipmentOpCost"].each do |header|
        @db["costs"][header] = @db["costs"][header].map(&:to_f)
      end

      # Load the localization factors.
      @db["localization_factors"] = CSV.read(Paths.costs_local_factors_path, headers: true)
      ["material", "installation", "total"].each do |header|
        @db["localization_factors"][header] = @db["localization_factors"][header].map(&:to_f)
      end

      # Load the construction data
      @db["constructions"] = File.open(Paths::CONSTRUCTIONS_PATH) { |file| JSON.load(file) }

      # Load the raw data
      @db["raw"] = {}
      costing_file_names = Paths::COSTING_DATA_PATHS.map { |path| path.basename(".*").to_s }
      costing_file_names.zip(Paths::COSTING_DATA_PATHS).each do |header, path|
        unless File.exist?(path)
          raise("Error: Could not find #{data_path}")
        end
        @db[header] = CSV.read(path, headers: true)
      end
    end

    # This method verifies that, for a given row the number of items listed
    # in the 'id_layers' column is the same as the number of quantities listed
    # in the 'Id_layers_quantity_multipliers' column in the 'hvac_vent_ahu'
    # sheet in the costing spreadsheet. If there is a difference in the number
    # of items and number of quantities in a row then that row needs to be
    # investigated and fixed.
    def validate_ahu_items_and_quantities()

      # Find out if there are a different number of items and number oof
      # quantities in any row of the 'hvac_vent_ahu' sheet.
      diff_id_quantities = @db['raw']['hvac_vent_ahu'].select{ |data|
        data['id_layers'].to_s.split(',').size != data['Id_layers_quantity_multipliers'].to_s.split(',').size}

      # If there is a difference (that is the diff_id_quantities has something
      # in it) then raise an error.
      unless diff_id_quantities.empty?
        puts "Errors in the hvac_vent_ahu Costing Table.  The number of id_layers does not match the number of"
        puts "Id_layers_quantity_multipliers for the following item(s):"
        puts JSON.pretty_generate(diff_id_quantities)
        raise("costing spreadsheet validation failed")
      end
    end

    # Overload the element of operator for database accesses.
    def [](element)
      @db[element]
    end

    # Overload the element assignment operator for inputting additional data.
    def []=(element, value)
      @db[element] = value
    end
  end
end
