
# open the class to add methods to apply HVAC efficiency standards
class OpenStudio::Model::Surface

  # Determine the component infiltration rate for this surface
  #
  # @param type [String] choices are 'baseline' and 'advanced'
  # @return [Double] infiltration rate
  #   @units cubic meters per second (m^3/s)
  # @todo handle floors over unconditioned spaces
  def component_infiltration_rate(type)
       
    comp_infil_rate_m3_per_s = 0.0   
       
    # Define the envelope component infiltration rates
    component_infil_rates_cfm_per_ft2 = {
      'baseline'=>{
        'roof'=>0.12,
        'exterior_wall'=>0.12,
        'below_grade_wall'=>0.12,
        'floor_over_unconditioned'=>0.12,
        'slab_on_grade'=>0.12,
      },
      'advanced'=>{
        'roof'=>0.04,
        'exterior_wall'=>0.04,
        'below_grade_wall'=>0.04,
        'floor_over_unconditioned'=>0.04,
        'slab_on_grade'=>0.04,
      }
    }
    
    boundary_condition = self.outsideBoundaryCondition
    # Skip non-outdoor surfaces
    return comp_infil_rate_m3_per_s unless self.outsideBoundaryCondition == 'Outdoors' || self.outsideBoundaryCondition == 'Ground'
    
    # Per area infiltration rate for this surface
    surface_type = self.surfaceType 
    infil_rate_cfm_per_ft2 = nil
    case boundary_condition
    when 'Outdoors'
      case surface_type
      when 'RoofCeiling'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['roof']
      when 'Wall'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['exterior_wall']
      end
    when 'Ground'
      case surface_type
      when 'Wall'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['below_grade_wall']
      when 'Floor'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['slab_on_grade']
      end
    when 'TODO Surface'
      case surface_type
      when 'Floor'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['floor_over_unconditioned']
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

    #OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Model", "...#{self.name}, infil = #{comp_infil_rate_cfm.round(2)} cfm @ rate = #{infil_rate_cfm_per_ft2} cfm/ft2, area = #{area_ft2.round} ft2.")
    
    return comp_infil_rate_m3_per_s
    
  end
  
end
