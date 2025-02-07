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

    # Map a DOE building type to the corresponding DEER building type.
    # DEER to DEER mappings included for some use cases
    # @param doe_building_type [String] DOE building type
    #
    # @return [String] DEER building type in short format
    def self.doe_to_deer_building_type(doe_building_type)
      dict = {}
      dict['SecondarySchool'] = 'ESe'
      dict['PrimarySchool'] = 'EPr'
      dict['SmallOffice'] = 'OfS'
      dict['MediumOffice'] = 'OfL'
      dict['LargeOffice'] = 'OfL'
      dict['SmallHotel'] = 'Mtl'
      dict['LargeHotel'] = 'Htl'
      dict['Warehouse'] = 'SUn' # Unconditioned Storage (SUn) is nearly identical to SCn
      dict['RetailStandalone'] = 'RtL'
      dict['RetailStripmall'] = 'RtS'
      dict['QuickServiceRestaurant'] = 'RFF'
      dict['FullServiceRestaurant'] = 'RSD'
      dict['MidriseApartment'] = 'MFm'
      dict['HighriseApartment'] = 'OfL'
      dict['Hospital'] = 'Hsp'
      dict['Outpatient'] = 'OfL'
      dict['SuperMarket'] = 'Gro'
      dict['Asm'] = 'Asm'
      dict['DMo'] = 'DMo'
      dict['ECC'] = 'ECC'
      dict['EPr'] = 'EPr'
      dict['ERC'] = 'ERC'
      dict['ESe'] = 'ESe'
      dict['EUn'] = 'EUn'
      dict['GHs'] = 'GHs'
      dict['Gro'] = 'Gro'
      dict['Hsp'] = 'Hsp'
      dict['Htl'] = 'Htl'
      dict['MBT'] = 'MBT'
      dict['MFm'] = 'MFm'
      dict['MLI'] = 'MLI'
      dict['Mtl'] = 'Mtl'
      dict['Nrs'] = 'Nrs'
      dict['OfL'] = 'OfL'
      dict['OfS'] = 'OfS'
      dict['RFF'] = 'RFF'
      dict['RSD'] = 'RSD'
      dict['Rt3'] = 'Rt3'
      dict['RtL'] = 'RtL'
      dict['RtS'] = 'RtS'
      dict['SCn'] = 'SCn'
      dict['SFm'] = 'SFm'
      dict['SUn'] = 'SUn'
      dict['WRf'] = 'WRf'

      return dict[doe_building_type]
    end

    # Building type abbreviation to long name map
    #
    # @param deer_building_type_short [String] DEER building type in short format
    # @return [String] DEER building type in long format
    def self.deer_building_type_to_long(deer_building_type_short)
      dict = {}
      dict['Asm'] = 'Assembly'
      dict['DMo'] = 'Residential Mobile Home'
      dict['ECC'] = 'Education - Community College'
      dict['EPr'] = 'Education - Primary School'
      dict['ERC'] = 'Education - Relocatable Classroom'
      dict['ESe'] = 'Education - Secondary School'
      dict['EUn'] = 'Education - University'
      dict['GHs'] = 'Greenhouse'
      dict['Gro'] = 'Grocery'
      dict['Hsp'] = 'Health/Medical - Hospital'
      dict['Htl'] = 'Lodging - Hotel'
      dict['MBT'] = 'Manufacturing Biotech'
      dict['MFm'] = 'Residential Multi-family'
      dict['MLI'] = 'Manufacturing Light Industrial'
      dict['Mtl'] = 'Lodging - Motel'
      dict['Nrs'] = 'Health/Medical - Nursing Home'
      dict['OfL'] = 'Office - Large'
      dict['OfS'] = 'Office - Small'
      dict['RFF'] = 'Restaurant - Fast-Food'
      dict['RSD'] = 'Restaurant - Sit-Down'
      dict['Rt3'] = 'Retail - Multistory Large'
      dict['RtL'] = 'Retail - Single-Story Large'
      dict['RtS'] = 'Retail - Small'
      dict['SCn'] = 'Storage - Conditioned'
      dict['SFm'] = 'Residential Single Family'
      dict['SUn'] = 'Storage - Unconditioned'
      dict['WRf'] = 'Warehouse - Refrigerated'

      return dict[deer_building_type_short]
    end

    # HVAC type abbreviation to long name map
    #
    # @param deer_hvac_system_type_short [String] DEER HVAC system type in short format
    # @return [String] DEER HVAC system type in long format
    def self.deer_hvac_system_to_long(deer_hvac_system_type_short)
      dict = {}
      dict['DXGF'] = 'Split or Packaged DX Unit with Gas Furnace'
      dict['DXEH'] = 'Split or Packaged DX Unit with Electric Heat'
      dict['DXHP'] = 'Split or Packaged DX Unit with Heat Pump'
      dict['WLHP'] = 'Water Loop Heat Pump'
      dict['NCEH'] = 'No Cooling with Electric Heat'
      dict['NCGF'] = 'No Cooling with Gas Furnace'
      dict['PVVG'] = 'Packaged VAV System with Gas Boiler'
      dict['PVVE'] = 'Packaged VAV System with Electric Heat'
      dict['SVVG'] = 'Built-Up VAV System with Gas Boiler'
      dict['SVVE'] = 'Built-Up VAV System with Electric Reheat'
      dict['Unc'] = 'No HVAC (Unconditioned)'
      dict['PTAC'] = 'Packaged Terminal Air Conditioner'
      dict['PTHP'] = 'Packaged Terminal Heat Pump'
      dict['FPFC'] = 'Four Pipe Fan Coil'
      dict['DDCT'] = 'Dual Duct System'
      dict['EVAP'] = 'Evaporative Cooling with Separate Gas Furnace'

      return dict[deer_hvac_system_type_short]
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
      dict = {}
      dict['DEER Pre-1975'] = 'Before 1978'
      dict['DEER 1985'] = '1978-1992'
      dict['DEER 1996'] = '1993-2001'
      dict['DEER 2003'] = '2002-2005'
      dict['DEER 2007'] = '2006-2009'
      dict['DEER 2011'] = '2010-2013'
      dict['DEER 2014'] = '2014'
      dict['DEER 2015'] = '2015-2016'
      dict['DEER 2017'] = '2017 or Later'

      return dict[deer_template]
    end
  end
end
