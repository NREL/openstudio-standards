require "#{File.dirname(__FILE__)}/btap"


class OpenStudio::Model::Construction
  #This method will search through the layers and find the layer with the
  #lowest conductance and set that as the insulation layer. Note: Concrete walls
  #or slabs with no insulation layer but with a carper will see the carpet as the
  #insulation layer.
  #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
  #@return OpenStudio::Model::Material insulation_material_layer
  def self.find_and_set_insulaton_layer()
      insulation_material_layer = nil
      #return if there is already a defined insulation layer.
      return self.insulation unless self.insulation.empty?
      #set minimum conductance to 100.0
      min_conductance = 100.0
      #loop through Layers
      self.layers.each do |layer|
        #try casting the layer to an OpaqueMaterial.
        material = nil
        material = layer.to_OpaqueMaterial.get unless layer.to_OpaqueMaterial.empty?
        material = layer.to_FenestrationMaterial.get unless layer.to_FenestrationMaterial.empty?
        #check if the cast was successful, then find the insulation layer.
        unless nil == material
          if BTAP::Resources::Envelope::Materials::get_conductance(material) < min_conductance
            #Keep track of the highest thermal resistance value.
            min_conductance = BTAP::Resources::Envelope::Materials::get_conductance(material)
            insulation_material_layer = material
            unless material.to_OpaqueMaterial.empty?
              self.setInsulation(material)
            end
          end
        end
      end
      if self.insulation.empty? and self.isOpaque
        raise ("construction #{self.name.get.to_s} insulation layer could not be set!. This occurs when a insulation layer is duplicated in the construction.")
      end
      return insulation_material_layer
  end




  #This method will create a new construction based on self and a new conductance value.
  #It will check to see if a similar construction has already been created by this method
  #if so it will return the existing construction. If you wish to keep some of the properties, enter the
  #string "default" instead of a numerical value.
  #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
  #@param model [OpenStudio::Model::Model]
  #@param construction <String>
  #@param conductance [Fixnum]
  #@return [<String]OpenStudio::Model::getConstructionByName] new_construction
  def customize(model,
                construction,
                conductance,
                solarTransmittanceatNormalIncidence = nil,
                visibleTransmittance = nil
                )

    if self.isOpaque

    minimum_resistance = 0
    name_prefix = "#{construction.handle()} U- #{conductance}"

    #Check to see if we already made one like this.
    existing_construction = OpenStudio::Model::getConstructionByName(self.model,name_prefix)
    if not existing_construction.empty?
      # if so, return existing construction
      return existing_construction.get
    end

    #create a copy
    new_construction = self.deep_copy(self.model,construction)

    #Change Construction name in clone
    new_construction.setName( name_prefix)

    if  conductance.kind_of?(Float)
      #re-find insulation layer
      find_and_set_insulaton_layer(self.model,new_construction)

      #Determine how low the resistance can be set. Subtract existing insulation
      #Values from the total resistance to see how low we can go.
      minimum_resistance = (1 / new_construction.thermalConductance.to_f) - (1.0 / new_construction.insulation.get.thermalConductance.to_f)

      #Check if the requested resistance is smaller than the minimum
      # resistance. If so, use the minimum resistance instead.
      if minimum_resistance > ( 1 / conductance )
        #tell user why we are defaulting and set the conductance of the
        # construction.
        raise ("could not set conductance of construction #{new_construction.name.to_s} to because existing layers make this impossible. Change the construction to allow for this conductance to be set." + (conductance).to_s + "setting to closest value possible value:" + (1.0 / minimum_resistance).to_s )
        # new_construction.setConductance((1.0/minimum_resistance))
      else
        unless new_construction.setConductance(conductance)
          raise("could not set conductance of construction #{new_construction.name.to_s}")
        end
      end
    end
    return new_construction
    elsif self.isFenestration()

        #get equivilant values for tsol, tvis, and conductances.
        solarTransmittanceatNormalIncidence = self.get_shgc(model, construction) if solarTransmittanceatNormalIncidence == nil
        visibleTransmittance = self.get_tvis(model,construction) if visibleTransmittance == nil
        conductance = self.get_conductance(construction) if conductance == nil
        frontSideSolarReflectanceatNormalIncidence = 1.0 - solarTransmittanceatNormalIncidence
        backSideSolarReflectanceatNormalIncidence = 1.0 - solarTransmittanceatNormalIncidence
        frontSideVisibleReflectanceatNormalIncidence = 0.081000
        backSideVisibleReflectanceatNormalIncidence = 0.081000
        infraredTransmittanceatNormalIncidence = 0.0
        frontSideInfraredHemisphericalEmissivity = 0.84
        backSideInfraredHemisphericalEmissivity = 0.84
        #store part of fenestation in array bins.
        glazing_array = Array.new()
        shading_material_array = Array.new()
        gas_array = Array.new()
        construction.layers.each do |material|
          glazing_array << material unless material.to_Glazing.empty?
          shading_material_array << material unless material.to_ShadingMaterial.empty?
          gas_array << material unless material.to_GasLayer.empty?
        end

        #set value of fictious glazing based on the fenestrations front and back if available
        unless glazing_array.first.to_StandardGlazing.empty?
          frontSideSolarReflectanceatNormalIncidence  = glazing_array.first.to_StandardGlazing.get.frontSideSolarReflectanceatNormalIncidence
          frontSideVisibleReflectanceatNormalIncidence = glazing_array.first.to_StandardGlazing.get.frontSideVisibleReflectanceatNormalIncidence
          frontSideInfraredHemisphericalEmissivity = glazing_array.first.to_StandardGlazing.get.frontSideInfraredHemisphericalEmissivity
        end

        unless glazing_array.last.to_StandardGlazing.empty?
          backSideSolarReflectanceatNormalIncidence  = glazing_array.last.to_StandardGlazing.get.backSideSolarReflectanceatNormalIncidence
          backSideVisibleReflectanceatNormalIncidence = glazing_array.last.to_StandardGlazing.get.backSideVisibleReflectanceatNormalIncidence
          backSideInfraredHemisphericalEmissivity = glazing_array.last.to_StandardGlazing.get.backSideInfraredHemisphericalEmissivity
        end
        #create fictious glazing.
        #assume a thickness of 0.10m
        thickness = 0.10
        #calculate conductivity
        conductivity = conductance * thickness
        data_name_suffix = " cond=#{("%.3f" % conductivity).to_s} tvis=#{("%.3f" % visibleTransmittance).to_s} tsol=#{("%.3f" % solarTransmittanceatNormalIncidence).to_s}"
        cons_name = "Customized Fenestration:" + data_name_suffix
        glazing_name = "Customized Fenestration::" + data_name_suffix
        #Search to prevent the massive duplication that may ensue.
        return model.getConstructionByName(cons_name).get unless model.getConstructionByName(cons_name).empty?

        #fix for Simple glazing
        conductivity = conductance
        glazing = BTAP::Resources::Envelope::Materials::Fenestration::create_simple_glazing(
            construction.model,#model
            glazing_name,  #name
            0.60,          #SHGC
            conductivity,  #u-factor
            thickness,     #Thickness
            0.21           #vis trans
        )

        new_materials_array = Array.new()
        new_materials_array << glazing
        new_materials_array.concat(shading_material_array) unless shading_material_array.empty?
        return self.create_construction(construction.model, cons_name, new_materials_array)
    end
  end



