# BTAP Attributes: Currently stores model attributes related to envelopes. 
require 'singleton'

module BTAP
  class Attributes
    include Singleton

    @@model = nil
    attr_reader :costed_surfaces
    
    def initialize()
      
      # Surfaces considered for envelope costing
      @costed_surfaces = [ 
        "ExteriorWall",
        "ExteriorRoof",
        "ExteriorFloor",
        "ExteriorFixedWindow",
        "ExteriorOperableWindow",
        "ExteriorSkylight",
        "ExteriorTubularDaylightDiffuser",
        "ExteriorTubularDaylightDome",
        "ExteriorDoor",
        "ExteriorGlassDoor",
        "ExteriorOverheadDoor",
        "GroundContactWall",
        "GroundContactRoof",
        "GroundContactFloor"
      ]

      # @compiled = 
    end

    class << self
      def set_model(model)
        @@model = model
      end
    end

    # Get a list of 
    def compile_zones_and_spaces
      
    end

    def compile_surfaces
      model.getThermalZones.sort.each do |zone|
        zone.spaces.sort.each do |space|
          if space.spaceType.empty? or space.spaceType.get.standardsSpaceType.empty? or space.spaceType.get.standardsBuildingType.empty?
            raise ("standards Space type and building type is not defined for space:#{space.name.get}. Skipping this space for costing.")
          end

          surfaces = {}

          #Exterior
          exterior_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Outdoors")
          surfaces["ExteriorWall"] = BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "Wall")
          surfaces["ExteriorRoof"] = BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "RoofCeiling")
          surfaces["ExteriorFloor"] = BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "Floor")

          # Exterior Subsurface
          exterior_subsurfaces = exterior_surfaces.flat_map(&:subSurfaces)
          surfaces["ExteriorFixedWindow"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["FixedWindow"])
          surfaces["ExteriorOperableWindow"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["OperableWindow"])
          surfaces["ExteriorSkylight"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["Skylight"])
          surfaces["ExteriorTubularDaylightDiffuser"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["TubularDaylightDiffuser"])
          surfaces["ExteriorTubularDaylightDome"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["TubularDaylightDome"])
          surfaces["ExteriorDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["Door"])
          surfaces["ExteriorGlassDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["GlassDoor"])
          surfaces["ExteriorOverheadDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["OverheadDoor"])

          # Ground Surfaces
          ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Ground")
          ground_surfaces += BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Foundation")
          surfaces["GroundContactWall"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Wall")
          surfaces["GroundContactRoof"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "RoofCeiling")
          surfaces["GroundContactFloor"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Floor")
        end
      end
    end

    def test_attributes
      @@model.getThermalZones.sort.each do |zone|
        puts("Zone: #{zone.name.get}")
        zone.spaces.sort.each do |space|
          puts("  Space: #{space.name.get}")
          space.surfaces.sort.each do |surface|
          puts("      Surface: #{surface.name.get}")
          end
        end
      end
    end
  end

  class Zone
    def initialize

    end
  end
end