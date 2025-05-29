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

    # Return the cooling capacity of the DX cooling coil paired with the DX heating coil
    #
    # @param coil_heating_dx [OpenStudio::Model::CoilHeatingDXSingleSpeed, OpenStudio::Model::CoilHeatingDXMultiSpeed] coil heating dx object
    # @return [Double] capacity in W to be used for find object
    def self.coil_heating_dx_get_paired_coil_cooling_dx_capacity(coil_heating_dx)
      capacity_w = nil

      # Get the paired cooling coil
      clg_coil = nil

      # Unitary and zone equipment
      if coil_heating_dx.airLoopHVAC.empty?
        if coil_heating_dx.containingHVACComponent.is_initialized
          containing_comp = coil_heating_dx.containingHVACComponent.get
          if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
            clg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.coolingCoil
          elsif containing_comp.to_AirLoopHVACUnitarySystem.is_initialized
            unitary = containing_comp.to_AirLoopHVACUnitarySystem.get
            if unitary.coolingCoil.is_initialized
              clg_coil = unitary.coolingCoil.get
            end
          end
          # @todo Add other unitary systems
        elsif coil_heating_dx.containingZoneHVACComponent.is_initialized
          containing_comp = coil_heating_dx.containingZoneHVACComponent.get
          # PTHP
          if containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
            pthp = containing_comp.to_ZoneHVACPackagedTerminalHeatPump.get
            clg_coil = containing_comp.to_ZoneHVACPackagedTerminalHeatPump.get.coolingCoil
          end
        end
      end

      # On AirLoop directly
      if coil_heating_dx.airLoopHVAC.is_initialized
        air_loop = coil_heating_dx.airLoopHVAC.get

        # Check for the presence of any other type of cooling coil
        clg_types = ['OS:Coil:Cooling:DX:SingleSpeed',
                     'OS:Coil:Cooling:DX:TwoSpeed',
                     'OS:Coil:Cooling:DX:MultiSpeed']
        clg_types.each do |ct|
          coils = air_loop.supplyComponents(ct.to_IddObjectType)
          next if coils.empty?

          clg_coil = coils[0]
          # Stop on first DX cooling coil found
          break
        end
      end

      # If no paired cooling coil was found, throw an error and fall back to the heating capacity
      if clg_coil.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.HVAC.coil', "For #{coil_heating_dx.name}, the paired DX cooling coil could not be found to determine capacity. Using the coil's heating capacity instead, which will incorrectly select efficiency levels for most standards.")

        if coil_heating_dx.to_CoilHeatingDXSingleSpeed.is_initialized
          coil_heating_dx = coil_heating_dx.to_CoilHeatingDXSingleSpeed.get
          capacity_w = OpenstudioStandards::HVAC.coil_heating_dx_single_speed_get_capacity(coil_heating_dx, multiplier: multiplier)
          # add support for multi-speed DX heating coils
        end

        # return nil if no capacity is available
        if capacity_w.nil?
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.HVAC.coil', "For #{coil_heating_dx.name} capacity is not available.")
          return capacity_w
        end
      end

      multiplier = 1.0
      if ['PTAC', 'PTHP'].include?(OpenstudioStandards::HVAC.coil_dx_subcategory(clg_coil))
        thermal_zone = OpenstudioStandards::HVAC.hvac_component_get_thermal_zone(clg_coil)
        multiplier = thermal_zone.multiplier if !thermal_zone.nil?
      end

      # If a coil was found, cast to the correct type
      if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized
        clg_coil = clg_coil.to_CoilCoolingDXSingleSpeed.get
        capacity_w = OpenstudioStandards::HVAC.coil_cooling_dx_single_speed_get_capacity(clg_coil, multiplier: multiplier)
      elsif clg_coil.to_CoilCoolingDXTwoSpeed.is_initialized
        clg_coil = clg_coil.to_CoilCoolingDXTwoSpeed.get
        capacity_w = OpenstudioStandards::HVAC.coil_cooling_dx_two_speed_get_capacity(clg_coil, multiplier: multiplier)
      elsif clg_coil.to_CoilCoolingDXMultiSpeed.is_initialized
        clg_coil = clg_coil.to_CoilCoolingDXMultiSpeed.get
        capacity_w = OpenstudioStandards::HVAC.coil_cooling_dx_multi_speed_get_capacity(clg_coil, multiplier: multiplier)
      end

      return capacity_w
    end
  end
end
