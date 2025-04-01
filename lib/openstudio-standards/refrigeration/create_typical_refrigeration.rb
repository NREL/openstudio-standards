module OpenstudioStandards
  # The Refrigeration module provides methods to create, modify, and get information about refrigeration
  module Refrigeration
    # @!group Create Typical Refrigeration
    # Methods to add typical refrigeration

    # # Adds typical refrigeration to a model
    #
    # @param template [String] Technology or standards level, either 'old', 'new', or 'advanced'
    # @return [Boolean] returns true if successful, false if not
    def self.create_typical_refrigeration(model,
                                          template: 'new')
      # TODO: method to get system lineup here
      lineup = {
        cases: [
          {
            case_type: 'Vertical Open - All',
            length: 6.0
          },
          {
            case_type: 'Island - Deli Produce',
            length: 2.0
          },
          {
            case_type: 'Coffin - Frozen Food',
            length: 2.0
          }
        ],
        walkins: [
          {
            walkin_type: 'Walk-in Cooler - 120SF with no glass door'
          }
        ]
      }
      refrigeration_space_type_area = OpenStudio.convert(model.getBuilding.floorArea, 'm^2', 'ft^2').get

      medium_temperature_cases = []
      low_temperature_cases = []
      lineup[:cases].each do |ref_case|
        case_ = OpenstudioStandards::Refrigeration.create_case(model,
                                                               template: template,
                                                               case_type: ref_case[:case_type],
                                                               case_length: ref_case[:length])
        if case_.caseOperatingTemperature > -3.0
          medium_temperature_cases << case_
        else
          low_temperature_cases << case_
        end
      end

      medium_temperature_walkins = []
      low_temperature_walkins = []
      lineup[:walkins].each do |walkin|
        ref_walkin = OpenstudioStandards::Refrigeration.create_walkin(model,
                                                                      template: template,
                                                                      walkin_type: walkin[:walkin_type])
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
            OpenstudioStandards::Refrigeration.create_refrigeration_system(model, [ref_equip],
                                                                           template: template,
                                                                           operation_type: 'MT')
          end
        end
        unless low_temperature_equip.empty?
          low_temperature_equip.each do |ref_equip|
            OpenstudioStandards::Refrigeration.create_refrigeration_system(model, [ref_equip],
                                                                           template: template,
                                                                           operation_type: 'LT')
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
  end
end
