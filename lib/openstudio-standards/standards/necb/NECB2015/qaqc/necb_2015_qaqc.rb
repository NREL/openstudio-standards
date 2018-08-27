class NECB2015


  def load_qaqc_database_new()
    super()
    # replace 2011 to 2015 for all references in the tables.
    # puts JSON.pretty_generate( @standards_data['tables'] )
    @qaqc_data['tables'].each do |table|
      if table.has_key?('refs')
        # check if the reference is an array
        if table['refs'].is_a?(Array)
          table['refs'].each {|item|
            # Supply air system - necb_design_supply_temp_compliance
            item.gsub!('NECB2011-8.4.4.19', 'NECB2015-8.4.4.18')
            # Zone sizing compliance - Re: heating_sizing_factor and cooling_sizing_factor
            item.gsub!('NECB2011-8.4.4.9', 'NECB2015-8.4.4.8')
            item.gsub!('NECB2011', 'NECB2015')
          }
          # if the reference is a hash (e.g. see space.json compliance), then
          # replace the 2011 in the value with 2015
        elsif table['refs'].is_a?(Hash)
          table['refs'].keys.each  {|key|
            table['refs'][key].gsub!('NECB2011', 'NECB2015') unless table['refs'][key].nil?
          }
        end
      end
    end

    # Overwrite the data present from 2011 with the data read from the JSON files
    files = Dir.glob("#{File.dirname(__FILE__)}/qaqc_data/*.json").select {|e| File.file? e}
    puts "\n\n#{files}\n\n"
    files.each do |file|
      puts "loading standards data from #{file}"
      data = JSON.parse(File.read(file))
      if not data["tables"].nil? and data["tables"].first["data_type"] =="table"
        @qaqc_data["tables"] << data["tables"].first
      else
        @qaqc_data[data.keys.first] = data[data.keys.first]
      end
    end

    #needed for compatibility of standards database format
    @qaqc_data['tables'].each do |table|
      @qaqc_data[table['name']] = table
    end
    return @qaqc_data
  end


  def necb_envelope_compliance(qaqc)
    puts "\nUsing necb_envelope_compliance in NECB2015 Class\n"
    # Envelope
    necb_section_name = "NECB2015-Section 3.2.1.4"
    # store hdd in short form
    hdd = qaqc[:geography][:hdd]
    # calculate fdwr based on hdd.
    # [fdwr] *maximum* allowable total vertical fenestration and door area to
    # gross wall area ratio
    fdwr = 0
    # if hdd < 4000 [NECB 2011]
    if hdd <= 4000
      fdwr = 0.40
      # elsif hdd >= 4000 and hdd <=7000 [NECB 2011]
    elsif hdd > 4000 and hdd <7000
      fdwr = (2000-0.2 * hdd)/3000
      # elsif hdd >7000   [NECB 2011]
    elsif hdd >=7000
      fdwr = 0.20
    end
    #hardset srr to 0.05
    srr = 0.05

    # perform test. result must be equal to.
    necb_section_test(
        qaqc,
        (fdwr * 100), # fdwr is the maximum value possible
        '>=', # NECB 2011 [No Change]
        qaqc[:envelope][:fdwr].round(3),
        necb_section_name,
        "[ENVELOPE]fenestration_to_door_and_window_percentage",
        1 #padmassun added tollerance
    )

    # The total skylight area shall be less than 5% of gross roof area as determined
    # in article 3.1.1.6
    necb_section_test(
        qaqc,
        (srr * 100),
        '>=', # NECB 2011 [No Change]
        qaqc[:envelope][:srr].round(3),
        necb_section_name,
        "[ENVELOPE]skylight_to_roof_percentage",
        1 #padmassun added tollerance
    )
  end

  def necb_space_compliance(qaqc)
    #    #Padmassun's Code Start
    #csv_file_name ="#{File.dirname(__FILE__)}/necb_2011_spacetype_info.csv"
    qaqc[:spaces].each do |space|
      building_type =""
      space_type =""
      if space[:space_type_name].include? 'Space Function '
        space_type = (space[:space_type_name].to_s.rpartition('Space Function '))[2].strip
        building_type = 'Space Function'
      elsif space[:space_type_name].include? ' WholeBuilding'
        space_type = (space[:space_type_name].to_s.rpartition(' WholeBuilding'))[0].strip
        building_type = 'WholeBuilding'
      end

      ["occupancy_per_area_people_per_m2", "occupancy_schedule", "electric_equipment_per_area_w_per_m2"].each {|compliance_var|
        #qaqc_table = get_qaqc_table("space_compliance", {"template" => 'NECB2015', "building_type" => building_type, "space_type" => space_type}).first
        #qaqc_table = @qaqc_data['space_compliance']

        search_criteria = {"template" => 'NECB2015', "building_type" => building_type, "space_type" => space_type}
        qaqc_table = model_find_objects(@qaqc_data['space_compliance'], search_criteria)
        qaqc_table = qaqc_table.first
        puts"{\"building_type\" => #{building_type}, \"space_type\" => #{space_type}}"
        puts "#{qaqc_table}\n\n"

        necb_section_name = get_qaqc_table("space_compliance")['refs'][compliance_var]
        tolerance = get_qaqc_table("space_compliance")['tolerance'][compliance_var]
        # puts "\ncompliance_var:#{compliance_var}\n\tnecb_section_name:#{necb_section_name}\n\texp Value:#{qaqc_table[compliance_var]}\n"
        if compliance_var =="occupancy_per_area_people_per_m2"
          result_value = space[:occ_per_m2]
        elsif compliance_var =="occupancy_schedule"
          result_value = space[:occupancy_schedule]
        elsif compliance_var =="electric_equipment_per_area_w_per_m2"
          result_value = space[:electric_w_per_m2]
        end

        test_text = "[SPACE][#{space[:name]}]-[TYPE:][#{space_type}]-#{compliance_var}"
        next if result_value.nil?
        necb_section_test(
            qaqc,
            result_value,
            '==',
            qaqc_table[compliance_var],
            necb_section_name,
            test_text,
            tolerance
        )
      }

    end
    #Padmassun's Code End
  end

  def necb_qaqc(qaqc, model)
    puts "\n\nin necb_qaqc 2015 now\n\n"
    #Now perform basic QA/QC on items for NECB2015
    qaqc[:information] = []
    qaqc[:warnings] =[]
    qaqc[:errors] = []
    qaqc[:unique_errors]=[]

    necb_space_compliance(qaqc)

    necb_envelope_compliance(qaqc) # [DONE]

    necb_infiltration_compliance(qaqc, model) # [DONE-NC]

    necb_exterior_opaque_compliance(qaqc) # [DONE-NC]

    necb_exterior_fenestration_compliance(qaqc) # [DONE-NC]

    necb_exterior_ground_surfaces_compliance(qaqc) # [DONE-NC]

    necb_zone_sizing_compliance(qaqc) # [DONE] made changes to NECB section numbers

    necb_design_supply_temp_compliance(qaqc) # [DONE] made changes to NECB section numbers

    # Cannot implement 5.2.2.8.(4) and 5.2.2.8.(5) due to OpenStudio's limitation.
    necb_economizer_compliance(qaqc) # [DONE-NC]

    #NECB code regarding MURBS (§5.2.10.4) has not been implemented in both NECB 2011 and 2015
    necb_hrv_compliance(qaqc, model) # [DONE-NC]

    necb_vav_fan_power_compliance(qaqc) # [DONE-NC]

    sanity_check(qaqc)

    necb_plantloop_sanity(qaqc)

    qaqc[:information] = qaqc[:information].sort
    qaqc[:warnings] = qaqc[:warnings].sort
    qaqc[:errors] = qaqc[:errors].sort
    qaqc[:unique_errors]= qaqc[:unique_errors].sort
    return qaqc
  end

end
