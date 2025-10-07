class BTAPCarbon
  def initialize(attributes)
    @carbon_database  = []
    @costing_database = CostingDatabase.instance
    @cp               = CommonPaths.instance
    @attributes       = attributes
    @carbon_report    = {}

    # Build the carbon database.
    # [@cp.carbon_opaque_path, @cp.carbon_glazing_path].each do |path|
    path = @cp.carbon_opaque_path
      data = CSV.read(path)

      1.upto data.length - 1 do |i|
        row   = data[i]
        index = row.each
        item  = Hash.new

        item["materials_opaque_id"]                     = index.next
        item["description"]                             = index.next
        item["type"]                                    = index.next
        item["quantity"]                                = index.next.to_f
        item["per m2"]                                  = index.next.to_f
        item["Product Category"]                        = index.next
        item["Embodied Carbon (A1-A5)"]                 = index.next.to_f
        item["Embodied Carbon (A-C)"]                   = index.next.to_f
        item["Environmental Product Declaration (EPD)"] = index.next

        @carbon_database << item
      # end
    end
  end

  def audit_embodied_carbon
    total_emissions = 0

    @attributes.surface_types.each do |surface_type|
      @carbon_report["#{surface_type.underscore}_area_m2"] = 0.0
      @carbon_report["#{surface_type.underscore}_carbon"] = 0.0
    end

    @attributes.spaces.each do |space|
      @attributes.surface_types.each do |surface_type|
        space.surfaces_hash[surface_type].each do |surface|
          surfArea = surface.netArea * space.thermalZone.get.multiplier
          
          @carbon_report["#{surface_type.underscore}_area_m2"] = \
            (@carbon_report["#{surface_type.underscore}_area_m2"] + surfArea).round(2)

          # Get the carbon emissions for each material in the space.
          if surface.construction_hash.nil?
            # TODO: undefined space type
            emissions = 0.0
          else
            emissions = carbon_from_construction(surface.construction_hash)
          end

          # Calculate the carbon emissions
          @carbon_report["#{surface_type.underscore}_carbon"] = \
            (@carbon_report["#{surface_type.underscore}_carbon"] + emissions * surfArea).round(2)
          
          total_emissions += @carbon_report["#{surface_type.underscore}_carbon"]
        end
      end
    end

    @carbon_report["total"] = total_emissions
    return @carbon_report
  end
end

# Retrieve the carbon emissions given a construction.
def carbon_from_construction(construction)
  total_emissions = 0.0

  construction["material_opaque_id_layers"].split(',').each do |material_id|

    # Locate the material entry in the costing database
    material_costing = @costing_database["raw"]["materials_opaque"].find do |row| 
      row["materials_opaque_id"] == material_id
    end

    if material_costing.nil?
      raise("Error: Could not find material with ID #{material_id} in the costing database.")
    end

    # Locate the material entry in the carbon database
    material_carbon = @carbon_database.find do |row| 
      row["materials_opaque_id"] == material_id
    end

    if material_carbon.nil?
      # require '/home/osdev/script/my_debug.rb'; require 'irb'; IRB.start_session(binding); exit
      raise("Error: Could not find material with ID #{material_id} in the carbon database.")
    end
    # Convert the units according to the carbon database and multiply by the expected emissions.
    total_emissions += material_carbon["quantity"] / material_costing["quantity"].to_f # * material_carbon["Embodied Carbon (A-C)"]
  end

  return total_emissions
end
