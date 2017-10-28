class NECB_2011_Prototype < NECB_2011_Model
  @@building_type = nil
  attr_reader :instvarbuilding_type

  def initialize
    @instvartemplate = @@template
    @instvarbuilding_type = @@building_type
  end

end

class NECB_2011FullServiceRestaurant < NECB_2011_Prototype
  @@building_type = 'FullServiceRestaurant'
  register_standard ("#{@@template}_#{@@building_type}")

end

class NECB_2011HighriseApartment < NECB_2011_Model
  @@building_type = 'HighriseApartment'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011Hospital < NECB_2011_Model
  @@building_type = 'Hospital'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011LargeHotel < NECB_2011_Model
  @@building_type = 'LargeHotel'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011LargeOffice< NECB_2011_Model
  @@building_type = 'LargeOffice'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011MediumOffice< NECB_2011_Model
  @@building_type = 'MediumOffice'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011MidriseApartment < NECB_2011_Model
  @@building_type = 'MidriseApartment'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011Outpatient < NECB_2011_Model
  @@building_type = 'Outpatient'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011PrimarySchool< NECB_2011_Model
  @@building_type = 'PrimarySchool'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011QuickServiceRestaurant < NECB_2011_Model
  @@building_type = 'QuickServiceRestaurant'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011RetailStandalone < NECB_2011_Model
  @@building_type = 'RetailStandalone'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011SecondarySchool < NECB_2011_Model
  @@building_type = 'SecondarySchool'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011SmallHotel < NECB_2011_Model
  @@building_type = 'SmallHotel'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011SmallOffice < NECB_2011_Model
  @@building_type = 'SmallOffice'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011RetailStripmall < NECB_2011_Model
  @@building_type = 'RetailStripmall'
  register_standard ("#{@@template}_#{@@building_type}")


end

class NECB_2011Warehouse < NECB_2011_Model
  @@building_type = 'Warehouse'
  register_standard ("#{@@template}_#{@@building_type}")

end