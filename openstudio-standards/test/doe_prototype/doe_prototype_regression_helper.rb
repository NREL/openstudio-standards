
def find_object(hash_of_objects, search_criteria)

  desired_object = nil
  matching_objects = []

  # Compare each of the objects against the search criteria
  hash_of_objects.each do |object|
    meets_all_search_criteria = true
    search_criteria.each do |key, value|
      # Don't check non-existent search criteria
      next unless object.key?(key)
      # Stop as soon as one of the search criteria is not met
      if object[key] != value
        meets_all_search_criteria = false
        break
      end
    end
    # Skip objects that don't meet all search criteria
    next unless meets_all_search_criteria
    # If made it here, object matches all search criteria
    matching_objects << object
  end

  # Check the number of matching objects found
  if matching_objects.size.zero?
    desired_object = nil
    OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned no results. Search criteria: #{search_criteria}, Called from #{caller(0)[1]}")
  elsif matching_objects.size == 1
    desired_object = matching_objects[0]
  else
    desired_object = matching_objects[0]
    OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned #{matching_objects.size} results, the first one will be returned. Called from #{caller(0)[1]}. \n Search criteria: \n #{search_criteria}, capacity = #{capacity} \n  All results: \n #{matching_objects.join("\n")}")
  end

  return desired_object
end

def load_idf_file(bldg_type, vintage, climate_zone)

  idf = nil
  errs = []
  idf_path_string = "#{Dir.pwd}/output/#{bldg_type}-#{vintage}-#{climate_zone}/#{bldg_type}-#{vintage}-#{climate_zone}.idf"
  idf_path = OpenStudio::Path.new(idf_path_string)
  idf = OpenStudio::IdfFile::load(idf_path, "EnergyPlus".to_IddFileType)
  if idf.empty?
    errs << "#{bldg_type}-#{vintage}-#{climate_zone}.idf didn't load"
  else
    idf = idf.get
  end

  return [idf, errs]

end

def load_or_create_sql(bldg_type, vintage, climate_zone)

  errs = []

  # Get the sql file from annual simulation.
  # If it doesn't exist, run a sizing run.
  sql_path_string = "#{Dir.pwd}/output/#{bldg_type}-#{vintage}-#{climate_zone}/AnnualRun/EnergyPlus/eplusout.sql"
  unless File.exists?(sql_path_string)
    sizing_run_dir = "#{Dir.pwd}/output/#{bldg_type}-#{vintage}-#{climate_zone}/SizingRunRegression"
    sql_path_string = "#{sizing_run_dir}/EnergyPlus/eplusout.sql"
    unless File.exists?(sql_path_string)
      # Load the .osm
      osm_path = "#{Dir.pwd}/output/#{bldg_type}-#{vintage}-#{climate_zone}/final.osm"
      unless File.exists?(osm_path)
        errs << "#{bldg_type}-#{vintage}-#{climate_zone} Could not find OSM to run sizing run to create sql file."
        return [nil, errs]
      end
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      model = version_translator.loadModel(osm_path)
      if model.empty?
        errs << "#{bldg_type}-#{vintage}-#{climate_zone} Could not load OSM to run sizing run to create sql file."
        return [nil, errs]
      end
      model = model.get
      
      # Run the sizing run
      if model.runSizingRun(sizing_run_dir) == false
        errs << "#{bldg_type}-#{vintage}-#{climate_zone} Sizing run to create sql file failed."
        return [nil, errs]
      end

    end
  end

  # Open the sql file
  sql_path = OpenStudio::Path.new(sql_path_string)
  if OpenStudio.exists(sql_path)
    sql = OpenStudio::SqlFile.new(sql_path)
  else
    errs << "#{bldg_type}-#{vintage}-#{climate_zone} Can't open sql file."
    return [nil, errs]
  end

  return [sql, errs]

end

