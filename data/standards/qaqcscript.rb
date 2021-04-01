# A script to check that the R-value of constructions in the speedDataLibrary

require "json"
require "pry-nav"
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'#
#require 'minitest/autorun'
require 'fileutils'
require 'openstudio-standards'
require 'pry-nav'

# constructOSMs/constructions.rb needs this

#$speed_constructions = JSON.parse(File.read(File.join(File.dirname(__FILE__),'./SpeedDataLibrary_constructions.json')))

#$speed_materials = JSON.parse(File.read(File.join(File.dirname(__FILE__),'./SpeedDataLibrary_materials.json')))

speed_input = JSON.parse(File.read(File.join(File.dirname(__FILE__),'./inputs_new.json')))

### Helper method ripped from https://github.com/PW-Corporate/speed_engine/blob/master/app/designSpace/helpers.js#L325-L351
def energycodeToOpenStudioStandards(energyCode)
  # Convert from project json energy code to "ASHRAE_90_1_2007","ASHRAE_90_1_2010","ASHRAE_90_1_2013"
  # energy code which OpenStudio standards is expecting - "90.1-2007","90.1-2010","90.1-2013"

  # https://www.rubydoc.info/gems/openstudio-standards/0.2.2/Standard#build-class_method
  # args into build - DOE Pre-1980, DOE 1980-2004, 90.1-2004, 90.1-2007, 90.1-2010, 90.1-2013, NREL ZNE Ready 2017, NECB2011


  case energyCode
  when "ASHRAE_90_1_2007"

    return "90.1-2007"

  when "ASHRAE_90_1_2010"

    return "90.1-2010"

  when "ASHRAE_90_1_2013"

    return "90.1-2013"
  else
    raise "Could not find energy code"
  end
end


# load the test model
# translator = OpenStudio::OSVersion::VersionTranslator.new
# path = OpenStudio::Path.new(File.dirname(__FILE__) + "/resources/construction_lib.osm")
# model = translator.loadModel(path)

# #binding.pry
# #assert((not model.empty?))
# model = model.get

# Loop through constructions in resource model


# model.getConstructions.each do |construction|
	
	# binding.pry

# end

@construction_qaqc_report = []

#{ method_name: 'check_envelope_conductance', cat: 'Baseline', standards: true, data: nil, tol_min: 0.1, tol_max: true, units: 'fraction' }

## Inspried by....https://github.com/NREL/openstudio-standards/blob/master/test/90_1_general/test_find_construction_properties_data.rb

path = OpenStudio::Path.new(File.join(File.dirname(__FILE__) ,'./construction_lib.osm'))

translator = OpenStudio::OSVersion::VersionTranslator.new

@constructions_resource_osm = translator.loadModel(path).get

# make an empty model
model = OpenStudio::Model::Model.new


