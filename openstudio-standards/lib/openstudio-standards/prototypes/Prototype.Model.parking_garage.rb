# open the class to add pouplate loads and HVAC for parking garages and parking lots
class OpenStudio::Model::Model

  # todo - initially support whole building parking garage, but try to setup so ParkingGarage and be used as buildinging type component on mixed use building.

  # todo - replace 405 ft^2 with lookup from standards json

  # Add loads and ventilation to parking garages and parking lots
  #
  # @param building_type_hash [Hash] key is building type, value is fraction of garage used for this building type. This will impact schedules for garage
  # @param floor_area_per_spot [Double] used to calculate how many spots are in garage. this value should include impact of circulation and other non-parking area/ 405 ft^2 default is from parking tab of OpenStudio standards
  # @param covered_top_story[Bool] flag for top story covered will impact how lighting is applied, maybe infer this from geometry tha tis passed in
  # @Param fraction_spots_charging [Double] will determine plug load for car charging
  # @Param fraction_ext_walls_open [Double] can impact
  # @Param diversity_factor [Double] not sure if this method needs this? it woudl be used when testing if garage has enough capacity for a collection of buildings it serves. Maybe would have impact on load schedules?
  # @return [Hash] newly added objects where keys are load type, and value is an array of objects
  def add_typical_parking_garage(building_type_hash = nil,floor_area_per_spot = 405.0,rooftop_parking = true,fraction_spots_charging = 0.05,fraction_ext_walls_open = 1.0 ,diversity_factor = 1.0, add_loads = true, add_constructions = true, add_infil = true, add_hvac = true)

    # todo - try and move most code like constructions and LPD, EPD to those methods in standards. Even elevators and some ext lights can be moved.  Maybe this measure can also call those method in case it is used by itself without the other methods from create typical moodel being run. Schedules may have to be here, since they may be dynamically generated from other buildng types.

    new_objects = {}
    new_objects[:lights] = []
    new_objects[:ext_lights] = []
    new_objects[:elec_equip] = []

    # determine store number of parking spots
    garage_structure_floor_area = 0.0
    garage_additional_floor_area = 0.0
    # todo - it is a little confusing now if rootop parking is determined by flag and ext roof, or by stub exterior lights object with area defined in ft^2 by multiplier. Don't think I want it done both ways.
    if rooftop_parking == true
      # add area for exterior roof area of spaces with ParkingGarage space type
      self.getSpaceTypes.each do |space_type|
        next if not space_type.standardsBuildingType.is_initialized and ["ParkingGarage","Parking garage "].include?(space_type.standardBuildingType.get)

        # update floor area
        garage_structure_floor_area += space_type.floorArea

        # loop through spaces gathering area of exterior roof surfaces
        space_type.spaces.each do |space|
          space.surfaces.each do |surface|
            next if not surface.surfaceType == "RoofCeiling" and surface.outsideBoundaryCondition == "Outdoors"
            garage_additional_floor_area += surface.netArea * space.multiplier #typically multiplier will be 1, but could be exceptions
          end
        end
      end

    end

    # setup for charger
    # this are rough numbers for draw per charger for various classes, should be verified or setup as argument
    # todo - create argument to choose class or directly expose design level
    charger_class_one = 1400.0 # W
    charger_class_two = 5000.0 # W
    charger_class_three = 75000.0 # W
    charger_super = 120000.0 # W

    # create charger def if fraction is > 0
    default_charger_type = charger_class_two
    if fraction_spots_charging > 0.0
      car_charge_def = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
      car_charge_def.setDesignLevel(default_charger_type)
      car_charge_def.setName("EV charger")
    end

    # alter exterior lights if necessary
    # note: models passed in should have a stub exterior lights object with one of these names, and with the multiplier set ot the ft^2 of parking. This is the parking lot or rooftop parking equivalent to geometry.
    valid_names = ["Garage Rooftop Parking","Dedicated Surface Parking"]
    self.getFacility.exteriorLights.each do |ext_light|
      test_names = [ext_light.name,ext_light.endUseSubcategory]
      next if not (valid_names & test_names).size > 0

      # alter def
      ext_lights_def = ext_light.exteriorLightsDefinition
      ext_lights_def.setName("#{ext_light.name} Def (W/ft^2)")
      # todo - set real value
      ext_lights_def.setDesignLevel(9999.0)
      # todo - set schedule
      # todo - set control
      new_objects[:ext_lights] << ext_light

      # log change
      OpenStudio.logFree(OpenStudio::Info, 'Prototype.Model.parking_garage', "Found #{ext_light.name} in model, updating schedule and control, and setting definition to #{ext_lights_def.designLevel} W/ft^2 for #{ext_light.multiplier} ft^2.")

      # update garage_additional_floor_area
      puts "hello #{ext_light.name}, #{ext_light.multiplier}"
      # todo - I'm double counting area for garage with rooftop since it has both ext roofs and flag set plus existing ext lights ojbect.
      surface_parking_si = OpenStudio::convert(ext_light.multiplier,"ft^2","m^2").get
      garage_additional_floor_area += surface_parking_si

      # todo - garage (but not dedicated surface parking) should have facade and walkway lighting


      # todo - add general plug load for rooftop or surface parking (probably no plug loads for surface parking unless security cameras?)


      if fraction_spots_charging > 0.0

        # add EV charging
        ext_charging_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
        ext_charging_def.setName("EV charger Surface or Roof Def (W)")
        ext_charging_def.setDesignLevel(default_charger_type)

        # create ext light inst (for EV charging)
        # todo - create real schedule
        ext_charging_sch_other = self.alwaysOnDiscreteSchedule
        ext_charging = OpenStudio::Model::ExteriorLights.new(ext_charging_def,ext_charging_sch_other)
        ext_charging.setName("EV charger Surface or Roof")
        ext_charging.setControlOption("ScheduleNameOnly")
        ext_charging.setEndUseSubcategory("EV charger Surface or Roof")
        # todo - set multiplier
        new_objects[:ext_lights] << ext_light

        # update log
        OpenStudio.logFree(OpenStudio::Info, 'Prototype.Model.parking_garage', "Adding #{ext_charging.multiplier.round(1)} #{default_charger_type} W EV chargers to roof or surface parking.")


      end

    end

    # loop through space types
    self.getSpaceTypes.each do |space_type|
      next if not space_type.standardsBuildingType.is_initialized and ["ParkingGarage","Parking garage "].include?(space_type.standardBuildingType.get)


      # todo - should constructions be somewhere else


      # add lights (excludes surface parking and rooftop parking lights)
      # todo - set real value
      space_type.setLightingPowerPerFloorArea(9999.0)
      new_objects[:lights] << space_type.lights.first


      # add misc plug loads (not including charging)
      # todo - set real value
      space_type.setElectricEquipmentPowerPerFloorArea(9999.0)
      new_objects[:elec_equip] << space_type.electricEquipment.first


      # add charging stations
      if fraction_spots_charging > 0.0
        space_type_charger_count = 0
        space_type.spaces.each do |space|
          car_charge_inst = OpenStudio::Model::ElectricEquipment.new(car_charge_def)
          car_charge_inst.setSpaceType(space_type)
          floor_area_ip = OpenStudio::convert(space.floorArea,"m^2","ft^2").get
          car_charge_inst.setMultiplier(fraction_spots_charging * space.multiplier * floor_area_ip/floor_area_per_spot)
          # todo - set schedule
          new_objects[:elec_equip] << car_charge_inst

          # update counter
          space_type_charger_count += car_charge_inst.multiplier

        end

        # update log
        OpenStudio.logFree(OpenStudio::Info, 'Prototype.Model.parking_garage', "Adding #{space_type_charger_count.round(1)} #{car_charge_def.designLevel} W EV chargers to #{space_type.name} space type.")

      end

      # todo - add elevators (not valid for parking, would have elevators in stand alone or mixed use)


      # todo - add infiltration


      # todo - add design spec OA


      # todo - add schedules ot internal loads


      # todo - add ventilation

    end

    # general log about garage, garage roof, and surface parking
    garage_structure_floor_area_ip = OpenStudio::convert(garage_structure_floor_area,"m^2","ft^2").get
    garage_additional_floor_area_ip = OpenStudio::convert(garage_additional_floor_area,"m^2","ft^2").get
    number_of_spots = ((garage_structure_floor_area_ip + garage_additional_floor_area_ip)/floor_area_per_spot).to_i
    OpenStudio.logFree(OpenStudio::Info, 'Prototype.Model.parking_garage', "Building has #{garage_structure_floor_area_ip.round} ft^2 of structure parking plus #{garage_additional_floor_area_ip.round} additional ft^2 at #{floor_area_per_spot} ft^2/spot results in #{number_of_spots} parking spots.")


    return new_objects
  end


end