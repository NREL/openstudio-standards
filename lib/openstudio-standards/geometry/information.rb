# Methods to get information about model geometry
# Many of these methods may be moved to core OpenStudio
module OpenstudioStandards
  module Geometry
    # @!group Information

    # calculate aspect ratio from area and perimeter
    # @param area [Double] area
    # @param perimeter [Double] perimeter
    # @return [Double] aspect ratio
    def self.calc_aspect_ratio(area, perimeter)
      l = 0.25 * (perimeter + Math.sqrt(p**2 - 16 * area))
      w = 0.25 * (perimeter - Math.sqrt(p**2 - 16 * area))
      aspect_ratio = l / w

      return aspect_ratio
    end
  end
end