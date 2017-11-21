class NECB2011
  def apply_standard_lights(set_lights, space_type, space_type_properties)
    lights_have_info = false
    lighting_per_area = space_type_properties['lighting_per_area'].to_f
    lighting_per_person = space_type_properties['lighting_per_person'].to_f
    lights_frac_to_return_air = space_type_properties['lighting_fraction_to_return_air'].to_f
    lights_frac_radiant = space_type_properties['lighting_fraction_radiant'].to_f
    lights_frac_visible = space_type_properties['lighting_fraction_visible'].to_f
    lights_frac_replaceable = space_type_properties['lighting_fraction_replaceable'].to_f
    lights_have_info = true unless lighting_per_area.zero?
    lights_have_info = true unless lighting_per_person.zero?

    if set_lights && lights_have_info

      # Remove all but the first instance
      instances = space_type.lights.sort
      if instances.size.zero?
        definition = OpenStudio::Model::LightsDefinition.new(space_type.model)
        definition.setName("#{space_type.name} Lights Definition")
        instance = OpenStudio::Model::Lights.new(definition)
        instance.setName("#{space_type.name} Lights")
        instance.setSpaceType(space_type)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} had no lights, one has been created.")
        instances << instance
      elsif instances.size > 1
        instances.each_with_index do |inst, i|
          next if i.zero?
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{inst.name} from #{space_type.name}.")
          inst.remove
        end
      end

      # Modify the definition of the instance
      space_type.lights.sort.each do |inst|
        definition = inst.lightsDefinition
        unless lighting_per_area.zero?
          occ_sens_lpd_frac = 1.0
          # NECB 2011 space types that require a reduction in the LPD to account for
          # the requirement of an occupancy sensor (8.4.4.6(3) and 4.2.2.2(2))
          reduce_lpd_spaces = ['Classroom/lecture/training', 'Conf./meet./multi-purpose', 'Lounge/recreation',
                             'Conf./meet./multi-purpose', 'Washroom-sch-A', 'Washroom-sch-B', 'Washroom-sch-C', 'Washroom-sch-D',
                             'Washroom-sch-E', 'Washroom-sch-F', 'Washroom-sch-G', 'Washroom-sch-H', 'Washroom-sch-I',
                             'Dress./fitt. - performance arts', 'Locker room', 'Locker room-sch-A', 'Locker room-sch-B',
                             'Locker room-sch-C', 'Locker room-sch-D', 'Locker room-sch-E', 'Locker room-sch-F', 'Locker room-sch-G',
                             'Locker room-sch-H', 'Locker room-sch-I', 'Retail - dressing/fitting']
          if reduce_lpd_spaces.include?(space_type.standardsSpaceType.get)
            # Note that "Storage area", "Storage area - refrigerated", "Hospital - medical supply" and "Office - enclosed"
            # LPD should only be reduced if their space areas are less than specific area values.
            # This is checked in a space loop after this function in the calling routine.
            occ_sens_lpd_frac = 0.9
          end
          definition.setWattsperSpaceFloorArea(OpenStudio.convert(lighting_per_area.to_f * occ_sens_lpd_frac, 'W/ft^2', 'W/m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set LPD to #{lighting_per_area} W/ft^2.")
        end
        unless lighting_per_person.zero?
          definition.setWattsperPerson(OpenStudio.convert(lighting_per_person.to_f, 'W/person', 'W/person').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set lighting to #{lighting_per_person} W/person.")
        end
        unless lights_frac_to_return_air.zero?
          definition.setReturnAirFraction(lights_frac_to_return_air)
        end
        unless lights_frac_radiant.zero?
          definition.setFractionRadiant(lights_frac_radiant)
        end
        unless lights_frac_visible.zero?
          definition.setFractionVisible(lights_frac_visible)
        end
        # unless lights_frac_replaceable.zero?
        #  definition.setFractionReplaceable(lights_frac_replaceable)
        # end
      end

      # If additional lights are specified, add those too
      additional_lighting_per_area = space_type_properties['additional_lighting_per_area'].to_f
      unless additional_lighting_per_area.zero?
        # Create the lighting definition
        additional_lights_def = OpenStudio::Model::LightsDefinition.new(space_type.model)
        additional_lights_def.setName("#{space_type.name} Additional Lights Definition")
        additional_lights_def.setWattsperSpaceFloorArea(OpenStudio.convert(additional_lighting_per_area.to_f, 'W/ft^2', 'W/m^2').get)
        additional_lights_def.setReturnAirFraction(lights_frac_to_return_air)
        additional_lights_def.setFractionRadiant(lights_frac_radiant)
        additional_lights_def.setFractionVisible(lights_frac_visible)

        # Create the lighting instance and hook it up to the space type
        additional_lights = OpenStudio::Model::Lights.new(additional_lights_def)
        additional_lights.setName("#{space_type.name} Additional Lights")
        additional_lights.setSpaceType(space_type)
      end

    end
  end
end
