module OpenstudioStandards
  # The Refrigeration module provides methods to create, modify, and get information about refrigeration
  module Refrigeration
    # @!group Create Typical Refrigeration
    # Methods to add typical refrigeration

    # Adds typical refrigeration to a model
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param template [String] Technology or standards level, either 'old', 'new', or 'advanced'
    # @return [Boolean] returns true if successful, false if not
    def self.create_typical_refrigeration(model,
                                          template: 'new')
      # get refrigeration equipment list based on space types and area
      ref_equip_list = OpenstudioStandards::Refrigeration.typical_refrigeration_equipment_list(model)
      refrigeration_space_type_area = OpenStudio.convert(model.getBuilding.floorArea, 'm^2', 'ft^2').get

      # Find the thermal zones most suited for holding the display cases
      thermal_zone_case = OpenstudioStandards::Refrigeration.refrigeration_case_zone(model)
      if !ref_equip_list[:cases].empty? &&  thermal_zone_case.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Refrigeration', "Attempted to add display cases to the model, but could find no thermal zone to put them into.")
        return false
      end

      medium_temperature_cases = []
      low_temperature_cases = []
      ref_equip_list[:cases].each do |ref_case|
        case_ = OpenstudioStandards::Refrigeration.create_case(model,
                                                               template: template,
                                                               case_type: ref_case[:case_type],
                                                               case_length: ref_case[:length],
                                                               thermal_zone: thermal_zone_case)
        if case_.caseOperatingTemperature > -3.0
          medium_temperature_cases << case_
        else
          low_temperature_cases << case_
        end
      end

      # Find the thermal zones most suited for holding the walkins
      thermal_zone_walkin = OpenstudioStandards::Refrigeration.refrigeration_walkin_zone(model)
      if !ref_equip_list[:walkins].empty? && thermal_zone_walkin.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Refrigeration', "Attempted to add walkins to the model, but could find no thermal zone to put them into.")
        return false
      end

      medium_temperature_walkins = []
      low_temperature_walkins = []
      ref_equip_list[:walkins].each do |walkin|
        ref_walkin = OpenstudioStandards::Refrigeration.create_walkin(model,
                                                                      template: template,
                                                                      walkin_type: walkin[:walkin_type],
                                                                      thermal_zone: thermal_zone_walkin)
        if ref_walkin.operatingTemperature > -3.0
          medium_temperature_walkins << ref_walkin
        else
          low_temperature_walkins << ref_walkin
        end
      end

      medium_temperature_equip = medium_temperature_cases + medium_temperature_walkins
      low_temperature_equip = low_temperature_cases + low_temperature_walkins
      separate_system_size_limit = 20_000.0
      if refrigeration_space_type_area < separate_system_size_limit
        # each piece of equipment gets its own refrigeration system
        unless medium_temperature_equip.empty?
          medium_temperature_equip.each do |ref_equip|
            OpenstudioStandards::Refrigeration.create_compressor_rack(model, ref_equip,
                                                                      template: template)
          end
        end
        unless low_temperature_equip.empty?
          low_temperature_equip.each do |ref_equip|
            OpenstudioStandards::Refrigeration.create_compressor_rack(model, ref_equip,
                                                                      template: template)
          end
        end
      else
        unless medium_temperature_equip.empty?
          OpenstudioStandards::Refrigeration.create_refrigeration_system(model, medium_temperature_equip,
                                                                         template: template,
                                                                         operation_type: 'MT')
        end
        unless low_temperature_equip.empty?
          OpenstudioStandards::Refrigeration.create_refrigeration_system(model, low_temperature_equip,
                                                                         template: template,
                                                                         operation_type: 'LT')
        end
      end

      return true
    end

    # Returns the typical refrigeration equipment in a model based on space types
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [Hash] Hash of refrigeration case lengths and walkin area
    def self.typical_refrigeration_equipment_list(model)
      # get building type
      building_type = 'SuperMarket'
      building_type_area_ft2 = 50000.0

      # when grocery store
      cases_list = []
      walkins_list = []
      case building_type
      when 'SuperMarket', 'GroceryStore'
        # cases
        cases_list << { case_type: 'Reach-in - Ice Cream', length: 30.0 * (building_type_area_ft2 / 50000.0) }
        cases_list << { case_type: 'Coffin - Ice Cream', length: 4.0 * (building_type_area_ft2 / 50000.0) }
        cases_list << { case_type: 'Reach-in - Frozen Food', length: 90.0 * (building_type_area_ft2 / 50000.0) }
        cases_list << { case_type: 'Reach-in - Dairy, Deli, Beverage Case', length: 30.0 * (building_type_area_ft2 / 50000.0) }
        cases_list << { case_type: 'Service - Meat Deli Bakery', length: 60.0 * (building_type_area_ft2 / 50000.0) }
        cases_list << { case_type: 'Island - Deli Produce', length: 12.0 * (building_type_area_ft2 / 50000.0) }
        cases_list << { case_type: 'Vertical Open - All', length: 30.0 * (building_type_area_ft2 / 50000.0) }

        # walkins
        walkins_list << {
          walkin_type: 'Walk-in Cooler - 120SF with no glass door'
        }
      end

      equipment_list = {
        cases: cases_list,
        walkins: walkins_list
      }

      return equipment_list
    end
  end
end
