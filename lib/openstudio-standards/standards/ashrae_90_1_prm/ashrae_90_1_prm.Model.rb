class ASHRAE901PRM < Standard
  # @!group Model


  # Determines the area of the building above which point
  # the non-dominant area type gets it's own HVAC system type.
  # @return [Double] the minimum area (m^2)
  def model_prm_baseline_system_group_minimum_area(model, custom)
    exception_min_area_ft2 = 20_000
    # Customization - Xcel EDA Program Manual 2014
    # 3.2.1 Mechanical System Selection ii
    if custom == 'Xcel Energy CO EDA'
      exception_min_area_ft2 = 5000
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Customization; per Xcel EDA Program Manual 2014 3.2.1 Mechanical System Selection ii, minimum area for non-predominant conditions reduced to #{exception_min_area_ft2} ft2.")
    end
    exception_min_area_m2 = OpenStudio.convert(exception_min_area_ft2, 'ft^2', 'm^2').get
    return exception_min_area_m2
  end

  # Determines which system number is used
  # for the baseline system.
  # @return [String] the system number: 1_or_2, 3_or_4,
  # 5_or_6, 7_or_8, 9_or_10
  def model_prm_baseline_system_number(model, climate_zone, area_type, fuel_type, area_ft2, num_stories, custom)
    sys_num = nil

    # Customization - Xcel EDA Program Manual 2014
    # Table 3.2.2 Baseline HVAC System Types
    if custom == 'Xcel Energy CO EDA'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'Custom; per Xcel EDA Program Manual 2014 Table 3.2.2 Baseline HVAC System Types, the 90.1-2010 lookup for HVAC system types shall be used.')

      # Set the area limit
      limit_ft2 = 25_000

      case area_type
      when 'residential'
        sys_num = '1_or_2'
      when 'nonresidential'
        # nonresidential and 3 floors or less and <25,000 ft2
        if num_stories <= 3 && area_ft2 < limit_ft2
          sys_num = '3_or_4'
          # nonresidential and 4 or 5 floors or 5 floors or less and 25,000 ft2 to 150,000 ft2
        elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150_000))
          sys_num = '5_or_6'
          # nonresidential and more than 5 floors or >150,000 ft2
        elsif num_stories >= 5 || area_ft2 > 150_000
          sys_num = '7_or_8'
        end
      when 'heatedonly'
        sys_num = '9_or_10'
      when 'retail'
        # Should only be hit by Xcel EDA
        sys_num = '3_or_4'
      end

    else

      # Set the area limit
      limit_ft2 = 25_000

      case area_type
      when 'residential'
        sys_num = '1_or_2'
      when 'nonresidential'
        # nonresidential and 3 floors or less and <25,000 ft2
        if num_stories <= 3 && area_ft2 < limit_ft2
          sys_num = '3_or_4'
        # nonresidential and 4 or 5 floors or 5 floors or less and 25,000 ft2 to 150,000 ft2
        elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150_000))
          sys_num = '5_or_6'
        # nonresidential and more than 5 floors or >150,000 ft2
        elsif num_stories >= 5 || area_ft2 > 150_000
          sys_num = '7_or_8'
        end
      when 'heatedonly'
        sys_num = '9_or_10'
      when 'retail'
        sys_num = '3_or_4'
      end

    end

    return sys_num
  end

  # Change the fuel type based on climate zone, depending on the standard.
  # For 90.1-2013, fuel type is based on climate zone, not the proposed model.
  # @return [String] the revised fuel type
  def model_prm_baseline_system_change_fuel_type(model, fuel_type, climate_zone, custom = nil)
    if custom == 'Xcel Energy CO EDA'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'Custom; per Xcel EDA Program Manual 2014 Table 3.2.2 Baseline HVAC System Types, the 90.1-2010 rules for heating fuel type (based on proposed model) rules apply.')
      return fuel_type
    end

    # For 90.1-2013 the fuel type is determined based on climate zone.
    # Don't change the fuel if it purchased heating or cooling.
    if fuel_type == 'electric' || fuel_type == 'fossil'
      case climate_zone
      when 'ASHRAE 169-2006-1A',
           'ASHRAE 169-2006-2A',
           'ASHRAE 169-2006-3A',
           'ASHRAE 169-2013-1A',
           'ASHRAE 169-2013-2A',
           'ASHRAE 169-2013-3A'
        fuel_type = 'electric'
      else
        fuel_type = 'fossil'
      end
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Heating fuel is #{fuel_type} for 90.1-2013, climate zone #{climate_zone}.  This is independent of the heating fuel type in the proposed building, per G3.1.1-3.  This is different than previous versions of 90.1.")
    end

    return fuel_type
  end

  # Determines the fan type used by VAV_Reheat and VAV_PFP_Boxes systems.
  # Variable speed fan for 90.1-2013
  # @return [String] the fan type: TwoSpeed Fan, Variable Speed Fan
  def model_baseline_system_vav_fan_type(model)
    fan_type = 'Variable Speed Fan'
    return fan_type
  end

  # This method creates customized infiltration objects for each
  # space and removes the SpaceType-level infiltration objects.
  #
  # @return [Bool] true if successful, false if not
  def baseline_apply_infiltration_standard(model, climate_zone)
    # Model shouldn't use SpaceInfiltrationEffectiveLeakageArea
    # Excerpt from the EnergyPlus Input/Output reference manual:
    #     "This model is based on work by Sherman and Grimsrud (1980)
    #     and is appropriate for smaller, residential-type buildings."
    # Return an error if the model does use this object
    ela = 0
    model.getSpaceInfiltrationEffectiveLeakageAreas.sort.each do |eff_la|
      ela += 1
    end
    if ela > 0
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'The current model cannot include SpaceInfiltrationEffectiveLeakageArea. These objects cannot be used to model infiltration according to the 90.1-PRM rules.')
    end

    # Get the space building envelope area
    # According to the 90.1 definition, building envelope include:
    # - "the elements of a building that separate conditioned spaces from the exterior"
    # - "the elements of a building that separate conditioned space from unconditioned
    #    space or that enclose semiheated spaces through which thermal energy may be
    #    transferred to or from the exterior, to or from unconditioned spaces or to or
    #    from conditioned spaces."
    building_envelope_area_m2 = 0
    model.getSpaces.sort.each do |space|
      building_envelope_area_m2 += space_envelope_area(space, climate_zone)
    end
    if building_envelope_area_m2 == 0.0
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', 'Calculated building envelope area is 0 m2, no infiltration will be added.')
      return 0.0
    end

    # Calculate current model air leakage rate @ 75 Pa and report it
    curr_tot_infil_m3_per_s_per_envelope_area = model_current_building_envelope_infiltration_at_75pa(model, building_envelope_area_m2)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The proposed model I_75Pa is estimated to be #{curr_tot_infil_m3_per_s_per_envelope_area} m3/s per m2 of total building envelope.")

    # Calculate building adjusted building envelope
    # air infiltration following the 90.1 PRM rules
    tot_infil_m3_per_s = model_adjusted_building_envelope_infiltration(model, building_envelope_area_m2)

    # Find infiltration method used in the model, if any.
    #
    # If multiple methods are used, use per above grade wall
    # area (i.e. exterior wall area), if air/changes per hour
    # or exterior surface area is used, use Flow/ExteriorWallArea
    infil_method = model_get_infiltration_method(model)
    infil_method = 'Flow/ExteriorWallArea' if infil_method != 'Flow/Area' || infil_method != 'Flow/ExteriorWallArea'
    infil_coefficients = model_get_infiltration_coefficients(model)

    # Set the infiltration rate at each space
    model.getSpaces.sort.each do |space|
      space_apply_infiltration_rate(space, tot_infil_m3_per_s, infil_method, infil_coefficients)
    end

    # Remove infiltration rates set at the space type
    model.getSpaceTypes.sort.each do |space_type|
      space_type.spaceInfiltrationDesignFlowRates.each(&:remove)
    end

    return true
  end

  # This method retrieves the type of infiltration input
  # used in the model. If input is inconsitent, returns
  # Flow/Area
  #
  # @return [String] infiltration input type
  def model_get_infiltration_method(model)
    infil_method = nil
    model.getSpaces.sort.each do |space|
      # Infiltration at the space level
      unless space.spaceInfiltrationDesignFlowRates.empty?
        old_infil = space.spaceInfiltrationDesignFlowRates[0]
        old_infil_method = old_infil.designFlowRateCalculationMethod.to_s
        # Return flow per space floor area if method is inconsisten in proposed model
        return 'Flow/Area' if infil_method != old_infil_method && !infil_method.nil?

        infil_method = old_infil_method
      end

      # Infiltration at the space type level
      if infil_method.nil? && space.spaceType.is_initialized
        space_type = space.spaceType.get
        unless space_type.spaceInfiltrationDesignFlowRates.empty?
          old_infil = space_type.spaceInfiltrationDesignFlowRates[0]
          old_infil_method = old_infil.designFlowRateCalculationMethod.to_s
          # Return flow per space floor area if method is inconsisten in proposed model
          return 'Flow/Area' if infil_method != old_infil_method && !infil_method.nil?

          infil_method = old_infil_method
        end
      end
    end

    return infil_method
  end

  # This method retrieves the infiltration coefficients
  # used in the model. If input is inconsitent, returns
  # [0, 0, 0.224, 0] as per PRM user manual
  #
  # @return [String] infiltration input type
  def model_get_infiltration_coefficients(model)
    cst = nil
    temp = nil
    vel = nil
    vel_2 = nil
    infil_coeffs = [cst, temp, vel, vel_2]
    model.getSpaces.sort.each do |space|
      # Infiltration at the space level
      unless space.spaceInfiltrationDesignFlowRates.empty?
        old_infil = space.spaceInfiltrationDesignFlowRates[0]
        cst = old_infil.constantTermCoefficient
        temp = old_infil.temperatureTermCoefficient
        vel = old_infil.velocityTermCoefficient
        vel_2 = old_infil.velocitySquaredTermCoefficient
        old_infil_coeffs = [cst, temp, vel, vel_2] if !(cst.nil? && temp.nil? && vel.nil? && vel_2.nil?)
        # Return flow per space floor area if method is inconsisten in proposed model
        return [0.0, 0.0, 0.224, 0.0] if infil_coeffs != old_infil_coeffs && !(infil_coeffs[0].nil? &&
                                                                                    infil_coeffs[1].nil? &&
                                                                                    infil_coeffs[2].nil? &&
                                                                                    infil_coeffs[3].nil?)

        infil_coeffs = old_infil_coeffs
      end

      # Infiltration at the space type level
      if infil_coeffs == [nil, nil, nil, nil] && space.spaceType.is_initialized
        space_type = space.spaceType.get
        unless space_type.spaceInfiltrationDesignFlowRates.empty?
          old_infil = space_type.spaceInfiltrationDesignFlowRates[0]
          cst = old_infil.constantTermCoefficient
          temp = old_infil.temperatureTermCoefficient
          vel = old_infil.velocityTermCoefficient
          vel_2 = old_infil.velocitySquaredTermCoefficient
          old_infil_coeffs = [cst, temp, vel, vel_2] if !(cst.nil? && temp.nil? && vel.nil? && vel_2.nil?)
          # Return flow per space floor area if method is inconsisten in proposed model
          return [0.0, 0.0, 0.224, 0.0] unless infil_coeffs != old_infil_coeffs && !(infil_coeffs[0].nil? &&
                                                                                      infil_coeffs[1].nil? &&
                                                                                      infil_coeffs[2].nil? &&
                                                                                      infil_coeffs[3].nil?)

          infil_coeffs = old_infil_coeffs
        end
      end
    end
    return infil_coeffs
  end

  # This methods calculate the current model air leakage rate @ 75 Pa.
  # It assumes that the model follows the PRM methods, see G3.1.1.4
  # in 90.1-2019 for reference.
  #
  # @param [OpenStudio::Model::Model] OpenStudio Model object
  # @param [Double] Building envelope area as per 90.1 in m^2
  #
  # @return [Float] building model air leakage rate
  def model_current_building_envelope_infiltration_at_75pa(model, building_envelope_area_m2)
    bldg_air_leakage_rate = 0
    model.getSpaces.sort.each do |space|
      # Infiltration at the space level
      unless space.spaceInfiltrationDesignFlowRates.empty?
        infil_obj = space.spaceInfiltrationDesignFlowRates[0]
        unless infil_obj.designFlowRate.is_initialized
          if infil_obj.flowperSpaceFloorArea.is_initialized
            bldg_air_leakage_rate += infil_obj.flowperSpaceFloorArea.get * space.floorArea
          elsif infil_obj.flowperExteriorSurfaceArea.is_initialized
            bldg_air_leakage_rate += infil_obj.flowperExteriorSurfaceArea.get * space.exteriorArea
          elsif infil_obj.flowperExteriorWallArea.is_initialized
            bldg_air_leakage_rate += infil_obj.flowperExteriorWallArea.get * space.exteriorWallArea
          elsif infil_obj.airChangesperHour.is_initialized
            bldg_air_leakage_rate += infil_obj.airChangesperHour.get * space.volume / 3600
          end
        end
      end

      # Infiltration at the space type level
      if space.spaceType.is_initialized
        space_type = space.spaceType.get
        unless space_type.spaceInfiltrationDesignFlowRates.empty?
          infil_obj = space_type.spaceInfiltrationDesignFlowRates[0]
          unless infil_obj.designFlowRate.is_initialized
            if infil_obj.flowperSpaceFloorArea.is_initialized
              bldg_air_leakage_rate += infil_obj.flowperSpaceFloorArea.get * space.floorArea
            elsif infil_obj.flowperExteriorSurfaceArea.is_initialized
              bldg_air_leakage_rate += infil_obj.flowperExteriorSurfaceArea.get * space.exteriorArea
            elsif infil_obj.flowperExteriorWallArea.is_initialized
              bldg_air_leakage_rate += infil_obj.flowperExteriorWallArea.get * space.exteriorWallArea
            elsif infil_obj.airChangesperHour.is_initialized
              bldg_air_leakage_rate += infil_obj.airChangesperHour.get * space.volume / 3600
            end
          end
        end
      end
    end
    # adjust_infiltration_to_prototype_building_conditions(1) corresponds
    # to the 0.112 shown in G3.1.1.4
    curr_tot_infil_m3_per_s_per_envelope_area = bldg_air_leakage_rate / adjust_infiltration_to_prototype_building_conditions(1) / building_envelope_area_m2
    return curr_tot_infil_m3_per_s_per_envelope_area
  end

  # This method calculates the building envelope infiltration,
  # this approach uses the 90.1 PRM rules
  #
  # @return [Float] building envelope infiltration
  def model_adjusted_building_envelope_infiltration(model, building_envelope_area_m2)
    # Determine the total building baseline infiltration rate in cfm per ft2 of the building envelope at 75 Pa
    basic_infil_rate_cfm_per_ft2 = space_infiltration_rate_75_pa

    # Do nothing if no infiltration
    return 0.0 if basic_infil_rate_cfm_per_ft2.zero?

    # Conversion factor
    conv_fact = OpenStudio.convert(1, 'm^3/s', 'ft^3/min').to_f / OpenStudio.convert(1, 'm^2', 'ft^2').to_f

    # Adjust the infiltration rate to the average pressure for the prototype buildings.
    # adj_infil_rate_cfm_per_ft2 = 0.112 * basic_infil_rate_cfm_per_ft2
    adj_infil_rate_cfm_per_ft2 = adjust_infiltration_to_prototype_building_conditions(basic_infil_rate_cfm_per_ft2)
    adj_infil_rate_m3_per_s_per_m2 = adj_infil_rate_cfm_per_ft2 / conv_fact

    # Calculate the total infiltration
    tot_infil_m3_per_s = adj_infil_rate_m3_per_s_per_m2 * building_envelope_area_m2

    return tot_infil_m3_per_s
  end

  # Apply the standard construction to each surface in the model, based on the construction type currently assigned.
  #
  # @return [Bool] true if successful, false if not
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Bool] returns true if successful, false if not
  def model_apply_standard_constructions(model, climate_zone, wwr_building_type = nil, wwr_info = {})
    types_to_modify = []

    # Possible boundary conditions are
    # Adiabatic
    # Surface
    # Outdoors
    # Ground
    # Foundation
    # GroundFCfactorMethod
    # OtherSideCoefficients
    # OtherSideConditionsModel
    # GroundSlabPreprocessorAverage
    # GroundSlabPreprocessorCore
    # GroundSlabPreprocessorPerimeter
    # GroundBasementPreprocessorAverageWall
    # GroundBasementPreprocessorAverageFloor
    # GroundBasementPreprocessorUpperWall
    # GroundBasementPreprocessorLowerWall

    # Possible surface types are
    # Floor
    # Wall
    # RoofCeiling
    # FixedWindow
    # OperableWindow
    # Door
    # GlassDoor
    # OverheadDoor
    # Skylight
    # TubularDaylightDome
    # TubularDaylightDiffuser

    # Create an array of surface types
    types_to_modify << ['Outdoors', 'Floor']
    types_to_modify << ['Outdoors', 'Wall']
    types_to_modify << ['Outdoors', 'RoofCeiling']
    types_to_modify << ['Outdoors', 'FixedWindow']
    types_to_modify << ['Outdoors', 'OperableWindow']
    types_to_modify << ['Outdoors', 'Door']
    types_to_modify << ['Outdoors', 'GlassDoor']
    types_to_modify << ['Outdoors', 'OverheadDoor']
    types_to_modify << ['Outdoors', 'Skylight']
    types_to_modify << ['Surface', 'Floor']
    types_to_modify << ['Surface', 'Wall']
    types_to_modify << ['Surface', 'RoofCeiling']
    types_to_modify << ['Surface', 'FixedWindow']
    types_to_modify << ['Surface', 'OperableWindow']
    types_to_modify << ['Surface', 'Door']
    types_to_modify << ['Surface', 'GlassDoor']
    types_to_modify << ['Surface', 'OverheadDoor']
    types_to_modify << ['Ground', 'Floor']
    types_to_modify << ['Ground', 'Wall']
    types_to_modify << ['Foundation', 'Wall']
    types_to_modify << ['GroundFCfactorMethod', 'Wall']
    types_to_modify << ['OtherSideCoefficients', 'Wall']
    types_to_modify << ['OtherSideConditionsModel', 'Wall']
    types_to_modify << ['GroundBasementPreprocessorAverageWall', 'Wall']
    types_to_modify << ['GroundBasementPreprocessorUpperWall', 'Wall']
    types_to_modify << ['GroundBasementPreprocessorLowerWall', 'Wall']
    types_to_modify << ['Foundation', 'Floor']
    types_to_modify << ['GroundFCfactorMethod', 'Floor']
    types_to_modify << ['OtherSideCoefficients', 'Floor']
    types_to_modify << ['OtherSideConditionsModel', 'Floor']
    types_to_modify << ['GroundSlabPreprocessorAverage', 'Floor']
    types_to_modify << ['GroundSlabPreprocessorCore', 'Floor']
    types_to_modify << ['GroundSlabPreprocessorPerimeter', 'Floor']

    # Find just those surfaces
    surfaces_to_modify = []
    surface_category = {}
    org_surface_boundary_conditions = {}
    types_to_modify.each do |boundary_condition, surface_type|
      # Surfaces
      model.getSurfaces.sort.each do |surf|
        next unless surf.outsideBoundaryCondition == boundary_condition
        next unless surf.surfaceType == surface_type

        # Check if surface is adjacent to an unenclosed or unconditioned space (e.g. attic or parking garage)
        if surf.outsideBoundaryCondition == 'Surface'
          adj_space = surf.adjacentSurface.get.space.get
          adj_space_cond_type = space_conditioning_category(adj_space)
          if adj_space_cond_type == 'Unconditioned'
            # Get adjacent surface
            adjacent_surf = surf.adjacentSurface.get

            # Store original boundary condition type
            org_surface_boundary_conditions[surf.name.to_s] = adjacent_surf

            # Temporary change the surface's boundary condition to 'Outdoors' so it can be assigned a baseline construction
            surf.setOutsideBoundaryCondition('Outdoors')
            adjacent_surf.setOutsideBoundaryCondition('Outdoors')
          end
        end

        if boundary_condition == 'Outdoors'
          surface_category[surf] = 'ExteriorSurface'
        elsif ['Ground', 'Foundation', 'GroundFCfactorMethod', 'OtherSideCoefficients', 'OtherSideConditionsModel', 'GroundSlabPreprocessorAverage', 'GroundSlabPreprocessorCore', 'GroundSlabPreprocessorPerimeter', 'GroundBasementPreprocessorAverageWall', 'GroundBasementPreprocessorAverageFloor', 'GroundBasementPreprocessorUpperWall', 'GroundBasementPreprocessorLowerWall'].include?(boundary_condition)
          surface_category[surf] = 'GroundSurface'
        else
          surface_category[surf] = 'NA'
        end
        surfaces_to_modify << surf
      end

      # SubSurfaces
      model.getSubSurfaces.sort.each do |surf|
        next unless surf.outsideBoundaryCondition == boundary_condition
        next unless surf.subSurfaceType == surface_type

        surface_category[surf] = 'ExteriorSubSurface'
        surfaces_to_modify << surf
      end
    end

    # Modify these surfaces
    prev_created_consts = {}
    surfaces_to_modify.sort.each do |surf|
      # Get space conditioning
      space = surf.space.get
      space_cond_type = space_conditioning_category(space)

      # Do not modify constructions for unconditioned spaces
      prev_created_consts = planar_surface_apply_standard_construction(surf, climate_zone, prev_created_consts, wwr_building_type, wwr_info, surface_category[surf]) unless space_cond_type == 'Unconditioned'

      # Reset boundary conditions to original if they were temporary modified
      if org_surface_boundary_conditions.include?(surf.name.to_s)
        surf.setAdjacentSurface(org_surface_boundary_conditions[surf.name.to_s])
      end
    end

    # List the unique array of constructions
    if prev_created_consts.size.zero?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', 'None of the constructions in your proposed model have both Intended Surface Type and Standards Construction Type')
    else
      prev_created_consts.each do |surf_type, construction|
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "For #{surf_type.join(' ')}, applied #{construction.name}.")
      end
    end

    return true
  end

  # Go through the default construction sets and hard-assigned constructions.
  # Clone the existing constructions and set their intended surface type and standards construction type per the PRM.
  # For some standards, this will involve making modifications.  For others, it will not.
  #
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  def model_apply_prm_construction_types(model)
    types_to_modify = []

    # Possible boundary conditions are
    # Adiabatic
    # Surface
    # Outdoors
    # Ground
    # Foundation
    # GroundFCfactorMethod
    # OtherSideCoefficients
    # OtherSideConditionsModel
    # GroundSlabPreprocessorAverage
    # GroundSlabPreprocessorCore
    # GroundSlabPreprocessorPerimeter
    # GroundBasementPreprocessorAverageWall
    # GroundBasementPreprocessorAverageFloor
    # GroundBasementPreprocessorUpperWall
    # GroundBasementPreprocessorLowerWall

    # Possible surface types are
    # AtticFloor
    # AtticWall
    # AtticRoof
    # DemisingFloor
    # DemisingWall
    # DemisingRoof
    # ExteriorFloor
    # ExteriorWall
    # ExteriorRoof
    # ExteriorWindow
    # ExteriorDoor
    # GlassDoor
    # GroundContactFloor
    # GroundContactWall
    # GroundContactRoof
    # InteriorFloor
    # InteriorWall
    # InteriorCeiling
    # InteriorPartition
    # InteriorWindow
    # InteriorDoor
    # OverheadDoor
    # Skylight
    # TubularDaylightDome
    # TubularDaylightDiffuser

    # Possible standards construction types
    # Mass
    # SteelFramed
    # WoodFramed
    # IEAD
    # View
    # Daylight
    # Swinging
    # NonSwinging
    # Heated
    # Unheated
    # RollUp
    # Sliding
    # Metal
    # Nonmetal framing (all)
    # Metal framing (curtainwall/storefront)
    # Metal framing (entrance door)
    # Metal framing (all other)
    # Metal Building
    # Attic and Other
    # Glass with Curb
    # Plastic with Curb
    # Without Curb

    # Create an array of types
    types_to_modify << ['Outdoors', 'ExteriorWall', 'SteelFramed']
    types_to_modify << ['Outdoors', 'ExteriorRoof', 'IEAD']
    types_to_modify << ['Outdoors', 'ExteriorFloor', 'SteelFramed']
    types_to_modify << ['Ground', 'GroundContactFloor', 'Unheated']
    types_to_modify << ['Ground', 'GroundContactWall', 'Mass']

    # Foundation
    types_to_modify << ['Foundation', 'GroundContactFloor', 'Unheated']
    types_to_modify << ['Foundation', 'GroundContactWall', 'Mass']

    # F/C-Factor methods
    types_to_modify << ['GroundFCfactorMethod', 'GroundContactFloor', 'Unheated']
    types_to_modify << ['GroundFCfactorMethod', 'GroundContactWall', 'Mass']

    # Other side coefficients
    types_to_modify << ['OtherSideCoefficients', 'GroundContactFloor', 'Unheated']
    types_to_modify << ['OtherSideConditionsModel', 'GroundContactFloor', 'Unheated']
    types_to_modify << ['OtherSideCoefficients', 'GroundContactWall', 'Mass']
    types_to_modify << ['OtherSideConditionsModel', 'GroundContactWall', 'Mass']

    # Slab preprocessor
    types_to_modify << ['GroundSlabPreprocessorAverage', 'GroundContactFloor', 'Unheated']
    types_to_modify << ['GroundSlabPreprocessorCore', 'GroundContactFloor', 'Unheated']
    types_to_modify << ['GroundSlabPreprocessorPerimeter', 'GroundContactFloor', 'Unheated']

    # Basement preprocessor
    types_to_modify << ['GroundBasementPreprocessorAverageWall', 'GroundContactWall', 'Mass']
    types_to_modify << ['GroundBasementPreprocessorAverageFloor', 'GroundContactFloor', 'Unheated']
    types_to_modify << ['GroundBasementPreprocessorUpperWall', 'GroundContactWall', 'Mass']
    types_to_modify << ['GroundBasementPreprocessorLowerWall', 'GroundContactWall', 'Mass']

    # Modify all constructions of each type
    types_to_modify.each do |boundary_cond, surf_type, const_type|
      constructions = model_find_constructions(model, boundary_cond, surf_type)

      constructions.sort.each do |const|
        standards_info = const.standardsInformation
        standards_info.setIntendedSurfaceType(surf_type)
        standards_info.setStandardsConstructionType(const_type)
      end
    end

    return true
  end

  # Reduces the SRR to the values specified by the PRM. SRR reduction will be done by shrinking vertices toward the centroid.
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  def model_apply_prm_baseline_skylight_to_roof_ratio(model)
    # Loop through all spaces in the model, and
    # per the 90.1-2019 PRM User Manual, only
    # account for exterior roofs for enclosed
    # spaces. Include space multipliers.
    roof_m2 = 0.001 # Avoids divide by zero errors later
    sky_m2 = 0
    total_roof_m2 = 0.001
    total_subsurface_m2 = 0
    model.getSpaces.sort.each do |space|
      next if space_conditioning_category(space) == 'Unconditioned'

      # Loop through all surfaces in this space
      roof_area_m2 = 0
      sky_area_m2 = 0
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'

        # This roof's gross area (including skylight area)
        roof_area_m2 += surface.grossArea * space.multiplier
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'Skylight'

          sky_area_m2 += ss.netArea * space.multiplier
        end
      end

      total_roof_m2 += roof_area_m2
      total_subsurface_m2 += sky_area_m2
    end

    # Calculate the SRR of each category
    srr = ((total_subsurface_m2 / total_roof_m2) * 100.0).round(1)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The skylight to roof ratios (SRRs) is: : #{srr.round}%.")

    # SRR limit
    srr_lim = model_prm_skylight_to_roof_ratio_limit(model)

    # Check against SRR limit
    red = srr > srr_lim

    # Stop here unless skylights need reducing
    return true unless red

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Reducing the size of all skylights equally down to the limit of #{srr_lim.round}%.")

    # Determine the factors by which to reduce the skylight area
    mult = srr_lim / srr

    # Reduce the skylight area if any of the categories necessary
    model.getSpaces.sort.each do |space|
      next if space_conditioning_category(space) == 'Unconditioned'

      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'

        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'Skylight'

          # Reduce the size of the skylight
          red = 1.0 - mult
          sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid(ss, red)
        end
      end
    end

    return true
  end

  # Add design day schedule objects for space loads, for PRM 2019 baseline models
  # @author Xuechen (Jerry) Lei, PNNL
  # @param model [OpenStudio::model::Model] OpenStudio model object
  #
  def model_apply_prm_baseline_sizing_schedule(model)
    space_loads = model.getSpaceLoads
    loads = []
    space_loads.sort.each do |space_load|
      load_type = space_load.iddObjectType.valueName.sub('OS_', '').strip.sub('_', '')
      casting_method_name = "to_#{load_type}"
      if space_load.respond_to?(casting_method_name)
        casted_load = space_load.public_send(casting_method_name).get
        loads << casted_load
      else
        p 'Need Debug, casting method not found @JXL'
      end
    end

    load_schedule_name_hash = {
      'People' => 'numberofPeopleSchedule',
      'Lights' => 'schedule',
      'ElectricEquipment' => 'schedule',
      'GasEquipment' => 'schedule',
      'SpaceInfiltration_DesignFlowRate' => 'schedule'
    }

    loads.each do |load|
      load_type = load.iddObjectType.valueName.sub('OS_', '').strip
      load_schedule_name = load_schedule_name_hash[load_type]
      next unless !load_schedule_name.nil?

      # check if the load is in a dwelling space
      if load.spaceType.is_initialized
        space_type = load.spaceType.get
      elsif load.space.is_initialized && load.space.get.spaceType.is_initialized
        space_type = load.space.get.spaceType.get
      else
        space_type = nil
        puts "No hosting space/spacetype found for load: #{load.name}"
      end
      if !space_type.nil? && /apartment/i =~ space_type.standardsSpaceType.to_s
        load_in_dwelling = true
      else
        load_in_dwelling = false
      end

      load_schedule = load.public_send(load_schedule_name).get
      schedule_type = load_schedule.iddObjectType.valueName.sub('OS_', '').strip.sub('_', '')
      load_schedule = load_schedule.public_send("to_#{schedule_type}").get

      case schedule_type
      when 'ScheduleRuleset'
        load_schmax = get_8760_values_from_schedule(model, load_schedule).max
        load_schmin = get_8760_values_from_schedule(model, load_schedule).min
        load_schmode = get_weekday_values_from_8760(model,
                                                    Array(get_8760_values_from_schedule(model, load_schedule)),
                                                    value_includes_holiday = true).mode[0]

        # AppendixG-2019 G3.1.2.2.1
        if load_type == 'SpaceInfiltration_DesignFlowRate'
          summer_value = load_schmax
          winter_value = load_schmax
        else
          summer_value = load_schmax
          winter_value = load_schmin
        end

        # AppendixG-2019 Exception to G3.1.2.2.1
        if load_in_dwelling
          summer_value = load_schmode
        end

        # set cooling design day schedule
        summer_dd_schedule = OpenStudio::Model::ScheduleDay.new(model)
        summer_dd_schedule.setName("#{load.name} Summer Design Day")
        summer_dd_schedule.addValue(OpenStudio::Time.new(1.0), summer_value)
        load_schedule.setSummerDesignDaySchedule(summer_dd_schedule)

        # set heating design day schedule
        winter_dd_schedule = OpenStudio::Model::ScheduleDay.new(model)
        winter_dd_schedule.setName("#{load.name} Winter Design Day")
        winter_dd_schedule.addValue(OpenStudio::Time.new(1.0), winter_value)
        load_schedule.setWinterDesignDaySchedule(winter_dd_schedule)

      when 'ScheduleConstant'
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Space load #{load.name} has schedule type of ScheduleConstant. Nothing to be done for ScheduleConstant")
        next
      end
    end
  end

  # Applies the multi-zone VAV outdoor air sizing requirements to all applicable air loops in the model.
  # @note This is not applicable to the stable baseline; hence no action in this method
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  def model_apply_multizone_vav_outdoor_air_sizing(model)
    return
  end


  # Identifies non mechanically cooled ("nmc") systems, if applicable
  #
  # TODO: Zone-level evaporative cooler is not currently supported by
  #       by OpenStudio, will need to be added to the method when
  #       supported.
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @return zone_nmc_sys_type [Hash] Zone to nmc system type mapping
  def model_identify_non_mechanically_cooled_systems(model)
    # Iterate through zones to find out if they are served by nmc systems
    model.getThermalZones.sort.each do |zone|
      # Check if airloop has economizer and either:
      # - No cooling coil and/or,
      # - An evaporative cooling coil
      air_loop = zone.airLoopHVAC

      unless air_loop.empty?
        # Iterate through all the airloops assigned to a zone
        zone.airLoopHVACs.each do |airloop|
          air_loop = air_loop.get
          if (!air_loop_hvac_include_cooling_coil?(air_loop) &&
            air_loop_hvac_include_evaporative_cooler?(air_loop)) ||
             (!air_loop_hvac_include_cooling_coil?(air_loop) &&
               air_loop_hvac_include_economizer?(air_loop))
            air_loop.additionalProperties.setFeature('non_mechanically_cooled', true)
            air_loop.thermalZones.each do |thermal_zone|
              thermal_zone.additionalProperties.setFeature('non_mechanically_cooled', true)
            end
          end
        end
      end
    end
  end

  # Specify supply air temperature setpoint for unit heaters based on 90.1 Appendix G G3.1.2.8.2
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone Object
  #
  # @return [Double] for zone with unit heaters, return design supply temperature; otherwise, return nil
  def thermal_zone_prm_unitheater_design_supply_temperature(thermal_zone)
    thermal_zone.equipment.each do |eqt|
      if eqt.to_ZoneHVACUnitHeater.is_initialized
        return OpenStudio.convert(105, 'F', 'C').get
      end
    end
    return nil
  end

  # Specify supply to room delta for laboratory spaces based on 90.1 Appendix G Exception to G3.1.2.8.1
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone Object
  #
  # @return [Double] for zone with laboratory space, return 17; otherwise, return nil
  def thermal_zone_prm_lab_delta_t(thermal_zone)
    # For labs, add 17 delta-T; otherwise, add 20 delta-T
    thermal_zone.spaces.each do |space|
      space_std_type = space.spaceType.get.standardsSpaceType.get
      if space_std_type == 'laboratory'
        return 17
      end
    end
    return nil
  end

  # Indicate if fan power breakdown (supply, return, and relief)
  # are needed
  #
  # @return [Boolean] true if necessary, false otherwise
  def model_get_fan_power_breakdown
    return true
  end

  # Template method for adding a setpoint manager for a coil control logic to a heating coil.
  # ASHRAE 90.1-2019 Appendix G.
  #
  # @param model [OpenStudio::Model::Model] Openstudio model
  # @param thermalZones Array([OpenStudio::Model::ThermalZone]) thermal zone array
  # @param coil Heating Coils
  # @return [Boolean] true
  def model_set_central_preheat_coil_spm(model, thermalZones, coil)
    # search for the highest zone setpoint temperature
    max_heat_setpoint = 0.0
    coil_name = coil.name.get.to_s
    thermalZones.each do |zone|
      tstat = zone.thermostatSetpointDualSetpoint
      if tstat.is_initialized
        tstat = tstat.get
        setpoint_sch = tstat.heatingSetpointTemperatureSchedule
        setpoint_min_max = search_min_max_value_from_design_day_schedule(setpoint_sch, 'heating')
        setpoint_c = setpoint_min_max['max']
        if setpoint_c > max_heat_setpoint
          max_heat_setpoint = setpoint_c
        end
      end
    end
    # in this situation, we hard set the temperature to be 22 F
    # (ASHRAE 90.1 Room heating stepoint temperature is 72 F)
    max_heat_setpoint = 22.2 if max_heat_setpoint == 0.0

    max_heat_setpoint_f = OpenStudio.convert(max_heat_setpoint, 'C', 'F').get
    preheat_setpoint_f = max_heat_setpoint_f - 20
    preheat_setpoint_c = OpenStudio.convert(preheat_setpoint_f, 'F', 'C').get

    # create a new constant schedule and this method will add schedule limit type
    preheat_coil_sch = model_add_constant_schedule_ruleset(model,
                                                           preheat_setpoint_c,
                                                           name = "#{coil_name} Setpoint Temp - #{preheat_setpoint_f.round}F")
    preheat_coil_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, preheat_coil_sch)
    preheat_coil_manager.setName("#{coil_name} Preheat Coil Setpoint Manager")

    if coil.to_CoilHeatingWater.is_initialized
      preheat_coil_manager.addToNode(coil.airOutletModelObject.get.to_Node.get)
    elsif coil.to_CoilHeatingElectric.is_initialized
      preheat_coil_manager.addToNode(coil.outletModelObject.get.to_Node.get)
    elsif coil.to_CoilHeatingGas.is_initialized
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.models.CoilHeatingGas', 'Preheat coils in baseline system shall only be electric or hydronic. Current coil type: Natural Gas')
      preheat_coil_manager.addToNode(coil.airOutletModelObject.get.to_Node.get)
    end

    return true
  end

  # A template method that handles the loading of user input data from multiple sources
  # include data source from:
  # 1. user data csv files
  # 2. data from measure and OpenStudio interface
  # @param [Openstudio:model:Model] model
  # @param [String] climate_zone
  # @param [String] default_hvac_building_type
  # @param [String] default_wwr_building_type
  # @param [String] default_swh_building_type
  # @param [Hash] bldg_type_hvac_zone_hash A hash maps building type for hvac to a list of thermal zones
  # @return True
  def handle_user_input_data(model, climate_zone, default_hvac_building_type, default_wwr_building_type, default_swh_building_type, bldg_type_hvac_zone_hash)
    # load the multiple building area types from user data
    handle_multi_building_area_types(model, climate_zone, default_hvac_building_type, default_wwr_building_type, default_swh_building_type, bldg_type_hvac_zone_hash)
    # load user data from proposed model
    handle_airloop_user_input_data(model)
    # load air loop DOAS user data from the proposed model
    handle_airloop_doas_user_input_data(model)
    # load zone HVAC user data from proposed model
    handle_zone_hvac_user_input_data(model)
  end

  # A function to load airloop data from userdata csv files
  # @param [OpenStudio::Model::Model] OpenStudio model object
  def handle_airloop_user_input_data(model)
    # ============================Process airloop info ============================================
    user_airloops = @standards_data.key?('userdata_airloop_hvac') ? @standards_data['userdata_airloop_hvac'] : nil
    model.getAirLoopHVACs.each do |air_loop|
      air_loop_name = air_loop.name.get
      if user_airloops && user_airloops.length > 1
        user_airloops.each do |user_airloop|
          if air_loop_name == user_airloop['name']
            # gas phase air cleaning is system base - add proposed hvac system name to zones
            if user_airloop.key?('economizer_exception_for_gas_phase_air_cleaning') && !user_airloop['economizer_exception_for_gas_phase_air_cleaning'].nil?
              if user_airloop['economizer_exception_for_gas_phase_air_cleaning'].downcase == 'yes'
                air_loop.thermalZones.each do |thermal_zone|
                  thermal_zone.additionalProperties.setFeature('economizer_exception_for_gas_phase_air_cleaning', air_loop_name)
                end
              end
            end
            # Open refrigerated cases is zone based - add yes or no to zones
            if user_airloop.key?('economizer_exception_for_open_refrigerated_cases') && !user_airloop['economizer_exception_for_open_refrigerated_cases'].nil?
              if user_airloop['economizer_exception_for_open_refrigerated_cases'].downcase == 'yes'
                air_loop.thermalZones.each do |thermal_zone|
                  thermal_zone.additionalProperties.setFeature('economizer_exception_for_open_refrigerated_cases', 'yes')
                end
              end
            end
            # Fan power credits
            user_airloop.keys.each do |info_key|
              if info_key.include?('fan_power_credit')
                if !user_airloop[info_key].to_s.empty?
                  if info_key.include?('has_')
                    if user_airloop[info_key].downcase == 'yes'
                      air_loop.thermalZones.each do |thermal_zone|
                        if thermal_zone.additionalProperties.hasFeature(info_key)
                          current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                          thermal_zone.additionalProperties.setFeature(info_key, current_value + 1.0)
                        else
                          thermal_zone.additionalProperties.setFeature(info_key, 1.0)
                        end
                      end
                    end
                  else
                    air_loop.thermalZones.each do |thermal_zones|
                      if thermal_zone.additionalProperties.hasFeature(info_key)
                        current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                        thermal_zone.additionalProperties.setFeature(info_key, current_value + user_airloop[info_key])
                      else
                        thermal_zone.additionalProperties.setFeature(info_key, user_airloop[info_key])
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  # A function to load airloop DOAS data from userdata csv files
  # @param [OpenStudio::Model::Model] OpenStudio model object
  def handle_airloop_doas_user_input_data(model)
    # Get user data
    user_airloop_doass = @standards_data.key?('userdata_airloop_hvac_doas') ? @standards_data['userdata_airloop_hvac_doas'] : nil

    # Parse user data
    if user_airloop_doass && user_airloop_doass.length >= 1
      user_airloop_doass.each do |user_airloop_doas|
        # Get AirLoopHVACDedicatedOutdoorAirSystem
        air_loop_doas = model.getAirLoopHVACDedicatedOutdoorAirSystemByName(user_airloop_doas['name'])
        if !air_loop_doas.is_initialized
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.ashrae_90_1_prm.Model', "The AirLoopHVACDedicatedOutdoorAirSystem named #{user_airloop_doass['name']} mentioned in the userdata_airloop_hvac_doas was not found in the model, user specified data associated with it will be ignored.")
          next
        else
          air_loop_doas = air_loop_doas.get
        end

        # Parse fan power credits data
        user_airloop_doas.keys.each do |info_key|
          if info_key.include?('fan_power_credit')
            if !user_airloop_doas[info_key].to_s.empty?
              # Case 1: Yes/no
              if info_key.include?('has_')
                if user_airloop_doas[info_key].downcase == 'yes'
                  air_loop_doas.airLoops.each do |air_loop|
                    air_loop.thermalZones.each do |thermal_zone|
                      if thermal_zone.additionalProperties.hasFeature(info_key)
                        current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                        thermal_zone.additionalProperties.setFeature(info_key, current_value + 1.0)
                      else
                        thermal_zone.additionalProperties.setFeature(info_key, 1.0)
                      end
                    end
                  end
                end
              else
                # Case 2: user provided value
                air_loop_doas.airLoops.each do |air_loop|
                  air_loop.thermalZones.each do |thermal_zones|
                    if thermal_zone.additionalProperties.hasFeature(info_key)
                      current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                      thermal_zone.additionalProperties.setFeature(info_key, current_value + user_airloop_doas[info_key])
                    else
                      thermal_zone.additionalProperties.setFeature(info_key, user_airloop_doas[info_key])
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  # Analyze HVAC, window-to-wall ratio and SWH building (area) types from user data inputs in the @standard_data library
  # This function returns True, but the values are stored in the multi-building_data argument.
  # The hierarchy for process the building types
  # 1. Highest: PRM rules - if rules applied against user inputs, the function will use the calculated value to reset the building type
  # 2. Second: User defined building type in the csv file.
  # 3. Third: User defined userdata_building.csv file. If an object (e.g. space, thermalzone) are not defined in their correspondent userdata csv file, use the building csv file
  # 4. Fourth: Dropdown list in the measure GUI. If none presented, use the data from the dropdown list.
  # NOTE! This function will add building types to OpenStudio objects as an additional features for hierarchy 1-3
  # The object additional feature is empty when the function determined it uses fourth hierarchy.
  #
  # @param [OpenStudio::Model::Model] model
  # @param [String] climate_zone
  # @param [String] default_hvac_building_type (Fourth Hierarchy hvac building type)
  # @param [String] default_wwr_building_type (Fourth Hierarchy wwr building type)
  # @param [String] default_swh_building_type (Fourth Hierarchy swh building type)
  # @param [Hash] bldg_type_zone_hash An empty hash that maps building type for hvac to a list of thermal zones
  # @return True
  def handle_multi_building_area_types(model, climate_zone, default_hvac_building_type, default_wwr_building_type, default_swh_building_type, bldg_type_hvac_zone_hash)
    # Construct the user_building hashmap
    user_buildings = @standards_data.key?('userdata_building') ? @standards_data['userdata_building'] : nil

    # Build up a hvac_building_type : thermal zone hash map
    # =============================HVAC user data process===========================================
    user_thermal_zones = @standards_data.key?('userdata_thermal_zone') ? @standards_data['userdata_thermal_zone'] : nil
    # First construct hvac building type -> thermal Zone hash and hvac building type -> floor area
    bldg_type_zone_hash = {}
    bldg_type_zone_area_hash = {}
    model.getThermalZones.each do |thermal_zone|
      # get climate zone to check the conditioning category
      thermal_zone_condition_category = thermal_zone_conditioning_category(thermal_zone, climate_zone)
      if thermal_zone_condition_category == 'Semiheated' || thermal_zone_condition_category == 'Unconditioned'
        next
      end

      # Check for Second hierarchy
      hvac_building_type = nil
      if user_thermal_zones && user_thermal_zones.length >= 1
        user_thermal_zone_index = user_thermal_zones.index { |user_thermal_zone| user_thermal_zone['name'] == thermal_zone.name.get }
        # make sure the thermal zone has assigned a building_type_for_hvac
        unless user_thermal_zone_index.nil? || user_thermal_zones[user_thermal_zone_index]['building_type_for_hvac'].nil?
          # Only thermal zone in the user data and have building_type_for_hvac data will be assigned.
          hvac_building_type = user_thermal_zones[user_thermal_zone_index]['building_type_for_hvac']
        end
      end
      # Second hierarchy does not apply, check Third hierarchy
      if hvac_building_type.nil? && user_buildings && user_buildings.length >= 1
        building_name = thermal_zone.model.building.get.name.get
        user_building_index = user_buildings.index { |user_building| user_building['name'] == building_name }
        unless user_building_index.nil? || user_buildings[user_building_index]['building_type_for_hvac'].nil?
          # Only thermal zone in the buildings user data and have building_type_for_hvac data will be assigned.
          hvac_building_type = user_buildings[user_building_index]['building_type_for_hvac']
        end
      end
      # Third hierarchy does not apply, apply Fourth hierarchy
      if hvac_building_type.nil?
        hvac_building_type = default_hvac_building_type
      end
      # Add data to the hash map
      unless bldg_type_zone_hash.key?(hvac_building_type)
        bldg_type_zone_hash[hvac_building_type] = []
      end
      unless bldg_type_zone_area_hash.key?(hvac_building_type)
        bldg_type_zone_area_hash[hvac_building_type] = 0.0
      end
      # calculate floor area for the thermal zone
      part_of_floor_area = false
      thermal_zone.spaces.sort.each do |space|
        next unless space.partofTotalFloorArea

        # a space in thermal zone is part of floor area.
        part_of_floor_area = true
        bldg_type_zone_area_hash[hvac_building_type] += space.floorArea * space.multiplier
      end
      if part_of_floor_area
        # Only add the thermal_zone if it is part of the floor area
        bldg_type_zone_hash[hvac_building_type].append(thermal_zone)
      end
    end
    # Handle an edge case that all zones in the model are unconditioned.
    unless bldg_type_zone_hash.empty?
      # Calculate the total floor area.
      # If the max tie, this algorithm will pick the first encountered hvac building type as the maximum.
      total_floor_area = 0.0
      hvac_bldg_type_with_max_floor = nil
      hvac_bldg_type_max_floor_area = 0.0
      bldg_type_zone_area_hash.each do |key, value|
        if value > hvac_bldg_type_max_floor_area
          hvac_bldg_type_with_max_floor = key
          hvac_bldg_type_max_floor_area = value
        end
        total_floor_area += value
      end

      # Reset the thermal zones by going through the hierarchy 1 logics
      bldg_type_hvac_zone_hash.clear
      # Add the thermal zones for the maximum floor (primary system)
      bldg_type_hvac_zone_hash[hvac_bldg_type_with_max_floor] = bldg_type_zone_hash[hvac_bldg_type_with_max_floor]
      bldg_type_zone_hash.each do |bldg_type, bldg_type_zone|
        # loop the rest bldg_types
        unless bldg_type.eql? hvac_bldg_type_with_max_floor
          if OpenStudio.convert(total_floor_area, 'm^2', 'ft^2').get <= 40000
            # Building is smaller than 40k sqft, it could only have one hvac_building_type, reset all the thermal zones.
            bldg_type_hvac_zone_hash[hvac_bldg_type_with_max_floor].push(*bldg_type_zone)
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "The building floor area is less than 40,000 square foot. Thermal zones under hvac building type #{bldg_type} is reset to #{hvac_bldg_type_with_max_floor}")
          else
            if OpenStudio.convert(bldg_type_zone_area_hash[bldg_type], 'm^2', 'ft^2').get < 20000
              # in this case, all thermal zones shall be categorized as the primary hvac_building_type
              bldg_type_hvac_zone_hash[hvac_bldg_type_with_max_floor].push(*bldg_type_zone)
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "The floor area in hvac building type #{bldg_type} is less than 20,000 square foot. Thermal zones under this hvac building type is reset to #{hvac_bldg_type_with_max_floor}")
            else
              bldg_type_hvac_zone_hash[bldg_type] = bldg_type_zone
            end
          end
        end
      end

      # Write in hvac building type thermal zones by thermal zone
      bldg_type_hvac_zone_hash.each do |h1_bldg_type, bldg_type_zone_array|
        bldg_type_zone_array.each do |thermal_zone|
          thermal_zone.additionalProperties.setFeature('building_type_for_hvac', h1_bldg_type)
        end
      end
    end

    # =============================SPACE user data process===========================================
    user_spaces = @standards_data.key?('userdata_space') ? @standards_data['userdata_space'] : nil
    model.getSpaces.each do |space|
      type_for_wwr = nil
      # Check for 2nd level hierarchy
      if user_spaces && user_spaces.length >= 1
        user_spaces.each do |user_space|
          unless user_space['building_type_for_wwr'].nil?
            if space.name.get == user_space['name']
              type_for_wwr = user_space['building_type_for_wwr']
            end
          end
        end
      end

      if type_for_wwr.nil?
        # 2nd Hierarchy does not apply, check for 3rd level hierarchy
        building_name = space.model.building.get.name.get
        if user_buildings && user_buildings.length >= 1
          user_buildings.each do |user_building|
            unless user_building['building_type_for_wwr'].nil?
              if user_building['name'] == building_name
                type_for_wwr = user_building['building_type_for_wwr']
              end
            end
          end
        end
      end

      if type_for_wwr.nil?
        # 3rd level hierarchy does not apply, Apply 4th level hierarchy
        type_for_wwr = default_wwr_building_type
      end
      # add wwr type to space:
      space.additionalProperties.setFeature('building_type_for_wwr', type_for_wwr)
    end
    # =============================SWH user data process===========================================
    user_wateruse_equipments = @standards_data.key?('userdata_wateruse_equipment') ? @standards_data['userdata_wateruse_equipment'] : nil
    model.getWaterUseEquipments.each do |wateruse_equipment|
      type_for_swh = nil
      # Check for 2nd hierarchy
      if user_wateruse_equipments && user_wateruse_equipments.length >= 1
        user_wateruse_equipments.each do |user_wateruse_equipment|
          unless user_wateruse_equipment['building_type_for_swh'].nil?
            if wateruse_equipment.name.get == user_wateruse_equipment['name']
              type_for_swh = user_wateruse_equipment['building_type_for_swh']
            end
          end
        end
      end

      if type_for_swh.nil?
        # 2nd hierarchy does not apply, check for 3rd hierarchy
        # get space building type
        building_name = wateruse_equipment.model.building.get.name.get
        if user_buildings && user_buildings.length >= 1
          user_buildings.each do |user_building|
            unless user_building['building_type_for_swh'].nil?
              if user_building['name'] == building_name
                type_for_swh = user_building['building_type_for_swh']
              end
            end
          end
        end
      end

      if type_for_swh.nil?
        # 3rd hierarchy does not apply, apply 4th hierarchy
        type_for_swh = default_swh_building_type
      end
      # add swh type to wateruse equipment:
      wateruse_equipment.additionalProperties.setFeature('building_type_for_swh', type_for_swh)
    end
    return true
  end

  # Modify the existing service water heating loops to match the baseline required heating type.
  #
  # @param model [OpenStudio::Model::Model] the model
  # @param building_type [String] the building type
  # @return [Bool] returns true if successful, false if not
  def model_apply_baseline_swh_loops(model, building_type)
    model.getPlantLoops.sort.each do |plant_loop|
      # Skip non service water heating loops
      next unless plant_loop_swh_loop?(plant_loop)

      # Rename the loop to avoid accidentally hooking up the HVAC systems to this loop later.
      plant_loop.setName('Service Water Heating Loop')

      htg_fuels, combination_system, storage_capacity, total_heating_capacity = plant_loop_swh_system_type(plant_loop)

      # htg_fuels.size == 0 shoudln't happen

      electric = true

      if htg_fuels.include?('NaturalGas') ||
          htg_fuels.include?('PropaneGas') ||
          htg_fuels.include?('FuelOilNo1') ||
          htg_fuels.include?('FuelOilNo2') ||
          htg_fuels.include?('Coal') ||
          htg_fuels.include?('Diesel') ||
          htg_fuels.include?('Gasoline')
        electric = false
      end

      # Per Table G3.1 11.e, if the baseline system was a combination of heating and service water heating,
      # delete all heating equipment and recreate a WaterHeater:Mixed.

      if combination_system
        a = plant_loop.supplyComponents
        b = plant_loop.demandComponents
        plantloopComponents = a += b
        plantloopComponents.each do |component|
          # Get the object type
          obj_type = component.iddObjectType.valueName.to_s
          next if ['OS_Node', 'OS_Pump_ConstantSpeed', 'OS_Pump_VariableSpeed', 'OS_Connector_Splitter', 'OS_Connector_Mixer', 'OS_Pipe_Adiabatic'].include?(obj_type)

          component.remove
        end

        water_heater = OpenStudio::Model::WaterHeaterMixed.new(model)
        water_heater.setName('Baseline Water Heater')
        water_heater.setHeaterMaximumCapacity(total_heating_capacity)
        water_heater.setTankVolume(storage_capacity)
        plant_loop.addSupplyBranchForComponent(water_heater)

        if electric
          # G3.1.11.b: If electric, WaterHeater:Mixed with electric resistance
          water_heater.setHeaterFuelType('Electricity')
          water_heater.setHeaterThermalEfficiency(1.0)
        else
          # @todo for now, just get the first fuel that isn't Electricity
          # A better way would be to count the capacities associated
          # with each fuel type and use the preponderant one
          fuels = htg_fuels - ['Electricity']
          fossil_fuel_type = fuels[0]
          water_heater.setHeaterFuelType(fossil_fuel_type)
          water_heater.setHeaterThermalEfficiency(0.8)
        end
        # If it's not a combination heating and service water heating system
        # just change the fuel type of all water heaters on the system
        # to electric resistance if it's electric
      else
        # Per Table G3.1 11.i, piping losses was deleted

        a = plant_loop.supplyComponents
        b = plant_loop.demandComponents
        plantloopComponents = a += b
        plantloopComponents.each do |component|
          # Get the object type
          obj_type = component.iddObjectType.valueName.to_s
          next if !['OS_Pipe_Indoor', 'OS_Pipe_Outdoor'].include?(obj_type)
          pipe = component.to_PipeIndoor.get
          node = pipe.to_StraightComponent.get.outletModelObject.get.to_Node.get

          node_name = node.name.get
          pipe_name = pipe.name.get

          # Add Pipe_Adiabatic
          newpipe = OpenStudio::Model::PipeAdiabatic.new(model)
          newpipe.setName(pipe_name)
          newpipe.addToNode(node)
          component.remove
        end


        if electric
          plant_loop.supplyComponents.each do |component|
            next unless component.to_WaterHeaterMixed.is_initialized

            water_heater = component.to_WaterHeaterMixed.get
            # G3.1.11.b: If electric, WaterHeater:Mixed with electric resistance
            water_heater.setHeaterFuelType('Electricity')
            water_heater.setHeaterThermalEfficiency(1.0)
          end
        end
      end
    end

    # Set the water heater fuel types if it's 90.1-2013
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      water_heater_mixed_apply_prm_baseline_fuel_type(water_heater, building_type)
    end

    return true
  end

  # Check whether the baseline model generation needs to run all four orientations
  # The default shall be true
  #
  # @param [Boolean] run_all_orients: user inputs to indicate whether it is required to run all orientations
  # @param [OpenStudio::Model::Model] Openstudio model
  def run_all_orientations(run_all_orients, user_model)
    # Step 0, assign the default value
    run_orients_flag = run_all_orients
    # Step 1 check orientation variations - priority 2
    fenestration_area_hash = get_model_fenestration_area_by_orientation(user_model)
    fenestration_area_hash.each do |orientation, fenestration_area|
      fenestration_area_hash.each do |other_orientation, other_fenestration_area|
        next unless orientation != other_orientation

        variance = (other_fenestration_area - fenestration_area) / fenestration_area
        if variance.abs > 0.05
          # if greater then 0.05
          run_orients_flag = true
        end
      end
    end
    # Step 2 read user data - priority 1 - user data will override the priority 2
    user_buildings = @standards_data.key?('userdata_building') ? @standards_data['userdata_building'] : nil
    if user_buildings
      building_name = user_model.building.get.name.get
      user_building_index = user_buildings.index { |user_building| building_name.include? user_building['name'] }
      unless user_building_index.nil? || user_buildings[user_building_index]['is_exempt_from_rotations'].nil?
        # user data exempt the rotation, No indicates true for running orients.
        run_orients_flag = user_buildings[user_building_index]['is_exempt_from_rotations'].casecmp('No') == 0
      end
    end
    return run_orients_flag
  end

  def get_model_fenestration_area_by_orientation(user_model)
    # First index is wall, second index is window
    fenestration_area_hash = {
      'N' => 0.0,
      'S' => 0.0,
      'E' => 0.0,
      'W' => 0.0
    }
    user_model.getSpaces.each do |space|
      space_cond_type = space_conditioning_category(space)
      next if space_cond_type == 'Unconditioned'

      # Get zone multiplier
      multiplier = space.thermalZone.get.multiplier
      space.surfaces.each do |surface|
        next if surface.surfaceType != 'Wall'
        next if surface.outsideBoundaryCondition != 'Outdoors'

        orientation = surface_cardinal_direction(surface)
        surface.subSurfaces.each do |subsurface|
          subsurface_type = subsurface.subSurfaceType.to_s.downcase
          # Do not count doors
          next unless (subsurface_type.include? 'window') || (subsurface_type.include? 'glass')

          fenestration_area_hash[orientation] += subsurface.grossArea * subsurface.multiplier * multiplier
        end
      end
    end
    return fenestration_area_hash
  end

  # Apply the standard construction to each surface in the model, based on the construction type currently assigned.
  #
  # @return [Bool] true if successful, false if not
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Bool] returns true if successful, false if not
  def model_apply_constructions(model, climate_zone, wwr_building_type, wwr_info)
    model_apply_standard_constructions(model, climate_zone, wwr_building_type, wwr_info)

    return true
  end

  # Update ground temperature profile based on the weather file specified in the model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Bool] returns true if successful, false if not
  def model_update_ground_temperature_profile(model, climate_zone)
    # Check if the ground temperature profile is needed
    surfaces_with_fc_factor_boundary = false
    model.getSurfaces.each do |surface|
      if surface.outsideBoundaryCondition.to_s == 'GroundFCfactorMethod'
        surfaces_with_fc_factor_boundary = true
        break
      end
    end

    return false unless surfaces_with_fc_factor_boundary

    # Remove existing FCFactor temperature profile
    model.getSiteGroundTemperatureFCfactorMethod.remove

    # Get path to weather file specified in the model
    weather_file_path = model.getWeatherFile.path.get.to_s

    # Look for stat file corresponding to the weather file
    stat_file_path = weather_file_path.sub('.epw', '.stat').to_s
    if !File.exist? stat_file_path
      # When the stat file corresponding with the weather file in the model is missing,
      # use the weather file that represent the climate zone
      climate_zone_weather_file_map = model_get_climate_zone_weather_file_map
      weather_file = climate_zone_weather_file_map[climate_zone]
      stat_file_path = model_get_weather_file(weather_file).sub('.epw', '.stat').to_s
    end

    ground_temp = OpenStudio::Model::SiteGroundTemperatureFCfactorMethod.new(model)
    ground_temperatures = model_get_monthly_ground_temps_from_stat_file(stat_file_path)
    unless ground_temperatures.empty?
      # set the site ground temperature building surface
      ground_temp.setAllMonthlyTemperatures(ground_temperatures)
    end

    return true
  end

  # Generate baseline log to a specific file directory
  # @param file_directory [String] file directory
  def generate_baseline_log(file_directory)
    log_messages_to_file_prm("#{file_directory}/prm.log", false)
  end

  # Retrieve zone HVAC user specified compliance inputs from CSV file
  #
  # @param [OpenStudio::Model::Model] OpenStudio model object
  def handle_zone_hvac_user_input_data(model)
    user_zone_hvac = @standards_data.key?('userdata_zone_hvac') ? @standards_data['userdata_zone_hvac'] : nil
    return unless !user_zone_hvac.empty?

    zone_hvac_equipment = model.getZoneHVACComponents
    if zone_hvac_equipment.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.model', 'No zone HVAC equipment is present in the proposed model, user provided information cannot be used to generate the baseline building model.')
      return
    end

    user_zone_hvac.each do |zone_hvac_eqp_info|
      user_defined_zone_hvac_obj_name = zone_hvac_eqp_info['name']
      user_defined_zone_hvac_obj_type_name = zone_hvac_eqp_info['zone_hvac_object_type_name']

      # Check that the object type name do exist
      begin
        user_defined_zone_hvac_obj_type_name_idd = user_defined_zone_hvac_obj_type_name.to_IddObjectType
      rescue StandardError => e
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.model', "#{user_defined_zone_hvac_obj_type_name}, provided in the user zone HVAC user data, is not a valid OpenStudio model object.")
      end

      # Retrieve zone HVAC object(s) by name
      zone_hvac_eqp = model.getZoneHVACComponentsByName(user_defined_zone_hvac_obj_name, false)

      # If multiple object have the same name
      if zone_hvac_eqp.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.model', "The #{user_defined_zone_hvac_obj_type_name} object named #{user_defined_zone_hvac_obj_name} provided in the user zone HVAC user data could not be found in the model.")
      elsif zone_hvac_eqp.length == 1
        zone_hvac_eqp = zone_hvac_eqp[0]
        zone_hvac_eqp_idd = zone_hvac_eqp.iddObjectType.to_s
        if zone_hvac_eqp_idd != user_defined_zone_hvac_obj_type_name
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.model', "The object type name provided in the zone HVAC user data (#{user_defined_zone_hvac_obj_type_name}) does not match with the one in the model: #{zone_hvac_eqp_idd}.")
        end
      else
        zone_hvac_eqp.each do |eqp|
          zone_hvac_eqp_idd = eqp.iddObjectType
          if zone_hvac_eqp_idd == user_defined_zone_hvac_obj_type_name
            zone_hvac_eqp = eqp
            break
          end
        end
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.model', "A #{user_defined_zone_hvac_obj_type_name} object named #{user_defined_zone_hvac_obj_name} (as specified in the user zone HVAC data) could not be found in the model.")
      end

      if zone_hvac_eqp.thermalZone.is_initialized
        thermal_zone = zone_hvac_eqp.thermalZone.get

        zone_hvac_eqp_info.keys.each do |info_key|
          if info_key.include?('fan_power_credit')
            if !zone_hvac_eqp_info[info_key].to_s.empty?
              if info_key.include?('has_')
                if thermal_zone.additionalProperties.hasFeature(info_key)
                  current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                  thermal_zone.additionalProperties.setFeature(info_key, current_value + 1.0)
                else
                  thermal_zone.additionalProperties.setFeature(info_key, 1.0)
                end
              else
                if thermal_zone.additionalProperties.hasFeature(info_key)
                  current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                  thermal_zone.additionalProperties.setFeature(info_key, current_value + zone_hvac_eqp_info[info_key])
                else
                  thermal_zone.additionalProperties.setFeature(info_key, zone_hvac_eqp_info[info_key])
                end
              end
            end
          end
        end
      end
    end
  end

  # Assign spaces to system groups based on building area type
  # Get zone groups separately for each hvac building type
  # @param custom [String] identifier for custom programs, not used here, but included for backwards compatibility
  # @param bldg_type_hvac_zone_hash [Hash of bldg_type:list of zone objects] association of zones to each hvac building type
  # @return [Array<Hash>] an array of hashes of area information,
  # with keys area_ft2, type, fuel, and zones (an array of zones)
  def model_prm_baseline_system_groups(model, custom, bldg_type_hvac_zone_hash)

    bldg_groups = []

    bldg_type_hvac_zone_hash.keys.each do |hvac_building_type, zones_in_building_type|

      # Get all groups for this hvac building type
      new_groups = get_baseline_system_groups_for_one_building_type(model, hvac_building_type, zones_in_building_type)

      # Add the groups for this hvac building type to the full list
      new_groups.each do |group|
        bldg_groups << group
      end
    end

    return bldg_groups
  end


  
  # Assign spaces to system groups for one hvac building type
  # One group contains all zones associated with one HVAC type
  # Separate groups are made for laboratories, computer rooms, district cooled zones, heated-only zones, or hybrids of these
  # Groups may include zones from multiple floors; separating by floor is handled later
  # For stable baseline, heating type is based on climate, not proposed heating type
  # Isolate zones that have heating-only or district (purchased) heat or chilled water
  # @param bldg_type_hvac_zone_hash [Hash of bldg_type:list of zone objects] association of zones to each hvac building type
  # @return [Array<Hash>] an array of hashes of area information,
  # with keys area_ft2, type, fuel, and zones (an array of zones)
  def get_baseline_system_groups_for_one_building_type(model, hvac_building_type, zones_in_building_type)
    # Build zones hash of [zone, zone area, occupancy type, building type, fuel]
    zones = model_zones_with_occ_and_fuel_type(model, custom)

    # Ensure that there is at least one conditioned zone
    if zones.size.zero?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', 'The building does not appear to have any conditioned zones. Make sure zones have thermostat with appropriate heating and cooling setpoint schedules.')
      return []
    end

    # Consider special rules for computer rooms
    # need load of all

    # Get cooling load of all computer rooms to establish system types
    comp_room_loads = {}
    bldg_comp_room_load = 0
    zones.each do |zn|
      zone_load = 0.0
      has_computer_room = false
      # First check if any space in zone has a computer room
      zn['zone'].spaces.each do |space|
        if space.spaceType.get.standardsSpaceType.get == 'computer room'
          has_computer_room = true
          break
        end
      end
      if has_computer_room
        # Collect load for entire zone
        zone_load_w = zn['zone'].coolingDesignLoad.to_f
        zone_load_w *= zn['zone'].floorArea * zn['zone'].multiplier
        zone_load = OpenStudio.convert(zone_load_w, 'W', 'Btu/hr').get
      end
      comp_room_loads[zn['zone'].name.get] = zone_load
      bldg_comp_room_load += zone_load
    end

    # Lab zones are grouped separately if total lab exhaust in building > 15000 cfm
    # Make list of zone objects that contain laboratory spaces
    lab_zones = []
    has_lab_spaces = {}
    model.getThermalZones.sort.each do |zone|
      # Check if this zone includes laboratory space
      zone.spaces.each do |space|
        spacetype = space.spaceType.get.standardsSpaceType.get
        has_lab_spaces[zone.name.get] = false
        if space.spaceType.get.standardsSpaceType.get == 'laboratory'
          lab_zones << zone
          has_lab_spaces[zone.name.get] = true
          break
        end
      end
    end

    lab_exhaust_si = 0
    lab_relief_si = 0
    if !lab_zones.empty?
      # Build a hash of return_node:zone_name
      node_list = {}
      zone_return_flow_si = Hash.new(0)
      var_name = 'System Node Standard Density Volume Flow Rate'
      frequency = 'hourly'
      model.getThermalZones.each do |zone|
        port_list = zone.returnPortList
        port_list_objects = port_list.modelObjects
        port_list_objects.each do |node|
          node_name = node.nameString
          node_list[node_name] = zone.name.get
        end
        zone_return_flow_si[zone.name.get] = 0
      end

      # Get return air flow for each zone (even non-lab zones are needed)
      # Take from hourly reports created during sizing run
      node_list.each do |node_name, zone_name|
        sql = model.sqlFile
        if sql.is_initialized
          sql = sql.get
          query = "SELECT ReportDataDictionaryIndex FROM ReportDataDictionary WHERE KeyValue = '#{node_name}' COLLATE NOCASE"
          val = sql.execAndReturnFirstDouble(query)
          query = "SELECT MAX(Value) FROM ReportData WHERE ReportDataDictionaryIndex = '#{val.get}'"
          val = sql.execAndReturnFirstDouble(query)
          if val.is_initialized
            result = OpenStudio::OptionalDouble.new(val.get)
          end
          zone_return_flow_si[zone_name] += result.to_f
        end
      end

      # Calc ratio of Air Loop relief to sum of zone return for each air loop
      # and store in zone hash

      # For each air loop, get relief air flow and calculate lab exhaust from the central air handler
      # Take from hourly reports created during sizing run
      zone_relief_flow_si = {}
      model.getAirLoopHVACs.sort.each do |air_loop_hvac|
        # First get relief air flow from sizing run sql file
        relief_node = air_loop_hvac.reliefAirNode.get
        node_name = relief_node.nameString
        relief_flow_si = 0
        relief_fraction = 0
        sql = model.sqlFile
        if sql.is_initialized
          sql = sql.get
          query = "SELECT ReportDataDictionaryIndex FROM ReportDataDictionary WHERE KeyValue = '#{node_name}' COLLATE NOCASE"
          val = sql.execAndReturnFirstDouble(query)
          query = "SELECT MAX(Value) FROM ReportData WHERE ReportDataDictionaryIndex = '#{val.get}'"
          val = sql.execAndReturnFirstDouble(query)
          if val.is_initialized
            result = OpenStudio::OptionalDouble.new(val.get)
          end
          relief_flow_si = result.to_f
        end

        # Get total flow of zones on this air loop
        total_zone_return_si = 0
        air_loop_hvac.thermalZones.each do |zone|
          total_zone_return_si += zone_return_flow_si[zone.name.get]
        end

        relief_fraction = relief_flow_si / total_zone_return_si unless total_zone_return_si == 0

        # For each zone calc total effective exhaust
        air_loop_hvac.thermalZones.each do |zone|
          zone_relief_flow_si[zone.name.get] = relief_fraction * zone_return_flow_si[zone.name.get]
        end
      end

      # Now check for exhaust driven by zone exhaust fans
      lab_zones.each do |zone|
        zone.equipment.each do |zone_equipment|
          # Get tally of exhaust fan flow
          if zone_equipment.to_FanZoneExhaust.is_initialized
            zone_exh_fan = zone_equipment.to_FanZoneExhaust.get
            # Check if any spaces in this zone are laboratory
            lab_exhaust_si += zone_exh_fan.maximumFlowRate.get
          end
        end

        # Also account for outdoor air exhausted from this zone via return/relief
        lab_relief_si += zone_relief_flow_si[zone.name.get]
      end
    end

    lab_exhaust_si += lab_relief_si
    lab_exhaust_cfm = OpenStudio.convert(lab_exhaust_si, 'm^3/s', 'cfm').get

    # Isolate computer rooms onto separate groups
    # Computer rooms may need to be split to two groups, depending on load
    # Isolate heated-only and destrict cooling zones onto separate groups
    # District heating does not require separate group
    final_groups = []
    # Initialize arrays of zone objects by category
    heated_only_zones = []
    heated_cooled_zones = []
    district_cooled_zones = []
    comp_room_svav_zones = []
    comp_room_psz_zones = []
    dist_comp_room_svav_zones = []
    dist_comp_room_psz_zones = []
    lab_zones = []

    total_area_ft2 = 0
    zones.each do |zn|
      if thermal_zone_heated?(zn['zone']) && !thermal_zone_cooled?(zn['zone'])
        heated_only_zones << zn['zone']
      elsif comp_room_loads[zn['zone'].name.get] > 0
        # This is a computer room zone
        if bldg_comp_room_load > 3_000_000 || comp_room_loads[zn['zone'].name.get] > 600_000
          # System 11
          if zn['fuel'].include?('DistrictCooling')
            dist_comp_room_svav_zones << zn['zone']
          else
            comp_room_svav_zones << zn['zone']
          end
        else
          # PSZ
          if zn['fuel'].include?('DistrictCooling')
            dist_comp_room_psz_zones << zn['zone']
          else
            comp_room_psz_zones << zn['zone']
          end
        end

      elsif has_lab_spaces[zn['zone'].name.get] && lab_exhaust_cfm > 15_000
        lab_zones << zn['zone']
      elsif zn['fuel'].include?('DistrictCooling')
        district_cooled_zones << zn['zone']
      else
        heated_cooled_zones << zn['zone']
      end
      # Collect total floor area of all zones for this building area type
      area_m2 = zn['zone'].floorArea * zn['zone'].multiplier
      total_area_ft2 += OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
    end

    # Build final_groups array
    unless heated_only_zones.empty?
      htd_only_group = {}
      htd_only_group['occ'] = 'heated-only storage'
      htd_only_group['fuel'] = 'any'
      htd_only_group['zone_group_type'] = 'heated_only_zones'
      area_m2 = 0
      heated_only_zones.each do |zone|
        area_m2 += zone.floorArea * zone.multiplier
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
      htd_only_group['group_area_ft2'] = area_ft2
      htd_only_group['building_area_type_ft2'] = total_area_ft2
      htd_only_group['zones'] = heated_only_zones
      final_groups << htd_only_group
    end
    unless district_cooled_zones.empty?
      district_cooled_group = {}
      district_cooled_group['occ'] = hvac_building_type
      district_cooled_group['fuel'] = 'districtcooling'
      district_cooled_group['zone_group_type'] = 'district_cooled_zones'
      area_m2 = 0
      district_cooled_zones.each do |zone|
        area_m2 += zone.floorArea * zone.multiplier
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
      district_cooled_group['group_area_ft2'] = area_ft2
      district_cooled_group['building_area_type_ft2'] = total_area_ft2
      district_cooled_group['zones'] = district_cooled_zones
      # store info if any zone has district, fuel, or electric heating
      district_cooled_group['fuel'] = get_group_heat_types(model, district_cooled_zones)
      final_groups << district_cooled_group
    end
    unless heated_cooled_zones.empty?
      heated_cooled_group = {}
      heated_cooled_group['occ'] = hvac_building_type
      heated_cooled_group['fuel'] = 'any'
      heated_cooled_group['zone_group_type'] = 'heated_cooled_zones'
      area_m2 = 0
      heated_cooled_zones.each do |zone|
        area_m2 += zone.floorArea * zone.multiplier
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
      heated_cooled_group['group_area_ft2'] = area_ft2
      heated_cooled_group['building_area_type_ft2'] = total_area_ft2
      heated_cooled_group['zones'] = heated_cooled_zones
      # store info if any zone has district, fuel, or electric heating
      heated_cooled_group['fuel'] = get_group_heat_types(model, heated_cooled_zones)
      final_groups << heated_cooled_group
    end
    unless lab_zones.empty?
      lab_group = {}
      lab_group['occ'] = hvac_building_type
      lab_group['fuel'] = 'any'
      lab_group['zone_group_type'] = 'lab_zones'
      area_m2 = 0
      lab_zones.each do |zone|
        area_m2 += zone.floorArea * zone.multiplier
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
      lab_group['group_area_ft2'] = area_ft2
      lab_group['building_area_type_ft2'] = total_area_ft2
      lab_group['zones'] = lab_zones
      # store info if any zone has district, fuel, or electric heating
      lab_group['fuel'] = get_group_heat_types(model, lab_zones)
      final_groups << lab_group
    end
    unless comp_room_svav_zones.empty?
      comp_room_svav_group = {}
      comp_room_svav_group['occ'] = 'computer room szvav'
      comp_room_svav_group['fuel'] = 'any'
      comp_room_svav_group['zone_group_type'] = 'computer_zones'
      area_m2 = 0
      comp_room_svav_zones.each do |zone|
        area_m2 += zone.floorArea * zone.multiplier
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
      comp_room_svav_group['group_area_ft2'] = area_ft2
      comp_room_svav_group['building_area_type_ft2'] = total_area_ft2
      comp_room_svav_group['zones'] = comp_room_svav_zones
      # store info if any zone has district, fuel, or electric heating
      comp_room_svav_group['fuel'] = get_group_heat_types(model, comp_room_svav_zones)
      final_groups << comp_room_svav_group
    end
    unless comp_room_psz_zones.empty?
      comp_room_psz_group = {}
      comp_room_psz_group['occ'] = 'computer room psz'
      comp_room_psz_group['fuel'] = 'any'
      comp_room_psz_group['zone_group_type'] = 'computer_zones'
      area_m2 = 0
      comp_room_psz_zones.each do |zone|
        area_m2 += zone.floorArea * zone.multiplier
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
      comp_room_psz_group['group_area_ft2'] = area_ft2
      comp_room_psz_group['building_area_type_ft2'] = total_area_ft2
      comp_room_psz_group['zones'] = comp_room_psz_zones
      # store info if any zone has district, fuel, or electric heating
      comp_room_psz_group['fuel'] = get_group_heat_types(model, comp_room_psz_zones)
      final_groups << comp_room_psz_group
    end
    unless dist_comp_room_svav_zones.empty?
      dist_comp_room_svav_group = {}
      dist_comp_room_svav_group['occ'] = hvac_building_type
      dist_comp_room_svav_group['fuel'] = 'districtcooling'
      dist_comp_room_svav_group['zone_group_type'] = 'computer_zones'
      area_m2 = 0
      dist_comp_room_svav_zones.each do |zone|
        area_m2 += zone.floorArea * zone.multiplier
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
      dist_comp_room_svav_group['group_area_ft2'] = area_ft2
      dist_comp_room_svav_group['building_area_type_ft2'] = total_area_ft2
      dist_comp_room_svav_group['zones'] = dist_comp_room_svav_zones
      # store info if any zone has district, fuel, or electric heating
      dist_comp_room_svav_group['fuel'] = get_group_heat_types(model, dist_comp_room_svav_zones)
      final_groups << dist_comp_room_svav_group
    end
    unless dist_comp_room_psz_zones.empty?
      dist_comp_room_psz_group = {}
      dist_comp_room_psz_group['occ'] = hvac_building_type
      dist_comp_room_psz_group['fuel'] = 'districtcooling'
      dist_comp_room_psz_group['zone_group_type'] = 'computer_zones'
      area_m2 = 0
      dist_comp_room_psz_zones.each do |zone|
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
      dist_comp_room_psz_group['group_area_ft2'] = area_ft2
      dist_comp_room_psz_group['building_area_type_ft2'] = total_area_ft2
      dist_comp_room_psz_group['zones'] = dist_comp_room_psz_zones
      # store info if any zone has district, fuel, or electric heating
      dist_comp_room_psz_group['fuel'] = get_group_heat_types(model, dist_comp_room_psz_zones)
      final_groups << dist_comp_room_psz_group
    end

    ngrps = final_groups.count
    # Determine the number of stories spanned by each group and report out info.
    final_groups.each do |group|
      # Determine the number of stories this group spans
      num_stories = model_num_stories_spanned(model, group['zones'])
      group['stories'] = num_stories
      # Report out the final grouping
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Final system type group: occ = #{group['occ']}, fuel = #{group['fuel']}, area = #{group['group_area_ft2'].round} ft2, num stories = #{group['stories']}, zones:")
      group['zones'].sort.each_slice(5) do |zone_list|
        zone_names = []
        zone_list.each do |zone|
          zone_names << zone.name.get.to_s
        end
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "--- #{zone_names.join(', ')}")
      end
    end

    return final_groups
  end

  # Alternate method for 2016 and later stable baseline
  # Limits for each building area type are taken from data table
  # Heating fuel is based on climate zone, unless district heat is in proposed
  #
  # @note Select system type from data table base on key parameters
  # @param climate_zone [string] id code for the climate
  # @param sys_group [data structure] Data structure defining list of zones for a single hvac building type
  # @param custom [string] included here for backwards compatibility (not used here)
  # @param hvac_building_type [String] Chosen by user via measure interface or user data files
  # @param district_heat_zones [hash] of zone name => true for has district heat, false for has not
  # @return [String] The system type.  Possibilities are PTHP, PTAC, PSZ_AC, PSZ_HP, PVAV_Reheat, PVAV_PFP_Boxes,
  #   VAV_Reheat, VAV_PFP_Boxes, Gas_Furnace, Electric_Furnace
  def model_prm_stable_baseline_system_type(model, climate_zone, sys_group, custom, hvac_building_type, district_heat_zones)

    area_type = sys_group['occ']
    fuel_type = sys_group['fuel']
    area_ft2 = sys_group['building_area_type_ft2']
    num_stories = sys_group['stories']
    zones = sys_group['zones']

    #             [type, central_heating_fuel, zone_heating_fuel, cooling_fuel]
    system_type = [nil, nil, nil, nil]

    # Find matching record from prm baseline hvac table
    # First filter by number of stories
    iStoryGroup = 0
    props = {}
    0.upto(9) do |i|
      iStoryGroup += 1
      props = model_find_object(standards_data['prm_baseline_hvac'],
                                'template' => template,
                                'hvac_building_type' => area_type,
                                'flrs_range_group' => iStoryGroup,
                                'area_range_group' => 1)

      if !props
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find baseline HVAC type for: #{template}-#{area_type}.")
      end
      if num_stories <= props['bldg_flrs_max']
        # Story Group Is found
        break
      end
    end

    # Next filter by floor area
    iAreaGroup = 0
    baseine_is_found = false
    loop do
      iAreaGroup += 1
      props = model_find_object(standards_data['prm_baseline_hvac'],
                                'template' => template,
                                'hvac_building_type' => area_type,
                                'flrs_range_group' => iStoryGroup,
                                'area_range_group' => iAreaGroup)

      if !props
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find baseline HVAC type for: #{template}-#{area_type}.")
      end
      below_max = false
      above_min = false
      # check if actual building floor area is within range for this area group
      if props['max_area_qual'] == 'LT'
        if area_ft2 < props['bldg_area_max']
          below_max = true
        end
      elsif props['max_area_qual'] == 'LE'
        if area_ft2 <= props['bldg_area_max']
          below_max = true
        end
      end
      if props['min_area_qual'] == 'GT'
        if area_ft2 > props['bldg_area_min']
          above_min = true
        end
      elsif props['min_area_qual'] == 'GE'
        if area_ft2 >= props['bldg_area_min']
          above_min = true
        end
      end
      if (above_min == true) && (below_max == true)
        baseline_is_found = true
        break
      end
      if iAreaGroup > 9
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find baseline HVAC type for: #{template}-#{area_type}.")
        break
      end
    end

    heat_type = find_prm_heat_type(hvac_building_type, climate_zone)

    # hash to relate apx G systype categories to sys types for model
    sys_hash = {}
    if heat_type == 'fuel'
      sys_hash['PTAC'] = 'PTAC'
      sys_hash['PSZ'] = 'PSZ_AC'
      sys_hash['SZ-CV'] = 'SZ_CV'
      sys_hash['Heating and ventilation'] = 'Gas_Furnace'
      sys_hash['PSZ-AC'] = 'PSZ_AC'
      sys_hash['Packaged VAV'] = 'PVAV_Reheat'
      sys_hash['VAV'] = 'VAV_Reheat'
      sys_hash['Unconditioned'] = 'None'
      sys_hash['SZ-VAV'] = 'SZ_VAV'
    else
      sys_hash['PTAC'] = 'PTHP'
      sys_hash['PSZ'] = 'PSZ_HP'
      sys_hash['SZ-CV'] = 'SZ_CV'
      sys_hash['Heating and ventilation'] = 'Electric_Furnace'
      sys_hash['PSZ-AC'] = 'PSZ_HP'
      sys_hash['Packaged VAV'] = 'PVAV_PFP_Boxes'
      sys_hash['VAV'] = 'VAV_PFP_Boxes'
      sys_hash['Unconditioned'] = 'None'
      sys_hash['SZ-VAV'] = 'SZ_VAV'
    end

    model_sys_type = sys_hash[props['system_type']]

    if /districtheating/i =~ fuel_type
      central_heat = 'DistrictHeating'
    elsif heat_type =~ /fuel/i
      central_heat = 'NaturalGas'
    else
      central_heat = 'Electricity'
    end
    if /districtheating/i =~ fuel_type && /elec/i !~ fuel_type && /fuel/i !~ fuel_type
      # if no zone has fuel or elect, set default to district for zones
      zone_heat = 'DistrictHeating'
    elsif heat_type =~ /fuel/i
      zone_heat = 'NaturalGas'
    else
      zone_heat = 'Electricity'
    end
    if /districtcooling/i =~ fuel_type
      cool_type = 'DistrictCooling'
    elsif props['system_type'] =~ /Heating and ventilation/i || props['system_type'] =~ /unconditioned/i
      cool_type = nil
    end

    system_type = [model_sys_type, central_heat, zone_heat, cool_type]
    return system_type
  end

  # For a multizone system, create the fan schedule based on zone occupancy/fan schedules
  # @author Doug Maddox, PNNL
  # @param model
  # @param zone_fan_scheds [Hash] of hash of zoneName:8760FanSchedPerZone
  # @param pri_zones [Array<String>] names of zones served by the multizone system
  # @param system_name [String] name of air loop
  def model_create_multizone_fan_schedule(model, zone_op_hrs, pri_zones, system_name)
    # Exit if not stable baseline
    return if /prm/i !~ template

    # Create fan schedule for multizone system
    fan_8760 = []
    # If any zone is on for an hour, then the system fan must be on for that hour
    pri_zones.each do |zone|
      zone_name = zone.name.get.to_s
      if fan_8760.empty?
        fan_8760 = zone_op_hrs[zone_name]
      else
        (0..fan_8760.size - 1).each do |ihr|
          if zone_op_hrs[zone_name][ihr] > 0
            fan_8760[ihr] = 1
          end
        end
      end
    end

    # Convert 8760 array to schedule ruleset
    fan_sch_limits = model.getScheduleTypeLimitsByName('fan schedule limits for prm')
    if fan_sch_limits.empty?
      fan_sch_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
      fan_sch_limits.setName('fan schedule limits for prm')
      fan_sch_limits.setNumericType('DISCRETE')
      fan_sch_limits.setUnitType('Dimensionless')
      fan_sch_limits.setLowerLimitValue(0)
      fan_sch_limits.setUpperLimitValue(1)
    else
      fan_sch_limits = fan_sch_limits.get
    end
    sch_name = system_name + ' ' + 'fan schedule'
    make_ruleset_sched_from_8760(model, fan_8760, sch_name, fan_sch_limits)

    air_loop = model.getAirLoopHVACByName(system_name).get
    air_loop.additionalProperties.setFeature('fan_sched_name', sch_name)
  end

  # For a multizone system, identify any zones to isolate to separate PSZ systems
  # isolated zones are on the 'secondary' list
  # This version of the method applies to standard years 2016 and later (stable baseline)
  # @author Doug Maddox, PNNL
  # @param model
  # @param zones [Array<Object>]
  # @param zone_fan_scheds [Hash] hash of zoneName:8760FanSchedPerZone
  # @return [Hash] A hash of two arrays of ThermalZones,
  # where the keys are 'primary' and 'secondary'
  def model_diff_primary_secondary_zones(model, zones, zone_fan_scheds)
    pri_zones = []
    sec_zones = []
    pri_zone_names = []
    sec_zone_names = []
    zone_op_hrs = {} # hash of zoneName: 8760 array of operating hours

    # If there is only one zone, then set that as primary
    if zones.size == 1
      zones.each do |zone|
        pri_zones << zone
        pri_zone_names << zone.name.get.to_s
        zone_name = zone.name.get.to_s
        if zone_fan_scheds.key?(zone_name)
          zone_fan_sched = zone_fan_scheds[zone_name]
        else
          zone_fan_sched = nil
        end
        zone_op_hrs[zone.name.get.to_s] = thermal_zone_get_annual_operating_hours(model, zone, zone_fan_sched)
      end
      # Report out the primary vs. secondary zones
      unless sec_zone_names.empty?
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Secondary system zones = #{sec_zone_names.join(', ')}.")
      end

      return { 'primary' => pri_zones, 'secondary' => sec_zones, 'zone_op_hrs' => zone_op_hrs }
    end

    zone_eflh = {} # hash of zoneName: eflh for zone
    zone_max_load = {}  # hash of zoneName: coincident max internal load
    load_limit = 10     # differ by 10 Btu/hr-sf or more
    eflh_limit = 40     # differ by more than 40 EFLH/week from average of other zones
    zone_area = {} # hash of zoneName:area

    # Get coincident peak internal load for each zone
    zones.each do |zone|
      zone_name = zone.name.get.to_s
      if zone_fan_scheds.key?(zone_name)
        zone_fan_sched = zone_fan_scheds[zone_name]
      else
        zone_fan_sched = nil
      end
      zone_op_hrs[zone_name] = thermal_zone_get_annual_operating_hours(model, zone, zone_fan_sched)
      zone_eflh[zone_name] = thermal_zone_occupancy_eflh(zone, zone_op_hrs[zone_name])
      zone_max_load_w = thermal_zone_peak_internal_load(model, zone)
      zone_max_load_w_m2 = zone_max_load_w / zone.floorArea
      zone_max_load[zone_name] = OpenStudio.convert(zone_max_load_w_m2, 'W/m^2', 'Btu/hr*ft^2').get
      zone_area[zone_name] = zone.floorArea
    end

    # Eliminate all zones for which both max load and EFLH exceed limits
    zones.each do |zone|
      zone_name = zone.name.get.to_s
      max_load = zone_max_load[zone_name]
      avg_max_load = get_wtd_avg_of_other_zones(zone_max_load, zone_area, zone_name)
      max_load_diff = (max_load - avg_max_load).abs
      avg_eflh = get_avg_of_other_zones(zone_eflh, zone_name)
      eflh_diff = (avg_eflh - zone_eflh[zone_name]).abs

      if max_load_diff >= load_limit && eflh_diff > eflh_limit
        # Add zone to secondary list, and remove from hashes
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Zone moved to PSZ due to load AND eflh: #{zone_name}; load limit = #{load_limit}, eflh_limit = #{eflh_limit}")
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "load diff = #{max_load_diff}, this zone load = #{max_load}, avg zone load = #{avg_max_load}")
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "eflh diff = #{eflh_diff}, this zone load = #{zone_eflh[zone_name]}, avg zone eflh = #{avg_eflh}")

        sec_zones << zone
        sec_zone_names << zone_name
        zone_eflh.delete(zone_name)
        zone_max_load.delete(zone_name)
      end
    end

    # Eliminate worst zone where EFLH exceeds limit
    # Repeat until all zones are within limit
    num_zones = zone_eflh.size
    avg_eflh_save = 0
    max_zone_name = ''
    max_eflh_diff = 0
    max_zone = nil
    (1..num_zones).each do |izone|
      # This loop is to iterate to eliminate one zone at a time
      max_eflh_diff = 0
      zones.each do |zone|
        # This loop finds the worst remaining zone to eliminate if above threshold
        zone_name = zone.name.get.to_s
        next if !zone_eflh.key?(zone_name)

        avg_eflh = get_avg_of_other_zones(zone_eflh, zone_name)
        eflh_diff = (avg_eflh - zone_eflh[zone_name]).abs
        if eflh_diff > max_eflh_diff
          max_eflh_diff = eflh_diff
          max_zone_name = zone_name
          max_zone = zone
          avg_eflh_save = avg_eflh
        end
      end
      if max_eflh_diff > eflh_limit
        # Move the max Zone to the secondary list
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Zone moved to PSZ due to eflh: #{max_zone_name}; limit = #{eflh_limit}")
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "eflh diff = #{max_eflh_diff}, this zone load = #{zone_eflh[max_zone_name]}, avg zone eflh = #{avg_eflh_save}")
        sec_zones << max_zone
        sec_zone_names << max_zone_name
        zone_eflh.delete(max_zone_name)
        zone_max_load.delete(max_zone_name)
      else
        # All zones are now within the limit, exit the iteration
        break
      end
    end

    # Eliminate worst zone where max load exceeds limit and repeat until all pass
    num_zones = zone_eflh.size
    highest_max_load_diff = -1
    highest_zone = nil
    highest_zone_name = ''
    highest_max_load = 0
    avg_max_load_save = 0

    (1..num_zones).each do |izone|
      # This loop is to iterate to eliminate one zone at a time
      highest_max_load_diff = 0
      zones.each do |zone|
        # This loop finds the worst remaining zone to eliminate if above threshold
        zone_name = zone.name.get.to_s
        next if !zone_max_load.key?(zone_name)

        max_load = zone_max_load[zone_name]
        avg_max_load = get_wtd_avg_of_other_zones(zone_max_load, zone_area, zone_name)
        max_load_diff = (max_load - avg_max_load).abs
        if max_load_diff >= highest_max_load_diff
          highest_max_load_diff = max_load_diff
          highest_zone_name = zone_name
          highest_zone = zone
          highest_max_load = max_load
          avg_max_load_save = avg_max_load
        end
      end
      if highest_max_load_diff > load_limit
        # Move the max Zone to the secondary list
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Zone moved to PSZ due to load: #{highest_zone_name}; load limit = #{load_limit}")
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "load diff = #{highest_max_load_diff}, this zone load = #{highest_max_load}, avg zone load = #{avg_max_load_save}")
        sec_zones << highest_zone
        sec_zone_names << highest_zone_name
        zone_eflh.delete(highest_zone_name)
        zone_max_load.delete(highest_zone_name)
      else
        # All zones are now within the limit, exit the iteration
        break
      end
    end

    # Place remaining zones in multizone system list
    zone_eflh.each_key do |key|
      zones.each do |zone|
        if key == zone.name.get.to_s
          pri_zones << zone
          pri_zone_names << key
        end
      end
    end

    # Report out the primary vs. secondary zones
    unless pri_zone_names.empty?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Primary system zones = #{pri_zone_names.join(', ')}.")
    end
    unless sec_zone_names.empty?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Secondary system zones = #{sec_zone_names.join(', ')}.")
    end

    return { 'primary' => pri_zones, 'secondary' => sec_zones, 'zone_op_hrs' => zone_op_hrs }
  end


end

