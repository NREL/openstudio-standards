class ASHRAE9012010 < ASHRAE901
  # Get applicable performance curve for capacity as a function of temperature
  #
  # @param chiller_electric_eir [OpenStudio::Model::ChillerElectricEIR] chiller object
  # @param compressor_type [String] compressor type
  # @param cooling_type [String] cooling type ('AirCooled' or 'WaterCooled')
  # @param chiller_tonnage [Double] chiller capacity in ton
  # @return [String] name of applicable cuvre, nil if not found
  # @todo the current assingment is meant to replicate what was in the data, it probably needs to be reviewed
  def chiller_electric_eir_get_cap_f_t_curve_name(chiller_electric_eir, compressor_type, cooling_type, chiller_tonnage, compliance_path)
    case cooling_type
    when 'AirCooled'
      return 'AirCooled_Chiller_2010_PathA_CAPFT'
    when 'WaterCooled'
      case compressor_type
      when 'Centrifugal'
        return 'WaterCooled_Centrifugal_Chiller_GT150_2004_CAPFT' if chiller_tonnage >= 150

        return 'WaterCooled_Centrifugal_Chiller_LT150_2004_CAPFT'
      when 'Reciprocating', 'Rotary Screw', 'Scroll'
        # 2010 reference might suggest that this is the wrong curve
        return 'WaterCooled_PositiveDisplacement_Chiller_GT150_2010_PathA_CAPFT' if chiller_tonnage >= 150

        # 2010 reference might suggest that this is the wrong curve
        return 'WaterCooled_PositiveDisplacement_Chiller_LT150_2010_PathA_CAPFT'
      else
        return nil
      end
    else
      return nil
    end
  end

  # Get applicable performance curve for EIR as a function of temperature
  #
  # @param chiller_electric_eir [OpenStudio::Model::ChillerElectricEIR] chiller object
  # @param compressor_type [String] compressor type
  # @param cooling_type [String] cooling type ('AirCooled' or 'WaterCooled')
  # @param chiller_tonnage [Double] chiller capacity in ton
  # @return [String] name of applicable cuvre, nil if not found
  # @todo the current assingment is meant to replicate what was in the data, it probably needs to be reviewed
  def chiller_electric_eir_get_eir_f_t_curve_name(chiller_electric_eir, compressor_type, cooling_type, chiller_tonnage, compliance_path)
    case cooling_type
    when 'AirCooled'
      return 'AirCooled_Chiller_2010_PathA_EIRFT'
    when 'WaterCooled'
      case compressor_type
      when 'Centrifugal'
        return 'WaterCooled_Centrifugal_Chiller_GT150_2004_EIRFT' if chiller_tonnage >= 150

        return 'WaterCooled_Centrifugal_Chiller_LT150_2004_EIRFT'
      when 'Reciprocating', 'Rotary Screw', 'Scroll'
        # 2010 reference might suggest that this is the wrong curve
        return 'WaterCooled_PositiveDisplacement_Chiller_GT150_2010_PathA_EIRFT' if chiller_tonnage >= 150

        # 2010 reference might suggest that this is the wrong curve
        return 'WaterCooled_PositiveDisplacement_Chiller_LT150_2010_PathA_EIRFT'
      else
        return nil
      end
    else
      return nil
    end
  end

  # Get applicable performance curve for EIR as a function of part load ratio
  #
  # @param chiller_electric_eir [OpenStudio::Model::ChillerElectricEIR] chiller object
  # @param compressor_type [String] compressor type
  # @param cooling_type [String] cooling type ('AirCooled' or 'WaterCooled')
  # @param chiller_tonnage [Double] chiller capacity in ton
  # @return [String] name of applicable cuvre, nil if not found
  # @todo the current assingment is meant to replicate what was in the data, it probably needs to be reviewed
  def chiller_electric_eir_get_eir_f_plr_curve_name(chiller_electric_eir, compressor_type, cooling_type, chiller_tonnage, compliance_path)
    case cooling_type
    when 'AirCooled'
      return 'AirCooled_Chiller_AllCapacities_2004_2010_EIRFPLR'
    when 'WaterCooled'
      case compressor_type
      when 'Centrifugal'
        return 'ChlrWtrCentPathAAllEIRRatio_fQRatio'
      when 'Reciprocating', 'Rotary Screw', 'Scroll'
        return 'ChlrWtrPosDispPathAAllEIRRatio_fQRatio'
      else
        return nil
      end
    else
      return nil
    end
  end
end
