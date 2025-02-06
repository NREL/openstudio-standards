require 'singleton'
require 'json'
require 'csv'
require_relative 'common_paths.rb'

# Singleton class to centralize all database operations
class CostingDatabase
  include Singleton

  def initialize
    @cp = CommonPaths.instance # Stores paths
    @db = Hash.new             # Stores the costing database
  end

  # Load the data from disk into memory
  def load_database()
    File.open(@cp.costing_database_path) do |file|
      @db = JSON.parse(file.read)
    end

    load_costs(@cp.costs_path)
    load_localization_factors(@cp.costs_local_factors_path)
  end

  # Load each row of the costs and read the numerical data as floats
  def load_costs(path)
    data = CSV.read(path)

    1.upto data.length - 1 do |i|
      row = data[i]
      index = row.each
      item = Hash.new
      item["baseCosts"] = Hash.new
      costs = item["baseCosts"]

      item["id"]               = index.next
      item["sheet"]            = index.next
      item["source"]           = index.next
      item["description"]      = index.next
      item["city"]             = index.next
      item["province_state"]   = index.next
      costs["materialOpCost"]  = index.next.to_f
      costs["laborOpCost"]     = index.next.to_f
      costs["equipmentOpCost"] = index.next.to_f

      @db["costs"] << item
    end
  end

  # Load each row of the localization factors and read the numerical data as floats
  def load_localization_factors(path)
    data = CSV.read(path)
    1.upto data.length - 1 do |i|
      row = data[i]
      index = row.each
      item = Hash.new

      item["province_state"] = index.next
      item["city"]           = index.next
      item["division"]       = index.next
      item["code_prefix"]    = index.next
      item["material"]       = index.next.to_f
      item["installation"]   = index.next.to_f
      item["total"]          = index.next.to_f

      @db["localization_factors"] << item
    end
  end

  def save_database
    File.open(@cp.costing_database_path, "w") do |file|
      file.write(JSON.pretty_generate(@db))
    end
  end

  # Overload the element of operator for database accesses
  def [](element)
    @db[element]
  end

  # Overload the element assignment operator for inputting additional data
  def []=(element, value)
    @db[element] = value
  end
end
