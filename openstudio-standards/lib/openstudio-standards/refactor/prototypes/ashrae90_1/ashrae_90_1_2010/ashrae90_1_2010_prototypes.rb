class A90_1_2010_Prototype < A90_1_2010_Model
  attr_reader :instvarbuilding_type
  def initialize
    super()
  end

end
[
    "SmallHotel",
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
class A90_1_2010#{name} < A90_1_2010_Prototype
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