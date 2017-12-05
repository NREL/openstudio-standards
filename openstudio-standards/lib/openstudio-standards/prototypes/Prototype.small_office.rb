
# Extend the class to add Small Office specific stuff
module PrototypeBuilding
module SmallOffice
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil

    space_type_map = case template
                     when 'NECB 2011'
                       # dom = ?
                       {
                         '- undefined -' => ['Attic'],
                         'Office - enclosed' => ['Core_ZN', 'Perimeter_ZN_1', 'Perimeter_ZN_2', 'Perimeter_ZN_3', 'Perimeter_ZN_4']
                       }
                     else
                       {
                         'WholeBuilding - Sm Office' => ['Perimeter_ZN_1', 'Perimeter_ZN_2', 'Perimeter_ZN_3', 'Perimeter_ZN_4', 'Core_ZN'],
                         'Attic' => ['Attic']
                       }
                     end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC-2',
        'space_names' =>
          [
            'Perimeter_ZN_1'
          ]
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC-3',
        'space_names' =>
          [
            'Perimeter_ZN_2'
          ]
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC-4',
        'space_names' =>
          [
            'Perimeter_ZN_3'
          ]
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC-5',
        'space_names' =>
          [
            'Perimeter_ZN_4'
          ]
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC-1',
        'space_names' =>
          [
            'Core_ZN'
          ]
      }
    ]

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
  
    # add extra infiltration for entry door
    PrototypeBuilding::SmallOffice.add_door_infiltration(template, climate_zone, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Added door infiltration')
    
    # add extra infiltration for attic
    PrototypeBuilding::SmallOffice.add_attic_infiltration(template, climate_zone, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Added attic infiltration')    
    
    return true
  end # add hvac
  

  def self.add_door_infiltration(template, climate_zone, model)
    # add extra infiltration for entry door in m3/s (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      entry_space = model.getSpaceByName('Perimeter_ZN_1').get
      infiltration_entrydoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entrydoor.setName('entry door Infiltration')
      infiltration_per_zone_entrydoor = 0
      if template == '90.1-2004'
        infiltration_per_zone_entrydoor = 0.129785425
        infiltration_entrydoor.setSchedule(model.add_schedule('OfficeSmall INFIL_Door_Opening_SCH'))
      elsif template == '90.1-2007' || template == '90.1-2010'|| template == '90.1-2013'
        case climate_zone
        when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2B'
          infiltration_per_zone_entrydoor = 0.129785425
          infiltration_entrydoor.setSchedule(model.add_schedule('OfficeSmall INFIL_Door_Opening_SCH'))
        else
          infiltration_per_zone_entrydoor = 0.076455414
          infiltration_entrydoor.setSchedule(model.add_schedule('OfficeSmall INFIL_Door_Opening_SCH_2013'))
        end
      end
      infiltration_entrydoor.setDesignFlowRate(infiltration_per_zone_entrydoor)
      infiltration_entrydoor.setConstantTermCoefficient(1.0)
      infiltration_entrydoor.setTemperatureTermCoefficient(0.0)
      infiltration_entrydoor.setVelocityTermCoefficient(0.0)
      infiltration_entrydoor.setVelocitySquaredTermCoefficient(0.0)
      infiltration_entrydoor.setSpace(entry_space)
    end
  end  
  
  def self.add_attic_infiltration(template, climate_zone, model)
    # add extra infiltration for attic in m3/s (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      entry_space = model.getSpaceByName('Attic').get
      infiltration_attic = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_attic.setName('attic Infiltration')
      infiltration_per_zone_attic = 0.2001
      infiltration_attic.setSchedule(model.add_schedule('Always On'))
      infiltration_attic.setDesignFlowRate(infiltration_per_zone_attic)
      infiltration_attic.setConstantTermCoefficient(1.0)
      infiltration_attic.setTemperatureTermCoefficient(0.0)
      infiltration_attic.setVelocityTermCoefficient(0.0)
      infiltration_attic.setVelocitySquaredTermCoefficient(0.0)      
      infiltration_attic.setSpace(entry_space)
    end
  end    


  

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end
end
