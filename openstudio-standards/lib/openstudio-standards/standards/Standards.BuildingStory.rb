
# open the class to add methods to apply HVAC efficiency standards
class OpenStudio::Model::BuildingStory

  # Determine which of the zones on this story
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
  # @return [Array<OpenStudio::Model::ThermalZone>) An array of ThermalZones.
  def get_primary_thermal_zones()
  
    # Get all the spaces on this story
    spaces = self.spaces
    
    # Get all the thermal zones that serve these spaces
    zones = []
    spaces.each do |space|
      if space.thermalZone.is_initialized
        zones << space.thermalZone.get
      else
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Standards.BuildingStory", "For #{self.name}, space #{space.name} has no thermal zone, it is not included in the simulation.")
      end
    end
  
    # Determine the operational hours (proxy is annual
    # full load lighting hours) for all zones
    zone_data_1 = []
    zones.each do |zone|    
      data = {}
      data['zone'] = zone
      # Get the area
      area_ft2 = OpenStudio.convert(zone.floorArea, 'm^2', 'ft^2').get
      data['area_ft2'] = area_ft2      
      OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "#{zone.name}")
      zone.spaces.each do |space|
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "***#{space.name}")
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
          OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "******#{lights.name}")
          # Get the fractional lighting schedule
          lights_sch = lights.numberoflightsSchedule
          full_load_hrs = 0.0
          # Skip lights with no schedule
          next if lights_sch.empty?
          lights_sch = lights_sch.get
          if lights_sch.to_ScheduleRuleset.is_initialized || 
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
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "******full_load_hrs = #{full_load_hrs.round}")

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
        area_hrs += other_data['area_ft2'] * other_data['ann_op_hrs']
        tot_area += other_data['area_ft2']
      end
      avg_ann_op_hrs = area_hrs / (tot_area)
      avg_wk_op_hrs = avg_ann_op_hrs / 52.0
      OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For #{self.name}, zone #{data['zone'].name} average of #{avg_wk_op_hrs.round} hrs/wk.")
      
      # Compare avg to this zone
      wk_op_hrs = data['wk_op_hrs']
      if wk_op_hrs < avg_wk_op_hrs - 40.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For #{self.name}, zone #{data['zone'].name}, the weekly full load operating hrs of #{wk_op_hrs.round} hrs is more than 40 hrs lower than the average of #{avg_wk_op_hrs.round} hrs, zone will not be attached to the primary system.")
        next
      elsif wk_op_hrs > avg_wk_op_hrs + 40.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For #{self.name}, zone #{data['zone'].name}, the weekly full load operating hrs of #{wk_op_hrs.round} hrs is more than 40 hrs higher than the average of #{avg_wk_op_hrs.round} hrs, zone will not be attached to the primary system.")
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
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Standards.BuildingStory", "For #{self.name}, zone #{data['zone'].name}, could not determine the design heating load.")
      end
      # Get the cooling load
      clg_load_w_per_m2 = zone.coolingDesignLoad
      if clg_load_w_per_m2.is_initialized
        clg_load_btu_per_ft2 = OpenStudio.convert(clg_load_w_per_m2.get,'W/m^2','Btu/hr*ft^2').get
        data['clg_load_btu_per_ft2'] = clg_load_btu_per_ft2
      else
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Standards.BuildingStory", "For #{self.name}, zone #{data['zone'].name}, could not determine the design cooling load.")
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
      area_hrs = 1
      htg_area = 1
      clg_area = 1
      other_zone_data_1.each do |other_data|
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
      OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For #{self.name}, average heating = #{avg_htg_load_btu_per_ft2.round} Btu/hr*ft^2, average cooling = #{avg_clg_load_btu_per_ft2.round} Btu/hr*ft^2.")
    
      # Filter on heating load
      htg_load_btu_per_ft2 = data['htg_load_btu_per_ft2']
      if htg_load_btu_per_ft2 < avg_htg_load_btu_per_ft2 - 10.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For #{self.name}, zone #{data['zone'].name}, the heating load of #{htg_load_btu_per_ft2.round} Btu/hr*ft^2 is more than 10 Btu/hr*ft^2 lower than the average of #{avg_htg_load_btu_per_ft2.round} Btu/hr*ft^2, zone will not be attached to the primary system.")
        next
      elsif htg_load_btu_per_ft2 > avg_htg_load_btu_per_ft2 + 10.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For #{self.name}, zone #{data['zone'].name}, the heating load of #{htg_load_btu_per_ft2.round} Btu/hr*ft^2 is more than 10 Btu/hr*ft^2 higher than the average of #{avg_htg_load_btu_per_ft2.round} Btu/hr*ft^2, zone will not be attached to the primary system.")
        next
      end
      
      # Filter on cooling load
      clg_load_btu_per_ft2 = data['clg_load_btu_per_ft2']
      if clg_load_btu_per_ft2 < avg_clg_load_btu_per_ft2 - 10.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For #{self.name}, zone #{data['zone'].name}, the cooling load of #{clg_load_btu_per_ft2.round} Btu/hr*ft^2 is more than 10 Btu/hr*ft^2 lower than the average of #{avg_clg_load_btu_per_ft2.round} Btu/hr*ft^2, zone will not be attached to the primary system.")
        next
      elsif clg_load_btu_per_ft2 > avg_clg_load_btu_per_ft2 + 10.0
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.BuildingStory", "For #{self.name}, zone #{data['zone'].name}, the cooling load of #{clg_load_btu_per_ft2.round} Btu/hr*ft^2 is more than 10 Btu/hr*ft^2 higher than the average of #{avg_clg_load_btu_per_ft2.round} Btu/hr*ft^2, zone will not be attached to the primary system.")
        next
      end
      
      # It is a primary zone!
      primary_zones << zone
      
    end
    
    return primary_zones
  
  end

end
