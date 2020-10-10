class ECMS

  def apply_pv_ground(model:, pv_ground_type:, pv_ground_area_total_m2:, pv_ground_tilt_angle:, pv_ground_azimuth_angle:, pv_ground_module:)
    # puts pv_ground_area_total_m2,pv_ground_tilt_angle,pv_ground_azimuth_angle,pv_ground_type,pv_ground_module

    ##### If pv_type is nil.. do nothing.
    return if pv_ground_type.nil? || pv_ground_type == FALSE

    ##### Calculate number of PV panels
    #TODO: Note: assuming 5 ft x 2 ft as PV panel's size since it seems to fit the racking system used for ground mounts as per Mike Lubun's comment.
    pv_area_each_ft2 = 5.0 * 2.0
    pv_area_each_m2 = (OpenStudio.convert(pv_area_each_ft2, 'ft^2', 'm^2').get) #convert pv_area_each_ft2 to m2
    # puts pv_area_each_m2
    pv_number_panels = pv_ground_area_total_m2/pv_area_each_m2
    # puts pv_number_panels

    ##### Get data of the PV panel from the json file
    pv_info = @standards_data['tables']['pv']['table'].detect { |item| item['pv_module'] == pv_ground_module }
    pv_watt = pv_info['pv_wattage']
    # puts pv_watt

    ##### Create the generator
    dc_system_capacity = pv_number_panels * pv_watt
    # puts dc_system_capacity
    generator = OpenStudio::Model::GeneratorPVWatts.new(model,dc_system_capacity)
    generator.setModuleType('Standard') #TODO: Question: module type?
    generator.setArrayType('FixedOpenRack')   #TODO: Check which option should be used
    generator.setTiltAngle(pv_ground_tilt_angle)
    generator.setAzimuthAngle(pv_ground_azimuth_angle)

    ##### Create the inverter
    inverter = OpenStudio::Model::ElectricLoadCenterInverterPVWatts.new(model)
    inverter.setDCToACSizeRatio(1.1)   #TODO: Question: DCToACSizeRatio?
    inverter.setInverterEfficiency(0.96)   #TODO: Question: InverterEfficiency?

    ##### Get distribution systems and set relevant parameters
    model.getElectricLoadCenterDistributions.sort.each  do |elc_distribution|
      elc_distribution.setInverter(inverter)
      elc_distribution.setGeneratorOperationSchemeType('Baseload')  #TODO: Check which option should be used
    end

  end

end
