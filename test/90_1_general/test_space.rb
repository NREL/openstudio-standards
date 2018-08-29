require_relative '../helpers/minitest_helper'

class TestSpace < Minitest::Test

  def test_space_daylighted_areas

    template = '90.1-2013'
    standard = Standard.build(template)

    # make a model
    model = OpenStudio::Model::Model.new
    
    
    # Create a space from a floor print and extrude distance
    floorprint = OpenStudio::Point3dVector.new
    floorprint << OpenStudio::Point3d.new(0,0,0)
    floorprint << OpenStudio::Point3d.new(0,10,0)
    floorprint << OpenStudio::Point3d.new(10,10,0)
    floorprint << OpenStudio::Point3d.new(10,0,0)

    space = OpenStudio::Model::Space::fromFloorPrint(floorprint, 3, model)
    assert(space.is_initialized)
    space = space.get
    
    space.surfaces.each do |surface|
      if surface.surfaceType == 'Wall'
        surface.setWindowToWallRatio(0.2)
      end
    end
    
    # trying to make sure this does not hang
    result = standard.space_daylighted_areas(space)
    puts result
    
    space.surfaces.each do |surface|
      if surface.surfaceType == 'Wall'
        surface.setWindowToWallRatio(0.5)
      end
    end
    
    # trying to make sure this does not hang
    result = standard.space_daylighted_areas(space)
    puts result   
    
    space.surfaces.each do |surface|
      if surface.surfaceType == 'Wall'
        surface.setWindowToWallRatio(0.9)
      end
    end
    
    # trying to make sure this does not hang
    result = standard.space_daylighted_areas(space)
    puts result
  end

end
