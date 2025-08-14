# BTAP Attributes: Currently stores model attributes related to envelopes. 
require 'singleton'

module BTAP
  class Attributes
    include Singleton

    @@model = nil

    attr_reader :costed_surfaces
    attr_reader :storage
    attr_reader :zones
    attr_reader :spaces
    attr_reader :surfaces
    
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

      @zones    = [] # BTAP::Zone
      @spaces   = [] # BTAP::Space
      @surfaces = [] # BTAP::Surface

      self.compile
    end

    # Compile all the pertinent data into this class' data structure. 
    def compile
      @@model.getThermalZones.sort.each do |zone|
        zone_wrapper = BTAP::Zone.new(zone)
        @zones << zone_wrapper
        zone.spaces.sort.each do |space|
          if space.spaceType.empty? or space.spaceType.get.standardsSpaceType.empty? or space.spaceType.get.standardsBuildingType.empty?
            raise ("standards Space type and building type is not defined for space:#{space.name.get}. Skipping this space.")
          end

          space_wrapper = BTAP::Space.new(space)
          zone_wrapper.spaces << space_wrapper
          @spaces << space_wrapper
          
          # Exterior
          exterior_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Outdoors")
          space_wrapper["ExteriorWall"]  = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "Wall"))
          space_wrapper["ExteriorRoof"]  = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "RoofCeiling"))
          space_wrapper["ExteriorFloor"] = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "Floor"))

          # Exterior Subsurfaces
          exterior_subsurfaces = exterior_surfaces.flat_map(&:subSurfaces)
          space_wrapper["ExteriorFixedWindow"]             = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["FixedWindow"]))
          space_wrapper["ExteriorOperableWindow"]          = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["OperableWindow"]))
          space_wrapper["ExteriorSkylight"]                = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["Skylight"]))
          space_wrapper["ExteriorTubularDaylightDiffuser"] = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["TubularDaylightDiffuser"]))
          space_wrapper["ExteriorTubularDaylightDome"]     = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["TubularDaylightDome"]))
          space_wrapper["ExteriorDoor"]                    = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["Door"]))
          space_wrapper["ExteriorGlassDoor"]               = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["GlassDoor"]))
          space_wrapper["ExteriorOverheadDoor"]            = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["OverheadDoor"]))

          # Ground Surfaces
          ground_surfaces  = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Ground")
          ground_surfaces += BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Foundation")
          space_wrapper["GroundContactWall"]  = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Wall"))
          space_wrapper["GroundContactRoof"]  = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "RoofCeiling"))
          space_wrapper["GroundContactFloor"] = BTAP::Surface.new(BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Floor"))

          # Put all surfaces into the total list of surfaces for this space.
          @costed_surfaces.each do |surface|
            @surfaces << space_wrapper[surface]
          end
        end
      end
    end

    class << self
      def set_model(model)
        @@model = model
      end

      def model
        return model
      end
    end

    def test_attributes_wrapper
      @zones.each do |zone|
        puts("Zone: #{zone.get.name.get}")
        zone.spaces.each do |space|
          puts("  Space: #{space.get.name.get}")
          costed_surfaces.each do |surface|
            puts("      Surface: #{space.surfaces[surface].get}")
          end
        end
      end
    end

    def test_arrays
      @zones.each do |zone|
        puts("Zone: #{zone.get.name.get}")
      end
      
      @spaces.each do |space|
        puts("  Space: #{space.get.name.get}")
      end

      @surfaces.each do |surface|
        puts("      Surface: #{surface.get}")
      end
    end

    def test_attributes_model
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

  # Wrapper class for zones
  class Zone
    attr_reader :get
    attr_reader :spaces

    def initialize(zone)
      @get = zone
      @spaces  = []
    end

    def <<(space) # Overload the append operator to add spaces
      @spaces << space
    end
  end

  # Wrapper class for spaces
  class Space
    attr_reader :get
    attr_reader :surfaces

    def initialize(space)
      @get  = space
      @surfaces = {} # Store surfaces a hash
    end
    
    def [](surface) # Overload the element of operator to hash surfaces based on @costed_surfaces
      @surfaces[surface]
    end

    def []=(surface_type, surface_value) # Overload the element assignment operator
      @surfaces[surface_type] = surface_value
    end
  end

  # Wrapper class for surfaces
  class Surface
    attr_reader :get

    def initialize(surface)
      @get = surface
    end
  end
end