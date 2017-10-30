require 'json'
# Extend the class to add Medium Office specific stuff
class StandardsModel
  def model_define_space_type_map(model, building_type, template, climate_zone)
    space_type_map_json = File.absolute_path(File.join(File.dirname(__FILE__),"../../../../../../data/geometry/archetypes/#{building_type}.json"))
    begin
      space_type_map = JSON.parse(File.read(space_type_map_json))
    rescue JSON::ParserError => e
      puts "THE CONTENTS OF THE JSON FILE AT #{space_type_map_json} IS NOT VALID"
      raise e
    end

    if space_type_map.has_key?(building_type)
      template_found = false
      #search for template within building_type key
      space_type_map[building_type]['space_map'].each_with_index do |item, index|  
        if item["template"].include?(template)
          template_found = true
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model.define_space_type_map', "Template = [#{template}] found for Building Type = [#{building_type}] in [\"#{building_type}\"]['space_map'][#{index}][\"space_type_map\"]")
          return item["space_type_map"]
        end
      end

      unless template_found #throw error because space type mapping was not found
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model.define_space_type_map', "Template = [#{template}] was not found for Building Type = [#{building_type}] at #{space_type_map_json}.")
        return false 
      end

    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model.define_space_type_map', "Building Type = #{building_type} was not found at #{space_type_map_json}")
      return false
    end
  end



  def model_custom_hvac_tweaks(model, building_type, template, climate_zone, prototype_input)
    case building_type
    when 'SecondarySchool'
      return PrototypeBuilding::SecondarySchool.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'PrimarySchool'
      return PrototypeBuilding::PrimarySchool.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'SmallOffice'
      return PrototypeBuilding::SmallOffice.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'MediumOffice'
      return PrototypeBuilding::MediumOffice.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'LargeOffice'
      return PrototypeBuilding::LargeOffice.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'SmallHotel'
      return PrototypeBuilding::SmallHotel.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'LargeHotel'
      return PrototypeBuilding::LargeHotel.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'Warehouse'
      return PrototypeBuilding::Warehouse.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'RetailStandalone'
      return PrototypeBuilding::RetailStandalone.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'RetailStripmall'
      return PrototypeBuilding::RetailStripmall.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'QuickServiceRestaurant'
      return PrototypeBuilding::QuickServiceRestaurant.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'FullServiceRestaurant'
      return PrototypeBuilding::FullServiceRestaurant.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'Hospital'
      return PrototypeBuilding::Hospital.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'Outpatient'
      return PrototypeBuilding::Outpatient.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'MidriseApartment'
      return PrototypeBuilding::MidriseApartment.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'HighriseApartment'
      return PrototypeBuilding::HighriseApartment.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
	when 'SuperMarket'
      return PrototypeBuilding::SuperMarket.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)  
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model.custom_hvac_tweaks', "Building Type = #{building_type} not recognized")
      return false
    end
  end

  def model_custom_swh_tweaks(model, building_type, template, climate_zone, prototype_input)
    case building_type
    when 'SecondarySchool'
      return PrototypeBuilding::SecondarySchool.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'PrimarySchool'
      return PrototypeBuilding::PrimarySchool.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'SmallOffice'
      return PrototypeBuilding::SmallOffice.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'MediumOffice'
      return PrototypeBuilding::MediumOffice.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'LargeOffice'
      return PrototypeBuilding::LargeOffice.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'SmallHotel'
      return PrototypeBuilding::SmallHotel.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'LargeHotel'
      return PrototypeBuilding::LargeHotel.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'Warehouse'
      return PrototypeBuilding::Warehouse.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'RetailStandalone'
      return PrototypeBuilding::RetailStandalone.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'RetailStripmall'
      return PrototypeBuilding::RetailStripmall.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'QuickServiceRestaurant'
      return PrototypeBuilding::QuickServiceRestaurant.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'FullServiceRestaurant'
      return PrototypeBuilding::FullServiceRestaurant.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'Hospital'
      return PrototypeBuilding::Hospital.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'Outpatient'
      return PrototypeBuilding::Outpatient.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'MidriseApartment'
      return PrototypeBuilding::MidriseApartment.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    when 'HighriseApartment'
      return PrototypeBuilding::HighriseApartment.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
	when 'SuperMarket'
      return PrototypeBuilding::SuperMarket.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)  
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model.custom_swh_tweaks', "Building Type = #{building_type} not recognized")
      return false
    end
  end
end
