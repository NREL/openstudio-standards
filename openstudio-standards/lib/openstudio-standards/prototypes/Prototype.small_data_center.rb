
# Modules for building-type specific methods
module PrototypeBuilding
module SmallDataCenter
  
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = {
      'ComputerRoom' => ['ComputerRoom']
    }
    
    return space_type_map
  end
  
  def self.define_hvac_system_map(building_type, template, climate_zone)
    
    system_to_space_map = [
      {
        'type' => 'CRAC',
        'space_names' => ['ComputerRoom']
      }
    ]
    
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

# TODO ITE object is not implemented in OpenStudio yet
# Use normal electric equipment as substitution temperarily
# will switch to ITE object after it is implemented by NREL.
=begin
    # remove normal electric equipment
    model.getElectricEquipments.each(&:remove)
    # add new IT equipment (ITE object)
    model.getSpaceTypes.each do |space_type|
      puts "space type = #{space_type.name}"
      if (space_type.name.get.downcase.include? 'computer') || (space_type.name.get.downcase.include? 'datacenter')
        space_type_properties = space_type.get_standards_data(template)
        ite = OpenStudio::Model::ElectricEquipmentITEAirCooled.new(model)
        puts "ite = #{ite}"
      end
    end
=end    
    
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
  
end 
end
