# Using Evals to metaprogram here... Probably bad practice and makes debugging difficult...that being said I'm stubbing
# these for now to expediate testing. This only works now since we all use the same buildings.. as the buildings change in the future will require
# separate files for each template in the templates folder.

prototype_buildings = [
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
]


templates = ['NECB_2011',
             'A90_1_2004',
             'A90_1_2007',
             'A90_1_2010',
             'A90_1_2013',
             'DOERef1980_2004',
             'DOERefPre1980',
             'NRELZNEReady2017'
]

templates.each do |template|
  #Create Prototype base class (May not be needed...)
  #Ex: class NECB_2011_Prototype < NECB_2011_Model
  eval <<DYNAMICClass
class #{template}_Prototype < #{template}_Model
  attr_reader :instvarbuilding_type
  def initialize
    super()
  end
end
DYNAMICClass

  #Create Building Specific classes for each building.
  #Example class NECB_2011Hospital
  prototype_buildings.each do |name|
    eval <<DYNAMICClass
class #{template}#{name} < #{template}_Prototype
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
end
