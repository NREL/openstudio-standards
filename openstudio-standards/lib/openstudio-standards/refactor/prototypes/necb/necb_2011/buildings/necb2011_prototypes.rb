class NECB_2011_Prototype < NECB_2011_Model
  attr_reader :instvarbuilding_type
  def initialize
    super()
  end

end


[
    "FullServiceRestaurant",
    "Hospital",
    "HighriseApartment",
    "LargeHotel",
    "LargeOffice",
    "MediumOffice",
    "MidriseApartment",
    "Outpatient",
    "PrimarySchool",
    "QuickServiceRestaurant",
    "RetailStandalone",
    "SecondarySchool",
    "SmallHotel",
    "SmallOffice",
    "RetailStripmall",
    "Warehouse"

].each do |name|
  eval <<DYNAMICClass
class NECB2011#{name} < NECB_2011_Prototype
  @@building_type = "#{name}"
  register_standard ("\#{@@template}_\#{@@building_type}")
  def initialize
    super()
    @instvarbuilding_type = @@building_type
    puts @instvarbuilding_type
  end
end
DYNAMICClass
end