def get_names(sql, name_col, report_name, table_name)

  errs = []
  name_query = "
      SELECT #{name_col} 
      FROM tabulardatawithstrings 
      WHERE ReportName='#{report_name}' 
      AND ReportForString='Entire Facility' 
      AND TableName='#{table_name}'"
  names = sql.execAndReturnVectorOfString(name_query)
  if names.empty?
    errs << "Can't get object names."
    names = []
  else
    names = names.get
  end

  return [names, errs]

end

def get_properties(sql, names, name_suffix, prop_suffix, props, name_col, report_name, table_name)

  vals = {}
  errs = []
  names.sort.each do |name|
    props.each do |prop|
      prop_query = "
        SELECT #{name_col} 
        FROM tabulardatawithstrings 
        WHERE ReportName='#{report_name}' 
        AND ReportForString='Entire Facility' 
        AND TableName='#{table_name}'
        AND RowName='#{name}'
        AND ColumnName='#{prop}'"
      val = sql.execAndReturnFirstDouble(prop_query)
      if val.empty?
        errs << "Can't get #{prop} for #{name}."
        next
      end
      # Remove the name suffix from the name
      # For example, ' ZN' would change 'CORE_ZN ZN'
      # to 'CORE_ZN'
      fixed_name = name.gsub(name_suffix, '')
      vals["#{fixed_name}_#{prop}#{prop_suffix}"] = val.get
    end
  end

  return [vals, errs]

end

def get_sim_settings(idf)

  vals = {}
  errs = []

  # Building
  obj = idf.getObjectsByType("Building".to_IddObjectType)[0]
  vals['North Axis'] = obj.getDouble(1).get
  vals['Terrain'] = obj.getString(2).get
  vals['Loads Convergence Tolerance Value'] = obj.getDouble(3).get
  vals['Temperature Convergence Tolerance Value'] = obj.getDouble(4).get
  vals['Solar Distribution'] = obj.getString(5).get
  vals['Maximum Number of Warmup Days'] = obj.getDouble(6).get
  vals['Minimum Number of Warmup Days'] = obj.getDouble(7).get

  # ShadowCalculation
  obj = idf.getObjectsByType("ShadowCalculation".to_IddObjectType)[0]
  unless obj.nil?      
    vals['ShadowCalculation.Calculation Method'] = obj.getString(0).get
    vals['ShadowCalculation.Calculation Frequency'] = obj.getDouble(1).get
  end

  # SurfaceConvectionAlgorithm:Inside
  obj = idf.getObjectsByType("SurfaceConvectionAlgorithm:Inside".to_IddObjectType)[0]
  vals['SurfaceConvectionAlgorithm.Inside'] = obj.getString(0).get

  # SurfaceConvectionAlgorithm:Outside
  obj = idf.getObjectsByType("SurfaceConvectionAlgorithm:Outside".to_IddObjectType)[0]
  vals['SurfaceConvectionAlgorithm.Outside'] = obj.getString(0).get

  # HeatbalanceAlgorithm
  # obj = idf.getObjectsByType("HeatbalanceAlgorithm".to_IddObjectType)[0]
  # unless obj.nil?
    # vals['HeatBalanceAlgorithm'] = obj.getString(0).get
    # vals['SurfaceTemperatureUpperLimit'] = obj.getDouble(1).get
  # end

  # Timestep
  obj = idf.getObjectsByType("Timestep".to_IddObjectType)[0]
  vals['Timestep'] = obj.getDouble(0).get

  # ConvergenceLimits

  obj = idf.getObjectsByType("ConvergenceLimits".to_IddObjectType)[0]
  unless obj.nil?
    vals['Minimum System Timestep'] = obj.getDouble(0).get
    vals['Maximum HVAC Iterations'] = obj.getDouble(1).get
  end

  # Site:Location
  obj = idf.getObjectsByType("Site:Location".to_IddObjectType)[0]
  vals['Latitude'] = obj.getDouble(1).get
  vals['Longitude'] = obj.getDouble(2).get
  vals['Time Zone'] = obj.getDouble(3).get
  vals['Elevation'] = obj.getDouble(4).get

  # Site:GroundTemperature:BuildingSurface
  obj = idf.getObjectsByType("Site:GroundTemperature:BuildingSurface".to_IddObjectType)[0]
  unless obj.nil?
    vals['ground_temp_1'] = obj.getDouble(0).get
    vals['ground_temp_2'] = obj.getDouble(1).get
    vals['ground_temp_3'] = obj.getDouble(2).get
    vals['ground_temp_4'] = obj.getDouble(3).get
    vals['ground_temp_5'] = obj.getDouble(4).get
    vals['ground_temp_6'] = obj.getDouble(5).get
    vals['ground_temp_7'] = obj.getDouble(6).get
    vals['ground_temp_8'] = obj.getDouble(7).get
    vals['ground_temp_9'] = obj.getDouble(8).get
    vals['ground_temp_10'] = obj.getDouble(9).get
    vals['ground_temp_11'] = obj.getDouble(10).get
    vals['ground_temp_12'] = obj.getDouble(11).get
  end

  # Site:WaterMainsTemperature
  obj = idf.getObjectsByType("Site:WaterMainsTemperature".to_IddObjectType)[0]
  vals['Calculation Method'] = obj.getString(0).get
  vals['Temperature Schedule Name'] = obj.getString(1).get
  vals['Annual Average Outdoor Air Temperature'] = obj.getDouble(2).get
  vals['Maximum Difference In Monthly Average Outdoor Air Temperatures'] = obj.getDouble(3).get

  # Sizing:Parameters
  obj = idf.getObjectsByType("Sizing:Parameters".to_IddObjectType)[0]
  vals['Heating Sizing Factor'] = obj.getDouble(0).get
  vals['Cooling Sizing Factor'] = obj.getDouble(1).get
  # vals['Timesteps in Averaging Window'] = obj.getDouble(2).get

  return vals

