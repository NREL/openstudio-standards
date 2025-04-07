module OpenstudioStandards
  # The Refrigeration module provides methods to create, modify, and get information about refrigeration
  module Refrigeration
    # @!group Information
    # Methods to get information about model refrigeration

    # Find the thermal zone that is best for adding refrigerated display cases into.
    # First, check for space types that typically have refrigeration.
    # Fall back to largest zone in the model if no typical space types are found.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [OpenStudio::Model::ThermalZone] returns a thermal zone if found, nil if not.
    def self.refrigeration_case_zone(model)
      # Ideally, look for one of the space types
      # that would typically have refrigeration.
      display_case_zone = nil
      display_case_zone_area_m2 = 0.0
      model.getThermalZones.each do |zone|
        space_type = OpenstudioStandards::ThermalZone.thermal_zone_get_space_type(zone)
        next if space_type.empty?

        space_type = space_type.get
        next if space_type.standardsSpaceType.empty?
        next if space_type.standardsBuildingType.empty?

        stds_spc_type = space_type.standardsSpaceType.get
        stds_bldg_type = space_type.standardsBuildingType.get
        case "#{stds_bldg_type} #{stds_spc_type}"
        when 'PrimarySchool Kitchen',
            'SecondarySchool Kitchen',
            'SuperMarket Sales',
            'QuickServiceRestaurant Kitchen',
            'FullServiceRestaurant Kitchen',
            'LargeHotel Kitchen',
            'Hospital Kitchen',
            'EPr Kitchen',
            'ESe Kitchen',
            'Gro GrocSales',
            'RFF StockRoom',
            'RSD StockRoom',
            'Htl Kitchen',
            'Hsp Kitchen'
          if zone.floorArea > display_case_zone_area_m2
            display_case_zone = zone
            display_case_zone_area_m2 = zone.floorArea
          end
        end
      end

      unless display_case_zone.nil?
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Refrigeration', "Display case zone is #{display_case_zone.name}, the largest zone with a space type typical for display cases.")
        return display_case_zone
      end

      # If no typical space type was found, choose the largest zone in the model.
      display_case_zone = nil
      display_case_zone_area_m2 = 0
      model.getThermalZones.each do |zone|
        if zone.floorArea > display_case_zone_area_m2
          display_case_zone = zone
          display_case_zone_area_m2 = zone.floorArea
        end
      end

      unless display_case_zone.nil?
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Refrigeration', "No space types typical for display cases were found, so the display cases will be placed in #{display_case_zone.name}, the largest zone.")
        return display_case_zone
      end

      return display_case_zone
    end

    # Find the thermal zone that is best for adding refrigerated walkins into.
    # First, check for space types that typically have refrigeration.
    # Fall back to largest zone in the model if no typical space types are found.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [OpenStudio::Model::ThermalZone] returns a thermal zone if found, nil if not.
    def self.refrigeration_walkin_zone(model)
      # Ideally, look for one of the space types
      # that would typically have refrigeration walkins.
      walkin_zone = nil
      walkin_zone_area_m2 = 0.0
      model.getThermalZones.each do |zone|
        space_type = OpenstudioStandards::ThermalZone.thermal_zone_get_space_type(zone)
        next if space_type.empty?

        space_type = space_type.get
        next if space_type.standardsSpaceType.empty?
        next if space_type.standardsBuildingType.empty?

        stds_spc_type = space_type.standardsSpaceType.get
        stds_bldg_type = space_type.standardsBuildingType.get
        case "#{stds_bldg_type} #{stds_spc_type}"
        when 'PrimarySchool Kitchen',
            'SecondarySchool Kitchen',
            'SuperMarket DryStorage',
            'QuickServiceRestaurant	Kitchen',
            'FullServiceRestaurant Kitchen',
            'LargeHotel Kitchen',
            'Hospital Kitchen',
            'EPr Kitchen',
            'ESe Kitchen',
            'Gro RefWalkInCool',
            'Gro RefWalkInFreeze',
            'RFF StockRoom',
            'RSD StockRoom',
            'Htl Kitchen',
            'Hsp Kitchen'
          if zone.floorArea > walkin_zone_area_m2
            walkin_zone = zone
            walkin_zone_area_m2 = zone.floorArea
          end
        end
      end

      unless walkin_zone.nil?
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Refrigeration', "Walkin zone is #{walkin_zone.name}, the largest zone with a space type typical for walkins.")
        return walkin_zone
      end

      # If no typical space type was found,
      # choose the largest zone in the model.
      walkin_zone = nil
      walkin_zone_area_m2 = 0
      model.getThermalZones.each do |zone|
        if zone.floorArea > walkin_zone_area_m2
          walkin_zone = zone
          walkin_zone_area_m2 = zone.floorArea
        end
      end

      unless walkin_zone.nil?
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Refrigeration', "No space types typical for walkins were found, so the walkins will be placed in #{walkin_zone.name}, the largest zone.")
        return walkin_zone
      end

      return walkin_zone
    end
  end
end
