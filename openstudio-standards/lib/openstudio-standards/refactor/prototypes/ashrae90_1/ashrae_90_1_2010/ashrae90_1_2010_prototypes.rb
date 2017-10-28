class A90_1_2010__Prototype < A90_1_2010_Model
  @@building_type = nil
  attr_reader :instvarbuilding_type

  def initialize
    @instvartemplate = @@template
    @instvarbuilding_type = @@building_type
  end

end

class A90_1_2010_ModelFullServiceRestaurant < A90_1_2010__Prototype 
@@building_type = 'FullServiceRestaurant'
register_standard ("#{@@template}_#{@@building_type}")
  

end

class A90_1_2010_ModelHighriseApartment < A90_1_2010__Prototype 
  @@building_type = 'HighriseApartment'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelHospital < A90_1_2010__Prototype 
  @@building_type = 'Hospital'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelLargeHotel < A90_1_2010__Prototype 
  @@building_type = 'LargeHotel'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelLargeOffice< A90_1_2010__Prototype 
  @@building_type = 'LargeOffice'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelMediumOffice< A90_1_2010__Prototype 
  @@building_type = 'MediumOffice'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelMidriseApartment < A90_1_2010__Prototype 
  @@building_type = 'MidriseApartment'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelOutpatient < A90_1_2010__Prototype 
  @@building_type = 'Outpatient'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelPrimarySchool< A90_1_2010__Prototype 
  @@building_type = 'PrimarySchool'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelQuickServiceRestaurant < A90_1_2010__Prototype 
  @@building_type = 'QuickServiceRestaurant'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelRetailStandalone < A90_1_2010__Prototype 
  @@building_type = 'RetailStandalone'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelSecondarySchool < A90_1_2010__Prototype 
  @@building_type = 'SecondarySchool'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelSmallHotel < A90_1_2010__Prototype 
  @@building_type = 'SmallHotel'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelSmallOffice < A90_1_2010__Prototype 
  @@building_type = 'SmallOffice'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelRetailStripmall < A90_1_2010__Prototype 
  @@building_type = 'RetailStripmall'
  register_standard ("#{@@template}_#{@@building_type}")


end

class A90_1_2010_ModelWarehouse < A90_1_2010__Prototype 
  @@building_type = 'Warehouse'
  register_standard ("#{@@template}_#{@@building_type}")
  
end