# speed_building_types = ['Office',
# 'FullServiceRestaurant','HighriseApartment','Hospital','LargeHotel','MidriseApartment','Outpatient','PrimarySchool','QuickServiceRestaurant','Retail','SecondarySchool','SmallHotel','SuperMarket','Warehouse'
# ]
### https://www.matthewb.id.au/csv/text-list-to-javascript-array.html thank you!
# originally taken from space_type in InputJSONData_SpaceLoads.csv
#ashrae_standard_space_types = 
#['OfficeLarge Data Center','Stair','Lobby','Elec/MechRoom','Corridor','Conference','BreakRoom','Storage','Restroom','OpenOffice','ClosedOffice','Dining','Classroom','OfficeLarge Data Center','MediumOffice - Stair','MediumOffice - Lobby','MediumOffice - Elec/MechRoom','MediumOffice - Corridor','MediumOffice - Conference','MediumOffice - Breakroom','MediumOffice - Storage','MediumOffice - Restroom','MediumOffice - OpenOffice','MediumOffice - ClosedOffice','MediumOffice - Dining','MediumOffice - Classroom','OfficeLarge Data Center','SmallOffice - Stair','SmallOffice - Lobby','SmallOffice - Elec/MechRoom','SmallOffice - Corridor','SmallOffice - Conference','SmallOffice - Breakroom','SmallOffice - Storage','SmallOffice - Restroom','SmallOffice - OpenOffice','SmallOffice - ClosedOffice','SmallOffice - Dining','SmallOffice - Classroom','Kitchen','Dining','Apartment','Corridor','Office','Kitchen','Basement','Corridor','Dining','ER_Exam','ER_NurseStn','ER_Trauma','ER_Triage','ICU_NurseStn','ICU_Open','ICU_PatRm','Lab','Lobby','NurseStn','Office','OR','PatRoom','PhysTherapy','Radiology','Kitchen','Banquet','Basement','Cafe','Corridor','GuestRoom','Laundry','Lobby','Mechanical','Retail','Storage','Apartment','Corridor','Office','Anesthesia','BioHazard','Cafe','Conference','DressingRoom','Elec/MechRoom','Exam','Hall','IT_Room','Janitor','Lobby','LockerRoom','Lounge','MedGas','MRI','NurseStation','Office','OR','PACU','PhysicalTherapy','PreOp','ProcedureRoom','Reception','Stair','Toilet','Xray','Restroom','Office','Mechanical','Lobby','Library','Gym','Corridor','Classroom','Cafeteria','Kitchen','ComputerRoom','Dining','Kitchen','Back_Space','Point_of_Sale','Retail','Auditorium','Cafeteria','Classroom','Corridor','Gym','Library','Lobby','Mechanical','Office','Restroom','Kitchen','ComputerRoom','Corridor','Elec/MechRoom','ElevatorCore','Exercise','GuestLounge','GuestRoom123Occ','GuestRoom123Vac','Laundry','Meeting','Office','PublicRestroom','StaffLounge','Stair','Storage','Sales','Office','DryStorage','Sales','Office','Bulk','OfficeLarge Data Center','Stair','Lobby','Elec/MechRoom','Corridor','Conference','BreakRoom','Storage','Restroom','OpenOffice','ClosedOffice','Dining','Classroom','OfficeLarge Data Center','MediumOffice - Stair','MediumOffice - Lobby','MediumOffice - Elec/MechRoom','MediumOffice - Corridor','MediumOffice - Conference','MediumOffice - Breakroom','MediumOffice - Storage','MediumOffice - Restroom','MediumOffice - OpenOffice','MediumOffice - ClosedOffice','MediumOffice - Dining','MediumOffice - Classroom','OfficeLarge Data Center','SmallOffice - Stair','SmallOffice - Lobby','SmallOffice - Elec/MechRoom','SmallOffice - Corridor','SmallOffice - Conference','SmallOffice - Breakroom','SmallOffice - Storage','SmallOffice - Restroom','SmallOffice - OpenOffice','SmallOffice - ClosedOffice','SmallOffice - Dining','SmallOffice - Classroom','Kitchen','Dining','Apartment','Corridor','Office','Kitchen','Basement','Corridor','Dining','ER_Exam','ER_NurseStn','ER_Trauma','ER_Triage','ICU_NurseStn','ICU_Open','ICU_PatRm','Lab','Lobby','NurseStn','Office','OR','PatRoom','PhysTherapy','Radiology','Kitchen','Banquet','Basement','Cafe','Corridor','GuestRoom','Laundry','Lobby','Mechanical','Retail','Storage','Apartment','Corridor','Office','Anesthesia','BioHazard','Cafe','Conference','DressingRoom','Elec/MechRoom','Exam','Hall','IT_Room','Janitor','Lobby','LockerRoom','Lounge','MedGas','MRI','NurseStation','Office','OR','PACU','PhysicalTherapy','PreOp','ProcedureRoom','Reception','Stair','Toilet','Xray','Restroom','Office','Mechanical','Lobby','Library','Gym','Corridor','Classroom','Cafeteria','Kitchen','ComputerRoom','Dining','Kitchen','Back_Space','Point_of_Sale','Retail','Auditorium','Cafeteria','Classroom','Corridor','Gym','Library','Lobby','Mechanical','Office','Restroom','Kitchen','ComputerRoom','Corridor','Elec/MechRoom','ElevatorCore','Exercise','GuestLounge','GuestRoom123Occ','GuestRoom123Vac','Laundry','Meeting','Office','PublicRestroom','StaffLounge','Stair','Storage','Sales','Office','DryStorage','Sales','Office','Bulk','OfficeLarge Data Center','Stair','Lobby','Elec/MechRoom','Corridor','Conference','BreakRoom','Storage','Restroom','OpenOffice','ClosedOffice','Dining','Classroom','OfficeLarge Data Center','MediumOffice - Stair','MediumOffice - Lobby','MediumOffice - Elec/MechRoom','MediumOffice - Corridor','MediumOffice - Conference','MediumOffice - Breakroom','MediumOffice - Storage','MediumOffice - Restroom','MediumOffice - OpenOffice','MediumOffice - ClosedOffice','MediumOffice - Dining','MediumOffice - Classroom','OfficeLarge Data Center','SmallOffice - Stair','SmallOffice - Lobby','SmallOffice - Elec/MechRoom','SmallOffice - Corridor','SmallOffice - Conference','SmallOffice - Breakroom','SmallOffice - Storage','SmallOffice - Restroom','SmallOffice - OpenOffice','SmallOffice - ClosedOffice','SmallOffice - Dining','SmallOffice - Classroom','Kitchen','Dining','Apartment','Corridor','Office','Kitchen','Basement','Corridor','Dining','ER_Exam','ER_NurseStn','ER_Trauma','ER_Triage','ICU_NurseStn','ICU_Open','ICU_PatRm','Lab','Lobby','NurseStn','Office','OR','PatRoom','PhysTherapy','Radiology','Kitchen','Banquet','Basement','Cafe','Corridor','GuestRoom','Laundry','Lobby','Mechanical','Retail','Storage','Apartment','Corridor','Office','Anesthesia','BioHazard','Cafe','Conference','DressingRoom','Elec/MechRoom','Exam','Hall','IT_Room','Janitor','Lobby','LockerRoom','Lounge','MedGas','MRI','NurseStation','Office','OR','PACU','PhysicalTherapy','PreOp','ProcedureRoom','Reception','Stair','Toilet','Xray','Restroom','Office','Mechanical','Lobby','Library','Gym','Corridor','Classroom','Cafeteria','Kitchen','ComputerRoom','Dining','Kitchen','Back_Space','Point_of_Sale','Retail','Auditorium','Cafeteria','Classroom','Corridor','Gym','Library','Lobby','Mechanical','Office','Restroom','Kitchen','ComputerRoom','Corridor','Elec/MechRoom','ElevatorCore','Exercise','GuestLounge','GuestRoom123Occ','GuestRoom123Vac','Laundry','Meeting','Office','PublicRestroom','StaffLounge','Stair','Storage','Sales','Office','DryStorage','Sales','Office','Bulk'];

