# Methods to modify geometry
module OpenstudioStandards
  module Geometry
    # @!group Modify

    # lower z value of vertices with starting value above z_value_target to z_value_target
    #
    # @param surfaces [Array<OpenStudio::Model::Surface>] array of Surface objects
    # @param z_value_target [Double]
    # @return [Array] array of z values in meters
    def self.surfaces_lower_z_values(surfaces, z_value_target)
      count = 0

      # loop over all surfaces
      surfaces.each do |surface|
        # create a new set of vertices
        new_vertices = OpenStudio::Point3dVector.new

        # get the existing vertices for this interior partition
        vertices = surface.vertices
        flag = false
        vertices.each do |vertex|
          # initialize new vertex to old vertex
          x = vertex.x
          y = vertex.y
          z = vertex.z

          # if this z vertex is not on the z = 0 plane
          if z > z_value_target
            z = z_value_target
            flag = true
          end

          # add point to new vertices
          new_vertices << OpenStudio::Point3d.new(x, y, z)
        end

        # set vertices to new vertices
        # @todo check if this was made, and issue warning if it was not. Could happen if resulting surface not planer.
        surface.setVertices(new_vertices)

        count += 1 if flag
      end

      return count
    end
  end
end
