module OpenstudioStandards
  # The CreateTypical module provides methods to create and modify an entire building energy model of a typical building
  module CreateTypical
    # @!group CreateTypicalEnumerations
    # Enumerations for CreateTypical

    # Get DOE building types
    #
    # @param extended [Boolean] set to true to return additional building types
    # @return [OpenStudio::StringVector] array of building type strings
    def self.get_doe_building_types(extended = false)
      # DOE Prototypes
      array = OpenStudio::StringVector.new
      array << 'SecondarySchool'
      array << 'PrimarySchool'
      array << 'SmallOffice'
      array << 'MediumOffice'
      array << 'LargeOffice'
      array << 'SmallHotel'
      array << 'LargeHotel'
      array << 'Warehouse'
      array << 'RetailStandalone'
      array << 'RetailStripmall'
      array << 'QuickServiceRestaurant'
      array << 'FullServiceRestaurant'
      array << 'MidriseApartment'
      array << 'HighriseApartment'
      array << 'Hospital'
      array << 'Outpatient'
      array << 'SuperMarket'
      array << 'Laboratory'
      array << 'LargeDataCenterLowITE'
      array << 'LargeDataCenterHighITE'
      array << 'SmallDataCenterLowITE'
      array << 'SmallDataCenterHighITE'
      array << 'Courthouse'
      array << 'College'

      return array
    end

    # Get DEER building types
    #
    # @param extended [Boolean] set to true to return additional building types
    # @return [OpenStudio::StringVector] array of building type strings
    def self.get_deer_building_types(extended = false)
      # DOE Prototypes
      array = OpenStudio::StringVector.new
      array << 'Asm'
      array << 'DMo'
      array << 'ECC'
      array << 'EPr'
      array << 'ERC'
      array << 'ESe'
      array << 'EUn'
      array << 'GHs'
      array << 'Gro'
      array << 'Hsp'
      array << 'Htl'
      array << 'MBT'
      array << 'MFm'
      array << 'MLI'
      array << 'Mtl'
      array << 'Nrs'
      array << 'OfL'
      array << 'OfS'
      array << 'RFF'
      array << 'RSD'
      array << 'Rt3'
      array << 'RtL'
      array << 'RtS'
      array << 'SCn'
      array << 'SFm'
      array << 'SUn'
      array << 'WRf'

      return array
    end

    # list of building types that are valid for get_space_types_from_building_type
    #
    # @param extended [Boolean] set to true to return additional building types
    # @return [OpenStudio::StringVector] array of building type strings
    def self.get_building_types(extended = false)
      # get building_types
      if extended
        doe = get_doe_building_types(true)
        deer = get_deer_building_types(true)
      else
        doe = get_doe_building_types
        deer = get_deer_building_types
      end

      # combine building_types
      array = OpenStudio::StringVector.new
      temp_array = doe.to_a + deer.to_a
      temp_array.each do |i|
        array << i
      end

      return array
    end

    # Get DOE templates
    #
    # @param extended [Boolean] set to true to return additional templates
    # @return [OpenStudio::StringVector] array of available standard templates as strings
    def self.get_doe_templates(extended = false)
      array = OpenStudio::StringVector.new
      array << 'DOE Ref Pre-1980'
      array << 'DOE Ref 1980-2004'
      array << '90.1-2004'
      array << '90.1-2007'
      array << '90.1-2010'
      array << '90.1-2013'
      array << '90.1-2016'
      array << '90.1-2019'
      array << 'ComStock DOE Ref Pre-1980'
      array << 'ComStock DOE Ref 1980-2004'
      array << 'ComStock 90.1-2004'
      array << 'ComStock 90.1-2007'
      array << 'ComStock 90.1-2010'
      array << 'ComStock 90.1-2013'
      array << 'ComStock 90.1-2016'
      array << 'ComStock 90.1-2019'
      if extended
        # array << '189.1-2009' # if turn this on need to update space_type_array for RetailStripmall
        array << 'NREL ZNE Ready 2017'
      end

      return array
    end

    # Get DEER templates
    #
    # @param extended [Boolean] set to true to return additional templates
    # @return [OpenStudio::StringVector] array of available standard templates as strings
    def self.get_deer_templates(extended = false)
      array = OpenStudio::StringVector.new
      array << 'DEER Pre-1975'
      array << 'DEER 1985'
      array << 'DEER 1996'
      array << 'DEER 2003'
      array << 'DEER 2007'
      array << 'DEER 2011'
      array << 'DEER 2014'
      array << 'DEER 2015'
      array << 'DEER 2017'
      array << 'DEER 2020'
      if extended
        array << 'DEER 2025'
        array << 'DEER 2030'
        array << 'DEER 2035'
        array << 'DEER 2040'
        array << 'DEER 2045'
        array << 'DEER 2050'
        array << 'DEER 2055'
        array << 'DEER 2060'
        array << 'DEER 2065'
        array << 'DEER 2070'
        array << 'DEER 2075'
      end

      array << 'ComStock DEER Pre-1975'
      array << 'ComStock DEER 1985'
      array << 'ComStock DEER 1996'
      array << 'ComStock DEER 2003'
      array << 'ComStock DEER 2007'
      array << 'ComStock DEER 2011'
      array << 'ComStock DEER 2014'
      array << 'ComStock DEER 2015'
      array << 'ComStock DEER 2017'
      array << 'ComStock DEER 2020'

      return array
    end

    # list of templates that are valid for get_space_types_from_building_type
    #
    # @param extended [Boolean] set to true to return additional templates
    # @return [OpenStudio::StringVector] array of available standard templates as strings
    def self.get_templates(extended = false)
      # get templates
      if extended
        doe = get_doe_templates(true)
        deer = get_deer_templates(true)
      else
        doe = get_doe_templates
        deer = get_deer_templates
      end

      # combine templates
      array = OpenStudio::StringVector.new
      temp_array = doe.to_a + deer.to_a
      temp_array.each do |i|
        array << i
      end

      return array
    end

    # Get DOE climate zones
    #
    # @param extended [Boolean] set to true to return additional climate zones
    # @param extra [String] extra climate zone to append to list
    # @return [OpenStudio::StringVector] array of available climate zones as strings
    def self.get_doe_climate_zones(extended = false, extra = nil)
      # Lookup From Model should be added as an option where appropriate in the measure
      cz_choices = OpenStudio::StringVector.new
      if !extra.nil?
        cz_choices << extra
      end
      cz_choices << 'ASHRAE 169-2013-1A'
      cz_choices << 'ASHRAE 169-2013-1B'
      cz_choices << 'ASHRAE 169-2013-2A'
      cz_choices << 'ASHRAE 169-2013-2B'
      cz_choices << 'ASHRAE 169-2013-3A'
      cz_choices << 'ASHRAE 169-2013-3B'
      cz_choices << 'ASHRAE 169-2013-3C'
      cz_choices << 'ASHRAE 169-2013-4A'
      cz_choices << 'ASHRAE 169-2013-4B'
      cz_choices << 'ASHRAE 169-2013-4C'
      cz_choices << 'ASHRAE 169-2013-5A'
      cz_choices << 'ASHRAE 169-2013-5B'
      cz_choices << 'ASHRAE 169-2013-5C'
      cz_choices << 'ASHRAE 169-2013-6A'
      cz_choices << 'ASHRAE 169-2013-6B'
      cz_choices << 'ASHRAE 169-2013-7A'
      cz_choices << 'ASHRAE 169-2013-8A'
      if extended
        cz_choices << 'ASHRAE 169-2013-0A'
        cz_choices << 'ASHRAE 169-2013-0B'
      end

      return cz_choices
    end

    # Get DEER climate zones
    #
    # @param extended [Boolean] set to true to return additional climate zones
    # @param extra [String] extra climate zone to append to list
    # @return [OpenStudio::StringVector] array of available climate zones as strings
    def self.get_deer_climate_zones(extended = false, extra = nil)
      # Lookup From Model should be added as an option where appropriate in the measure
      cz_choices = OpenStudio::StringVector.new
      if !extra.nil?
        cz_choices << extra
      end
      cz_choices << 'CEC T24-CEC1'
      cz_choices << 'CEC T24-CEC2'
      cz_choices << 'CEC T24-CEC3'
      cz_choices << 'CEC T24-CEC4'
      cz_choices << 'CEC T24-CEC5'
      cz_choices << 'CEC T24-CEC6'
      cz_choices << 'CEC T24-CEC7'
      cz_choices << 'CEC T24-CEC8'
      cz_choices << 'CEC T24-CEC9'
      cz_choices << 'CEC T24-CEC10'
      cz_choices << 'CEC T24-CEC11'
      cz_choices << 'CEC T24-CEC12'
      cz_choices << 'CEC T24-CEC13'
      cz_choices << 'CEC T24-CEC14'
      cz_choices << 'CEC T24-CEC15'
      cz_choices << 'CEC T24-CEC16'

      return cz_choices
    end

    # Get climate zones
    #
    # @param extended [Boolean] set to true to return additional climate zones
    # @param extra [String] extra climate zone to append to list
    # @return [OpenStudio::StringVector] array of available climate zones as strings
    def self.get_climate_zones(extended = false, extra = nil)
      # get climate_zones
      if extended && !extra.nil?
        doe = get_doe_climate_zones(true, extra)
        deer = get_deer_climate_zones(true, nil)
      elsif extended
        doe = get_doe_climate_zones(true, nil)
        deer = get_deer_climate_zones(true, nil)
      elsif !extra.nil?
        doe = get_doe_climate_zones(false, extra)
        deer = get_deer_climate_zones(false, nil)
      else
        doe = get_doe_climate_zones
        deer = get_deer_climate_zones
      end

      # combine climate zones
      array = OpenStudio::StringVector.new
      temp_array = doe.to_a + deer.to_a
      temp_array.each do |i|
        array << i
      end

      return array
    end

    # Building type abbreviation to long name map
    #
    # @param deer_building_type_short [String] DEER building type in short format
    # @return [String] DEER building type in long format
    def self.deer_building_type_to_long(deer_building_type_short)
      case deer_building_type_short
      when 'Asm'
        'Assembly'
      when 'DMo'
        'Residential Mobile Home'
      when 'ECC'
        'Education - Community College'
      when 'EPr'
        'Education - Primary School'
      when 'ERC'
        'Education - Relocatable Classroom'
      when 'ESe'
        'Education - Secondary School'
      when 'EUn'
        'Education - University'
      when 'GHs'
        'Greenhouse'
      when 'Gro'
        'Grocery'
      when 'Hsp'
        'Health/Medical - Hospital'
      when 'Htl'
        'Lodging - Hotel'
      when 'MBT'
        'Manufacturing Biotech'
      when 'MFm'
        'Residential Multi-family'
      when 'MLI'
        'Manufacturing Light Industrial'
      when 'Mtl'
        'Lodging - Motel'
      when 'Nrs'
        'Health/Medical - Nursing Home'
      when 'OfL'
        'Office - Large'
      when 'OfS'
        'Office - Small'
      when 'RFF'
        'Restaurant - Fast-Food'
      when 'RSD'
        'Restaurant - Sit-Down'
      when 'Rt3'
        'Retail - Multistory Large'
      when 'RtL'
        'Retail - Single-Story Large'
      when 'RtS'
        'Retail - Small'
      when 'SCn'
        'Storage - Conditioned'
      when 'SFm'
        'Residential Single Family'
      when 'SUn'
        'Storage - Unconditioned'
      when 'WRf'
        'Warehouse - Refrigerated'
      end
    end

    # HVAC type abbreviation to long name map
    #
    # @param deer_hvac_system_type_short [String] DEER HVAC system type in short format
    # @return [String] DEER HVAC system type in long format
    def self.deer_hvac_system_to_long(deer_hvac_system_type_short)
      case deer_hvac_system_type_short
      when 'DXGF'
        'Split or Packaged DX Unit with Gas Furnace'
      when 'DXEH'
        'Split or Packaged DX Unit with Electric Heat'
      when 'DXHP'
        'Split or Packaged DX Unit with Heat Pump'
      when 'WLHP'
        'Water Loop Heat Pump'
      when 'NCEH'
        'No Cooling with Electric Heat'
      when 'NCGF'
        'No Cooling with Gas Furnace'
      when 'PVVG'
        'Packaged VAV System with Gas Boiler'
      when 'PVVE'
        'Packaged VAV System with Electric Heat'
      when 'SVVG'
        'Built-Up VAV System with Gas Boiler'
      when 'SVVE'
        'Built-Up VAV System with Electric Reheat'
      when 'Unc'
        'No HVAC (Unconditioned)'
      when 'PTAC'
        'Packaged Terminal Air Conditioner'
      when 'PTHP'
        'Packaged Terminal Heat Pump'
      when 'FPFC'
        'Four Pipe Fan Coil'
      when 'DDCT'
        'Dual Duct System'
      when 'EVAP'
        'Evaporative Cooling with Separate Gas Furnace'
      end
    end

    # Valid building type/hvac type combos
    #
    # @param deer_building_type_short [String] DEER building type in short format
    # @return [Array<String>] Allowable HVAC systems for the DEER building type
    def self.deer_building_type_to_hvac_systems(deer_building_type_short)
      case deer_building_type_short
      when 'Asm', 'ERC', 'Gro', 'Mtl', 'MLI', 'RFF', 'RSD', 'RtL', 'RtS', 'SCn'
        ['DXEH', 'DXGF', 'DXHP', 'NCEH', 'NCGF']
      when 'ECC', 'ESe', 'Htl', 'MBT', 'OfL', 'OfS', 'Rt3'
        ['DXEH', 'DXGF', 'DXHP', 'NCEH', 'NCGF', 'PVVE', 'PVVG', 'SVVE', 'SVVG', 'WLHP']
      when 'EPr'
        ['DXEH', 'DXGF', 'DXHP', 'NCEH', 'NCGF', 'WLHP']
      when 'EUn', 'Hsp'
        ['DXEH', 'DXGF', 'DXHP', 'NCEH', 'NCGF', 'PVVE', 'PVVG', 'SVVE', 'SVVG']
      when 'Nrs'
        ['DXEH', 'DXGF', 'DXHP', 'FPFC', 'NCEH', 'NCGF', 'PVVE', 'PVVG', 'SVVE', 'SVVG']
      when 'SUn'
        ['Unc']
      when 'WRf'
        ['DXGF']
      end
    end

    # Age range to DEER template
    # @param deer_template [String] DEER template
    # @return [String] DEER age range
    def self.deer_template_to_age_range(deer_template)
      case deer_template
      when 'DEER Pre-1975'
        'Before 1978'
      when 'DEER 1985'
        '1978-1992'
      when 'DEER 1996'
        '1993-2001'
      when 'DEER 2003'
        '2002-2005'
      when 'DEER 2007'
        '2006-2009'
      when 'DEER 2011'
        '2010-2013'
      when 'DEER 2014'
        '2014'
      when 'DEER 2015'
        '2015-2016'
      when 'DEER 2017'
        '2017 or Later'
      end
    end
  end
end
