require 'json'

# PRM output utility functions
# This function will extract the additional properties from thermal zones, spaces, surface, and AirLoopHvac
#
def extract_additional_properties(model)
  # The model shall be the PRM generated baseline model - which contains most of the information needed for extraction.
  output_json = {}

  # Step 1 process thermal zone
  thermal_zones_output = {}
  model.getThermalZones.each do |zone|
    if zone.hasAdditionalProperties
      zone_additionalProperties = zone.additionalProperties
      zone_output = {
        'building_type_for_hvac' => zone_additionalProperties.hasFeature('building_type_for_hvac') ? zone_additionalProperties.getFeatureAsString('building_type_for_hvac').get : '',
        'has_health_safety_night_cycle_exception' => zone_additionalProperties.hasFeature('has_health_safety_night_cycle_exception') ? zone_additionalProperties.getFeatureAsBoolean('has_health_safety_night_cycle_exception').get : false,
        'return_air_type' => zone_additionalProperties.hasFeature('return_air_type') ? zone_additionalProperties.getFeatureAsString('return_air_type').get : '',
        'proposed_model_zone_design_air_flow' => zone_additionalProperties.hasFeature('proposed_model_zone_design_air_flow') ? zone_additionalProperties.getFeatureAsDouble('proposed_model_zone_design_air_flow').get : 0.0,
        'supply_fan_w' => zone_additionalProperties.hasFeature('supply_fan_w') ? zone_additionalProperties.getFeatureAsDouble('supply_fan_w').get : 0.0,
        'return_fan_w' => zone_additionalProperties.hasFeature('return_fan_w') ? zone_additionalProperties.getFeatureAsDouble('return_fan_w').get : 0.0,
        'relief_fan_w' => zone_additionalProperties.hasFeature('relief_fan_w') ? zone_additionalProperties.getFeatureAsDouble('relief_fan_w').get : 0.0,
        'zone_dcv_implemented_in_user_model' => zone_additionalProperties.hasFeature('zone DCV implemented in user model') ? zone_additionalProperties.getFeatureAsBoolean('zone DCV implemented in user model').get : false,
        'airloop_user_specified_dcv_exception' => zone_additionalProperties.hasFeature('airloop user specified DCV exception') ? zone_additionalProperties.getFeatureAsBoolean('airloop user specified DCV exception').get : false,
        'zone_user_specified_dcv_exception' => zone_additionalProperties.hasFeature('zone user specified DCV exception') ? zone_additionalProperties.getFeatureAsBoolean('zone user specified DCV exception').get : false,
        'airloop_dcv_required_by_901' => zone_additionalProperties.hasFeature('airloop dcv required by 901') ? zone_additionalProperties.getFeatureAsBoolean('airloop dcv required by 901').get : false,
        'zone_dcv_required_by_901' => zone_additionalProperties.hasFeature('zone dcv required by 901') ? zone_additionalProperties.getFeatureAsBoolean('zone dcv required by 901').get : false,
        'apxg_no_need_to_have_dcv' => zone_additionalProperties.hasFeature('apxg no need to have DCV') ? zone_additionalProperties.getFeatureAsBoolean('apxg no need to have DCV').get : false,
        'baseline_system_type' => zone_additionalProperties.hasFeature('baseline_system_type') ? zone_additionalProperties.getFeatureAsString('baseline_system_type').get : ''
      }
      thermal_zones_output[zone.name.get] = zone_output
    end
  end
  output_json["thermal_zones"] = thermal_zones_output

  # Space and surface object output
  spaces_output = {}
  surfaces_output = {}
  subsurfaces_output = {}
  model.getSpaces.each do |space|
    if space.hasAdditionalProperties
      space_additional_properties = space.additionalProperties
      space_output = {
        'zone_name'=> space.thermalZone.is_initialized ? space.thermalZone.get.name.get : '',
        'building_story' => space.buildingStory.is_initialized ? space.buildingStory.get.name.get : '',
        'building_type_for_wwr' => space_additional_properties.hasFeature('building_type_for_wwr') ? space_additional_properties.getFeatureAsString('building_type_for_wwr').get : '',
        'space_conditioning_category' => space_additional_properties.hasFeature('space_conditioning_category') ? space_additional_properties.getFeatureAsString('space_conditioning_category').get : '',
        'occ_control_credit' => space_additional_properties.hasFeature('occ_control_credit') ? space_additional_properties.getFeatureAsDouble('occ_control_credit').get : 0.0
      }
      spaces_output[space.name.get] = space_output
    end
    space.surfaces.sort.each do |surface|
      if surface.hasAdditionalProperties
        surface_additional_properties = surface.additionalProperties
        surface_output = {
          'space_name' => space.name.get,
          'space_conditioning_category' => space_additional_properties.hasFeature('space_conditioning_category') ? space_additional_properties.getFeatureAsString('space_conditioning_category').get : '',
          'surface_boundary_condition' => surface.outsideBoundaryCondition,
          'surface_area' => surface.grossArea * space.multiplier,
          'surface_wwr' => surface_additional_properties.hasFeature('surface_wwr') ? surface_additional_properties.getFeatureAsDouble('surface_wwr').get : 0.0,
          'adjusted_wwr' => surface_additional_properties.hasFeature('adjusted_wwr') ? surface_additional_properties.getFeatureAsDouble('adjusted_wwr').get : 0.0,
          'added_wwr' => surface_additional_properties.hasFeature('added_wwr') ? surface_additional_properties.getFeatureAsDouble('added_wwr').get : 0.0
        }
        surfaces_output[surface.name.get] = surface_output
      end
      surface.subSurfaces.sort.each do |sub|
        # subsurface_additional_properties = sub.additionalProperties
        subsurface_output = {
          'surface_name'=> surface.name.get,
          'subsurface_area' => sub.netArea * space.multiplier,
          'subsurface_type' => sub.subSurfaceType
        }
        subsurfaces_output[sub.name.get] = subsurface_output
      end
    end
  end
  output_json['spaces'] = spaces_output
  output_json['surfaces'] = surfaces_output
  output_json['subsurfaces'] = subsurfaces_output

  # Air loop output
  airloops_output = {}
  model.getAirLoopHVACs.each do |airloop|
    if airloop.hasAdditionalProperties
      airloop_additional_properties = airloop.additionalProperties
      airloop_output = {
        'fan_sched_name' => airloop_additional_properties.hasFeature('fan_sched_name') ? airloop_additional_properties.getFeatureAsString('fan_sched_name').get : '',
        'zone_group_type'=> airloop_additional_properties.hasFeature('zone_group_type') ? airloop_additional_properties.getFeatureAsString('zone_group_type').get : '',
        'sys_group_occ' => airloop_additional_properties.hasFeature('sys_group_occ') ? airloop_additional_properties.getFeatureAsString('sys_group_occ').get : '',
        'baseline_system_type' => airloop_additional_properties.hasFeature('baseline_system_type') ? airloop_additional_properties.getFeatureAsString('baseline_system_type').get : '',
      }
      airloops_output[airloop.name.get] = airloop_output
    end
  end
  output_json['airlooops'] = airloops_output
  return output_json
end

# Convert a nested hash to a json and save it to a file path.
# @param output_hash Hash
# @param file_path string
def export_baseline_report(output_hash, file_path)
  json_string = JSON.pretty_generate(output_hash)
  begin
    File.open("#{file_path}/baseline_report.json", 'w') do |f|
      f.write(json_string)
    end
  rescue Errno::EACCES
    puts 'Error: Permission denied. You do not have sufficient permissions to write to this file.'
  rescue Errno::ENOSPC
    puts 'Error: Disk full. There is not enough space on the disk to write this file.'
  rescue Errno::ENOENT
    puts 'Error: Invalid file path. The file path specified does not exist.'
  end
end
