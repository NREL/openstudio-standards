
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
  def define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template

    when 'NECB 2011'
      sch = 'C'
      space_type_map = {
        'Retail - sales' => ['LGstore1', 'LGstore2', 'SMstore1', 'SMstore2', 'SMstore3', 'SMstore4', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8']
      }
    else
      space_type_map = {
        'Strip mall - type 1' => ['LGstore1', 'SMstore1'],
        'Strip mall - type 2' => ['SMstore2', 'SMstore3', 'SMstore4'],
        'Strip mall - type 3' => ['LGstore2', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8']
      }
    end
    return space_type_map
  end

  def define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_1',
        'space_names' => ['LGSTORE1'],
        'hvac_op_sch_index' => 1
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_2',
        'space_names' => ['SMstore1'],
        'hvac_op_sch_' => 1
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_3',
        'space_names' => ['SMstore2'],
        'hvac_op_sch_index' => 2
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_4',
        'space_names' => ['SMstore3'],
        'hvac_op_sch_index' => 2
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_5',
        'space_names' => ['SMstore4'],
        'hvac_op_sch_index' => 2
      }, {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_6',
        'space_names' => ['LGSTORE2'],
        'hvac_op_sch_index' => 3
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_7',
        'space_names' => ['SMstore5'],
        'hvac_op_sch_index' => 3
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_8',
        'space_names' => ['SMstore6'],
        'hvac_op_sch_index' => 3
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_9',
        'space_names' => ['SMstore7'],
        'hvac_op_sch_index' => 3
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_10',
        'space_names' => ['SMstore8']
      }
    ]
    return system_to_space_map
  end

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    system_to_space_map = define_hvac_system_map(building_type, template, climate_zone)

    # Add infiltration door opening
    # Spaces names to design infiltration rates (m3/s)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      door_infiltration_map = { ['LGstore1', 'LGstore2'] => 0.388884328,
                                ['SMstore1', 'SMstore2', 'SMstore3', 'SMstore4', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8'] => 0.222287037 }

      door_infiltration_map.each_pair do |space_names, infiltration_design_flowrate|
        space_names.each do |space_name|
          space = getSpaceByName(space_name).get
          # Create the infiltration object and hook it up to the space type
          infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(self)
          infiltration.setName("#{space_name} Door Open Infiltration")
          infiltration.setSpace(space)
          infiltration.setDesignFlowRate(infiltration_design_flowrate)
          infiltration_schedule = add_schedule('RetailStripmall INFIL_Door_Opening_SCH')
          if infiltration_schedule.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Can't find schedule (RetailStripmall INFIL_Door_Opening_SCH).")
            return false
          else
            infiltration.setSchedule(infiltration_schedule)
          end
        end
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')
    return true
  end # add hvac

  def update_waterheater_loss_coefficient(template)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
      getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.205980747)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.205980747)
      end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input)
    update_waterheater_loss_coefficient(template)

    return true
  end
end
