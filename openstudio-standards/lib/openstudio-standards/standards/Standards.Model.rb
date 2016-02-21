
# Loads the openstudio standards dataset.
#
# @return [Hash] a hash of standards data
def load_openstudio_standards_json()

  standards_files = []
  standards_files << 'OpenStudio_Standards_boilers.json'
  standards_files << 'OpenStudio_Standards_chillers.json'
  standards_files << 'OpenStudio_Standards_climate_zone_sets.json'
  standards_files << 'OpenStudio_Standards_climate_zones.json'
  standards_files << 'OpenStudio_Standards_construction_properties.json'
  standards_files << 'OpenStudio_Standards_construction_sets.json'
  standards_files << 'OpenStudio_Standards_constructions.json'
  standards_files << 'OpenStudio_Standards_curve_bicubics.json'
  standards_files << 'OpenStudio_Standards_curve_biquadratics.json'
  standards_files << 'OpenStudio_Standards_curve_cubics.json'
  standards_files << 'OpenStudio_Standards_curve_quadratics.json'
  standards_files << 'OpenStudio_Standards_ground_temperatures.json'
  standards_files << 'OpenStudio_Standards_heat_pumps_heating.json'
  standards_files << 'OpenStudio_Standards_heat_pumps.json'
  standards_files << 'OpenStudio_Standards_materials.json'
  standards_files << 'OpenStudio_Standards_motors.json'
  standards_files << 'OpenStudio_Standards_prototype_inputs.json'
  standards_files << 'OpenStudio_Standards_schedules.json'
  standards_files << 'OpenStudio_Standards_space_types.json'
  standards_files << 'OpenStudio_Standards_templates.json'
  standards_files << 'OpenStudio_Standards_unitary_acs.json'
#    standards_files << 'OpenStudio_Standards_unitary_hps.json'

  # Combine the data from the JSON files into a single hash
  top_dir = File.expand_path( '../../..',File.dirname(__FILE__))
  standards_data_dir = "#{top_dir}/data/standards"
  standards_data = {}
  standards_files.sort.each do |standards_file|
    temp = File.open("#{standards_data_dir}/#{standards_file}", 'r:UTF-8')
    file_hash = JSON.load(temp)
    standards_data = standards_data.merge(file_hash)
  end

  # Check that standards data was loaded
  if standards_data.keys.size == 0
    OpenStudio::logFree(OpenStudio::Error, "OpenStudio Standards JSON data was not loaded correctly.")
  end
  
  return standards_data
  
end