end



# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model

  def perform_load_elimination_analysis(folder = Dir.pwd)
    #remove hvac and only use ideal loads.
    model = self.clone(true).to_Model
    BTAP::Resources::HVAC::clear_all_hvac_from_model(model)
    model.getThermalZones.sort.each {|zone| zone.setUseIdealAirLoads(true)}
    conductance = 0.200
    models = Array.new()
    #Add baseline
    models << {:name => 'baseline', :model => model}
    #Add copies of model with elimination of a characteristic.
    models << {:name => 'elim_ext_wall', :model => model.clone(true).to_Model}
=begin
    models << {:name => 'elim_ext_roof', :model => model.clone(true).to_Model.set_all_ext_roof_conductances_to(conductance)}
    models << {:name => 'elim_ground_floor', :model => model.clone(true).to_Model.set_all_ground_floor_conductances_to(conductance)}
    models << {:name => 'elim_ground_wall', :model => model.clone(true).to_Model.set_all_ground_wall_conductances_to(conductance)}
    models << {:name => 'elim_win_doors', :model => model.clone(true).to_Model.set_all_ext_windows_and_door_conductances_to(conductance)}
    models << {:name => 'elim_skylights', :model => model.clone(true).to_Model.set_all_ext_skylight_conductances_to(conductance)}
    models << {:name => 'elim_people', :model => model.clone(true).to_Model.eliminate_all_people_loads}
    models << {:name => 'elim_lighting', :model => model.clone(true).to_Model.eliminate_all_lighting_loads}
    models << {:name => 'elim_plug_loads', :model => model.clone(true).to_Model.eliminate_all_electric_loads}
    models << {:name => 'elim_outdoor_air', :model => model.clone(true).to_Model.eliminate_all_design_specification_outdoor_air}
    models << {:name => 'elim_infiltration', :model => model.clone(true).to_Model.eliminate_all_space_infiltration_design_flow_rates}
    models << {:name => 'elim_all_loads', :model => model.clone(true).to_Model.eliminate_all_loads}
