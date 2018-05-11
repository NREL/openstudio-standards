class Standard
  # @!group Surface

  # Determine the component infiltration rate for this surface
  #
  # @param type [String] choices are 'baseline' and 'advanced'
  # @return [Double] infiltration rate
  #   @units cubic meters per second (m^3/s)
  # @todo handle floors over unconditioned spaces
  def surface_component_infiltration_rate(surface, type)
    comp_infil_rate_m3_per_s = 0.0

    # Define the envelope component infiltration rates
    component_infil_rates_cfm_per_ft2 = {
      'baseline' => {
        'roof' => 0.12,
        'exterior_wall' => 0.12,
        'below_grade_wall' => 0.12,
        'floor_over_unconditioned' => 0.12,
        'slab_on_grade' => 0.12
      },
      'advanced' => {
        'roof' => 0.04,
        'exterior_wall' => 0.04,
        'below_grade_wall' => 0.04,
        'floor_over_unconditioned' => 0.04,
        'slab_on_grade' => 0.04
      }
    }

    boundary_condition = surface.outsideBoundaryCondition
    # Skip non-outdoor surfaces
    return comp_infil_rate_m3_per_s unless outsideBoundaryCondition == 'Outdoors' || surface.outsideBoundaryCondition == 'Ground'

    # Per area infiltration rate for this surface
    surface_type = surface.surfaceType
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
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.Model', "For #{surface.name}, could not determine surface type for infiltration, will not be included in calculation.")
      return comp_infil_rate_m3_per_s
    end

    # Area of the surface
    area_m2 = surface.netArea
    area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get

    # Rate for this surface
    comp_infil_rate_cfm = area_ft2 * infil_rate_cfm_per_ft2

    comp_infil_rate_m3_per_s = OpenStudio.convert(comp_infil_rate_cfm, 'cfm', 'm^3/s').get

    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Model", "...#{self.name}, infil = #{comp_infil_rate_cfm.round(2)} cfm @ rate = #{infil_rate_cfm_per_ft2} cfm/ft2, area = #{area_ft2.round} ft2.")

    return comp_infil_rate_m3_per_s
  end

  def surface_replace_existing_subsurfaces_with_centered_subsurface(model, sill_height_m, window_height_m, fdwr)
    puts "Chris was here (replace sub surfaces)!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    max_angle = 91
    min_angle = 89
    vertical_surfaces = find_exposed_conditioned_vertical_surfaces(model, max_angle, min_angle)
    vertical_surfaces.each do |vertical_surface|
      vertical_surface.subSurfaces.sort.each do |vertical_subsurface|
        if vertical_subsurface.nil?
          puts "Surface does not exist"
        else
          vertical_subsurface.remove
        end
      end
      # corner_coords = vertical_surface.vertices
      code_window_area = fdwr*vertical_surface.grossArea
      code_window_width = code_window_area/window_height_m
      min_z = 0
      vertical_surface.vertices.each_with_index do |vertex, index|
        if index == 0
          min_z = vertex.z
        elsif vertex.z < min_z
          min_z = vertex.z
        end
      end
      vertex_nminusone
      vertical_surface.vertices.each do |vertex|

      end
    end
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!Chris left (find sub surfaces)"
  end

  def find_exposed_conditioned_vertical_surfaces(model, max_angle, min_angle)
    puts "Chris was here (find surfaces)!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exposed_surfaces = []
    model.getSpaces.sort.each do |space|
      cooled = space_cooled?(space)
      heated = space_heated?(space)
      if heated || cooled
        space.surfaces.sort.each do |surface|
          next unless surface.surfaceType == 'Wall'
          next unless surface.outsideBoundaryCondition == 'Outdoors'
          tilt_radian = surface.tilt
          tilt_degrees = OpenStudio.convert(tilt_radian, 'rad', 'deg').get
          if tilt_degrees <= max_angle and tilt_degrees >= min_angle
            exposed_surfaces << surface
          end
          puts "Added outdoor surface"
          puts "Tilt: #{tilt_degrees}"
        end
      end
    end
    return exposed_surfaces
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!Chris left (find surfaces)"
      # planarSurfaces = surface.findPlanarSurfaces('minDegreesTelt' = min_angle)
  end
end
