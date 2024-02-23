class ASHRAE901PRM < Standard
  # Adjust the fenestration area to the values specified by the reduction value in a surface
  #
  # @param surface [OpenStudio::Model:Surface] openstudio surface object
  # @param reduction [Double] ratio of adjustments
  # @param model [OpenStudio::Model::Model] openstudio model
  # @return [Boolean] returns true if successful, false if not
  def surface_adjust_fenestration_in_a_surface(surface, reduction, model)
    # do nothing for cases when reduction == 1.0
    if reduction < 1.0
      surface.subSurfaces.each do |ss|
        next unless ss.subSurfaceType == 'FixedWindow' || ss.subSurfaceType == 'OperableWindow' || ss.subSurfaceType == 'GlassDoor'

        OpenstudioStandards::Geometry.sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid(ss, reduction)
      end
    elsif reduction > 1.0
      # case increase the window
      surface_wwr = OpenstudioStandards::Geometry.surface_get_window_to_wall_ratio(surface)
      if surface_wwr == 0.0
        # In this case, we are adding fenestration
        wwr_adjusted = reduction - 1.0
        # add the value to additional properties in case of readjusting WWR for doors
        surface.additionalProperties.setFeature('added_wwr', wwr_adjusted)
      else
        wwr_adjusted = surface_wwr * reduction
      end
      # Save doors to a temp list
      door_list = []
      surface.subSurfaces.each do |sub|
        if sub.subSurfaceType == 'Door'
          door = {}
          door['name'] = sub.name.get
          door['vertices'] = sub.vertices
          door['construction'] = sub.construction.get
          door_list << door
        end
      end
      # remove all existing windows and set the window to wall ratio to the calculated new WWR
      # Remove all sub-surfaces including doors
      surface.subSurfaces.each(&:remove)
      # Apply default construction to the subsurface - the standard construction will be applied later.
      surface.setWindowToWallRatio(wwr_adjusted, 0.6, true)
      # add door back.
      unless door_list.empty?
        door_list.each do |door|
          os_door = OpenStudio::Model::SubSurface.new(door['vertices'], model)
          os_door.setName(door['name'])
          os_door.setConstruction(door['construction'])
          os_door.setSurface(surface)
        end
      end
    end
  end
end
