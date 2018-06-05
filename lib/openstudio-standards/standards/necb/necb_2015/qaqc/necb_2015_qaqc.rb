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

    # Combine the data from the JSON files into a single hash
    top_dir = File.expand_path('../../..', File.dirname(__FILE__))
    standards_data_dir = "#{top_dir}/data/"
    files = Dir.glob("#{File.dirname(__FILE__)}/data/*.json").select {|e| File.file? e}
    files.each do |file|
      #puts "loading standards data from #{file}"
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

  def necb_qaqc(qaqc, model)
    puts "\n\nin necb_qaqc 2015 now\n\n"
    #Now perform basic QA/QC on items for NECB2015
    qaqc[:information] = []
    qaqc[:warnings] =[]
    qaqc[:errors] = []
    qaqc[:unique_errors]=[]

    # necb_space_compliance(qaqc)

    necb_envelope_compliance(qaqc) # [DONE]

    necb_infiltration_compliance(qaqc) # [DONE-NC]

    necb_exterior_opaque_compliance(qaqc) # [DONE-NC]

    necb_exterior_fenestration_compliance(qaqc) # [DONE-NC]

    necb_exterior_ground_surfaces_compliance(qaqc) # [DONE-NC]

    necb_zone_sizing_compliance(qaqc)

    necb_design_supply_temp_compliance(qaqc) # [DONE] made changes to NEECB section numbers

    # necb_economizer_compliance(qaqc)

    # necb_hrv_compliance(qaqc, model)

    necb_vav_fan_power_compliance(qaqc) # [DONE-NC]

    sanity_check(qaqc)

    # necb_plantloop_sanity(qaqc)

    qaqc[:information] = qaqc[:information].sort
    qaqc[:warnings] = qaqc[:warnings].sort
    qaqc[:errors] = qaqc[:errors].sort
    qaqc[:unique_errors]= qaqc[:unique_errors].sort
    return qaqc
  end

end
