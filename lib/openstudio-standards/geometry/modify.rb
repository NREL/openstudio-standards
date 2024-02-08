module OpenstudioStandards
  # This Module provides methods to create, modify, and get information about model geometry
  module Geometry
    # Methods to modify geometry

    # @!group Modify:Surfaces

    # @!endgroup Modify:Surfaces

    # @!group Modify:Model

    # Assign each space in the model to a building story based on common z (height) values.
    # If no story object is found for a particular height, create a new one and assign it to the space.
    # Does not assign a story to plenum spaces.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [Boolean] returns true if successful, false if not
    def self.model_assign_spaces_to_building_stories(model)
      # Make hash of spaces and min z values
      sorted_spaces = {}
      model.getSpaces.sort.each do |space|
        # Skip plenum spaces
        std = Standard.build('90.1-2019') # delete once space methods refactored
        next if std.space_plenum?(space)

        # loop through space surfaces to find min z value
        z_points = []
        space.surfaces.each do |surface|
          surface.vertices.each do |vertex|
            z_points << vertex.z
          end
        end
        min_z = z_points.min + space.zOrigin
        sorted_spaces[space] = min_z
      end

      # Pre-sort spaces
      sorted_spaces = sorted_spaces.sort_by { |a| a[1] }

      # Take the sorted list and assign/make stories
      sorted_spaces.each do |space|
        space_obj = space[0]
        space_min_z = space[1]
        if space_obj.buildingStory.empty?
          tolerance = 0.3
          story = OpenstudioStandards::Geometry.model_get_building_story_for_nominal_height(model, space_min_z, tolerance: tolerance)
          if story.nil?
            story = OpenStudio::Model::BuildingStory.new(model)
            story.setNominalZCoordinate(space_min_z)
            story.setName("Building Story #{space_min_z.round(1)}m")
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "No story with a min z value of #{space_min_z.round(2)} m +/- #{tolerance} m was found, so a new story called #{story.name} was created.")
          end
          space_obj.setBuildingStory(story)
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Space #{space[0].name} was not assigned to a story by the user.  It has been assigned to #{story.name}.")
        end
      end

      return true
    end

    # Set the model's north axis (degrees from true North)
    #
    # @param model [OpenStudio::Model::Model] OpenStudio Model object
    # @param north_axis [Float] Degrees from true North
    # @return [Boolean] Returns true if successful, false otherwise
    def self.model_set_building_north_axis(model, north_axis)
      return false if north_axis.nil?

      building = model.getBuilding
      building.setNorthAxis(north_axis)

      return true
    end

    # @!endgroup Modify:Model
  end
end