# open the class to add methods to apply HVAC efficiency standards
class OpenStudio::Model::Model

  # Load the helper libraries for getting the autosized
  # values for each type of model object.
  require_relative 'Standards.AirTerminalSingleDuctParallelPIUReheat'
  require_relative 'Standards.BuildingStory'
  require_relative 'Standards.Fan'
  require_relative 'Standards.FanConstantVolume'
  require_relative 'Standards.FanVariableVolume'
  require_relative 'Standards.FanOnOff'
  require_relative 'Standards.FanZoneExhaust'
  require_relative 'Standards.ChillerElectricEIR'
  require_relative 'Standards.CoilCoolingDXTwoSpeed'
  require_relative 'Standards.CoilCoolingDXSingleSpeed'
  require_relative 'Standards.CoilHeatingDXSingleSpeed'
  require_relative 'Standards.BoilerHotWater'
  require_relative 'Standards.AirLoopHVAC'
  require_relative 'Standards.WaterHeaterMixed'
  require_relative 'Standards.Space'
  require_relative 'Standards.Construction'
  require_relative 'Standards.ThermalZone'
  require_relative 'Standards.Surface'
  require_relative 'Standards.SubSurface'
  require_relative 'Standards.ScheduleRuleset'
  require_relative 'Standards.ScheduleConstant'
  require_relative 'Standards.SpaceType'
  require_relative 'Standards.PlanarSurface'
  require_relative 'Standards.PlantLoop'
  require_relative 'Standards.Pump'
  require_relative 'Standards.PumpConstantSpeed'
  require_relative 'Standards.PumpVariableSpeed'
  require_relative 'Standards.AirTerminalSingleDuctVAVReheat'

  # Creates a Performance Rating Method (aka Appendix G aka LEED) baseline building model
  # based on the inputs currently in the model.  
  # the current model with this model.
  #
  # @note Per 90.1, the Performance Rating Method "does NOT offer an alternative
  # compliance path for minimum standard compliance."  This means you can't use
  # this method for code compliance to get a permit.
  # @param building_type [String] the building type
  # @param building_vintage [String] the building vintage.  Valid choices are 90.1-2004, 90.1-2007, 90.1-2010, 90.1-2013.
  # @param climate_zone [String] the climate zone
  # @param sizing_run_dir [String] the directory where the sizing runs will be performed
  # @param debug [Boolean] If true, will report out more detailed debugging output
  # @return [Bool] returns true if successful, false if not
  def create_performance_rating_method_baseline_building(building_type, building_vintage, climate_zone, sizing_run_dir = Dir.pwd, debug = false)

    lookup_building_type = self.get_lookup_name(building_type)

    self.getBuilding.setName("#{building_vintage}-#{building_type}-#{climate_zone} PRM baseline created: #{Time.new}")

    # Reduce the WWR, if necessary
    self.apply_performance_rating_method_baseline_window_to_wall_ratio(building_vintage)
    
    # Assign building stories to spaces in the building
    # where stories are not yet assigned.
    self.assign_spaces_to_stories
    
    # Modify the internal loads in each space type, 
    # keeping user-defined schedules.
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Changing Lighting and Ventilation Rates")
    self.getSpaceTypes.sort.each do |space_type|
      space_type.set_internal_loads(building_vintage, false, true, false, false, true, false) 
    end

    # Modify some of the construction types as necessary
    self.apply_performance_rating_method_construction_types(building_vintage)
    
    # Set the construction properties of all the surfaces in the model
    self.apply_standard_constructions(building_vintage, climate_zone)
    
    # Get the groups of zones that define the
    # baseline HVAC systems for later use.
    # This must be done before removing the HVAC systems
    # because it requires knowledge of proposed HVAC fuels.
    sys_groups = self.performance_rating_method_baseline_system_groups(building_vintage)    
    
    # Remove all HVAC from model
    BTAP::Resources::HVAC.clear_all_hvac_from_model(self)
    
    # Add ideal loads to every zone and run
    # a sizing run to determine heating/cooling loads,
    # which will impact which zones go onto secondary
    # HVAC systems.
    self.getThermalZones.each do |zone|
      ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(self)
      ideal_loads.addToThermalZone(zone)
    end
    # Run sizing run
    if self.runSizingRun("#{sizing_run_dir}/SizingRunIdeal") == false
      return false
    end
    # Remove ideal loads
    self.getZoneHVACIdealLoadsAirSystems.each do |ideal_loads|
      ideal_loads.remove
    end

    # Determine the baseline HVAC system type for each of
    # the groups of zones and add that system type.
    sys_groups.each do |sys_group|

      # Determine the primary baseline system type
      system_type = performance_rating_method_baseline_system_type(building_vintage,
                                                                climate_zone,
                                                                sys_group['type'], 
                                                                sys_group['fuel'],
                                                                sys_group['area_ft2'],
                                                                sys_group['stories'])
                                                                
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "System type is #{system_type} for #{sys_group['zones'].size} zones.")
      sys_group['zones'].each do |zone|
        OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "---#{zone.name}")
      end
      
      # Add the system type for these zones
      self.add_performance_rating_method_baseline_system(building_vintage, system_type, sys_group['zones'])
    
    end

    # SAT reset, economizers
    self.getAirLoopHVACs.sort.each do |air_loop|
      air_loop.apply_performance_rating_method_baseline_controls(building_vintage, climate_zone)
    end
  
    # Apply the minimum damper positions
    self.getAirLoopHVACs.sort.each do |air_loop|
      air_loop.set_minimum_vav_damper_positions(building_vintage)
    end

    # Apply the baseline system temperatures
    self.getPlantLoops.sort.each do |plant_loop|
      plant_loop.apply_performance_rating_method_baseline_temperatures(building_vintage)
    end
    
    # Run sizing run with the HVAC equipment
    if self.runSizingRun("#{sizing_run_dir}/SizingRun1") == false
      return false
    end    

    # If there are any multizone systems, set damper positions
    # and perform a second sizing run
    has_multizone_systems = false
    self.getAirLoopHVACs.sort.each do |air_loop|
      if air_loop.is_multizone_vav_system
        self.apply_multizone_vav_outdoor_air_sizing(building_vintage)
        if self.runSizingRun("#{sizing_run_dir}/SizingRun2") == false
          return false
        end
        break
      end
    end

    # Set the baseline fan power for all airloops
    self.getAirLoopHVACs.sort.each do |air_loop|
      air_loop.set_performance_rating_method_baseline_fan_power(building_vintage)
    end
    
    # Set the baseline pumping power for all plant loops
    # Set the baseline pump control type for all plant loops
    # Set the baseline number of boilers
    self.getPlantLoops.sort.each do |plant_loop|
      plant_loop.apply_performance_rating_method_baseline_pump_power(building_vintage)
      plant_loop.apply_performance_rating_method_baseline_pumping_type(building_vintage)
      plant_loop.apply_performance_rating_method_number_of_boilers(building_vintage)
      plant_loop.apply_performance_rating_method_number_of_chillers(building_vintage)
    end

    # Run sizing run with the new chillers and boilers to determine capacities
    if self.runSizingRun("#{sizing_run_dir}/SizingRun3") == false
      return false
    end
    
    # Apply the HVAC efficiency standard
    self.applyHVACEfficiencyStandard(building_vintage, climate_zone)  
    
    # Add daylighting controls to each space
    self.getSpaces.sort.each do |space|
      added = space.addDaylightingControls(building_vintage, false, false)
    end

    # Delete all the unused curves
    self.getCurves.sort.each do |curve|
      if curve.parent.empty?
        #OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "#{curve.name} is unused; it will be removed.")
        curve.remove
      end
    end


    # Todo: turn off self shading
    # Set Solar Distribution to MinimalShadowing... problem is when you also have detached shading such as surrounding buildings etc
    # It won't be taken into account, while it should: only self shading from the building itself should be turned off but to my knowledge there isn't a way to do this in E+
    
    model_status = 'final'
    self.save(OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.osm"), true)

    # Translate to IDF and save for debugging
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(self)
    idf_path = OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.idf")  
    idf.save(idf_path,true)    

    return true

  end  

  # Determine the residential and nonresidential floor areas
  # based on the space type properties for each space.
  # For spaces with no space type, assume nonresidential.
  #
  # @return [Hash] keys are 'residential' and 'nonresidential', units are m^2
  def residential_and_nonresidential_floor_areas(standard)

    res_area_m2 = 0
    nonres_area_m2 = 0
    self.getSpaces.each do |space|
      if space.is_residential(standard)
        res_area_m2 += space.floorArea
      else
        nonres_area_m2 += space.floorArea
      end
    end
      
    return {'residential' => res_area_m2, 'nonresidential' => nonres_area_m2}
  
  end

  # Determine the number of residential and nonresidential stories.
  # If a story has both types, add it to both counts.
  # Checks the zone multipliers to get the floor multiplier
  # Ignores spaces that aren't part of total floor area
  #
  # @return [Hash] keys are 'residential' and 'nonresidential'
  def residential_and_nonresidential_story_counts(standard)
    
    res_stories = 0
    nonres_stories = 0

    self.getBuildingStorys.each do |story|

      has_res = false
      has_nonres = false

      zone_mults = []

      story.spaces.each do |space|

        # Ignore spaces that aren't part of the total floor area
        next if !space.partofTotalFloorArea

        # Handle zone multipliers
        if !space.thermalZone.empty?
          zone_mults << space.thermalZone.get.multiplier
        end

        if space.is_residential(standard)
          has_res = true
        else
          has_nonres = true
        end
      end

      if zone_mults.size == 0
        OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Story #{story.name} has no thermal zones!")
      else
        floor_mult = zone_mults.instance_eval { reduce(:+) / size.to_f }.to_i
      end
      res_stories += 1 * floor_mult if has_res
      nonres_stories += 1 * floor_mult if has_nonres
      if has_res && has_nonres
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Story #{story.name} is mixed use (residential and nonresidential).")
      end
    end

    return {'residential' => res_stories, 'nonresidential' => nonres_stories} 

  end  
  
  # Determine the dominant and exceptional areas of the
  # building based on fuel types and occupancy types.
  #
  # @param standard [String] the standard.  Valid choices are 90.1-2004, 90.1-2007, 90.1-2010, 90.1-2013.
  # @return [Array<Hash>] an array of hashes of area information,
  # with keys area_ft2, type, fuel, and zones (an array of zones)
  def performance_rating_method_baseline_system_groups(standard)
  
    # Get the residential and nonresidential
    # fossil and electric zones and their areas
    res_fossil = {'area_ft2'=>0, 'type'=>'residential', 'fuel'=>'fossil', 'zones'=>[]}
    res_elec = {'area_ft2'=>0, 'type'=>'residential', 'fuel'=>'electric', 'zones'=>[]}
    nonres_fossil = {'area_ft2'=>0, 'type'=>'nonresidential', 'fuel'=>'fossil', 'zones'=>[]}
    nonres_elec = {'area_ft2'=>0, 'type'=>'nonresidential', 'fuel'=>'electric', 'zones'=>[]}
    [res_fossil, res_elec, nonres_fossil, nonres_elec].each do |data|
      # If the zone meets the criteria, add it
      self.getThermalZones.each do |zone|
        area_m2 = zone.floorArea
        area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
        # Residential Fossil
        if data['type'] == 'residential' && data['fuel'] == 'fossil'
          if zone.is_residential(standard) && zone.is_fossil_hybrid_or_purchased_heat
            data['area_ft2'] += area_ft2
            data['zones'] << zone
          end
        # Residential Electric
        elsif data['type'] == 'residential' && data['fuel'] == 'electric'
          if zone.is_residential(standard) && !zone.is_fossil_hybrid_or_purchased_heat
            data['area_ft2'] += area_ft2
            data['zones'] << zone
          end
        # Nonresidential Fossil
        elsif data['type'] == 'nonresidential' && data['fuel'] == 'fossil'
          if !zone.is_residential(standard) && zone.is_fossil_hybrid_or_purchased_heat
            data['area_ft2'] += area_ft2
            data['zones'] << zone
          end
        # Nonresidential Electric
        elsif data['type'] == 'nonresidential' && data['fuel'] == 'electric'
          if !zone.is_residential(standard) && !zone.is_fossil_hybrid_or_purchased_heat
            data['area_ft2'] += area_ft2
            data['zones'] << zone
          end
        end
      end
    end
      
    # Determine the number of stories of each type
    stories = self.residential_and_nonresidential_story_counts(standard)
    res_stories = stories['residential']
    nonres_stories = stories['nonresidential']       

    res_fossil['stories'] = res_stories
    res_elec['stories'] = res_stories
    nonres_fossil['stories'] = nonres_stories
    nonres_elec['stories'] = nonres_stories
     
    # Determine the dominant area type.
    # In the event of a tie, choose nonresidential.
    dom_type = nil
    if res_fossil['area_ft2'] + res_elec['area_ft2'] > nonres_fossil['area_ft2'] + nonres_elec['area_ft2']
      dom_type = 'residential'
    else
      dom_type = 'nonresidential'
    end
  
    # Determine the dominant fuel type
    # in the dominant area type.
    # In the event of a tie, choose fossil.
    dom_fuel = nil
    if dom_type == 'residential'
      if res_elec['area_ft2'] > res_fossil['area_ft2']
        dom_fuel = 'electric'
      else
        dom_fuel = 'fossil'
      end
    elsif dom_type == 'nonresidential'
      if nonres_elec['area_ft2'] > nonres_fossil['area_ft2']
        dom_fuel = 'electric'
      else
        dom_fuel = 'fossil'
      end
    end
    
    # Categorize the hashes
    dom_type_dom_fuel = nil
    dom_type_sec_fuel = nil
    sec_type_dom_fuel = nil
    sec_type_sec_fuel = nil
    [res_fossil, res_elec, nonres_fossil, nonres_elec].each do |data|
      if data['type'] == dom_type && data['fuel'] == dom_fuel
        dom_type_dom_fuel = data
      elsif data['type'] == dom_type && data['fuel'] != dom_fuel
        dom_type_sec_fuel = data
      elsif data['type'] != dom_type && data['fuel'] == dom_fuel
        sec_type_dom_fuel = data    
      elsif data['type'] != dom_type && data['fuel'] != dom_fuel
        sec_type_sec_fuel = data
      end
    end
    
    # Define the minimum area for the 
    # exception that allows a different
    # system type in part of the building.
    # This is common across different versions
    # of 90.1
    exception_min_area_ft2 = nil
    case standard
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      exception_min_area_ft2 = 20000
    end    

    # There are four possible categories of data
    # dom is the dominant zones, or zones that don't fall into an exception
    # exc_fuel is any group of zones that meet the fuel type exception
    # exc_occ is any group of zones that meet the occ type exception
    # exc_fuel_occ is any group of zones that meet both the fuel and occ typ exceptions
    dom = dom_type_dom_fuel
    exc_fuel = nil
    exc_occ = nil
    exc_fuel_occ = nil
    # Exception for fuel type
    if dom_type_sec_fuel['area_ft2'] > exception_min_area_ft2
      exc_fuel = dom_type_sec_fuel
    else
      dom['area_ft2'] += dom_type_sec_fuel['area_ft2']
      dom['zones'] += dom_type_sec_fuel['zones']
    end
    # Exception for occupancy type
    if sec_type_dom_fuel['area_ft2'] > exception_min_area_ft2
      exc_fuel = sec_type_dom_fuel
    else
      dom['area_ft2'] += sec_type_dom_fuel['area_ft2']
      dom['zones'] += sec_type_dom_fuel['zones']
    end    
    # Exception for fuel type and occupancy type
    if sec_type_sec_fuel['area_ft2'] > exception_min_area_ft2
      exc_fuel = sec_type_sec_fuel
    else
      dom['area_ft2'] += sec_type_sec_fuel['area_ft2']
      dom['zones'] += sec_type_sec_fuel['zones']
    end     

    # Put all the non-nil groups into an array. 
    # A group will be nil if the exception was not triggered.
    sys_groups = []
    [dom, exc_fuel, exc_occ, exc_fuel_occ].each do |data|
      next if data.nil?
      sys_groups << data
    end
    
    return sys_groups
  
  end
  
  # Determine the baseline system type given the
  # inputs.  Logic is different for different standards.
  #
  # @param standard [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param area_type [String] Valid choices are residential,
  # nonresidential, and heatedonly
  # @param heating_fuel_type [String] Valid choices are
  # electric and fossil
  # @param area_ft2 [Double] Area in ft^2
  # @param num_stories [Integer] Number of stories
  # @return [String] The system type.  Possibilities are
  # PTHP, PTAC, PSZ_AC, PSZ_HP, PVAV_Reheat, PVAV_PFP_Boxes, 
  # VAV_Reheat, VAV_PFP_Boxes, Gas_Furnace, Electric_Furnace
  # @todo add 90.1-2013 systems 11-13
  def performance_rating_method_baseline_system_type(standard, climate_zone, area_type, heating_fuel_type, area_ft2, num_stories)
  
    system_type = nil
  
    case standard
    when '90.1-2004', '90.1-2007', '90.1-2010' 
      # Set the limit differently for
      # different codes
      limit_ft2 = 25000
      limit_ft2 = 75000 if standard == '90.1-2004'

      case area_type
      when 'residential'
        if heating_fuel_type == 'electric'
          system_type = 'PTHP' # sys 2
        else
          system_type = 'PTAC' # sys 1
        end
      when 'nonresidential'
        # nonresidential and 3 floors or less and <75,000 ft2
        if num_stories <= 3 && area_ft2 < limit_ft2
          if heating_fuel_type == 'electric'
            system_type = 'PSZ_HP' # sys 4
          else
            system_type = 'PSZ_AC' # sys 3
          end
        # nonresidential and 4 or 5 floors or 5 floors or less and 75,000 ft2 to 150,000 ft2
        elsif ( ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150000)) )
          if heating_fuel_type == 'electric'
            system_type = 'PVAV_PFP_Boxes' # sys 6
          else
            system_type = 'PVAV_Reheat' # sys 5
          end
        # nonresidential and more than 5 floors or >150,000 ft2
        elsif (num_stories >= 5 || area_ft2 > 150000)
          if heating_fuel_type == 'electric'
            system_type = 'VAV_PFP_Boxes' # sys 8
          else
            system_type = 'VAV_Reheat' # sys 7
          end
        end
      when 'heatedonly'
        if heating_fuel_type == 'electric'
          system_type = 'Electric_Furnace' # sys 9
        else
          system_type = 'Gas_Furnace' # sys 10
        end
      end
      
    when '90.1-2013'
    
      limit_ft2 = 25000
    
      # Fuel type is determined based on climate zone
      # for 90.1-2013
      case climate_zone
      when 'ASHRAE 169-2006-1A',
            'ASHRAE 169-2006-2A',
            'ASHRAE 169-2006-3A'
        heating_fuel_type = 'electric'
      else
        heating_fuel_type = 'fossil'
      end
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Heating fuel is #{heating_fuel_type} for 90.1-2013, climate zone #{climate_zone}.  This is independent of the heating fuel type in the proposed building, per G3.1.1-3.  This is different than previous versions of 90.1.")
    
      case area_type
      when 'residential'
        if heating_fuel_type == 'electric'
          system_type = 'PTHP' # sys 2
        else
          system_type = 'PTAC' # sys 1
        end
      when 'nonresidential'
        # nonresidential and 3 floors or less and <75,000 ft2
        if num_stories <= 3 && area_ft2 < limit_ft2
          if heating_fuel_type == 'electric'
            system_type = 'PSZ_HP' # sys 4
          else
            system_type = 'PSZ_AC' # sys 3
          end
        # nonresidential and 4 or 5 floors or 5 floors or less and 75,000 ft2 to 150,000 ft2
        elsif ( ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150000)) )
          if heating_fuel_type == 'electric'
            system_type = 'PVAV_PFP_Boxes' # sys 6
          else
            system_type = 'PVAV_Reheat' # sys 5
          end
        # nonresidential and more than 5 floors or >150,000 ft2
        elsif (num_stories >= 5 || area_ft2 > 150000)
          if heating_fuel_type == 'electric'
            system_type = 'VAV_PFP_Boxes' # sys 8
          else
            system_type = 'VAV_Reheat' # sys 7
          end
        end
      when 'heatedonly'
        if heating_fuel_type == 'electric'
          system_type = 'Electric_Furnace' # sys 9
        else
          system_type = 'Gas_Furnace' # sys 10
        end
      end

    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "System type is #{system_type} for #{standard}, #{area_type}, #{heating_fuel_type}, #{area_ft2.round} ft^2, #{num_stories} stories.")
  
    return system_type
    
  end
  
  # Add the specified baseline system type to the
  # specified zons based on the specified standard.
  # For some multi-zone system types, the standards require
  # identifying zones whose loads or schedules
  # are outliers and putting these systems on separate
  # single-zone systems.  This method does that.
  #
  # @param standard [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param area_type [String] Valid choices are residential,
  # nonresidential, and heatedonly
  # @param heating_fuel_type [String] Valid choices are
  # electric and fossil
  # @param area_ft2 [Double] Area in ft^2
  # @param num_stories [Integer] Number of stories
  # @param system_type [String] The system type.  Valid choices are
  # PTHP, PTAC, PSZ_AC, PSZ_HP, PVAV_Reheat, PVAV_PFP_Boxes, 
  # VAV_Reheat, VAV_PFP_Boxes, Gas_Furnace, Electric_Furnace,
  # which are also returned by the method
  # OpenStudio::Model::Model.performance_rating_method_baseline_system_type.
  # @todo add 90.1-2013 systems 11-13    
  def add_performance_rating_method_baseline_system(standard, system_type, zones)
  
    case standard
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
     
      case system_type
      when 'PTAC' # System 1
      
        if zones.size > 0
      
          # Retrieve the existing hot water loop
          # or add a new one if necessary.
          hot_water_loop = nil
          if self.getPlantLoopByName('Hot Water Loop').is_initialized
            hot_water_loop = self.getPlantLoopByName('Hot Water Loop').get
          else
            hot_water_loop = self.add_hw_loop('NaturalGas')
          end      
        
          # Add a hot water PTAC to each zone
          self.add_ptac(standard,
                        nil,
                        hot_water_loop,
                        zones,
                        'ConstantVolume',
                        'Water',
                        'Single Speed DX AC')
        end
      
 
      when 'PTHP' # System 2
      
        if zones.size > 0
        
          # Add an air-source packaged terminal
          # heat pump with electric supplemental heat
          # to each zone.
          self.add_pthp(standard, 
                  nil,
                  zones,
                  'ConstantVolume')
                
        end

      when 'PSZ_AC' # System 3

        if zones.size > 0
      
          # Add a gas-fired PSZ-AC to each zone
          # hvac_op_sch=nil means always on
          # oa_damper_sch to nil means always open
          self.add_psz_ac(standard,
                          sys_name=nil,
                          hot_water_loop=nil,
                          chilled_water_loop=nil,
                          zones,
                          hvac_op_sch=nil,
                          oa_damper_sch=nil,
                          fan_location='DrawThrough',
                          fan_type='ConstantVolume',
                          heating_type='Gas',
                          supplemental_heating_type='Gas',  # Should we really add supplemental heating here?
                          cooling_type='Single Speed DX AC',
                          building_type=nil)      
                        
        end
      
      when 'PSZ_HP'  # System 4

        if zones.size > 0
      
          # Add an air-source packaged single zone
          # heat pump with electric supplemental heat
          # to each zone.
          self.add_psz_ac(standard, 
                        'PSZ-HP', 
                        nil, 
                        nil,
                        zones,
                        nil,
                        nil,
                        'DrawThrough', 
                        'ConstantVolume',
                        'Single Speed Heat Pump',
                        'Electric',
                        'Single Speed Heat Pump',
                        building_type=nil)

        end
      
      when 'PVAV_Reheat' # System 5
      
        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        if self.getPlantLoopByName('Hot Water Loop').is_initialized
          hot_water_loop = self.getPlantLoopByName('Hot Water Loop').get
        else
          hot_water_loop = self.add_hw_loop('NaturalGas')
        end
        
        # Group zones by story
        story_zone_lists = self.group_zones_by_story(zones)
        
        # For the array of zones on each story,
        # separate the primary zones from the secondary zones.
        # Add the baseline system type to the primary zones
        # and add the suplemental system type to the secondary zones.
        story_zone_lists.each do |zones|
        
          # Differentiate primary and secondary zones
          pri_sec_zone_lists = self.differentiate_primary_secondary_thermal_zones(zones)
          pri_zones = pri_sec_zone_lists['primary']
          sec_zones = pri_sec_zone_lists['secondary']
          

          # Add a PVAV with Reheat for the primary zones
          story_name = zones[0].spaces[0].buildingStory.get.name.get
          sys_name = "#{story_name} PVAV_Reheat (Sys5)"

          # If and only if there are primary zones to attach to the loop
          # counter example: floor with only one elevator machine room that get classified as sec_zones
          if pri_zones.size > 0

            self.add_pvav(standard,
                          sys_name,
                          pri_zones,
                          nil,
                          nil,
                          hot_water_loop)
          end

          # Add a PSZ_AC for each secondary zone
          if sec_zones.size > 0
            self.add_performance_rating_method_baseline_system(standard, 'PSZ_AC', sec_zones)
          end
        end      
      
      when 'PVAV_PFP_Boxes' # System 6

      

      when 'VAV_Reheat' # System 7
      
        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        if self.getPlantLoopByName('Hot Water Loop').is_initialized
          hot_water_loop = self.getPlantLoopByName('Hot Water Loop').get
        else
          hot_water_loop = self.add_hw_loop('NaturalGas')
        end

        # Retrieve the existing chilled water loop
        # or add a new one if necessary.
        chilled_water_loop = nil
        if self.getPlantLoopByName('Chilled Water Loop').is_initialized
          chilled_water_loop = self.getPlantLoopByName('Chilled Water Loop').get
        else
          condenser_water_loop = self.add_cw_loop()
          chilled_water_loop = self.add_chw_loop(standard,
                                                'const_pri_var_sec',
                                                'WaterCooled',
                                                nil,
                                                'Rotary Screw',
                                                175.0,
                                                condenser_water_loop)
        end
        
        # Group zones by story
        story_zone_lists = self.group_zones_by_story(zones)
        
        # For the array of zones on each story,
        # separate the primary zones from the secondary zones.
        # Add the baseline system type to the primary zones
        # and add the suplemental system type to the secondary zones.
        story_zone_lists.each do |zones|

          # The group_zones_by_story NO LONGER returns empty lists when a given floor doesn't have any of the zones
          # So NO need to filter it out otherwise you get an error undefined method `spaces' for nil:NilClass
          #next if zones.empty?
        
          # Differentiate primary and secondary zones
          pri_sec_zone_lists = self.differentiate_primary_secondary_thermal_zones(zones)
          pri_zones = pri_sec_zone_lists['primary']
          sec_zones = pri_sec_zone_lists['secondary']
          
          # Add a VAV for the primary zones
          story_name = zones[0].spaces[0].buildingStory.get.name.get
          sys_name = "#{story_name} VAV_Reheat (Sys7)"

          # If and only if there are primary zones to attach to the loop
          # counter example: floor with only one elevator machine room that get classified as sec_zones
          if pri_zones.size > 0
            self.add_vav_reheat(standard,
                        sys_name,
                        hot_water_loop,
                        chilled_water_loop,
                        pri_zones,
                        nil,
                        nil,
                        0.62,
                        0.9,
                        OpenStudio.convert(4.0, 'inH_{2}O', 'Pa').get,
                        nil)
          end
          
          # Add a PSZ_AC for each secondary zone
          if sec_zones.size > 0
            self.add_performance_rating_method_baseline_system(standard, 'PSZ_AC', sec_zones)
          end


        end
    
      when 'VAV_PFP_Boxes' # System 8
      
        # Retrieve the existing chilled water loop
        # or add a new one if necessary.
        chilled_water_loop = nil
        if self.getPlantLoopByName('Chilled Water Loop').is_initialized
          chilled_water_loop = self.getPlantLoopByName('Chilled Water Loop').get
        else
          condenser_water_loop = self.add_cw_loop()
          chilled_water_loop = self.add_chw_loop(standard,
                                                'const_pri_var_sec',
                                                'WaterCooled',
                                                nil,
                                                'Rotary Screw',
                                                175.0,
                                                condenser_water_loop)
        end
        
        # Group zones by story
        story_zone_lists = self.group_zones_by_story(zones)
        
        # For the array of zones on each story,
        # separate the primary zones from the secondary zones.
        # Add the baseline system type to the primary zones
        # and add the suplemental system type to the secondary zones.
        story_zone_lists.each do |zones|
        
          # Differentiate primary and secondary zones
          pri_sec_zone_lists = self.differentiate_primary_secondary_thermal_zones(zones)
          pri_zones = pri_sec_zone_lists['primary']
          sec_zones = pri_sec_zone_lists['secondary']
          
          # Add an VAV for the primary zones
          story_name = zones[0].spaces[0].buildingStory.get.name.get
          sys_name = "#{story_name} VAV_PFP_Boxes (Sys8)"
          # If and only if there are primary zones to attach to the loop
          if pri_zones.size > 0
            self.add_vav_pfp_boxes(standard,
                                   sys_name,
                                  chilled_water_loop,
                                  pri_zones,
                                  nil,
                                  nil,
                                  0.62,
                                  0.9,
                                  OpenStudio.convert(4.0, 'inH_{2}O', 'Pa').get)
          end
          # Add a PSZ_HP for each secondary zone
          if sec_zones.size > 0
            self.add_performance_rating_method_baseline_system(standard, 'PSZ_HP', sec_zones)
          end

        end      

        when 'Gas_Furnace' # System 9
         
          if zones.size > 0
        
            # Add a System 9 - Gas Unit Heater to each zone
            self.add_unitheater(standard,
                               nil,
                               zones,
                               nil,
                               'ConstantVolume',
                               OpenStudio::convert(0.2, "inH_{2}O", "Pa").get,
                               'Gas',
                               nil)
                             
          end

      when 'Electric_Furnace'  # System 10
      
        if zones.size > 0
      
          # Add a System 10 - Electric Unit Heater to each zone
          self.add_unitheater(standard,
                                nil,
                                zones,
                                nil,
                                'ConstantVolume',
                                OpenStudio::convert(0.2, "inH_{2}O", "Pa").get,
                                'Electric',
                                nil)
                              
        end
      
      else
      
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "System type #{system_type} is not a valid choice, nothing will be added to the model.")

      end
    
    end

  end
  
  # Determine which of the zones
  # should be served by the primary HVAC system.
  # First, eliminate zones that differ by more
  # than 40 full load hours per week.  In this case,
  # lighting schedule is used as the proxy for operation
  # instead of occupancy to avoid accidentally removing
  # transition spaces.  Second, eliminate zones whose
  # heating or cooling loads differ from the 
  # area-weighted average of all other zones
  # on the system by more than 10 Btu/hr*ft^2.
  #
  # @todo Improve load-based exception algorithm.
  # Current algorithm is faithful to 90.1, but can
  # lead to nonsensical results in some cases.
  # @return [Hash] A hash of two arrays of ThermalZones,
  # where the keys are 'primary' and 'secondary'
  def differentiate_primary_secondary_thermal_zones(zones)
    
    # Determine the operational hours (proxy is annual
    # full load lighting hours) for all zones
    zone_data_1 = []
    zones.each do |zone|    
      data = {}
      data['zone'] = zone
      # Get the area
      area_ft2 = OpenStudio.convert(zone.floorArea, 'm^2', 'ft^2').get
      data['area_ft2'] = area_ft2      
      #OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "#{zone.name}")
      zone.spaces.each do |space|
        #OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "***#{space.name}")
        # Get all lights from either the space
        # or the space type.
        all_lights = []
        all_lights += space.lights
        if space.spaceType.is_initialized
          all_lights += space.spaceType.get.lights
        end
        # Base the annual operational hours
        # on the first lights schedule with hours
        # greater than zero.
        ann_op_hrs = 0
        all_lights.sort.each do |lights|
          #OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "******#{lights.name}")
          # Get the fractional lighting schedule
          lights_sch = lights.schedule
          full_load_hrs = 0.0
          # Skip lights with no schedule
          next if lights_sch.empty?
          lights_sch = lights_sch.get
          if lights_sch.to_ScheduleRuleset.is_initialized 
            lights_sch = lights_sch.to_ScheduleRuleset.get
            full_load_hrs = lights_sch.annual_equivalent_full_load_hrs
            if full_load_hrs > 0
              ann_op_hrs = full_load_hrs
              break # Stop after the first schedule with more than 0 hrs
            end
          elsif lights_sch.to_ScheduleConstant.is_initialized
            lights_sch = lights_sch.to_ScheduleConstant.get
            full_load_hrs = lights_sch.annual_equivalent_full_load_hrs
            if full_load_hrs > 0
              ann_op_hrs = full_load_hrs
              break # Stop after the first schedule with more than 0 hrs
            end
          end
        end
        wk_op_hrs = ann_op_hrs / 52.0
        data['wk_op_hrs'] = wk_op_hrs
        #OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "******wk_op_hrs = #{wk_op_hrs.round}")

      end
      
      zone_data_1 << data

    end        

    # Filter out any zones that operate differently by more
    # than 40hrs/wk.  This will be determined by a difference of more
    # than (40 hrs/wk * 52 wks/yr) = 2080 annual full load hrs.
    zones_same_hrs = []
    zone_data_1.each_with_index do |data, i|
    
      # Eliminate the data from this zone
      other_zone_data_1 = Array.new(zone_data_1)
      other_zone_data_1.delete_at(i)
      
      # Calculate the area-weighted
      # average operating hours
      area_hrs = 1
      tot_area = 1
      other_zone_data_1.each do |other_data|
        area_hrs += other_data['area_ft2'] * other_data['wk_op_hrs']
        tot_area += other_data['area_ft2']
      end
      avg_wk_op_hrs = area_hrs / tot_area
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.BuildingStory", "For zone #{data['zone'].name} average of #{avg_wk_op_hrs.round} hrs/wk for other zones on the system.")
      
      # Compare avg to this zone
      wk_op_hrs = data['wk_op_hrs']
      if wk_op_hrs < avg_wk_op_hrs - 40.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For zone #{data['zone'].name}, the weekly full load operating hrs of #{wk_op_hrs.round} hrs is more than 40 hrs lower than the average of #{avg_wk_op_hrs.round} hrs for other zones on the system, zone will not be attached to the primary system.")
        next
      elsif wk_op_hrs > avg_wk_op_hrs + 40.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For zone #{data['zone'].name}, the weekly full load operating hrs of #{wk_op_hrs.round} hrs is more than 40 hrs higher than the average of #{avg_wk_op_hrs.round} hrs for other zones on the system, zone will not be attached to the primary system.")
        next
      end
    
      # Operating hours are same
      zones_same_hrs << data['zone']  
    
    end
        
    # Get the heating and cooling loads and areas for
    # all remaining zones.
    zone_data_2 = []
    zones_same_hrs.each do |zone|    
      data = {}
      data['zone'] = zone
      # Get the area
      area_ft2 = OpenStudio.convert(zone.floorArea, 'm^2', 'ft^2').get
      data['area_ft2'] = area_ft2
      # Get the heating load
      htg_load_w_per_m2 = zone.heatingDesignLoad
      if htg_load_w_per_m2.is_initialized
        htg_load_btu_per_ft2 = OpenStudio.convert(htg_load_w_per_m2.get,'W/m^2','Btu/hr*ft^2').get
        data['htg_load_btu_per_ft2'] = htg_load_btu_per_ft2
      else
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Standards.BuildingStory", "For zone #{data['zone'].name}, could not determine the design heating load.")
      end
      # Get the cooling load
      clg_load_w_per_m2 = zone.coolingDesignLoad
      if clg_load_w_per_m2.is_initialized
        clg_load_btu_per_ft2 = OpenStudio.convert(clg_load_w_per_m2.get,'W/m^2','Btu/hr*ft^2').get
        data['clg_load_btu_per_ft2'] = clg_load_btu_per_ft2
      else
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Standards.BuildingStory", "For zone #{data['zone'].name}, could not determine the design cooling load.")
      end
      zone_data_2 << data
    end    
   
    # Filter out any zones that are +/- 10 Btu/hr*ft^2 from the
    # area-weighted average.
    primary_zones = []
    zone_data_2.each_with_index do |data, i|

      # Eliminate the data from this zone
      other_zone_data_2 = Array.new(zone_data_2)
      other_zone_data_2.delete_at(i)
      
      # Calculate the area-weighted
      # average heating and cooling loads    
      htg_load_hrs = 0
      clg_load_hrs = 0
      area_hrs = 1
      htg_area = 1
      clg_area = 1
      other_zone_data_2.each do |other_data|
        # Don't include nil or zero loads in average
        unless other_data['htg_load_btu_per_ft2'].nil? || other_data['htg_load_btu_per_ft2'] == 0.0
          htg_load_hrs += other_data['area_ft2'] * other_data['htg_load_btu_per_ft2']
          htg_area += other_data['area_ft2']
        end
        # Don't include nil or zero loads in average
        unless other_data['clg_load_btu_per_ft2'].nil? || other_data['clg_load_btu_per_ft2'] == 0.0
          clg_load_hrs += other_data['area_ft2'] * other_data['clg_load_btu_per_ft2']
          clg_area += other_data['area_ft2']
        end        
      end
      avg_htg_load_btu_per_ft2 = htg_load_hrs / htg_area
      avg_clg_load_btu_per_ft2 = clg_load_hrs / clg_area
      # This is throwing an error: undefined method `round' for nil:NilClass
      # So I'll assign zero if nil for now
      data['htg_load_btu_per_ft2'] ||= 0
      data['clg_load_btu_per_ft2'] ||= 0
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.BuildingStory", "For zone #{data['zone'].name} heating = #{data['htg_load_btu_per_ft2'].round} Btu/hr*ft^2, average heating = #{avg_htg_load_btu_per_ft2.round} Btu/hr*ft^2 for other zones. Cooling = #{data['clg_load_btu_per_ft2'].round} Btu/hr*ft^2, average cooling = #{avg_clg_load_btu_per_ft2.round} Btu/hr*ft^2 for other zones.")
    
      # Filter on heating load
      htg_load_btu_per_ft2 = data['htg_load_btu_per_ft2']
      if htg_load_btu_per_ft2 < avg_htg_load_btu_per_ft2 - 10.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For zone #{data['zone'].name}, the heating load of #{htg_load_btu_per_ft2.round} Btu/hr*ft^2 is more than 10 Btu/hr*ft^2 lower than the average of #{avg_htg_load_btu_per_ft2.round} Btu/hr*ft^2 for other zones on the system, zone will be assigned a secondary system.")
        next
      elsif htg_load_btu_per_ft2 > avg_htg_load_btu_per_ft2 + 10.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For zone #{data['zone'].name}, the heating load of #{htg_load_btu_per_ft2.round} Btu/hr*ft^2 is more than 10 Btu/hr*ft^2 higher than the average of #{avg_htg_load_btu_per_ft2.round} Btu/hr*ft^2 for other zones on the system, zone will be assigned a secondary system.")
        next
      end
      
      # Filter on cooling load
      clg_load_btu_per_ft2 = data['clg_load_btu_per_ft2']
      if clg_load_btu_per_ft2 < avg_clg_load_btu_per_ft2 - 10.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For zone #{data['zone'].name}, the cooling load of #{clg_load_btu_per_ft2.round} Btu/hr*ft^2 is more than 10 Btu/hr*ft^2 lower than the average of #{avg_clg_load_btu_per_ft2.round} Btu/hr*ft^2 for other zones on the system, zone will be assigned a secondary system.")
        next
      elsif clg_load_btu_per_ft2 > avg_clg_load_btu_per_ft2 + 10.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For zone #{data['zone'].name}, the cooling load of #{clg_load_btu_per_ft2.round} Btu/hr*ft^2 is more than 10 Btu/hr*ft^2 higher than the average of #{avg_clg_load_btu_per_ft2.round} Btu/hr*ft^2 for other zones on the system, zone will be assigned a secondary system.")
        next
      end
      
      # It is a primary zone!
      primary_zones << data['zone']
      
    end
    
    # Secondary zones are all other zones
    secondary_zones = []
    zones.each do |zone|
      unless primary_zones.include?(zone)
        secondary_zones << zone
      end
    end
    
    return {'primary'=>primary_zones, 'secondary'=>secondary_zones}
  
  end

  # Group an array of zones into multiple arrays, one
  # for each story in the building.
  # Removes empty array (when the story doesn't contain any of the zones)
  # @return [Array<Array<OpenStudio::Model::ThermalZone>>] array of arrays of zones
  def group_zones_by_story(zones)
  
    story_zone_lists = []
    self.getBuildingStorys.each do |story|
      
      # Get all the spaces on this story
      spaces = story.spaces
      
      # Get all the thermal zones that serve these spaces
      all_zones_on_story = []
      spaces.each do |space|
        if space.thermalZone.is_initialized
          all_zones_on_story << space.thermalZone.get
        else
          OpenStudio::logFree(OpenStudio::Warn, "openstudio.Standards.Model", "Space #{space.name} has no thermal zone, it is not included in the simulation.")
        end
      end
    
      # Find zones in the list that are on this story
      zones_on_story = []
      zones.each do |zone|
        if all_zones_on_story.include?(zone)
          zones_on_story << zone
        end
      end
      
      story_zone_lists << zones_on_story

    end
    
    return story_zone_lists
    
  end
  
  # Assign each space in the model to a building story
  # based on common z (height) values.  If no story  
  # object is found for a particular height, create a new one
  # and assign it to the space.  Does not assign a story
  # to plenum spaces.
  #
  # @return [Bool] returns true if successful, false if not.
  def assign_spaces_to_stories()

    # Make hash of spaces and minz values
    sorted_spaces = {}
    self.getSpaces.each do |space|
      # Skip plenum spaces
      next if space.is_plenum
      
      # loop through space surfaces to find min z value
      z_points = []
      space.surfaces.each do |surface|
        surface.vertices.each do |vertex|
          z_points << vertex.z
        end
      end
      minz = z_points.min + space.zOrigin
      sorted_spaces[space] = minz
    end

    # Pre-sort spaces
    sorted_spaces = sorted_spaces.sort{|a,b| a[1]<=>b[1]}

    # Take the sorted list and assign/make stories
    sorted_spaces.each do |space|
      space_obj = space[0]
      space_minz = space[1]
      if space_obj.buildingStory.empty?

        story = get_story_for_nominal_z_coordinate(space_minz)
        space_obj.setBuildingStory(story)

      end
    end

    return true
    
  end
  
  # Creates a construction set with the construction types specified in the
  # Performance Rating Method (aka Appendix G aka LEED) and adds it to the model.
  # This method creates and adds the constructions and their materials as well.
  #
  # @param category [String] the construction set category desired.  
  # Valid choices are Nonresidential, Residential, and Semiheated
  # @param building_vintage [String] the building vintage.  Valid choices are 90.1-2004, 90.1-2007, 90.1-2010, 90.1-2013.
  # @return [OpenStudio::Model::DefaultConstructionSet] returns a default
  # construction set populated with the specified constructions.
  def add_performance_rating_method_construction_set(building_vintage, category)
  
    construction_set = OpenStudio::Model::OptionalDefaultConstructionSet.new

    # Find the climate zone set that this climate zone falls into
    climate_zone_set = find_climate_zone_set(clim, building_vintage)
    if !climate_zone_set
      return construction_set
    end

    # Get the object data
    data = self.find_object($os_standards['construction_sets'], {'template'=>building_vintage, 'climate_zone_set'=> climate_zone_set, 'building_type'=>building_type, 'space_type'=>spc_type, 'is_residential'=>is_residential})
    if !data
      data = self.find_object($os_standards['construction_sets'], {'template'=>building_vintage, 'climate_zone_set'=> climate_zone_set, 'building_type'=>building_type, 'space_type'=>spc_type})
      if !data
        return construction_set
      end
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding construction set: #{building_vintage}-#{clim}-#{building_type}-#{spc_type}-is_residential#{is_residential}")

    name = make_name(building_vintage, clim, building_type, spc_type)

    # Create a new construction set and name it
    construction_set = OpenStudio::Model::DefaultConstructionSet.new(self)
    construction_set.setName(name)

    # Specify the types of constructions
    # Exterior surfaces constructions
    exterior_floor_standards_construction_type = 'SteelFramed'
    exterior_wall_standards_construction_type = 'SteelFramed'
    exterior_roof_standards_construction_type = 'IEAD'
    
    # Ground contact surfaces constructions
    ground_contact_floor_standards_construction_type = 'Unheated'
    ground_contact_wall_standards_construction_type = 'Mass'
    
    # Exterior sub surfaces constructions
    exterior_fixed_window_standards_construction_type = 'IEAD'
    exterior_operable_window_standards_construction_type = 'IEAD'
    exterior_door_standards_construction_type = 'IEAD'
    exterior_overhead_door_standards_construction_type = 'IEAD'
    exterior_skylight_standards_construction_type = 'IEAD'
    
    
    
    # Exterior surfaces constructions
    exterior_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultExteriorSurfaceConstructions(exterior_surfaces)
    exterior_surfaces.setFloorConstruction(find_and_add_construction(building_vintage,
                                                                     climate_zone_set,
                                                                     'ExteriorFloor',
                                                                     exterior_floor_standards_construction_type,
                                                                     category))


    exterior_surfaces.setWallConstruction(find_and_add_construction(building_vintage,
                                                                     climate_zone_set,
                                                                     'ExteriorWall',
                                                                     exterior_wall_standards_construction_type,
                                                                     category))
                                                                       
    exterior_surfaces.setRoofCeilingConstruction(find_and_add_construction(building_vintage,
                                                                     climate_zone_set,
                                                                     'ExteriorRoof',
                                                                     exterior_roof_standards_construction_type,
                                                                     category))

    # Interior surfaces constructions
    interior_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultInteriorSurfaceConstructions(interior_surfaces)
    construction_name = interior_floors
    if construction_name != nil
      interior_surfaces.setFloorConstruction(add_construction(construction_name))
    end
    construction_name = interior_walls
    if construction_name != nil
      interior_surfaces.setWallConstruction(add_construction(construction_name))
    end
    construction_name = interior_ceilings
    if construction_name != nil
      interior_surfaces.setRoofCeilingConstruction(add_construction(construction_name))
    end

    # Ground contact surfaces constructions
    ground_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultGroundContactSurfaceConstructions(ground_surfaces)
    ground_surfaces.setFloorConstruction(find_and_add_construction(building_vintage,
                                                                     climate_zone_set,
                                                                     'GroundContactFloor',
                                                                     ground_contact_floor_standards_construction_type,
                                                                     category))

    ground_surfaces.setWallConstruction(find_and_add_construction(building_vintage,
                                                                     climate_zone_set,
                                                                     'GroundContactWall',
                                                                     ground_contact_wall_standards_construction_type,
                                                                     category))

    # Exterior sub surfaces constructions
    exterior_subsurfaces = OpenStudio::Model::DefaultSubSurfaceConstructions.new(self)
    construction_set.setDefaultExteriorSubSurfaceConstructions(exterior_subsurfaces)
    if exterior_fixed_window_standards_construction_type && exterior_fixed_window_building_category
      exterior_subsurfaces.setFixedWindowConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'ExteriorWindow',
                                                                       exterior_fixed_window_standards_construction_type,
                                                                       category))
    end
    if exterior_operable_window_standards_construction_type && exterior_operable_window_building_category
      exterior_subsurfaces.setOperableWindowConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'ExteriorWindow',
                                                                       exterior_operable_window_standards_construction_type,
                                                                       category))
    end
    if exterior_door_standards_construction_type && exterior_door_building_category
      exterior_subsurfaces.setDoorConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'ExteriorDoor',
                                                                       exterior_door_standards_construction_type,
                                                                       category))
    end
    construction_name = exterior_glass_doors
    if construction_name != nil
      exterior_subsurfaces.setGlassDoorConstruction(add_construction(construction_name))
    end
    if exterior_overhead_door_standards_construction_type && exterior_overhead_door_building_category
      exterior_subsurfaces.setOverheadDoorConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'ExteriorDoor',
                                                                       exterior_overhead_door_standards_construction_type,
                                                                       category))
    end
    if exterior_skylight_standards_construction_type && exterior_skylight_building_category
      exterior_subsurfaces.setSkylightConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'Skylight',
                                                                       exterior_skylight_standards_construction_type,
                                                                       category))
    end
    if construction_name = tubular_daylight_domes
      exterior_subsurfaces.setTubularDaylightDomeConstruction(add_construction(construction_name))
    end
    if construction_name = tubular_daylight_diffusers
      exterior_subsurfaces.setTubularDaylightDiffuserConstruction(add_construction(construction_name))
    end

    # Interior sub surfaces constructions
    interior_subsurfaces = OpenStudio::Model::DefaultSubSurfaceConstructions.new(self)
    construction_set.setDefaultInteriorSubSurfaceConstructions(interior_subsurfaces)
    if construction_name = interior_fixed_windows
      interior_subsurfaces.setFixedWindowConstruction(add_construction(construction_name))
    end
    if construction_name = interior_operable_windows
      interior_subsurfaces.setOperableWindowConstruction(add_construction(construction_name))
    end
    if construction_name = interior_doors
      interior_subsurfaces.setDoorConstruction(add_construction(construction_name))
    end

    # Other constructions
    if construction_name = interior_partitions
      construction_set.setInteriorPartitionConstruction(add_construction(construction_name))
    end
    if construction_name = space_shading
      construction_set.setSpaceShadingConstruction(add_construction(construction_name))
    end
    if construction_name = building_shading
      construction_set.setBuildingShadingConstruction(add_construction(construction_name))
    end
    if construction_name = site_shading
      construction_set.setSiteShadingConstruction(add_construction(construction_name))
    end

    # componentize the construction set
    #construction_set_component = construction_set.createComponent

    # Return the construction set
    return OpenStudio::Model::OptionalDefaultConstructionSet.new(construction_set)    
  
  
    # Create a constuction set that is all 
  
  
  end
  
  # Applies the multi-zone VAV outdoor air sizing requirements
  # to all applicable air loops in the model.
  #
  # @note This must be performed before the sizing run because
  # it impacts component sizes, which in turn impact efficiencies.
  def apply_multizone_vav_outdoor_air_sizing(building_vintage)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying multizone vav OA sizing.')

    # Multi-zone VAV outdoor air sizing
    self.getAirLoopHVACs.sort.each {|obj| obj.apply_multizone_vav_outdoor_air_sizing(building_vintage)}

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying multizone vav OA sizing.')
    
  end

  # Applies the HVAC parts of the standard to all objects in the model
  # using the the template/standard specified in the model.
  def applyHVACEfficiencyStandard(building_vintage, climate_zone)

    sql_db_vars_map = Hash.new()

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying HVAC efficiency standards.')

    # Air Loop Controls
    self.getAirLoopHVACs.sort.each {|obj| obj.apply_standard_controls(building_vintage, climate_zone)}

    ##### Apply equipment efficiencies

    # Fans
    # self.getFanVariableVolumes.sort.each {|obj| obj.setStandardEfficiency(building_vintage)}
    # self.getFanConstantVolumes.sort.each {|obj| obj.setStandardEfficiency(building_vintage)}
    # self.getFanOnOffs.sort.each {|obj| obj.setStandardEfficiency(building_vintage)}
    # self.getFanZoneExhausts.sort.each {|obj| obj.setStandardEfficiency(building_vintage)}

    # Pumps
    #self.getPumpConstantSpeeds.sort.each {|obj| obj.set_standard_minimum_motor_efficiency(building_vintage)}
    #self.getPumpVariableSpeeds.sort.each {|obj| obj.set_standard_minimum_motor_efficiency(building_vintage)}
    
    # Unitary ACs
    self.getCoilCoolingDXTwoSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(building_vintage)}
    self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| sql_db_vars_map = obj.setStandardEfficiencyAndCurves(building_vintage, sql_db_vars_map)}

    # Unitary HPs
    self.getCoilHeatingDXSingleSpeeds.sort.each {|obj| sql_db_vars_map = obj.setStandardEfficiencyAndCurves(building_vintage, sql_db_vars_map)}

    # Chillers
    self.getChillerElectricEIRs.sort.each {|obj| obj.setStandardEfficiencyAndCurves(building_vintage)}

    # Boilers
    self.getBoilerHotWaters.sort.each {|obj| obj.setStandardEfficiencyAndCurves(building_vintage)}

    # Water Heaters
    self.getWaterHeaterMixeds.sort.each {|obj| obj.setStandardEfficiency(building_vintage)}

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying HVAC efficiency standards.')

  end

  # Applies daylighting controls to each space in the model
  # per the standard.
  def addDaylightingControls(building_vintage)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started adding daylighting controls.')

    # Add daylighting controls to each space
    self.getSpaces.sort.each do |space|
      added = space.addDaylightingControls(building_vintage, false, false)
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding daylighting controls.')

  end

  # Apply the air leakage requirements to the model,
  # as described in PNNL section 5.2.1.6.
  #
  # base infiltration rates off of.
  # @return [Bool] true if successful, false if not
  # @todo This infiltration method is not used by the Reference
  # buildings, fix this inconsistency.
  def apply_infiltration_standard(building_vintage)

    # Set the infiltration rate at each space
    self.getSpaces.sort.each do |space|
      space.set_infiltration_rate(building_vintage)
    end

    case building_vintage
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        #"For 'DOE Ref Pre-1980' and 'DOE Ref 1980-2004', infiltration rates are not defined using this method, no changes have been made to the model.
      else
        # Remove infiltration rates set at the space type
        self.getSpaceTypes.each do |space_type|
          space_type.spaceInfiltrationDesignFlowRates.each do |infil|
            infil.remove
          end
        end
      end
  end

  # Method to search through a hash for the objects that meets the
  # desired search criteria, as passed via a hash.
  # Returns an Array (empty if nothing found) of matching objects.
  #
  # @param hash_of_objects [Hash] hash of objects to search through
  # @param search_criteria [Hash] hash of search criteria
  # @param capacity [Double] capacity of the object in question.  If capacity is supplied,
  #   the objects will only be returned if the specified capacity is between
  #   the minimum_capacity and maximum_capacity values.
  # @return [Array] returns an array of hashes, one hash per object.  Array is empty if no results.
  # @example Find all the schedule rules that match the name
  #   rules = self.find_objects($os_standards['schedules'], {'name'=>schedule_name})
  #   if rules.size == 0
  #     OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for schedule: #{schedule_name}, will not be created.")
  #     return false #TODO change to return empty optional schedule:ruleset?
  #   end
  def find_objects(hash_of_objects, search_criteria, capacity = nil)

    desired_object = nil
    search_criteria_matching_objects = []
    matching_objects = []

    # Compare each of the objects against the search criteria
    hash_of_objects.each do |object|
      meets_all_search_criteria = true
      search_criteria.each do |key, value|
        # Don't check non-existent search criteria
        next unless object.has_key?(key)
        # Stop as soon as one of the search criteria is not met
        if object[key] != value
          meets_all_search_criteria = false
          break
        end
      end
      # Skip objects that don't meet all search criteria
      next if meets_all_search_criteria == false
      # If made it here, object matches all search criteria
      search_criteria_matching_objects << object
    end

    # If capacity was specified, narrow down the matching objects
    if capacity.nil?
      matching_objects = search_criteria_matching_objects
    else
      # Round up if capacity is an integer
      if capacity = capacity.round
        capacity = capacity + (capacity * 0.01)
      end
      search_criteria_matching_objects.each do |object|
        # Skip objects that don't have fields for minimum_capacity and maximum_capacity
        next if !object.has_key?('minimum_capacity') || !object.has_key?('maximum_capacity')
        # Skip objects that don't have values specified for minimum_capacity and maximum_capacity
        next if object['minimum_capacity'].nil? || object['maximum_capacity'].nil?
        # Skip objects whose the minimum capacity is below the specified capacity
        next if capacity <= object['minimum_capacity']
        # Skip objects whose max
        next if capacity > object['maximum_capacity']
        # Found a matching object
        matching_objects << object
      end
    end

    # Check the number of matching objects found
    if matching_objects.size == 0
      desired_object = nil
      #OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find objects search criteria returned no results. Search criteria: #{search_criteria}, capacity = #{capacity}.  Called from #{caller(0)[1]}.")
    end

    return matching_objects

  end

  # Method to search through a hash for an object that meets the
  # desired search criteria, as passed via a hash.  If capacity is supplied,
  # the object will only be returned if the specified capacity is between
  # the minimum_capacity and maximum_capacity values.
  #
  #
  # @param hash_of_objects [Hash] hash of objects to search through
  # @param search_criteria [Hash] hash of search criteria
  # @param capacity [Double] capacity of the object in question.  If capacity is supplied,
  #   the objects will only be returned if the specified capacity is between
  #   the minimum_capacity and maximum_capacity values.
  # @return [Hash] Return tbe first matching object hash if successful, nil if not.
  # @example Find the motor that meets these size criteria
  #   search_criteria = {
  #   'template' => template,
  #   'number_of_poles' => 4.0,
  #   'type' => 'Enclosed',
  #   }
  #   motor_properties = self.model.find_object(motors, search_criteria, 2.5)
  def find_object(hash_of_objects, search_criteria, capacity = nil)

    desired_object = nil
    search_criteria_matching_objects = []
    matching_objects = []

    # Compare each of the objects against the search criteria
    hash_of_objects.each do |object|
      meets_all_search_criteria = true
      search_criteria.each do |key, value|
        # Don't check non-existent search criteria
        next unless object.has_key?(key)
        # Stop as soon as one of the search criteria is not met
        if object[key] != value
          meets_all_search_criteria = false
          break
        end
      end
      # Skip objects that don't meet all search criteria
      next if !meets_all_search_criteria
      # If made it here, object matches all search criteria
      search_criteria_matching_objects << object
    end

    # If capacity was specified, narrow down the matching objects
    if capacity.nil?
      matching_objects = search_criteria_matching_objects
    else
      # Round up if capacity is an integer
      if capacity == capacity.round
        capacity = capacity + (capacity * 0.01)
      end
      search_criteria_matching_objects.each do |object|
        # Skip objects that don't have fields for minimum_capacity and maximum_capacity
        next if !object.has_key?('minimum_capacity') || !object.has_key?('maximum_capacity')
        # Skip objects that don't have values specified for minimum_capacity and maximum_capacity
        next if object['minimum_capacity'].nil? || object['maximum_capacity'].nil?
        # Skip objects whose the minimum capacity is below the specified capacity
        next if capacity <= object['minimum_capacity'].to_f
        # Skip objects whose max
        next if capacity > object['maximum_capacity'].to_f
        # Found a matching object
        matching_objects << object
      end
    end

    # Check the number of matching objects found
    if matching_objects.size == 0
      desired_object = nil
      #OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned no results. Search criteria: #{search_criteria}, capacity = #{capacity}.  Called from #{caller(0)[1]}")
    elsif matching_objects.size == 1
      desired_object = matching_objects[0]
    else
      desired_object = matching_objects[0]
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned #{matching_objects.size} results, the first one will be returned. Called from #{caller(0)[1]}. \n Search criteria: \n #{search_criteria} \n  All results: \n #{matching_objects.join("\n")}")
    end

    return desired_object

  end

  # Create a schedule from the openstudio standards dataset and
  # add it to the model.
  #
  # @param schedule_name [String} name of the schedule
  # @return [ScheduleRuleset] the resulting schedule ruleset
  # @todo make return an OptionalScheduleRuleset
  def add_schedule(schedule_name)
    return nil if schedule_name == nil or schedule_name == ""
    # First check model and return schedule if it already exists
    self.getSchedules.each do |schedule|
      if schedule.name.get.to_s == schedule_name
        OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added schedule: #{schedule_name}")
        return schedule
      end
    end

    require 'date'

    #OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding schedule: #{schedule_name}")

    # Find all the schedule rules that match the name
    rules = self.find_objects($os_standards['schedules'], {'name'=>schedule_name})
    if rules.size == 0
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for schedule: #{schedule_name}, will not be created.")
      return false #TODO change to return empty optional schedule:ruleset?
    end

    # Helper method to fill in hourly values
    def add_vals_to_sch(day_sch, sch_type, values)
      if sch_type == "Constant"
        day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), values[0])
      elsif sch_type == "Hourly"
        for i in 0..23
          next if values[i] == values[i + 1]
          day_sch.addValue(OpenStudio::Time.new(0, i + 1, 0, 0), values[i])
        end
      else
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Schedule type: #{sch_type} is not recognized.  Valid choices are 'Constant' and 'Hourly'.")
      end
    end

    # Make a schedule ruleset
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(self)
    sch_ruleset.setName("#{schedule_name}")

    # Loop through the rules, making one for each row in the spreadsheet
    rules.each do |rule|
      day_types = rule['day_types']
      start_date = DateTime.parse(rule['start_date'])
      end_date = DateTime.parse(rule['end_date'])
      sch_type = rule['type']
      values = rule['values']

      #Day Type choices: Wkdy, Wknd, Mon, Tue, Wed, Thu, Fri, Sat, Sun, WntrDsn, SmrDsn, Hol

      # Default
      if day_types.include?('Default')
        day_sch = sch_ruleset.defaultDaySchedule
        day_sch.setName("#{schedule_name} Default")
        add_vals_to_sch(day_sch, sch_type, values)
      end

      # Winter Design Day
      if day_types.include?('WntrDsn')
        day_sch = OpenStudio::Model::ScheduleDay.new(self)
        sch_ruleset.setWinterDesignDaySchedule(day_sch)
        day_sch = sch_ruleset.winterDesignDaySchedule
        day_sch.setName("#{schedule_name} Winter Design Day")
        add_vals_to_sch(day_sch, sch_type, values)
      end

      # Summer Design Day
      if day_types.include?('SmrDsn')
        day_sch = OpenStudio::Model::ScheduleDay.new(self)
        sch_ruleset.setSummerDesignDaySchedule(day_sch)
        day_sch = sch_ruleset.summerDesignDaySchedule
        day_sch.setName("#{schedule_name} Summer Design Day")
        add_vals_to_sch(day_sch, sch_type, values)
      end

      # Other days (weekdays, weekends, etc)
      if day_types.include?('Wknd') ||
        day_types.include?('Wkdy') ||
        day_types.include?('Sat') ||
        day_types.include?('Sun') ||
        day_types.include?('Mon') ||
        day_types.include?('Tue') ||
        day_types.include?('Wed') ||
        day_types.include?('Thu') ||
        day_types.include?('Fri')

        # Make the Rule
        sch_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
        day_sch = sch_rule.daySchedule
        day_sch.setName("#{schedule_name} #{day_types} Day")
        add_vals_to_sch(day_sch, sch_type, values)

        # Set the dates when the rule applies
        sch_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_date.month.to_i), start_date.day.to_i))
        sch_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_date.month.to_i), end_date.day.to_i))

        # Set the days when the rule applies
        # Weekends
        if day_types.include?('Wknd')
          sch_rule.setApplySaturday(true)
          sch_rule.setApplySunday(true)
        end
        # Weekdays
        if day_types.include?('Wkdy')
          sch_rule.setApplyMonday(true)
          sch_rule.setApplyTuesday(true)
          sch_rule.setApplyWednesday(true)
          sch_rule.setApplyThursday(true)
          sch_rule.setApplyFriday(true)
        end
        # Individual Days
        sch_rule.setApplyMonday(true) if day_types.include?('Mon')
        sch_rule.setApplyTuesday(true) if day_types.include?('Tue')
        sch_rule.setApplyWednesday(true) if day_types.include?('Wed')
        sch_rule.setApplyThursday(true) if day_types.include?('Thu')
        sch_rule.setApplyFriday(true) if day_types.include?('Fri')
        sch_rule.setApplySaturday(true) if day_types.include?('Sat')
        sch_rule.setApplySunday(true) if day_types.include?('Sun')

      end

    end # Next rule

    return sch_ruleset

  end

  # Create a material from the openstudio standards dataset.
  # @todo make return an OptionalMaterial
  def add_material(material_name)
    # First check model and return material if it already exists
    self.getMaterials.each do |material|
      if material.name.get.to_s == material_name
        OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added material: #{material_name}")
        return material
      end
    end

    #OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding material: #{material_name}")

    # Get the object data
    data = self.find_object($os_standards['materials'], {'name'=>material_name})
    if !data
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for material: #{material_name}, will not be created.")
      return false #TODO change to return empty optional material
    end

    material = nil
    material_type = data['material_type']

    if material_type == 'StandardOpaqueMaterial'
      material = OpenStudio::Model::StandardOpaqueMaterial.new(self)
      material.setName(material_name)

      material.setRoughness(data['roughness'].to_s)
      material.setThickness(OpenStudio.convert(data['thickness'].to_f, 'in', 'm').get)
      material.setConductivity(OpenStudio.convert(data['conductivity'].to_f, 'Btu*in/hr*ft^2*R', 'W/m*K').get)
      material.setDensity(OpenStudio.convert(data['density'].to_f, 'lb/ft^3', 'kg/m^3').get)
      material.setSpecificHeat(OpenStudio.convert(data['specific_heat'].to_f, 'Btu/lb*R', 'J/kg*K').get)
      material.setThermalAbsorptance(data['thermal_absorptance'].to_f)
      material.setSolarAbsorptance(data['solar_absorptance'].to_f)
      material.setVisibleAbsorptance(data['visible_absorptance'].to_f)

    elsif material_type == 'MasslessOpaqueMaterial'
      material = OpenStudio::Model::MasslessOpaqueMaterial.new(self)
      material.setName(material_name)
      material.setThermalResistance(OpenStudio.convert(data['resistance'].to_f, 'hr*ft^2*R/Btu', 'm^2*K/W').get)

      material.setConductivity(OpenStudio.convert(data['conductivity'].to_f, 'Btu*in/hr*ft^2*R', 'W/m*K').get)
      material.setDensity(OpenStudio.convert(data['density'].to_f, 'lb/ft^3', 'kg/m^3').get)
      material.setSpecificHeat(OpenStudio.convert(data['specific_heat'].to_f, 'Btu/lb*R', 'J/kg*K').get)
      material.setThermalAbsorptance(data['thermal_absorptance'].to_f)
      material.setSolarAbsorptance(data['solar_absorptance'].to_f)
      material.setVisibleAbsorptance(data['visible_absorptance'].to_f)

    elsif material_type == 'AirGap'
      material = OpenStudio::Model::AirGap.new(self)
      material.setName(material_name)

      material.setThermalResistance(OpenStudio.convert(data['resistance'].to_f, 'hr*ft^2*R/Btu*in', 'm*K/W').get)

    elsif material_type == 'Gas'
      material = OpenStudio::Model::Gas.new(self)
      material.setName(material_name)

      material.setThickness(OpenStudio.convert(data['thickness'].to_f, 'in', 'm').get)
      material.setGasType(data['gas_type'].to_s)

    elsif material_type == 'SimpleGlazing'
      material = OpenStudio::Model::SimpleGlazing.new(self)
      material.setName(material_name)

      material.setUFactor(OpenStudio.convert(data['u_factor'].to_f, 'Btu/hr*ft^2*R', 'W/m^2*K').get)
      material.setSolarHeatGainCoefficient(data['solar_heat_gain_coefficient'].to_f)
      material.setVisibleTransmittance(data['visible_transmittance'].to_f)

    elsif material_type == 'StandardGlazing'
      material = OpenStudio::Model::StandardGlazing.new(self)
      material.setName(material_name)

      material.setOpticalDataType(data['optical_data_type'].to_s)
      material.setThickness(OpenStudio.convert(data['thickness'].to_f, 'in', 'm').get)
      material.setSolarTransmittanceatNormalIncidence(data['solar_transmittance_at_normal_incidence'].to_f)
      material.setFrontSideSolarReflectanceatNormalIncidence(data['front_side_solar_reflectance_at_normal_incidence'].to_f)
      material.setBackSideSolarReflectanceatNormalIncidence(data['back_side_solar_reflectance_at_normal_incidence'].to_f)
      material.setVisibleTransmittanceatNormalIncidence(data['visible_transmittance_at_normal_incidence'].to_f)
      material.setFrontSideVisibleReflectanceatNormalIncidence(data['front_side_visible_reflectance_at_normal_incidence'].to_f)
      material.setBackSideVisibleReflectanceatNormalIncidence(data['back_side_visible_reflectance_at_normal_incidence'].to_f)
      material.setInfraredTransmittanceatNormalIncidence(data['infrared_transmittance_at_normal_incidence'].to_f)
      material.setFrontSideInfraredHemisphericalEmissivity(data['front_side_infrared_hemispherical_emissivity'].to_f)
      material.setBackSideInfraredHemisphericalEmissivity(data['back_side_infrared_hemispherical_emissivity'].to_f)
      material.setConductivity(OpenStudio.convert(data['conductivity'].to_f, 'Btu*in/hr*ft^2*R', 'W/m*K').get)
      material.setDirtCorrectionFactorforSolarandVisibleTransmittance(data['dirt_correction_factor_for_solar_and_visible_transmittance'].to_f)
      if /true/i.match(data['solar_diffusing'].to_s)
        material.setSolarDiffusing(true)
      else
        material.setSolarDiffusing(false)
      end

    else
      puts "Unknown material type #{material_type}"
      exit
    end

    return material

  end

  # Create a construction from the openstudio standards dataset.
  # If construction_props are specified, modifies the insulation layer accordingly.
  # @todo make return an OptionalConstruction
  def add_construction(construction_name, construction_props = nil)

    # First check model and return construction if it already exists
    self.getConstructions.each do |construction|
      if construction.name.get.to_s == construction_name
        OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added construction: #{construction_name}")
        return construction
      end
    end

    OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Adding construction: #{construction_name}")

    # Get the object data
    data = self.find_object($os_standards['constructions'], {'name'=>construction_name})
    if !data
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for construction: #{construction_name}, will not be created.")
      return OpenStudio::Model::OptionalConstruction.new
    end

    # Make a new construction and set the standards details
    construction = OpenStudio::Model::Construction.new(self)
    construction.setName(construction_name)
    standards_info = construction.standardsInformation

    intended_surface_type = data['intended_surface_type']
    unless intended_surface_type
      intended_surface_type = ''
    end
    standards_info.setIntendedSurfaceType(intended_surface_type)

    standards_construction_type = data['standards_construction_type']
    unless standards_construction_type
      standards_construction_type = ''
    end
    standards_info.setStandardsConstructionType(standards_construction_type)

    # TODO: could put construction rendering color in the spreadsheet

    # Add the material layers to the construction
    layers = OpenStudio::Model::MaterialVector.new
    data['materials'].each do |material_name|
      material = add_material(material_name)
      if material
        layers << material
      end
    end
    construction.setLayers(layers)

    # Modify the R value of the insulation to hit the specified U-value, C-Factor, or F-Factor.
    # Doesn't currently operate on glazing constructions
    if construction_props
      # Determine the target U-value, C-factor, and F-factor
      target_u_value_ip = construction_props['assembly_maximum_u_value']
      target_f_factor_ip = construction_props['assembly_maximum_f_factor']
      target_c_factor_ip = construction_props['assembly_maximum_c_factor']

      OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "#{data['intended_surface_type']} u_val #{target_u_value_ip} f_fac #{target_f_factor_ip} c_fac #{target_c_factor_ip}")

      if target_u_value_ip && !(data['intended_surface_type'] == 'ExteriorWindow' || data['intended_surface_type'] == 'Skylight')

        # Set the U-Value
        construction.set_u_value(target_u_value_ip.to_f, data['insulation_layer'], data['intended_surface_type'], true)

      elsif target_f_factor_ip && data['intended_surface_type'] == 'GroundContactFloor'

        # Set the F-Factor (only applies to slabs on grade)
        # TODO figure out what the prototype buildings did about ground heat transfer
        #construction.set_slab_f_factor(target_f_factor_ip.to_f, data['insulation_layer'])
        construction.set_u_value(0.0, data['insulation_layer'], data['intended_surface_type'], true)

      elsif target_c_factor_ip && data['intended_surface_type'] == 'GroundContactWall'

        # Set the C-Factor (only applies to underground walls)
        # TODO figure out what the prototype buildings did about ground heat transfer
        #construction.set_underground_wall_c_factor(target_c_factor_ip.to_f, data['insulation_layer'])
        construction.set_u_value(0.0, data['insulation_layer'], data['intended_surface_type'], true)

      end

    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding construction #{construction.name}.")

    return construction

  end

  # Helper method to find a particular construction and add it to the model
  # after modifying the insulation value if necessary.
  def find_and_add_construction(building_vintage, climate_zone_set, intended_surface_type, standards_construction_type, building_category)

    # Get the construction properties,
    # which specifies properties by construction category by climate zone set.
    # AKA the info in Tables 5.5-1-5.5-8
    props = self.find_object($os_standards['construction_properties'], {'template'=>building_vintage,
                                                                    'climate_zone_set'=> climate_zone_set,
                                                                    'intended_surface_type'=> intended_surface_type,
                                                                    'standards_construction_type'=> standards_construction_type,
                                                                    'building_category' => building_category
                                                                    })
    if !props
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find construction properties for: #{building_vintage}-#{climate_zone_set}-#{intended_surface_type}-#{standards_construction_type}-#{building_category}.")
      return false
    else
      OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Construction properties for: #{building_vintage}-#{climate_zone_set}-#{intended_surface_type}-#{standards_construction_type}-#{building_category} = #{props}.")
    end

    # Make sure that a construction is specified
    if props['construction'].nil?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "No typical construction is specified for construction properties of: #{building_vintage}-#{climate_zone_set}-#{intended_surface_type}-#{standards_construction_type}-#{building_category}.  Make sure it is entered in the spreadsheet.")
      return false
    end

    # Add the construction, modifying properties as necessary
    construction = add_construction(props['construction'], props)

    return construction

  end

  # Create a construction set from the openstudio standards dataset.
  # Returns an Optional DefaultConstructionSet
  def add_construction_set(building_vintage, clim, building_type, spc_type, is_residential)

    construction_set = OpenStudio::Model::OptionalDefaultConstructionSet.new

    # Find the climate zone set that this climate zone falls into
    climate_zone_set = find_climate_zone_set(clim, building_vintage)
    if !climate_zone_set
      return construction_set
    end

    # Get the object data
    data = self.find_object($os_standards['construction_sets'], {'template'=>building_vintage, 'climate_zone_set'=> climate_zone_set, 'building_type'=>building_type, 'space_type'=>spc_type, 'is_residential'=>is_residential})
    if !data
      data = self.find_object($os_standards['construction_sets'], {'template'=>building_vintage, 'climate_zone_set'=> climate_zone_set, 'building_type'=>building_type, 'space_type'=>spc_type})
      if !data
        return construction_set
      end
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding construction set: #{building_vintage}-#{clim}-#{building_type}-#{spc_type}-is_residential#{is_residential}")

    name = make_name(building_vintage, clim, building_type, spc_type)

    # Create a new construction set and name it
    construction_set = OpenStudio::Model::DefaultConstructionSet.new(self)
    construction_set.setName(name)

    # Exterior surfaces constructions
    exterior_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultExteriorSurfaceConstructions(exterior_surfaces)
    if data['exterior_floor_standards_construction_type'] && data['exterior_floor_building_category']
      exterior_surfaces.setFloorConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'ExteriorFloor',
                                                                       data['exterior_floor_standards_construction_type'],
                                                                       data['exterior_floor_building_category']))
    end
    if data['exterior_wall_standards_construction_type'] && data['exterior_wall_building_category']
      exterior_surfaces.setWallConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'ExteriorWall',
                                                                       data['exterior_wall_standards_construction_type'],
                                                                       data['exterior_wall_building_category']))
    end
    if data['exterior_roof_standards_construction_type'] && data['exterior_roof_building_category']
      exterior_surfaces.setRoofCeilingConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'ExteriorRoof',
                                                                       data['exterior_roof_standards_construction_type'],
                                                                       data['exterior_roof_building_category']))
    end

    # Interior surfaces constructions
    interior_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultInteriorSurfaceConstructions(interior_surfaces)
    construction_name = data['interior_floors']
    if construction_name != nil
      interior_surfaces.setFloorConstruction(add_construction(construction_name))
    end
    construction_name = data['interior_walls']
    if construction_name != nil
      interior_surfaces.setWallConstruction(add_construction(construction_name))
    end
    construction_name = data['interior_ceilings']
    if construction_name != nil
      interior_surfaces.setRoofCeilingConstruction(add_construction(construction_name))
    end

    # Ground contact surfaces constructions
    ground_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultGroundContactSurfaceConstructions(ground_surfaces)
    if data['ground_contact_floor_standards_construction_type'] && data['ground_contact_floor_building_category']
      ground_surfaces.setFloorConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'GroundContactFloor',
                                                                       data['ground_contact_floor_standards_construction_type'],
                                                                       data['ground_contact_floor_building_category']))
    end
    if data['ground_contact_wall_standards_construction_type'] && data['ground_contact_wall_building_category']
      ground_surfaces.setWallConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'GroundContactWall',
                                                                       data['ground_contact_wall_standards_construction_type'],
                                                                       data['ground_contact_wall_building_category']))
    end
    if data['ground_contact_ceiling_standards_construction_type'] && data['ground_contact_ceiling_building_category']
      ground_surfaces.setRoofCeilingConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'GroundContactRoof',
                                                                       data['ground_contact_ceiling_standards_construction_type'],
                                                                       data['ground_contact_ceiling_building_category']))
    end

    # Exterior sub surfaces constructions
    exterior_subsurfaces = OpenStudio::Model::DefaultSubSurfaceConstructions.new(self)
    construction_set.setDefaultExteriorSubSurfaceConstructions(exterior_subsurfaces)
    if data['exterior_fixed_window_standards_construction_type'] && data['exterior_fixed_window_building_category']
      exterior_subsurfaces.setFixedWindowConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'ExteriorWindow',
                                                                       data['exterior_fixed_window_standards_construction_type'],
                                                                       data['exterior_fixed_window_building_category']))
    end
    if data['exterior_operable_window_standards_construction_type'] && data['exterior_operable_window_building_category']
      exterior_subsurfaces.setOperableWindowConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'ExteriorWindow',
                                                                       data['exterior_operable_window_standards_construction_type'],
                                                                       data['exterior_operable_window_building_category']))
    end
    if data['exterior_door_standards_construction_type'] && data['exterior_door_building_category']
      exterior_subsurfaces.setDoorConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'ExteriorDoor',
                                                                       data['exterior_door_standards_construction_type'],
                                                                       data['exterior_door_building_category']))
    end
    construction_name = data['exterior_glass_doors']
    if construction_name != nil
      exterior_subsurfaces.setGlassDoorConstruction(add_construction(construction_name))
    end
    if data['exterior_overhead_door_standards_construction_type'] && data['exterior_overhead_door_building_category']
      exterior_subsurfaces.setOverheadDoorConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'ExteriorDoor',
                                                                       data['exterior_overhead_door_standards_construction_type'],
                                                                       data['exterior_overhead_door_building_category']))
    end
    if data['exterior_skylight_standards_construction_type'] && data['exterior_skylight_building_category']
      exterior_subsurfaces.setSkylightConstruction(find_and_add_construction(building_vintage,
                                                                       climate_zone_set,
                                                                       'Skylight',
                                                                       data['exterior_skylight_standards_construction_type'],
                                                                       data['exterior_skylight_building_category']))
    end
    if construction_name = data['tubular_daylight_domes']
      exterior_subsurfaces.setTubularDaylightDomeConstruction(add_construction(construction_name))
    end
    if construction_name = data['tubular_daylight_diffusers']
      exterior_subsurfaces.setTubularDaylightDiffuserConstruction(add_construction(construction_name))
    end

    # Interior sub surfaces constructions
    interior_subsurfaces = OpenStudio::Model::DefaultSubSurfaceConstructions.new(self)
    construction_set.setDefaultInteriorSubSurfaceConstructions(interior_subsurfaces)
    if construction_name = data['interior_fixed_windows']
      interior_subsurfaces.setFixedWindowConstruction(add_construction(construction_name))
    end
    if construction_name = data['interior_operable_windows']
      interior_subsurfaces.setOperableWindowConstruction(add_construction(construction_name))
    end
    if construction_name = data['interior_doors']
      interior_subsurfaces.setDoorConstruction(add_construction(construction_name))
    end

    # Other constructions
    if construction_name = data['interior_partitions']
      construction_set.setInteriorPartitionConstruction(add_construction(construction_name))
    end
    if construction_name = data['space_shading']
      construction_set.setSpaceShadingConstruction(add_construction(construction_name))
    end
    if construction_name = data['building_shading']
      construction_set.setBuildingShadingConstruction(add_construction(construction_name))
    end
    if construction_name = data['site_shading']
      construction_set.setSiteShadingConstruction(add_construction(construction_name))
    end

    # componentize the construction set
    #construction_set_component = construction_set.createComponent

    # Return the construction set
    return OpenStudio::Model::OptionalDefaultConstructionSet.new(construction_set)

  end

  def add_curve(curve_name)

    #OpenStudio::logFree(OpenStudio::Info, "openstudio.prototype.addCurve", "Adding curve '#{curve_name}' to the model.")

    success = false

    curve_biquadratics = $os_standards["curve_biquadratics"]
    curve_quadratics = $os_standards["curve_quadratics"]
    curve_bicubics = $os_standards["curve_bicubics"]
    curve_cubics = $os_standards["curve_cubics"]

    # Make biquadratic curves
    curve_data = self.find_object(curve_biquadratics, {"name"=>curve_name})
    if curve_data
      curve = OpenStudio::Model::CurveBiquadratic.new(self)
      curve.setName(curve_data["name"])
      curve.setCoefficient1Constant(curve_data["coeff_1"])
      curve.setCoefficient2x(curve_data["coeff_2"])
      curve.setCoefficient3xPOW2(curve_data["coeff_3"])
      curve.setCoefficient4y(curve_data["coeff_4"])
      curve.setCoefficient5yPOW2(curve_data["coeff_5"])
      curve.setCoefficient6xTIMESY(curve_data["coeff_6"])
      curve.setMinimumValueofx(curve_data["min_x"])
      curve.setMaximumValueofx(curve_data["max_x"])
      curve.setMinimumValueofy(curve_data["min_y"])
      curve.setMaximumValueofy(curve_data["max_y"])
      if curve_data["min_out"]
        curve.setMinimumCurveOutput(curve_data["min_out"])
      end
      if curve_data["max_out"]
        curve.setMaximumCurveOutput(curve_data["max_out"])
      end
      success = true
      return curve
    end

    # Make quadratic curves
    curve_data = self.find_object(curve_quadratics, {"name"=>curve_name})
    if curve_data
      curve = OpenStudio::Model::CurveQuadratic.new(self)
      curve.setName(curve_data["name"])
      curve.setCoefficient1Constant(curve_data["coeff_1"])
      curve.setCoefficient2x(curve_data["coeff_2"])
      curve.setCoefficient3xPOW2(curve_data["coeff_3"])
      curve.setMinimumValueofx(curve_data["min_x"])
      curve.setMaximumValueofx(curve_data["max_x"])
      if curve_data["min_out"]
        curve.setMinimumCurveOutput(curve_data["min_out"])
      end
      if curve_data["max_out"]
        curve.setMaximumCurveOutput(curve_data["max_out"])
      end      
      success = true
      return curve
    end

    # Make cubic curves
    curve_data = self.find_object(curve_cubics, {"name"=>curve_name})
    if curve_data
      curve = OpenStudio::Model::CurveCubic.new(self)
      curve.setName(curve_data["name"])
      curve.setCoefficient1Constant(curve_data["coeff_1"])
      curve.setCoefficient2x(curve_data["coeff_2"])
      curve.setCoefficient3xPOW2(curve_data["coeff_3"])
      curve.setCoefficient4xPOW3(curve_data["coeff_4"])
      curve.setMinimumValueofx(curve_data["min_x"])
      curve.setMaximumValueofx(curve_data["max_x"])
      if curve_data["min_out"]
        curve.setMinimumCurveOutput(curve_data["min_out"])
      end
      if curve_data["max_out"]
        curve.setMaximumCurveOutput(curve_data["max_out"])
      end      
      success = true
      return curve
    end

    # Make bicubic curves
    curve_data = self.find_object(curve_bicubics, {"name"=>curve_name})
    if curve_data
      curve = OpenStudio::Model::CurveBicubic.new(self)
      curve.setName(curve_data["name"])
      curve.setCoefficient1Constant(curve_data["coeff_1"])
      curve.setCoefficient2x(curve_data["coeff_2"])
      curve.setCoefficient3xPOW2(curve_data["coeff_3"])
      curve.setCoefficient4y(curve_data["coeff_4"])
      curve.setCoefficient5yPOW2(curve_data["coeff_5"])
      curve.setCoefficient6xTIMESY(curve_data["coeff_6"])
      curve.setCoefficient7xPOW3(curve_data["coeff_7"])
      curve.setCoefficient8yPOW3(curve_data["coeff_8"])
      curve.setCoefficient9xPOW2TIMESY(curve_data["coeff_9"])
      curve.setCoefficient10xTIMESYPOW2(curve_data["coeff_10"])
      curve.setMinimumValueofx(curve_data["min_x"])
      curve.setMaximumValueofx(curve_data["max_x"])
      curve.setMinimumValueofy(curve_data["min_y"])
      curve.setMaximumValueofy(curve_data["max_y"])
      if curve_data["min_out"]
        curve.setMinimumCurveOutput(curve_data["min_out"])
      end
      if curve_data["max_out"]
        curve.setMaximumCurveOutput(curve_data["max_out"])
      end      
      success = true
      return curve
    end

    # Return false if the curve was not created
    if success == false
      #OpenStudio::logFree(OpenStudio::Warn, "openstudio.prototype.addCurve", "Could not find a curve called '#{curve_name}' in the standards.")
      return nil
    end

  end

  # Get the full path to the weather file that is specified in the model.
  #
  # @return [OpenStudio::OptionalPath]
  def get_full_weather_file_path

    full_epw_path = OpenStudio::OptionalPath.new

    if self.weatherFile.is_initialized
      epw_path = self.weatherFile.get.path
      if epw_path.is_initialized
        if File.exist?(epw_path.get.to_s)
          full_epw_path = OpenStudio::OptionalPath.new(epw_path.get)
        else
          # If this is an always-run Measure, need to check a different path
          alt_weath_path = File.expand_path(File.join(File.dirname(__FILE__), "../../../resources"))
          alt_epw_path = File.expand_path(File.join(alt_weath_path, epw_path.get.to_s))
          if File.exist?(alt_epw_path)
            full_epw_path = OpenStudio::OptionalPath.new(OpenStudio::Path.new(alt_epw_path))
          else
            OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.Model", "Model has been assigned a weather file, but the file is not in the specified location of '#{epw_path.get}'.")
          end
        end
      else
        OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.Model", "Model has a weather file assigned, but the weather file path has been deleted.")
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Model has not been assigned a weather file.')
    end
  
    return full_epw_path
  
  end

  # Method to gather prototype simulation results for a specific climate zone, building type, and template
  #
  # @param climate_zone [String] string for the ASHRAE climate zone.
  # @param building_type [String] string for prototype building type.
  # @param template [String] string for prototype template to target.
  # @return [Hash] Returns a hash with data presented in various bins. Returns nil if no search results
  def process_results_for_datapoint(climate_zone, building_type, template)

    # Combine the data from the JSON files into a single hash
    top_dir = File.expand_path( '../../..',File.dirname(__FILE__))
    standards_data_dir = "#{top_dir}/data/standards"

    # Load the legacy idf results JSON file into a ruby hash
    temp = File.read("#{standards_data_dir}/legacy_idf_results.json")
    legacy_idf_results = JSON.parse(temp)

    # List of all fuel types
    fuel_types = ['Electricity', 'Natural Gas', 'Additional Fuel', 'District Cooling', 'District Heating', 'Water']

    # List of all end uses
    end_uses = ['Heating', 'Cooling', 'Interior Lighting', 'Exterior Lighting', 'Interior Equipment', 'Exterior Equipment', 'Fans', 'Pumps', 'Heat Rejection','Humidification', 'Heat Recovery', 'Water Systems', 'Refrigeration', 'Generators']

    # Get legacy idf results
    legacy_results_hash = {}
    legacy_results_hash['total_legacy_energy_val'] = 0
    legacy_results_hash['total_legacy_water_val'] = 0
    legacy_results_hash['total_energy_by_fuel'] = {}
    legacy_results_hash['total_energy_by_end_use'] = {}
    fuel_types.each do |fuel_type|

      end_uses.each do |end_use|
        next if end_use == 'Exterior Equipment'

        # Get the legacy results number
        legacy_val = legacy_idf_results.dig(building_type, template, climate_zone, fuel_type, end_use)

        # Combine the exterior lighting and exterior equipment
        if end_use == 'Exterior Lighting'
          legacy_exterior_equipment = legacy_idf_results.dig(building_type, template, climate_zone, fuel_type, 'Exterior Equipment')
          unless legacy_exterior_equipment.nil?
            legacy_val += legacy_exterior_equipment
          end
        end

        if legacy_val.nil?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "#{fuel_type} #{end_use} legacy idf value not found")
          next
        end

        # Add the energy to the total
        if fuel_type == 'Water'
          legacy_results_hash['total_legacy_water_val'] += legacy_val
        else
          legacy_results_hash['total_legacy_energy_val'] += legacy_val

          # add to fuel specific total
          if legacy_results_hash['total_energy_by_fuel'][fuel_type]
            legacy_results_hash['total_energy_by_fuel'][fuel_type] += legacy_val # add to existing counter
          else
            legacy_results_hash['total_energy_by_fuel'][fuel_type] = legacy_val # start new counter
          end

          # add to end use specific total
          if legacy_results_hash['total_energy_by_end_use'][end_use]
            legacy_results_hash['total_energy_by_end_use'][end_use] += legacy_val # add to existing counter
          else
            legacy_results_hash['total_energy_by_end_use'][end_use] = legacy_val # start new counter
          end

        end

      end # Next end use

    end # Next fuel type

    return legacy_results_hash

  end

  # Keep track of floor area for prototype buildings.
  # This is used to calculate EUI's to compare against non prototype buildings
  # Areas taken from scorecard Excel Files
  #
  # @param [Sting] building type
  # @return [Double] floor area (m^2) of prototype building for building type passed in. Returns nil if unexpected building type
  def find_prototype_floor_area(building_type)

    if building_type == 'FullServiceRestaurant' # 5502 ft^2
      result = 511
    elsif building_type == 'Hospital' # 241,410 ft^2 (including basement)
      result = 22422
    elsif building_type == 'LargeHotel' # 122,132 ft^2
      result = 11345
    elsif building_type == 'LargeOffice' # 498,600 ft^2
      result = 46320
    elsif building_type == 'MediumOffice' # 53,600 ft^2
      result = 4982
    elsif building_type == 'MidriseApartment' # 33,700 ft^2
      result = 3135
    elsif building_type == 'Office'
      result = nil # todo - there shouldn't be a prototype building for this
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Measures calling this should choose between SmallOffice, MediumOffice, and LargeOffice")
    elsif building_type == 'Outpatient' #40.950 ft^2
      result = 3804
    elsif building_type == 'PrimarySchool' # 73,960 ft^2
      result = 6871
    elsif building_type == 'QuickServiceRestaurant' # 2500 ft^2
      result = 232
    elsif building_type == 'Retail' # 24,695 ft^2
      result = 2294
    elsif building_type == 'SecondarySchool' # 210,900 ft^2
      result = 19592
    elsif building_type == 'SmallHotel' # 43,200 ft^2
      result = 4014
    elsif building_type == 'SmallOffice' # 5500 ft^2
      result = 511
    elsif building_type == 'StripMall' # 22,500 ft^2
      result = 2090
    elsif building_type == 'SuperMarket' #45,002 ft2 (from legacy reference idf file)
      result = 4181
    elsif building_type == 'Warehouse' # 49,495 ft^2 (legacy ref shows 52,045, but I wil calc using 49,495)
      result = 4595
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Didn't find expected building type. As a result can't determine floor prototype floor area")
      result = nil
    end

    return result

  end

  # this is used by other methods to get the clinzte aone and building type from a model.
  # it has logic to break office into small, medium or large based on building area that can be turned off
  # @param [bool] re-map small office or leave it alone
  # @return [hash] key for climate zone and building type, both values are strings
  def get_building_climate_zone_and_building_type(remap_office = true)

    # get climate zone from model
    # get ashrae climate zone from model
    climate_zone = ''
    climateZones = self.getClimateZones
    climateZones.climateZones.each do |climateZone|
      if climateZone.institution == "ASHRAE"
        climate_zone = "ASHRAE 169-2006-#{climateZone.value}"
        next
      end
    end

    # get building type from model
    building_type = ''
    if self.getBuilding.standardsBuildingType.is_initialized
      building_type = self.getBuilding.standardsBuildingType.get
    end

    # prototype small office approx 500 m^2
    # prototype medium office approx 5000 m^2
    # prototype large office approx 50,000 m^2
    # map office building type to small medium or large
    if building_type == "Office" and remap_office
      open_studio_area = self.getBuilding.floorArea
      if open_studio_area < 2750
        building_type = "SmallOffice"
      elsif open_studio_area < 25250
        building_type = "MediumOffice"
      else
        building_type = "LargeOffice"
      end
    end

    results = {}
    results['climate_zone'] = climate_zone
    results['building_type'] = building_type

    return results

  end

  # user needs to pass in building_vintage as string. The building type and climate zone will come from the model.
  # If the building type or ASHRAE climate zone is not set in the model this will return nil
  # If the lookup doesn't find matching simulation results this wil return nil
  #
  # @param [String] target prototype template for eui lookup
  # @return [Double] EUI (MJ/m^2) for target template for given OSM. Returns nil if can't calculate EUI
  def find_target_eui(template)

    building_data = self.get_building_climate_zone_and_building_type
    climate_zone = building_data['climate_zone']
    building_type = building_data['building_type']

    # look up results
    target_consumption = process_results_for_datapoint(climate_zone, building_type, template)

    # lookup target floor area for prototype buildings
    target_floor_area = find_prototype_floor_area(building_type)

    if target_consumption['total_legacy_energy_val'] > 0
      if target_floor_area > 0
        result = target_consumption['total_legacy_energy_val']/target_floor_area
      else
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find prototype building floor area")
        result = nil
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find target results for #{climate_zone},#{building_type},#{template}")
      result = nil # couldn't calculate EUI consumpiton lookup failed
    end

    return result

  end

  # user needs to pass in building_vintage as string. The building type and climate zone will come from the model.
  # If the building type or ASHRAE climate zone is not set in the model this will return nil
  # If the lookup doesn't find matching simulation results this wil return nil
  #
  # @param [String] target prototype template for eui lookup
  # @return [Hash] EUI (MJ/m^2) This will return a hash of end uses. key is end use, value is eui
  def find_target_eui_by_end_use(template)

    building_data = self.get_building_climate_zone_and_building_type
    climate_zone = building_data['climate_zone']
    building_type = building_data['building_type']

    # look up results
    target_consumption = process_results_for_datapoint(climate_zone, building_type, template)

    # lookup target floor area for prototype buildings
    target_floor_area = find_prototype_floor_area(building_type)

    if target_consumption['total_legacy_energy_val'] > 0
      if target_floor_area > 0
        result = {}
        target_consumption['total_energy_by_end_use'].each do |end_use,consumption|
          result[end_use] = consumption/target_floor_area
        end
      else
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find prototype building floor area")
        result = nil
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find target results for #{climate_zone},#{building_type},#{template}")
      result = nil # couldn't calculate EUI consumpiton lookup failed
    end

    return result

  end
  
  # Get a unique list of constructions with given
  # boundary condition and a given type of surface.
  # Pulls from both default construction sets and
  # hard-assigned constructions.
  #
  # @param boundary_condition [String] the desired boundary condition
  # valid choices are:
  # Adiabatic
  # Surface
  # Outdoors
  # Ground
  # @param type [String] the type of surface to find
  # valid choices are:
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
  # return [Array<OpenStudio::Model::ConstructionBase>]
  # an array of all constructions.
  def find_constructions(boundary_condition, type)

      constructions = []

      # From default construction sets
      self.getDefaultConstructionSets.each do |const_set|
        
        ext_surfs = const_set.defaultExteriorSurfaceConstructions
        int_surfs = const_set.defaultInteriorSurfaceConstructions
        gnd_surfs = const_set.defaultGroundContactSurfaceConstructions
        ext_subsurfs = const_set.defaultExteriorSubSurfaceConstructions
        int_subsurfs = const_set.defaultInteriorSubSurfaceConstructions

        # Can't handle incomplete construction sets
        if ext_surfs.empty? ||
          int_surfs.empty? ||
          gnd_surfs.empty? ||
          ext_subsurfs.empty? ||
          int_subsurfs.empty?

          OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Space", "Default construction set #{const_set.name} is incomplete; contructions from this set will not be reported.")
          next
        end

        ext_surfs = ext_surfs.get
        int_surfs = int_surfs.get
        gnd_surfs = gnd_surfs.get
        ext_subsurfs = ext_subsurfs.get
        int_subsurfs = int_subsurfs.get

        case type
        # Exterior Surfaces
        when 'ExteriorWall', 'AtticWall'
          constructions << ext_surfs.wallConstruction
        when 'ExteriorFloor'
          constructions << ext_surfs.floorConstruction
        when 'ExteriorRoof', 'AtticRoof'
          constructions << ext_surfs.roofCeilingConstruction       
        # Interior Surfaces
        when 'InteriorWall', 'DemisingWall', 'InteriorPartition'
          constructions << int_surfs.wallConstruction
        when 'InteriorFloor', 'AtticFloor', 'DemisingFloor'
          constructions << int_surfs.floorConstruction
        when 'InteriorCeiling', 'DemisingRoof'
          constructions << int_surfs.roofCeilingConstruction 
        # Ground Contact Surfaces
        when 'GroundContactWall'
          constructions << gnd_surfs.wallConstruction
        when 'GroundContactFloor'
          constructions << gnd_surfs.floorConstruction
        when 'GroundContactRoof'
          constructions << gnd_surfs.roofCeilingConstruction
        # Exterior SubSurfaces
        when 'ExteriorWindow'
          constructions << ext_subsurfs.fixedWindowConstruction
          constructions << ext_subsurfs.operableWindowConstruction
        when 'ExteriorDoor'
          constructions << ext_subsurfs.doorConstruction
        when 'GlassDoor'
          constructions << ext_subsurfs.glassDoorConstruction
        when 'OverheadDoor'
          constructions << ext_subsurfs.overheadDoorConstruction
        when 'Skylight'
          constructions << ext_subsurfs.skylightConstruction
        when 'TubularDaylightDome'
          constructions << ext_subsurfs.tubularDaylightDomeConstruction
        when 'TubularDaylightDiffuser'
          constructions << ext_subsurfs.tubularDaylightDiffuserConstruction
        # Interior SubSurfaces
        when 'InteriorWindow'
          constructions << int_subsurfs.fixedWindowConstruction
          constructions << int_subsurfs.operableWindowConstruction
        when 'InteriorDoor'
          constructions << int_subsurfs.doorConstruction          
        end
      end
      
      # Hard-assigned surfaces
      self.getSurfaces.each do |surf|
        next unless surf.outsideBoundaryCondition == boundary_condition
        next unless surf.surfaceType == type
        constructions << surf.construction
      end
      
      # Hard-assigned subsurfaces
      self.getSubSurfaces.each do |surf|
        next unless surf.outsideBoundaryCondition == boundary_condition
        next unless surf.subSurfaceType == type
        constructions << surf.construction
      end
      
      # Throw out the empty constructions
      all_constructions = []
      constructions.uniq.each do |const|
        next if const.empty?
        all_constructions << const.get
      end
      
      # Only return the unique list (should already be uniq)
      all_constructions = all_constructions.uniq

      # ConstructionBase can be sorted
      all_constructions = all_constructions.sort

      
      return all_constructions
      
  end

  # Go through the default construction sets and hard-assigned
  # constructions. Clone the existing constructions and set their
  # intended surface type and standards construction type per
  # the PRM.  For some standards, this will involve making
  # modifications.  For others, it will not.
  #
  # @param template [String] valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @return [Bool] returns true if successful, false if not
  def apply_performance_rating_method_construction_types(template)
  
    types_to_modify = []
    
    # Possible boundary conditions are
    # Adiabatic
    # Surface
    # Outdoors
    # Ground
    
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
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      types_to_modify << ['Outdoors', 'ExteriorWall', 'SteelFramed']
      types_to_modify << ['Outdoors', 'ExteriorRoof', 'IEAD']
      types_to_modify << ['Outdoors', 'ExteriorFloor', 'SteelFramed']
      types_to_modify << ['Ground', 'GroundContactFloor', 'Unheated']
      types_to_modify << ['Ground', 'GroundContactWall', 'Unheated']
    end
    
    # Modify all constructions of each type
    types_to_modify.each do |boundary_cond, surf_type, const_type|
      constructions = self.find_constructions(boundary_cond, surf_type)

      constructions.sort.each do |const|  
        standards_info = const.standardsInformation
        standards_info.setIntendedSurfaceType(surf_type)
        standards_info.setStandardsConstructionType(const_type)
      end

    end

    return true
    
  end  
  
  # Apply the standard construction to each surface in the 
  # model, based on the construction type currently assigned.
  #
  # @return [Bool] true if successful, false if not
  def apply_standard_constructions(template, climate_zone)  
  
    types_to_modify = []
  
    # Possible boundary conditions are 
    # Adiabatic
    # Surface
    # Outdoors
    # Ground    
    
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
    # each standard applies to.
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      types_to_modify << ['Outdoors', 'Floor']
      types_to_modify << ['Outdoors', 'Wall']
      types_to_modify << ['Outdoors', 'RoofCeiling']
      types_to_modify << ['Outdoors', 'FixedWindow']
      types_to_modify << ['Outdoors', 'OperableWindow']
      types_to_modify << ['Outdoors', 'Door']
      types_to_modify << ['Outdoors', 'GlassDoor']
      types_to_modify << ['Outdoors', 'OverheadDoor']
      types_to_modify << ['Outdoors', 'Skylight']
      types_to_modify << ['Ground', 'Floor']
      types_to_modify << ['Ground', 'Wall']
    end

    # Find just those surfaces
    surfaces_to_modify = []
    types_to_modify.each do |boundary_condition, surface_type|
    
      # Surfaces
      self.getSurfaces.each do |surf|
        next unless surf.outsideBoundaryCondition == boundary_condition
        next unless surf.surfaceType == surface_type
        surfaces_to_modify << surf
      end
      
      # SubSurfaces
      self.getSubSurfaces.each do |surf|
        next unless surf.outsideBoundaryCondition == boundary_condition
        next unless surf.subSurfaceType == surface_type
        surfaces_to_modify << surf
      end
   
    end
  
    # Modify these surfaces
    prev_created_consts = {}
    surfaces_to_modify.sort.each do |surf|
      prev_created_consts = surf.apply_standard_construction(template, climate_zone, prev_created_consts)
    end
  
    # List the unique array of constructions
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Applying standard constructions")
    if prev_created_consts.size == 0
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "None of the constructions in your proposed model have both Intended Surface Type and Standards Construction Type")
    else
      prev_created_consts.each do |surf_type, construction|
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "For #{surf_type.join(' ')}, applied #{construction.name}.")
      end
    end

    return true
  
  end

  # Reduces the WWR to the values specified by the PRM. WWR reduction
  # will be done by raising sill height.  This causes the least impact
  # on the daylighting area calculations and controls placement.
  #
  # @todo add proper support for 90.1-2013 with all those building
  # type specific values
  # @todo support semiheated spaces as a separate WWR category
  # @todo add window frame area to calculation of WWR
  def apply_performance_rating_method_baseline_window_to_wall_ratio(template)
  
    # Loop through all spaces in the model, and 
    # per the PNNL PRM Reference Manual, find the areas
    # of each space conditioning category (res, nonres, semi-heated)
    # separately.  Include space multipliers.
    nr_wall_m2 = 0.001 # Avoids divide by zero errors later
    nr_wind_m2 = 0  
    res_wall_m2 = 0.001
    res_wind_m2 = 0
    sh_wall_m2 = 0.001
    sh_wind_m2 = 0
    self.getSpaces.each do |space|
      
      # Loop through all surfaces in this space
      wall_area_m2 = 0
      wind_area_m2 = 0
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'Wall'
        # This wall's gross area (including window area)
        wall_area_m2 += surface.grossArea * space.multiplier
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'FixedWindow' || ss.subSurfaceType == 'OperableWindow'
          wind_area_m2 += ss.netArea * space.multiplier
        end
      end
      
      # Determine the space category
      cat = 'NonRes'
      if space.is_residential(template)
        cat = 'Res'
      end
      # if space.is_semiheated
        # cat = 'Semiheated'
      # end
      
      # Add to the correct category
      case cat
      when 'NonRes'
        nr_wall_m2 += wall_area_m2
        nr_wind_m2 += wind_area_m2
      when 'Res'
        res_wall_m2 += wall_area_m2
        res_wind_m2 += wind_area_m2
      when 'Semiheated'
        sh_wall_m2 += wall_area_m2
        sh_wind_m2 += wind_area_m2
      end
      
    end
      
    # Calculate the WWR of each category
    wwr_nr = ((nr_wind_m2 / nr_wall_m2)*100).round(1)
    wwr_res = ((res_wind_m2 / res_wall_m2)*100).round(1)
    wwr_sh = ((sh_wind_m2 / sh_wall_m2)*100).round(1)
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "The WWRs are: NonRes: #{wwr_nr.round}%, Res: #{wwr_res.round}%.")
    
    # WWR limit
    wwr_lim = 40.0
    
    # Check against WWR limit
    wwr_nr > wwr_lim ? red_nr = true : red_nr = false
    wwr_res > wwr_lim ? red_res = true : red_res = false
    wwr_sh > wwr_lim ? red_sh = true : red_sh = false

    # Stop here unless windows need reducing
    return true unless red_nr || red_res || red_sh
    
    # Determine the factors by which to reduce the window area
    mult_nr_red = wwr_lim / wwr_nr 
    mult_res_red = wwr_lim / wwr_res
    #mult_sh_red = wwr_lim / wwr_sh
    
    # Reduce the window area if any of the categories necessary
    self.getSpaces.each do |space|
      
      # Determine the space category
      cat = 'NonRes'
      if space.is_residential(template)
        cat = 'Res'
      end
      # if space.is_semiheated
        # cat = 'Semiheated'
      # end
      
      # Skip spaces whose windows don't need to be reduced
      case cat
      when 'NonRes'
        next unless red_nr
        mult = mult_nr_red
      when 'Res'
        next unless red_res
        mult = mult_res_red
      when 'Semiheated'
        next unless red_sh
        # mult = mult_sh_red
      end
      
      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'Wall'
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'FixedWindow' || ss.subSurfaceType == 'OperableWindow'
          # Reduce the size of the window
          red = 1.0 - mult
          ss.reduce_area_by_percent_by_raising_sill(red)
        end
      end

    end    
    
    return true
  
  end
  
  # Helper method to get the story object that
  # cooresponds to a specific minimum z value.
  # Makes a new story if none found at this height.
  #
  # @param minz [Double] the z value (height) of the
  # desired story, in meters.
  # @return [OpenStudio::Model::BuildingStory] the story
  def get_story_for_nominal_z_coordinate(minz)

    self.getBuildingStorys.each do |story|
      z = story.nominalZCoordinate
      if z.is_initialized
        if minz == z.get
          return story
        end
      end
    end

    story = OpenStudio::Model::BuildingStory.new(self)
    story.setNominalZCoordinate(minz)
    
    return story
    
  end  
  
  # Helper method to make a shortened version of a name
  # that will be readable in a GUI.
  def make_name(building_vintage, clim, building_type, spc_type)
    clim = clim.gsub('ClimateZone ', 'CZ')
    if clim == 'CZ1-8'
      clim = ''
    end

    if building_type == 'FullServiceRestaurant'
      building_type = 'FullSrvRest'
    elsif building_type == 'Hospital'
      building_type = 'Hospital'
    elsif building_type == 'LargeHotel'
      building_type = 'LrgHotel'
    elsif building_type == 'LargeOffice'
      building_type = 'LrgOffice'
    elsif building_type == 'MediumOffice'
      building_type = 'MedOffice'
    elsif building_type == 'MidriseApartment'
      building_type = 'MidApt'
    elsif building_type == 'HighriseApartment'
      building_type = 'HighApt'
    elsif building_type == 'Office'
      building_type = 'Office'
    elsif building_type == 'Outpatient'
      building_type = 'Outpatient'
    elsif building_type == 'PrimarySchool'
      building_type = 'PriSchl'
    elsif building_type == 'QuickServiceRestaurant'
      building_type = 'QckSrvRest'
    elsif building_type == 'Retail'
      building_type = 'Retail'
    elsif building_type == 'SecondarySchool'
      building_type = 'SecSchl'
    elsif building_type == 'SmallHotel'
      building_type = 'SmHotel'
    elsif building_type == 'SmallOffice'
      building_type = 'SmOffice'
    elsif building_type == 'StripMall'
      building_type = 'StMall'
    elsif building_type == 'SuperMarket'
      building_type = 'SpMarket'
    elsif building_type == 'Warehouse'
      building_type = 'Warehouse'
    end

    parts = [building_vintage]

    unless building_type.empty?
      parts << building_type
    end

    unless spc_type.nil?
      parts << spc_type
    end

    unless clim.empty?
      parts << clim
    end

    result = parts.join(' - ')

    return result
    
  end

  # Helper method to find out which climate zone set contains a specific climate zone.
  # Returns climate zone set name as String if success, nil if not found.
  def find_climate_zone_set(clim, building_vintage)
    result = nil

    possible_climate_zones = []
    $os_standards['climate_zone_sets'].each do |climate_zone_set|
      if climate_zone_set['climate_zones'].include?(clim)
        possible_climate_zones << climate_zone_set['name']
      end
    end

    # Check the results
    if possible_climate_zones.size == 0
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find a climate zone set containing #{clim}")
    elsif possible_climate_zones.size > 2
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Found more than 2 climate zone sets containing #{clim}; will return last matching cliimate zone set.")
    end

    # For Pre-1980 and 1980-2004, use the most specific climate zone set.
    # For example, 2A and 2 both contain 2A, so use 2A.
    # For 2004-2013, use least specific climate zone set.
    # For example, 2A and 2 both contain 2A, so use 2.
    case building_vintage
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      result = possible_climate_zones.sort.last
    when '90.1-2007', '90.1-2010', '90.1-2013'
      result = possible_climate_zones.sort.first
    when '90.1-2004'
      if possible_climate_zones.include? "ClimateZone 3"
        result = possible_climate_zones.sort.last
      else
        result = possible_climate_zones.sort.first
      end
    end
        
    # Check that a climate zone set was found
    if result.nil?
      
    end
    
    return result
  
  end

end