end

def compare_legacy_vals(old_obj, new_obj)

  # String comparison is case insensitive
  # Tolerance for numbers is 1% error
  tol = 0.01
  errs = []

  # Compare each key-value pair
  old_obj.each do |old_key, old_val|
    
    # Make sure that the key exists in the new object
    unless new_obj.key?(old_key)
      errs << "#{old_key}, old = #{old_val}, new = DOES NOT EXIST"
      next
    end

    # Get the new value
    new_val = new_obj[old_key]
    
    # Compare old to new value
    if new_val.is_a? String
      unless new_val.downcase == old_val.downcase
        errs << "#{old_key}, old = '#{old_val}', new = '#{new_val}'"
      end
    elsif new_val.is_a? Numeric
      # Calculate 1% of the old value
      ok_delta = (old_val * tol).abs
      delta = (old_val - new_val).abs
      if delta > ok_delta
        errs << "#{old_key}, old = #{old_val}, new = #{new_val}"
      end
    else
      unless new_val == old_val
        errs << "#{old_key}, old = #{old_val}, new = #{new_val}"
      end
    end

  end

  return errs

end

def compare_properties(property_type, bldg_types, vintages, climate_zones)
  
  # Load the legacy idf JSON file into a ruby hash
  temp = File.read("#{Dir.pwd}/data/#{property_type}.json")
  legacy_data = JSON.parse(temp)

  # Loop through all files
  fails = []
  bldg_types.sort.each do |bldg_type|
    vintages.sort.each do |vintage|
      climate_zones.sort.each do |climate_zone|
        # puts "#{bldg_type}-#{vintage}-#{climate_zone}"

        # Load or create the sql file
        sql, errs = load_or_create_sql(bldg_type, vintage, climate_zone)
        if errs.size > 0
          fails += errs
          next
        end

        # Record values for all fuel type/end use pairs
        vals = {}
        vals['building_type'] = bldg_type
        vals['template'] = vintage
        vals['climate_zone'] = climate_zone

        case property_type
        when 'sim_settings'

          # Load the IDF
          idf, errs = load_idf_file(bldg_type, vintage, climate_zone)
          fails += errs
          unless idf.nil?
            values = get_sim_settings(idf)
            vals = vals.merge(values)
          end

        when 'envelope'

          # Opaque Surfaces
          names, errs = get_names(sql, 'RowName', 'EnvelopeSummary', 'Opaque Exterior')
          fails += errs
          props = ['Reflectance', 'U-Factor no Film', 'Gross Area', 'Net Area']
          values, errs = get_properties(sql, names, '', '', props, 'Value', 'EnvelopeSummary', 'Opaque Exterior')
          vals = vals.merge(values)
          fails += errs
          
          # Exterior Fenestration
          names, errs = get_names(sql, 'RowName', 'EnvelopeSummary', 'Exterior Fenestration')
          fails += errs
          props = ['Glass Area', 'Frame Area', 'Divider Area', 'Glass U-Factor', 'Glass SHGC', 'Glass Visible Transmittance']
          values, errs = get_properties(sql, names, '', '', props, 'Value', 'EnvelopeSummary', 'Exterior Fenestration')
          vals = vals.merge(values)
          fails += errs

        when 'internal_loads'
          
          # Zone loads
          names, errs = get_names(sql, 'RowName', 'InputVerificationandResultsSummary', 'Zone Summary')
          fails += errs
          props = ['Multipliers', 'Lighting', 'People', 'Plug and Process']
          values, errs = get_properties(sql, names, ' ZN', '', props, 'Value', 'InputVerificationandResultsSummary', 'Zone Summary')
          vals = vals.merge(values)
          fails += errs

        when 'lighting'

          # Lighting hours
          names, errs = get_names(sql, 'RowName', 'LightingSummary', 'Interior Lighting')
          fails += errs
          props = ['Full Load Hours/Week', 'Scheduled Hours/Week']
          values, errs = get_properties(sql, names, ' ZN', '', props, 'Value', 'LightingSummary', 'Interior Lighting')
          vals = vals.merge(values)
          fails += errs

        when 'outdoor_air'

          # Ventilation and Infiltration
          names, errs = get_names(sql, 'RowName', 'OutdoorAirSummary', 'Minimum Outdoor Air During Occupied Hours')
          fails += errs
          props = ['Average Number of Occupants', 'Mechanical Ventilation', 'Infiltration']
          values, errs = get_properties(sql, names, ' ZN', '', props, 'Value', 'OutdoorAirSummary', 'Minimum Outdoor Air During Occupied Hours')
          vals = vals.merge(values)
          fails += errs

        when 'zone_sizing'

          # Cooling
          names, errs = get_names(sql, 'RowName', 'HVACSizingSummary', 'Zone Sensible Cooling')
          fails += errs
          props = ['User Design Load', 'User Design Air Flow', 'Thermostat Setpoint Temperature at Peak Load', 'Minimum Outdoor Air Flow Rate']
          values, errs = get_properties(sql, names, ' ZN', '_clg', props, 'Value', 'HVACSizingSummary', 'Zone Sensible Cooling')
          vals = vals.merge(values)
          fails += errs

          # Heating
          names, errs = get_names(sql, 'RowName', 'HVACSizingSummary', 'Zone Sensible Heating')
          fails += errs
          props = ['User Design Load', 'User Design Air Flow', 'Thermostat Setpoint Temperature at Peak Load', 'Minimum Outdoor Air Flow Rate']
          values, errs = get_properties(sql, names, ' ZN', '_htg', props, 'Value', 'HVACSizingSummary', 'Zone Sensible Heating')
          vals = vals.merge(values)
          fails += errs

        end

        # Find this building's information in the legacy JSON
        search_criteria = {
          "building_type" => bldg_type,
          "template" => vintage,
          "climate_zone" => climate_zone
        }
        legacy_vals = find_object(legacy_data, search_criteria)
        if legacy_vals.nil?
          fails << "Could not find legacy IDF data for #{bldg_type}-#{vintage}-#{climate_zone}"
          next
        end

        # Compare legacy vals to current vals
        # and save any failures
        errs = compare_legacy_vals(legacy_vals, vals)
        errs.each do |err|
          fails << "#{bldg_type}-#{vintage}-#{climate_zone}: #{err}"
        end

      end
    end
  end

  puts "*** #{property_type} ***"
  fails.each do |fail|
    puts fail
  end

  return fails

end
