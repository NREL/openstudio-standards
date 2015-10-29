
# open the class to add methods to apply HVAC efficiency standards
class OpenStudio::Model::SubSurface

  # Determine the component infiltration rate for this surface
  #
  # @param type [String] choices are 'baseline' and 'advanced'
  # @return [Double] infiltration rate
  #   @units cubic meters per second (m^3/s)
  def component_infiltration_rate(type)
       
    comp_infil_rate_m3_per_s = 0.0   
       
    # Define the envelope component infiltration rates
    component_infil_rates_cfm_per_ft2 = {
      'baseline'=>{
        'opaque_door'=>0.40,
        'loading_dock_door'=>0.40,
        'swinging_or_revolving_glass_door'=>1.0,
        'vestibule'=>1.0,
        'sliding_glass_door'=>0.40,
        'window'=>0.40,
        'skylight'=>0.40
      },
      'advanced'=>{
        'opaque_door'=>0.20,
        'loading_dock_door'=>0.20,
        'swinging_or_revolving_glass_door'=>1.0,
        'vestibule'=>1.0,
        'sliding_glass_door'=>0.20,
        'window'=>0.20,
        'skylight'=>0.20
      }
    }
    
    boundary_condition = self.outsideBoundaryCondition
    # Skip non-outdoor surfaces
    return comp_infil_rate_m3_per_s unless self.outsideBoundaryCondition == 'Outdoors' || self.outsideBoundaryCondition == 'Ground'
    
    # Per area infiltration rate for this surface
    surface_type = self.subSurfaceType 
    infil_rate_cfm_per_ft2 = nil
    case boundary_condition
    when 'Outdoors'
      case surface_type
      when 'Door'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['opaque_door']
      when 'OverheadDoor'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['loading_dock_door']
      when 'GlassDoor'
        OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.Model", "For #{self.name}, assuming swinging_or_revolving_glass_door for infiltration calculation.")
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['swinging_or_revolving_glass_door']
      when 'FixedWindow','OperableWindow'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['window']
      when 'Skylight','TubularDaylightDome','TubularDaylightDiffuser'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['skylight']
      end
    end
    if infil_rate_cfm_per_ft2.nil?
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.Standards.Model", "For #{self.name}, could not determine surface type for infiltration, will not be included in calculation.")
      return comp_infil_rate_m3_per_s
    end
      
    # Area of the surface
    area_m2 = self.netArea
    area_ft2 = OpenStudio.convert(area_m2,'m^2','ft^2').get
    
    # Rate for this surface
    comp_infil_rate_cfm = area_ft2 * infil_rate_cfm_per_ft2

    comp_infil_rate_m3_per_s = OpenStudio.convert(comp_infil_rate_cfm,'cfm','m^3/s').get

    #OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Model", "......#{self.name}, infil = #{comp_infil_rate_cfm.round(2)} cfm @ rate = #{infil_rate_cfm_per_ft2} cfm/ft2, area = #{area_ft2.round} ft2.")
    
    return comp_infil_rate_m3_per_s
    
  end
  
end
