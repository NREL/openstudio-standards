
# Custom changes for the Warehouse prototype.
# These are changes that are inconsistent with other prototype
# building types.
module Warehouse
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    return true
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)

    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Adjusting geometry input')
    case template
      when '90.1-2010', '90.1-2013'
        case climate_zone
          when 'ASHRAE 169-2006-6A',
               'ASHRAE 169-2006-6B',
               'ASHRAE 169-2006-7A',
               'ASHRAE 169-2006-8A',
               'ASHRAE 169-2013-6A',
               'ASHRAE 169-2013-6B',
               'ASHRAE 169-2013-7A',
               'ASHRAE 169-2013-8A'
            # Remove existing skylights
            model.getSubSurfaces.each do |subsurf|
              if subsurf.subSurfaceType.to_s == 'Skylight'
                subsurf.remove
              end
            end
            # Load older geometry corresponding to older code versions
            old_geo = load_geometry_osm('geometry/ASHRAE90120042007Warehouse.osm')
            # Clone the skylights from the older geometry
            old_geo.getSubSurfaces.each do |subsurf|
              if subsurf.subSurfaceType.to_s == 'Skylight'
                new_skylight = subsurf.clone(model).to_SubSurface.get
                old_roof = subsurf.surface.get
                # Assign surfaces to skylights
                model.getSurfaces.each do |model_surf|
                  if model_surf.name.to_s == old_roof.name.to_s
                    new_skylight.setSurface(model_surf)
                  end
                end
              end
            end
        end
    end
    return true
  end
end
