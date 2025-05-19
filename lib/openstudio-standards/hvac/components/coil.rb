module OpenstudioStandards
  # The HVAC module provides methods create, modify, and get information about HVAC systems in the model
  module HVAC
    # @!group Component:Coil
    # Methods to create, modify, and get information about HVAC coil objects

    # Finds the subcategory.  Possible choices are:
    # Single Package, Split System, PTAC, or PTHP
    #
    # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
    #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
    # @return [String] the coil_dx_subcategory(coil_dx)
    # @todo Add add split system vs single package to model object
    def self.coil_dx_subcategory(coil_dx)
      sub_category = 'Single Package'

      # Fallback to the name, mainly for library export
      if coil_dx.name.get.to_s.include?('Single Package')
        sub_category = 'Single Package'
      elsif coil_dx.name.get.to_s.include?('Split System') ||
            coil_dx.name.get.to_s.include?('Central Air Source HP')
        sub_category = 'Split System'
      elsif coil_dx.name.get.to_s.include?('Minisplit HP')
        sub_category = 'Minisplit System'
      elsif coil_dx.name.get.to_s.include?('CRAC')
        sub_category = 'CRAC'
      end

      if coil_dx.airLoopHVAC.empty? && coil_dx.containingZoneHVACComponent.is_initialized
        containing_comp = coil_dx.containingZoneHVACComponent.get
        # PTHP
        if containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          sub_category = 'PTHP'
        end
        # @todo Add other zone hvac systems
      end

      return sub_category
    end

    # Determine if it is a heat pump
    #
    # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
    #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
    # @return [Boolean] returns true if it is a heat pump, false if not
    def self.coil_dx_heat_pump?(coil_dx)
      heat_pump = false

      if coil_dx.airLoopHVAC.empty?
        if coil_dx.containingHVACComponent.is_initialized
          containing_comp = coil_dx.containingHVACComponent.get
          if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
            heat_pump = true
          elsif containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized
            htg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get.heatingCoil
            if htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized then heat_pump = true end
          end
        elsif coil_dx.containingZoneHVACComponent.is_initialized
          containing_comp = coil_dx.containingZoneHVACComponent.get
          # PTHP
          if containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
            heat_pump = true
          end
          # @todo Add other zone hvac systems
        end
      else
        if !coil_dx.airLoopHVAC.get.supplyComponents('OS:Coil:Heating:DX:SingleSpeed'.to_IddObjectType).empty? ||
           !coil_dx.airLoopHVAC.get.supplyComponents('OS:Coil:Heating:DX:VariableSpeed'.to_IddObjectType).empty?
          heat_pump = true
        end
      end

      return heat_pump
    end
  end
end
