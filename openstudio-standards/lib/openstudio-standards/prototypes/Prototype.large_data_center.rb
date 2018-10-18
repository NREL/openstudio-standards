
# Modules for building-type specific methods
module PrototypeBuilding
module LargeDataCenter

  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = {
      'DataCenter' => ['DataCenter']
    }
    
    return space_type_map
  end
  
  def self.define_hvac_system_map(building_type, template, climate_zone)
    
    system_to_space_map = [
      {
        'type' => 'CRAH',
        'space_names' => ['DataCenter']
      }
    ]
    
    return system_to_space_map
    
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

=begin
  def self.update_crah_num(building_type,prototype_input,template,model,sizing_run_dir)
    
    # get the chilled water loop
    chilled_water_loop = nil
    if model.getPlantLoopByName('Chilled Water Loop').is_initialized
      chilled_water_loop = model.getPlantLoopByName('Chilled Water Loop').get
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Chilled water loop doesn't exist for CRAH system. Failed to update CRAH number.")
    end
    # set no return plenum
    return_plenum = nil

    # get thermal zones
    thermal_zones = []
    space_name = 'DataCenter'
    space = model.getSpaceByName(space_name)
    if space.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
    end
    space = space.get
    zone = space.thermalZone
    if zone.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Space #{space_name} has no thermal zone; cannot add an HVAC system to this space.")
    end
    thermal_zones << zone.get
    puts "thermal_zones = #{thermal_zones}"

    # add another CRAH
    model.add_crah(template,
                   'test_system_name',
                   chilled_water_loop,
                   thermal_zones,
                   prototype_input['vav_operation_schedule'],
                   prototype_input['vav_oa_damper_schedule'],
                   prototype_input['vav_fan_efficiency'],
                   prototype_input['vav_fan_motor_efficiency'],
                   prototype_input['vav_fan_pressure_rise'],
                   return_plenum,
                   building_type)
             
    # Perform another sizing run to distribute air flow in multiple CRAH systems
    if model.runSizingRun("#{sizing_run_dir}/SR2_DC") == false
      return false
    end
    
  end
=end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
    
end 
end