# https://syntaxdb.com/ref/ruby/write-file
report = File.new(File.join(File.dirname(__FILE__), 'construction_qaqc_report.txt'),"w")

construction_type_array = []

modelClimateZones = model.getClimateZones

count = 0

if modelClimateZones.climateZones.length == 0 then modelClimateZones.appendClimateZone("ASHRAE") end

## Loop through constructions input json and compare them to standards in QAQC measure
speed_input["Constructions"].keys.each do |energyCode|

	#binding.pry
	
	speed_input["Constructions"][energyCode].keys.each do |climateZone|
		## In input json energy code is ASHRAE_90_1_2010,ASHRAE_90_1_2007,ASHRAE_90_1_2010
		target_standard = energycodeToOpenStudioStandards(energyCode)

		@standard = Standard.build(target_standard)

		#binding.pry


		speed_input["Constructions"][energyCode][climateZone].keys.each do |speed_intended_surface_type|
			# mode is like Non-Metal_Framing
			speed_input["Constructions"][energyCode][climateZone][speed_intended_surface_type].keys.each do |mode|

				if mode == "Slab_Type" then next end
				# Now we are at Wall_Type, or Wall_R_value
				speed_input["Constructions"][energyCode][climateZone][speed_intended_surface_type][mode].keys.each do |type|
					# Lets skip this for now
					if type.include? "R_Value" then next end
					if mode == "Int_Wall_Type" then next end
					if mode == "Floor_Type" then next end
					#if type == "Slab_Type" then next end
					#binding.pry
					begin
						#puts speed_input["Constructions"][energyCode][climateZone][speed_intended_surface_type][mode][type]

						constructions = speed_input["Constructions"][energyCode][climateZone][speed_intended_surface_type][mode][type]['Options'] <<
						speed_input["Constructions"][energyCode][climateZone][speed_intended_surface_type][mode][type]['Default']
					rescue => e
						binding.pry
					end
					
					constructions.each do |construction_name|

						default = false
						if speed_input["Constructions"][energyCode][climateZone][speed_intended_surface_type][mode][type]['Default'].nil? then binding.pry end

						if speed_input["Constructions"][energyCode][climateZone][speed_intended_surface_type][mode][type]['Default'] == construction_name then default = true end
						# Only look at defaults for now
						puts default
						default_tag = " NOT PRESCRIPTIVE - "
						if default == true then default_tag = " PRESCRIPTIVE " end
						count+= 1
						#if default == true then count+= 1 end
						
						construction = @constructions_resource_osm.getConstructionByName(construction_name.to_s).get

						if !construction.initialized then raise "Could not find "+construction end

						if !construction.standardsInformation.initialized then report.write(" #{default_tag} -- standards info not initalized for #{construction.name} #{target_standard}  -- skipping checks for this construction\n") end

						standards_info = construction.standardsInformation

						if !standards_info.initialized then report.write(" #{default_tag} -- standards info not initalized for #{construction.name} #{target_standard}  -- skipping checks for this construction \n") ; next end

						if standards_info.standardsConstructionType.empty? then report.write(" #{default_tag} -- standards construction type empty for #{construction.name} #{target_standard}  -- skipping checks for this construction \n") end
						
						if !standards_info.standardsConstructionType.is_initialized then report.write(" #{default_tag} -- standards info construction type not initalized for #{construction.name} #{target_standard}  -- skipping checks for this construction\n") ; next end

						standards_construction_type = standards_info.standardsConstructionType.get

						

						if standards_info.intendedSurfaceType.empty? then report.write(" #{default_tag} -- intended surface empty for #{construction.name} #{target_standard}  -- skipping checks for this construction\n") end
						## ASHRAE intended surface type from construction resource osm
						intended_surface_type = standards_info.intendedSurfaceType.get
						
						# All constructions in the construction resource osm should be of interest
						#next unless const_types_of_interest.include?(intended_surface_type)

						### Converted intended_surface_type from SPEED convention to ASHRAE

						# https://github.com/NREL/openstudio-standards/blob/master/test/90_1_general/test_find_construction_properties_data.rb#L30
						### Mode is standards_construction_type
						###
						### https://github.com/NREL/openstudio-standards/blob/33a152d027558f7efdd9201a06e838cdd9a4a546/lib/openstudio-standards/standards/Standards.SpaceType.rb#L567-L592

						#binding.pry

						const_types_of_interest = ['ExteriorRoof', 'ExteriorWall', 'GroundContactFloor', 'ExteriorWindow']
						
						#if !const_types_of_interest.include?(intended_surface_type) then report.write(" #{default_tag} -- intended surface for #{construction.name}  not included skipping #{intended_surface_type}   skipping checks for this construction \n") ; next end

						climate_zone_set = "ClimateZone #{climateZone.to_s}"

						search_criteria = {
							'template' => target_standard,
							'climate_zone_set' => climate_zone_set,
							'intended_surface_type' => intended_surface_type,
							'standards_construction_type' => standards_construction_type,
							'building_category' => 'Nonresidential'
						}

						data = @standard.model_find_object(@standard.standards_data['construction_properties'], search_criteria)
						### Having too much trouble with this
						#
						#data = @standard.space_type_get_construction_properties(space_type, intended_surface_type, construction_type)
						# Replace directly with the query it is built on

						#next unless 

						space_type_const_properties = {}
						
						space_type_const_properties[intended_surface_type] = {}

						#binding.pry

						if data.nil?
							#puts "lookup for #{target_standard}, #{climate_zone_set} #{intended_surface_type} #{standards_construction_type}, \n"
							report.write(" #{default_tag} -- Didn't find construction for #{target_standard}, #{climate_zone_set} #{intended_surface_type} #{standards_construction_type} .\n")

							#binding.pry
							next
							#flags <<  "Didn't find construction for #{standard_space_type} #{intended_surface_type} for #{space_type.name}."
						elsif intended_surface_type.include? 'ExteriorWall' || 'ExteriorFloor' || 'ExteriorDoor'
							space_type_const_properties[intended_surface_type]['u_value'] = data['assembly_maximum_u_value']
							space_type_const_properties[intended_surface_type]['reflectance'] = 0.30 # hard coded value
						elsif intended_surface_type.include? 'ExteriorRoof'
							space_type_const_properties[intended_surface_type]['u_value'] = data['assembly_maximum_u_value']
							space_type_const_properties[intended_surface_type]['reflectance'] = 0.55 # hard coded value
						else
							space_type_const_properties[intended_surface_type]['u_value'] = data['assembly_maximum_u_value']
							space_type_const_properties[intended_surface_type]['shgc'] = data['assembly_maximum_solar_heat_gain_coefficient']
						end

						puts "intended surface type"
						puts intended_surface_type


						target_r_value_ip = {}
						target_reflectance = {}
						target_u_value_ip = {}
						target_shgc = {}

						case intended_surface_type

						when 'ExteriorWall'
							target_r_value_ip['ExteriorWall'] = 1.0 / space_type_const_properties['ExteriorWall']['u_value'].to_f
							target_reflectance['ExteriorWall'] = space_type_const_properties['ExteriorWall']['reflectance'].to_f

						when 'ExteriorRoof'

							target_r_value_ip['ExteriorRoof'] = 1.0 / space_type_const_properties['ExteriorRoof']['u_value'].to_f
							target_reflectance['ExteriorRoof'] = space_type_const_properties['ExteriorRoof']['reflectance'].to_f
						when 'Floor'

							target_r_value_ip['Floor'] = 1.0 / space_type_const_properties['ExteriorFloor']['u_value'].to_f
							target_reflectance['Floor'] = space_type_const_properties['ExteriorFloor']['reflectance'].to_f
						when 'ExteriorWindow'

							target_u_value_ip['ExteriorWindow'] = space_type_const_properties['ExteriorWindow']['u_value'].to_f
							target_shgc['ExteriorWindow'] = space_type_const_properties['ExteriorWindow']['shgc'].to_f
						else
							raise intended_surface_type
						end




						#target_r_value_ip['Door'] = 1.0 / space_type_const_properties['ExteriorDoor']['u_value'].to_f
						#target_reflectance['Door'] = space_type_const_properties['ExteriorDoor']['reflectance'].to_f

						#target_u_value_ip['OperableWindow'] = space_type_const_properties['ExteriorWindow']['u_value'].to_f
						#target_shgc['OperableWindow'] = space_type_const_properties['ExteriorWindow']['shgc'].to_f
						#target_u_value_ip['Skylight'] = space_type_const_properties['Skylight']['u_value'].to_f
						#target_shgc['Skylight'] = space_type_const_properties['Skylight']['shgc'].to_f
						### get construction from resource osm
						
						min_pass = 0.05
						max_pass = 0.05

						if intended_surface_type != "ExteriorWindow"
							### Checking non subsurfaces (NOT windows)

							# don't use intened surface type of construction, look map based on surface type and boundary condition

								# currently only used for surfaces with outdoor boundary condition

							film_coefficients_r_value = @standard.film_coefficients_r_value(intended_surface_type, includes_int_film = true, includes_ext_film = true)
		
							thermal_conductance = construction.thermalConductance.get
							r_value_with_film = 1 / thermal_conductance + film_coefficients_r_value
							source_units = 'm^2*K/W'
							target_units = 'ft^2*h*R/Btu'
							r_value_ip = OpenStudio.convert(r_value_with_film, source_units, target_units).get
							solar_reflectance = construction.to_LayeredConstruction.get.layers[0].to_OpaqueMaterial.get.solarReflectance .get # TODO: - check optional first does what happens with ext. air wall
				
							# stop if didn't find values (0 or infinity)
							next if target_r_value_ip[intended_surface_type] == 0.0
							next if target_r_value_ip[intended_surface_type] == Float::INFINITY
				
							# check r avlues
							if r_value_ip < target_r_value_ip[intended_surface_type] * (1.0 - min_pass)
								report.write(" #{default_tag} -- R value of #{r_value_ip.round(2)} (#{target_units}) for #{construction.name} in  is more than #{min_pass * 100} % below the expected value of #{target_r_value_ip[intended_surface_type].round(2)} (#{target_units}) for #{target_standard}.\n")
							elsif r_value_ip > target_r_value_ip[intended_surface_type] * (1.0 + max_pass)
								report.write(" #{default_tag} -- R value of #{r_value_ip.round(2)} (#{target_units}) for #{construction.name} in is more than #{max_pass * 100} % above the expected value of #{target_r_value_ip[intended_surface_type].round(2)} (#{target_units}) for #{target_standard}.\n")
							end
				
							# check solar reflectance
							if (solar_reflectance < target_reflectance[intended_surface_type] * (1.0 - min_pass)) && (target_standard != 'ICC IECC 2015')
								report.write(" #{default_tag} -- Solar Reflectance of #{(solar_reflectance * 100).round} % for #{construction.name} in  is more than #{min_pass * 100} % below the expected value of #{(target_reflectance[intended_surface_type] * 100).round} %.\n")
							elsif (solar_reflectance > target_reflectance[intended_surface_type] * (1.0 + max_pass)) && (target_standard != 'ICC IECC 2015')
								report.write("#{default_tag} -- Solar Reflectance of #{(solar_reflectance * 100).round} % for #{construction.name} in  is more than #{max_pass * 100} % above the expected value of #{(target_reflectance[intended_surface_type] * 100).round} %.\n")
							end

							r_value_in_name = construction_name.split(" ").grep(/R-/)[0].split("-")[1].to_f

							if !r_value_in_name.is_a? Numeric then report.write("Could not get R-value from construction name of "+ construction.name + "something is wrong with SPEED DATA conversions") end
								
	
							if r_value_ip < r_value_in_name * (1.0 - 0.05)
								#flags <<  "SPEED construction library issue : c : R value of #{r_value_ip.round(2)} for #{construction.name} which is for #{intended_surface_type_standards} in all space types (building level) is more than #{0.05 * 100} % below the expected value of the R-value in the name of the construction of #{r_value_in_name} for surface"
								report.write(" #{default_tag} -- SPEED construction library issue : c : R value of #{r_value_ip.round(2)} for #{construction.name} which is for #{intended_surface_type} in all space types (building level) is more than #{0.05 * 100} % below the expected value of the R-value in the name of the construction of #{r_value_in_name} for surface \n")
							elsif r_value_ip > r_value_in_name * (1.0 + 0.05)
								#flags << "SPEED construction library issue : #{intended_surface_type_standards.upcase} : R value of #{r_value_ip.round(2)} for #{construction.name} which is for #{intended_surface_type_standards} in all space types (building level) is more than #{0.05 * 100} % below the expected value of the R-value in the name of the construction of #{r_value_in_name} for surface"
								report.write(" #{default_tag} -- SPEED construction library issue : #{intended_surface_type.upcase} : R value of #{r_value_ip.round(2)} for #{construction.name} which is for #{intended_surface_type} in all space types (building level) is more than #{0.05 * 100} % below the expected value of the R-value in the name of the construction of #{r_value_in_name} for surface \n")
							end
							### Checking windows

						else
							## Checking windows

							source_units = 'W/m^2*K'
							target_units = 'Btu/ft^2*h*R'


							u_factor_si = @standard.construction_calculated_u_factor(construction.to_LayeredConstruction.get.to_Construction.get)

							if u_factor_si.nil?
								#binding.pry
								report.write("Could not get u-factor for #{construction_name} as model has no sql file containing results -- skipping checks for this construction\n")
								next
							end

							u_factor_ip = OpenStudio.convert(u_factor_si, source_units, target_units).get

							shgc = @standard.construction_calculated_solar_heat_gain_coefficient(construction.to_LayeredConstruction.get.to_Construction.get)

							next if target_u_value_ip['ExteriorWindow'] == 0.0
							next if target_u_value_ip['ExteriorWindow'] == Float::INFINITY

							r_value_ip = OpenStudio.convert(r_value_with_film, source_units, target_units).get
							solar_reflectance = construction.to_LayeredConstruction.get.layers[0].to_OpaqueMaterial.get.solarReflectance.get # TODO: - check optional first does what happens with ext. air wall
			
							# stop if didn't find values (0 or infinity)
							next if target_r_value_ip['ExteriorWindow'] == 0.0
							next if target_r_value_ip['ExteriorWindow'] == Float::INFINITY
			
							if u_factor_ip < target_u_value_ip['ExteriorWindow'] * (1.0 - min_pass)
								#flags << "EXTERIOR WINDOW " +message + "U value of #{u_factor_ip.round(2)} (#{target_units}) for #{construction.name} in at  is more than #{min_pass * 100} % below the expected value of #{target_u_value_ip['ExteriorWindow'].round(2)} (#{target_units}) for #{display_standard}."
								report.write("#{default_tag} -- EXTERIOR WINDOW " +message + "U value of #{u_factor_ip.round(2)} (#{target_units}) for #{construction.name} in at  is more than #{min_pass * 100} % below the expected value of #{target_u_value_ip['ExteriorWindow'].round(2)} (#{target_units}) for #{display_standard}.\n")
							else u_factor_ip > target_u_value_ip['ExteriorWindow'] * (1.0 + max_pass)
								
								report.write("#{default_tag} -- EXTERIOR WINDOW " + message+ "U value of #{u_factor_ip.round(2)} (#{target_units}) for #{construction.name} in at  is more than #{max_pass * 100} % above the expected value of #{target_u_value_ip['ExteriorWindow'].round(2)} (#{target_units}) for #{display_standard}.\n")
							end

							# check shgc
							if shgc < target_shgc['ExteriorWindow'] * (1.0 - min_pass)
								#flags << "EXTERIOR WINDOW " + message + "SHGC of #{shgc.round(2)} % for #{construction.name} in at  is more than #{min_pass * 100} % below the expected value of #{target_shgc['ExteriorWindow'].round(2)} %."
								report.write("#{default_tag} -- EXTERIOR WINDOW " + message + "SHGC of #{shgc.round(2)} % for #{construction.name} in at  is more than #{min_pass * 100} % below the expected value of #{target_shgc['ExteriorWindow'].round(2)} %.\n")
							else shgc > target_shgc['ExteriorWindow'] * (1.0 + max_pass)
								#flags << "EXTERIOR WINDOW " +message + "SHGC of #{shgc.round(2)} % for #{construction.name} in at  is more than #{max_pass * 100} % above the expected value of #{target_shgc['ExteriorWindow'].round(2)} %."
								report.write("#{default_tag} -- EXTERIOR WINDOW " +message + "SHGC of #{shgc.round(2)} % for #{construction.name} in at  is more than #{max_pass * 100} % above the expected value of #{target_shgc['ExteriorWindow'].round(2)} %.\n")
							end

							# Check U-values and SHGC vs values in name

							#binding.pry

							#!r_value_in_name.is_a? Numeric then raise "Could not get R-value from construction name of "+surface_detail[:construction].name.get end

							u_value_in_name = construction.name.get.split(" ").grep(/U-/)[0].split("-")[1].to_f
							if !u_value_in_name.is_a? Numeric then raise "Could not get U-value from construction name of "+construction.name.get end

							if u_factor_ip < u_value_in_name * (1.0 - 0.05)
								report.write("#{default_tag} -- EXTERIOR WINDOW " +"R value of #{u_factor_ip.round(2)} ( for #{construction.name} which is for exterior windows in  is more than #{0.05 * 100} % below the expected value of the U-value in the name of the construction .\n")
							else u_factor_ip > u_value_in_name * (1.0 + 0.05)
								report.write("#{default_tag} -- EXTERIOR WINDOW " +"U value of #{u_factor_ip.round(2)} ( for #{construction.name} which is for exterior windows in  is more than #{0.05 * 100} % below the expected value of the U-value in the name of the construction .\n")
							end
						
							shgc_in_name = sub_surface_detail[:construction].name.get.split(" ").grep(/SHGC/)[0].split("-")[1].to_f
							if !shgc_in_name.is_a? Numeric then raise "Could not get shgc from construction name of "+sub_surface_detail[:construction].name.get end
							#surface_detail[:construction].name.get

							if shgc < shgc_in_name * (1.0 - 0.05)
								report.write("#{default_tag} -- EXTERIOR WINDOW " +"SHGC of #{shgc.round(2)} ( for #{construction.name} which is for exterior windows in  is more than #{0.05 * 100} % below the expected value of the SHGC value in the name of the construction .\n")
							else shgc > shgc_in_name * (1.0 + 0.05)
								report.write("#{default_tag} -- EXTERIOR WINDOW " +"SHGC of #{shgc.round(2)} ( for #{construction.name} which is for exterior windows in  is more than #{0.05 * 100} % below the expected value of the SHGC value in the name of the construction .\n")
							end
						end
					end
						
				end
			end
		end
	end
end
#binding.pry
report.write("\n")
report.write("Number of constructions reviewed #{count} number of constructions with issues raised .\n")

