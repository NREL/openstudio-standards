require 'json'

class OS_sim_extract
  # Name of file you want to add template fields to:
  in_json_file = './simulations.json'
  # Name of file you want this script to produce:
  out_json_file = './simulations_out.json'
  output_array = []
  file = File.read(in_json_file)
  data_tables = JSON.parse(file)
  data_tables.each do |data_table|
    building_type = nil
    template_version = nil
    area_scale_factor = nil
    epw_file = nil
    outdoor_air = false
    data_table["measures"].each do |measure|
      if measure["name"] == "btap_create_necb_prototype_building_scale"
        building_type = measure["arguments"]["building_type"]
        template_version = measure["arguments"]["template"]
        area_scale_factor = measure["arguments"]["area_scale_factor"]
        epw_file = measure["arguments"]["epw_file"]
      elsif measure["display_name"] == "BTAPIdealAirLoadsOptionsEplus"
        outdoor_air = true
      end
    end
    extract_hash = {
        :conditioned_floor_area => data_table["building"]["conditioned_floor_area_m2"],
        :exterior_area => data_table["building"]["exterior_area_m2"],
        :volume => data_table["building"]["volume"],
        :hdd => data_table["geography"]["hdd"],
        :cdd => data_table["geography"]["cdd"],
        :heating_gj => data_table["end_uses"]["heating_gj"],
        :cooling_gj => data_table["end_uses"]["cooling_gj"],
        :ep_conditioned_floor_area_m2 => data_table["code_metrics"]["ep_conditioned_floor_area_m2"],
        :os_conditioned_floor_area_m2 => data_table["code_metrics"]["os_conditioned_floor_area_m2"],
        :building_tedi_gj_per_m2 => data_table["code_metrics"]["building_tedi_gj_per_m2"],
        :building_medi_gj_per_m2 => data_table["code_metrics"]["building_medi_gj_per_m2"],
        :building_type => building_type,
        :template_version => template_version,
        :epw_file => epw_file,
        :area_scale_factor => area_scale_factor,
        :outdoor_air => outdoor_air
    }
    output_array << extract_hash
  end
  File.open(out_json_file,"w") {|each_file| each_file.write(JSON.pretty_generate(output_array))}
end