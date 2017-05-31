# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Space
  def get_average_height()
    roof_datum = 0
    total_roof_area = 0
    floor_datum = 0
    total_floor_area = 0
    average_height = 0
    #create a model to create a planar object.. Hopefully garbage collection deals with this right.
    temp_model =  OpenStudio::Model::Model.new()
    self.surfaces.each do |surface|
      projected_vertices = Array.new()
      if surface.surfaceType == "Floor"
        average_surface_height = 0
        surface.vertices.each do |point3d|
          average_surface_height += point3d.z / surface.vertices.size
          projected_vertices << OpenStudio::Point3d.new(point3d.x, point3d.y, 0)
        end
        total_floor_area += OpenStudio::Model::Surface.new(	projected_vertices ,temp_model).grossArea
        floor_datum += average_surface_height * surface.grossArea
      elsif surface.surfaceType == "RoofCeiling"
        average_surface_height = 0
        surface.vertices.each do |point3d|
          average_surface_height += point3d.z / surface.vertices.size
          projected_vertices << OpenStudio::Point3d.new(point3d.x, point3d.y, 0)
        end
        total_roof_area += OpenStudio::Model::Surface.new(	projected_vertices ,temp_model).grossArea
        roof_datum += average_surface_height * surface.grossArea
      end
    end
    if total_floor_area > 0 and total_roof_area > 0
      average_height = roof_datum / total_roof_area - floor_datum / total_floor_area
    end
    return average_height
  end
end
