require_relative '../../../test/helpers/minitest_helper'
require_relative '../../../test/helpers/create_doe_prototype_helper'

['NECB2011', 'NECB2015'].each do |template|
  model = OpenStudio::Model::Model.new
  Standard.build(template).add_all_spacetypes_to_model(model)
  BTAP::FileIO.save_osm(model, File.join(File.dirname(__FILE__), 'output', "#{template}_space_types.osm"))
end