=end

    #Get a handle for the baseline.
    baseline = models.find {|model| model[:name] == 'baseline' }
    #Create a result hash.
    result = Hash.new()
    models.each do |model|
      #run each model in its own folder.
      success = model_run_simulation_and_log_errors(model[:model], "#{folder}/#{model[:name]}")

      #Run the qa-qc method to get all the results.

      qa_qc = BTAP::perform_qaqc(model[:model])
      #Store total energy in the hash
      model[:total_end_uses_gj_per_m2] = qa_qc[:end_uses_eui][:total_end_uses_gj_per_m2]
      #This assumes that the baseline is always the first in the hash.
      unless model[:name] = 'baseline'
        result[model[:name]] = model[:total_end_uses_gj_per_m2] / baseline[:total_end_uses_gj_per_m2]
      end
    end
    return result
  end


  # Set global changes
  def set_all_ext_wall_conductances_to(conductance)
    #Set conductances to needed values in construction set if possible.
    self.getDefaultConstructionSets.sort.each_with_index do |default_construction_set, index|
      BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(
          self,
          "Sensitivity Def Cnst Set #{index}",
          default_construction_set,
          1/conductance,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil
      )
    end
    #sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    self.getPlanarSurfaces.sort.each {|item| item.resetConstruction}
    #if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope::assign_interior_surface_construction_to_adiabatic_surfaces(self, nil)
    return self
  end

  def set_all_ext_roof_conductances_to(conductance)
    #Set conductances to needed values in construction set if possible.
    self.getDefaultConstructionSets.sort.each_with_index do |default_construction_set, index|
      BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(
          self,
          "Sensitivity Def Cnst Set #{index}",
          default_construction_set,
          nil,
          nil,
          1/conductance,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil
      )
    end
    #sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    self.getPlanarSurfaces.sort.each {|item| item.resetConstruction}
    #if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope::assign_interior_surface_construction_to_adiabatic_surfaces(self, nil)
    return self
  end

  def set_all_ground_wall_conductances_to(conductance)
    #Set conductances to needed values in construction set if possible.
    self.getDefaultConstructionSets.sort.each_with_index do |default_construction_set, index|
      BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(
          self,
          "Sensitivity Def Cnst Set #{index}",
          default_construction_set,
          nil,
          nil,
          nil,
          1/conductance,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil
      )
    end
    #sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    self.getPlanarSurfaces.sort.each {|item| item.resetConstruction}
    #if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope::assign_interior_surface_construction_to_adiabatic_surfaces(self, nil)
    return self
  end

  def set_all_ground_floor_conductances_to(conductance)
    #Set conductances to needed values in construction set if possible.
    self.getDefaultConstructionSets.sort.each_with_index do |default_construction_set, index|
      BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(
          self,
          "Sensitivity Def Cnst Set #{index}",
          default_construction_set,
          nil,
          nil,
          nil,
          nil,
          1/conductance,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil
      )
    end
    #sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    self.getPlanarSurfaces.sort.each {|item| item.resetConstruction}
    #if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope::assign_interior_surface_construction_to_adiabatic_surfaces(self, nil)
    return self
  end

  def set_all_ext_windows_and_door_conductances_to(conductance)
    #Set conductances to needed values in construction set if possible.
    self.getDefaultConstructionSets.sort.each_with_index do |default_construction_set, index|
      BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(
          self,
          "Sensitivity Def Cnst Set #{index}",
          default_construction_set,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          1/conductance,
          nil,
          nil,
          1/conductance,
          nil,
          nil,
          1/conductance,
          1/conductance,
          nil,
          nil,
          1/conductance,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil
      )
    end
    #sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    self.getPlanarSurfaces.sort.each {|item| item.resetConstruction}
    #if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope::assign_interior_surface_construction_to_adiabatic_surfaces(self, nil)
    return self
  end

  def set_all_ext_skylight_conductances_to(conductance)
    #Set conductances to needed values in construction set if possible.
    self.getDefaultConstructionSets.sort.each_with_index do |default_construction_set, index|
      BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(
          self,
          "Sensitivity Def Cnst Set #{index}",
          default_construction_set,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          1/conductance,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil
      )
    end
    #sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    self.getPlanarSurfaces.sort.each {|item| item.resetConstruction}
    #if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope::assign_interior_surface_construction_to_adiabatic_surfaces(self, nil)
    return self
  end

  #This method will set the infiltration magnitude.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param self [OpenStudio::model::Model] A model object
  #@param setDesignFlowRate [Float]
  #@param setFlowperSpaceFloorArea [Float]
  #@param setFlowperExteriorSurfaceArea [Float]
  #@param setAirChangesperHour [Float]
  #@return [String] table
  def set_all_inflitration_rates(setDesignFlowRate,
                                 setFlowperSpaceFloorArea,
                                 setFlowperExteriorSurfaceArea,
                                 setAirChangesperHour)

    table = "name,infiltration_method,infiltration_design_flow_rate,infiltration_flow_per_space,infiltration_flow_per_exterior_area,infiltration_air_changes_per_hour\n"
    self.getSpaceInfiltrationDesignFlowRates.sort.each do |infiltration_load|
      infiltration_load.setAirChangesperHour(setAirChangesperHour) unless setAirChangesperHour.nil?
      infiltration_load.setDesignFlowRate(setDesignFlowRate) unless setDesignFlowRate.nil?
      infiltration_load.setFlowperSpaceFloorArea(setFlowperSpaceFloorArea) unless setFlowperSpaceFloorArea.nil?
      infiltration_load.setFlowperExteriorSurfaceArea(setFlowperExteriorSurfaceArea) unless setFlowperExteriorSurfaceArea.nil?
      table << infiltration_load.name.get.to_s << ","
      table << infiltration_load.designFlowRateCalculationMethod << ","
      infiltration_load.airChangesperHour.empty? ? ach = "NA" : ach = infiltration_load.airChangesperHour.get
      infiltration_load.designFlowRate.empty? ? dfr = "NA" : dfr = infiltration_load.designFlowRate.get
      infiltration_load.flowperSpaceFloorArea.empty? ? fsfa = "NA" : fsfa = infiltration_load.flowperSpaceFloorArea.get
      infiltration_load.flowperExteriorSurfaceArea.empty? ? fesa = "NA" : fesa = infiltration_load.flowperExteriorSurfaceArea.get
      table << "#{ach},#{dfr},#{fsfa},#{fesa}\n"
    end
    return table
  end

  #Scale Global Changes
  def scale_all_people_loads(factor)
    self.getPeoples.sort.each do |item|
      item.setMultiplier(item.multiplier * factor)
    end
  end

  #This method will scale people loads schedule.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param a_coef [Float]
  #@param b_coef [Float]
  #@param c_coef [Float]
  #@param time_shift [Float]
  #@param time_sign [Float]
  def scale_people_loads_schedule(a_coef,
                                  b_coef,
                                  c_coef,
                                  time_shift = nil,
                                  time_sign = nil)
    model.getPeoples.sort.each do |item|
      #Do an in-place modification of the schedule.
      BTAP::Resources::Schedules::modify_schedule!(self, item.schedule, a_coef, b_coef, c_coef, time_shift, time_sign)
    end
  end

  #This method will scale lighting loads.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param factor [Float]
  def scale_lighting_loads(factor)
    self.getLightss.sort.each do |item|
      item.setMultiplier(item.multiplier * factor)
    end
  end

  #This method will scale lighting loads schedule.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param a_coef [Float]
  #@param b_coef [Float]
  #@param c_coef [Float]
  #@param time_shift [Float]
  #@param time_sign [Float]
  def scale_lighting_loads_schedule(a_coef,
                                    b_coef,
                                    c_coef,
                                    time_shift = nil,
                                    time_sign = nil)
    model.getLightss.sort.each do |item|
      #Do an in-place modification of the schedule.
      BTAP::Resources::Schedules::modify_schedule!(self, item.schedule, a_coef, b_coef, c_coef, time_shift, time_sign)
    end
  end

  #This method will scale electrical loads.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param factor [Float]
  def scale_electrical_loads(model, factor)
    self.getElectricEquipments.sort.each do |item|
      item.setMultiplier(item.multiplier * factor)
    end
  end

  #This method will scale electrical loads schedule.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param a_coef [Float]
  #@param b_coef [Float]
  #@param c_coef [Float]
  #@param time_shift [Float]
  #@param time_sign [Float]
  def scale_electrical_loads_schedule(a_coef,
                                      b_coef,
                                      c_coef,
                                      time_shift = nil,
                                      time_sign = nil)
    self.getElectricEquipments.sort.each do |item|
      BTAP::Resources::Schedules::modify_schedule!(self, item.schedule, a_coef, b_coef, c_coef, time_shift, time_sign)
    end
  end

  #This method will scale Outdoor Air loads.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param factor [Float]
  def scale_oa_loads(factor)
    self.getDesignSpecificationOutdoorAirs.sort.each do |oa_def|
      oa_def.setOutdoorAirFlowperPerson(oa_def.outdoorAirFlowperPerson * factor) unless oa_def.isOutdoorAirFlowperPersonDefaulted
      oa_def.setOutdoorAirFlowperFloorArea(oa_def.outdoorAirFlowperFloorArea * factor) unless oa_def.isOutdoorAirFlowperFloorAreaDefaulted
      oa_def.setOutdoorAirFlowRate(oa_def.outdoorAirFlowRate * factor) unless oa_def.isOutdoorAirFlowRateDefaulted
      oa_def.setOutdoorAirFlowAirChangesperHour(oa_def.outdoorAirFlowAirChangesperHour * factor) unless oa_def.isOutdoorAirFlowAirChangesperHourDefaulted
    end
  end

  #This method will scale infiltration loads.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param factor [Float]
  def scale_inflitration_loads(factor)
    self.getSpaceInfiltrationDesignFlowRates.sort.each do |infiltration_load|
      infiltration_load.setDesignFlowRate(infiltration_load.designFlowRate.get * factor) unless infiltration_load.designFlowRate.empty?
      infiltration_load.setFlowperSpaceFloorArea(infiltration_load.flowperSpaceFloorArea.get * factor) unless infiltration_load.flowperSpaceFloorArea.empty?
      infiltration_load.setFlowperExteriorSurfaceArea(infiltration_load.flowperExteriorSurfaceArea.get * factor) unless infiltration_load.flowperExteriorSurfaceArea.empty?
      infiltration_load.setAirChangesperHour(infiltration_load.airChangesperHour.get * factor) unless infiltration_load.airChangesperHour.empty?
    end
  end

  # Elimination Methods
  #This method removes people loads from the model.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  def eliminate_all_people_loads()
    self.getPeoples.sort.each {|people| people.remove}
    self.getPeopleDefinitions.sort.each {|people| people.remove}
    return self
  end

  #This method removes light loads from model.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  def eliminate_all_lighting_loads()
    self.getLightss.sort.each {|item| item.remove}
    self.getLightsDefinitions.sort.each {|item| item.remove}
    return self
  end

  #This method removes elec loads from model.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  def eliminate_all_electric_loads()
    self.getElectricEquipments.sort.each {|item| item.remove}
    self.getElectricEquipmentDefinitions.sort.each {|item| item.remove}
    return self
  end

  #This method removes all design specification OA from model.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  def eliminate_all_design_specification_outdoor_air()
    self.getDesignSpecificationOutdoorAirs.sort.each {|item| item.remove}
    return self
  end

  #This method removes infiltration from model..
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  def eliminate_all_space_infiltration_design_flow_rates()
    self.getSpaceInfiltrationDesignFlowRates.sort.each {|item| item.remove}
    return self
  end

  #This method removes all space loads from model.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  def eliminate_all_loads()
    conductance = 0.200

    #self.set_all_ext_wall_conductances_to(conductance)
    #self.set_all_ext_roof_conductances_to(conductance)
    #self.set_all_ground_floor_conductances_to(conductance)
    #self.set_all_ground_wall_conductances_to(conductance)
    #self.set_all_ext_windows_and_door_conductances_to(conductance)
    #self.set_all_ext_skylight_conductances_to(conductance)
    self.eliminate_all_people_loads
    self.eliminate_all_lighting_loads
    self.eliminate_all_electric_loads
    self.eliminate_all_design_specification_outdoor_air
    self.eliminate_all_space_infiltration_design_flow_rates
    self.eliminate_all_space_infiltration_design_flow_rates
    return self
  end

