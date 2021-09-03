
require 'minitest/autorun'
require 'openstudio'

# if running from openstudio-standards.. load local standards
os_standards_local_lib_path = '../../../lib/openstudio-standards.rb'
if Dir.exist?(os_standards_local_lib_path)
  require_relative os_standards_local_lib_path
else
  require 'openstudio-standards'
end

def read_space_types()
  path = "/home/osdev/openstudio-standards/lib/openstudio-standards/standards/necb/NECB2011/data/geometry/DND*.osm"
  spacetype_list = []
  Dir.glob(path) do |osm_file|
    model = BTAP::FileIO::load_osm(osm_file)
    standard = NECB2011.new()
    model.getSpaces.each do |space|
      unless space.spaceType.empty?
        name = space.spaceType.get.name.get
        bt = space.spaceType.get.standardsBuildingType.get unless space.spaceType.get.standardsBuildingType.empty?
        st = space.spaceType.get.standardsSpaceType.get unless space.spaceType.get.standardsSpaceType.empty?
        spacetype_list << {'name': name, 'Original-StandardsBuildingType': bt, 'Original-StandardSpaceType': st}

      end
    end

  end
  unique_list = spacetype_list.uniq.sort_by { |st| st[:name] }


  CSV.open("data.csv", "wb") do |csv|
    csv << unique_list.first.keys # adds the attributes name on the first line
    unique_list.each do |hash|
      csv << hash.values
    end
  end

  standard_space_type_list = Standard.build('NECB2011').standards_data['space_types'].map { |space_types| {'building_type': space_types['building_type'],
                                                                                                           'space_type': space_types['space_type'],
                                                                                                           "necb_hvac_system_selection_type": space_types['necb_hvac_system_selection_type'],
                                                                                                           "necb_schedule_type": space_types['necb_schedule_type']


  } }
  standards_space_type_list.s

  CSV.open("spacetypes.csv", "wb") do |csv|
    csv << standard_space_type_list.first.keys # adds the attributes name on the first line
    standard_space_type_list.each do |hash|
      csv << hash.values
    end
  end
end

def map_spacetypes()

  map_list = CSV.open("cold_lake_map.csv", headers: :first_row).map(&:to_h)
  path = "/home/osdev/openstudio-standards/lib/openstudio-standards/standards/necb/NECB2011/data/geometry/DND*.osm"
  Dir.glob(path) do |osm_file|
    model = BTAP::FileIO::load_osm(osm_file)
    model.getSpaceTypes.each do |st|
      map_item = map_list.select { |item| item["Original Spacetype Name"] == st.name.get }
      unless map_item.empty?
        new_name = map_item.first()['New-StandardsBuildingType'].to_s + '-'+map_item.first()['New-StandardSpaceType'].to_s
        st.setName(new_name)
        st.setStandardsBuildingType(map_item.first()["New-StandardsBuildingType"])
        st.setStandardsSpaceType(map_item.first()["New-StandardSpaceType"])
        puts st
      end
    end
    BTAP::FileIO::save_osm(model,File.join(__dir__,File.basename(osm_file)))
  end
end


map_spacetypes()
