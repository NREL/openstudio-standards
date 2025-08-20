class BTAPCarbon
  def initialize(attributes)
    @db = []
    @cp = CommonPaths.instance
    @attributes = attributes
    @carbon_report = {}

    data = CSV.read(@cp.carbon_data_path)

    1.upto data.length - 1 do |i|
      row   = data[i]
      index = row.each
      item  = Hash.new

      item["materials_opaque_id"] = index.next
      item["OC23 - Products"]     = index.next
      item["Quantity"]            = index.next.to_f
      item["Unit"]                = index.next

      @db << item
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

          # Calculate the carbon emissions
          @carbon_report["#{surface_type.underscore}_carbon"] = \
            (@carbon_report["#{surface_type.underscore}_carbon"] + 1).round(2)
          
          total_emissions += @carbon_report["#{surface_type.underscore}_carbon"]
        end
      end
    end

    @carbon_report["total"] = total_emissions
    return @carbon_report
  end
end