end

# open the class to add methods to size all HVAC equipment

class OpenStudio::Model::Space
  def get_average_height()
    roof_datum = 0
    total_roof_area = 0
    floor_datum = 0
    total_floor_area = 0
    average_height = 0
    #create a model to create a planar object.. Hopefully garbage collection deals with this right.
    temp_model =  OpenStudio::Model::Model.new()
    self.surfaces.each do |surface|
      projected_vertices = Array.new()
      if surface.surfaceType == "Floor"
        average_surface_height = 0
        surface.vertices.each do |point3d|
          average_surface_height += point3d.z / surface.vertices.size
          projected_vertices << OpenStudio::Point3d.new(point3d.x, point3d.y, 0)
        end
        projected_surface_area =  OpenStudio::Model::Surface.new(projected_vertices ,temp_model).grossArea
        total_roof_area += projected_surface_area
        floor_datum += average_surface_height * projected_surface_area
      elsif surface.surfaceType == "RoofCeiling"
        average_surface_height = 0
        surface.vertices.each do |point3d|
          average_surface_height += point3d.z / surface.vertices.size
          projected_vertices << OpenStudio::Point3d.new(point3d.x, point3d.y, 0)
        end
        projected_surface_area =  OpenStudio::Model::Surface.new(projected_vertices ,temp_model).grossArea
        total_roof_area += projected_surface_area
        roof_datum += average_surface_height * projected_surface_area
      end
    end
    if total_floor_area > 0 and total_roof_area > 0
      average_height = roof_datum / total_roof_area - floor_datum / total_floor_area
    end
    return average_height
  end
end
