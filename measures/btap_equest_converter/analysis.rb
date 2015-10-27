# *********************************************************************
# *  Copyright (c) 2008-2015, Natural Resources Canada
# *  All rights reserved.
# *
# *  This library is free software; you can redistribute it and/or
# *  modify it under the terms of the GNU Lesser General Public
# *  License as published by the Free Software Foundation; either
# *  version 2.1 of the License, or (at your option) any later version.
# *
# *  This library is distributed in the hope that it will be useful,
# *  but WITHOUT ANY WARRANTY; without even the implied warranty of
# *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# *  Lesser General Public License for more details.
# *
# *  You should have received a copy of the GNU Lesser General Public
# *  License along with this library; if not, write to the Free Software
# *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
# **********************************************************************/

module BTAP
  #Contains methods to perform multi-run analysis of a building model
  module Analysis
    module Baseline
      "NECB 2011"
    end  
    
    #A single measure that is selectable.
    module Sensitivity
      choices = [
        #Envelope Insulation
        #Wall Roof Floor Door
        #Ground Exterior
        #Direction Story
        "Ground Surfaces RSI (5-100)",
        "Ext Wall RSI (5-100)", 
        "Ext Roof RSI (5-100)",
        "Ext Floor RSI (5-100)",
        
        
        #Door, Window, Skylight
        #Direction Story
        "Glazing RSI (5-100)",
        
        #Envelope Optical (ECMs Blinds, Low E glass / Tinting)
        #Door, Window, Skylight
        #Direction Story
        "Window Solar Transmittance (0-100%)",
        "Southern Window Solar Transmittance (0-100%)",
        
        #Envelope FDWR ( Design Considerations, Daylighting ECMs , baseline must have DL sensors)
        #Direction
        "FWDR (0-98%)",
        "SRR (0-10%)",
        
        #Shading (Overhang)
        #Direction
        "Overhang Ratio (0-50%)",

        #Loads
        "Infiltration (0-200%)",           #Tightening Building ECMs
        "Ventilation (0-200%)",            #UFAD reduction potential
        "Occupants (0-200%)",              #Employee reduction / Work at home incentive / Control ECMs
        "Lighting (0-200%)",               #Lighting ECMs, Control ECMS 
        "Plug Loads (0-200%)",             #Lighting ECMs, Control ECMS 
        "Setpoint Reduction H&C (0-100%)", #Control ECMs
        
        
        #HVAC Sensitivity
        "Fan Power (0-100%)",       #Natural Ventilation, UFAD
        "HW Boiler Eff (50-300%)",  #Equipment ECMs / GSHP
        "DHW Boiler Eff (50-300%)", #Equipment ECMs /GSHP
        "Cooling COP (2.0-5.0)",    #Equipment ECMs /GSHP
        "Heating COP (2.0-5.0)",    #Equipment ECMs /GSHP
        "Fan Eff (80-200%)",        #Equipment ECMs
        "Pump Eff (80-200%)",       #Equipment ECMs
        "Fuel Type",# NaturalGas, Electric fuel switching
        
        #Existing ECMS (require costing) 
        "DCV",
        "Cold Deck Reset Control",
        "Supply Air Temperature Reset",
        "Economizers" 
      ]
    end
  

   
    
    module Parametric
      #parametric Analysis methods. Each of these methods will create a set of
      #parametric runs based on the default set in the arguments.
      #Overhangs, Thermal mass, Blind control still needs to be examined (10)
      
      #This method will do an analysis of the opaque surface conductance sensitivity and returns a string model array.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object   {http://openstudio.nrel.gov/latest-c-sdk-documentation/model}
      #@params choice [String] description
      #@return [modelArray<String>]
      def self.opaque_surface_conductance_sensitivity_analysis(model,choice )
        
        case choice
        when "Ground Surfaces"
        when "Ext Wall RSI = 100"
        when "Ext Roof RSI = 100"
        when "Ext Floor RSI = 100"
        when "Window Skylight RSI = 100" 
        when "No Window Solar Transmittance"
        when "No Southern Window Solar Transmittance"
          #Loads
        when "No Infiltration"
        when "No Ventilation"
        when "No Occupants"
        when "No Lighting"
        when "No Plug Loads"
        when "No Setpoint"
          
          
        end
        
        ground_boundary_conditions = ["Ground",
          "GroundFCfactorMethod",
          "GroundSlabPreprocessorAverage",
          "GroundSlabPreprocessorCore",
          "GroundSlabPreprocessorPerimeter",
          "GroundBasementPreprocessorAverageWall",
          "GroundBasementPreprocessorAverageFloor",
          "GroundBasementPreprocessorUpperWall",
          "GroundBasementPreprocessorLowerWall"
        ]
        #get non-defaulted ground surfaces.

        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces,ground_boundary_conditions)
        non_defaulted_ground_surfaces = BTAP::Geometry::Surfaces::filter_by_non_defaulted_surfaces(ground_surfaces)
         
        
        
        #create models
        modelArray = Array.new()
        #perform Solar Transmittance parametric analysis
        values.each do |value|
          model = model_in.deep_copy()
          model.building.get.setName("Ground-Floor-R-Value="+ value.to_s)
          model.set_surface_RValues(["Floor"],
            ["Ground",
              "GroundFCfactorMethod",
              "GroundSlabPreprocessorAverage",
              "GroundSlabPreprocessorCore",
              "GroundSlabPreprocessorPerimeter",
              "GroundBasementPreprocessorAverageWall",
              "GroundBasementPreprocessorAverageFloor",
              "GroundBasementPreprocessorUpperWall",
              "GroundBasementPreprocessorLowerWall"
            ],
            value)
          modelArray.push(model)
        end
        #Run Files
        self.run_models(modelArray,folder_name)
        return modelArray
      end

      #Performs a ground sensitivity analysis
      def self.ground_wall_rvalue_sensitivity_model_analysis(model_in, folder_name,values = [5,10,15,20,30,50,100])
        #Create RunManager
        #create models
        modelArray = Array.new()
        #perform Solar Transmittance parametric analysis
        values.each do |value|
          runname = "Ground-Wall-R-Value="+ value.to_s
          model = model_in.deep_copy()
          model.building.get.setName(runname)
          model.set_surface_RValues(["Wall"],
            ["Ground",
              "GroundFCfactorMethod",
              "GroundSlabPreprocessorAverage",
              "GroundSlabPreprocessorCore",
              "GroundSlabPreprocessorPerimeter",
              "GroundBasementPreprocessorAverageWall",
              "GroundBasementPreprocessorAverageFloor",
              "GroundBasementPreprocessorUpperWall",
              "GroundBasementPreprocessorLowerWall"
            ],
            value)
          modelArray.push(model)
        end
        #Run Files
        self.run_models(modelArray,folder_name)
        return modelArray
      end

      
      #This method performs a wall sensitivity analysis and returns a string model array.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object   {http://openstudio.nrel.gov/latest-c-sdk-documentation/model}
      #@params folder_name [String] 
      #@params values<Fixnum>
      #@return [modelArray<String>]
      def self.wall_rvalue_sensitivity_model_analysis(model, folder_name,values = [5,10,15,20,30,50,100])
        #create models
        modelArray = Array.new()
        #perform Solar Transmittance parametric analysis
        values.each do |value|
          runname = "Wall_R_Value_"+ value.to_s
          model = model.deep_copy()
          model.building.get.setName(runname)
          model.set_surface_RValues(["Wall"],["Outdoors"],value)
          modelArray.push(model)
        end
        #Run Files
        self.run_models(modelArray,folder_name)
        return modelArray
      end
      
      #This method performs a roof sensitivity analysis and returns a string model array.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model_in [OpenStudio::model::Model] A model object {http://openstudio.nrel.gov/latest-c-sdk-documentation/model}
      #@params folder_name [String] 
      #@params values<Fixnum>
      #@return [modelArray<String>]
      def self.roof_rvalue_sensitivity_model_analysis(model_in, folder_name,values = [5,10,15,20,30,50,100])
        #create models
        modelArray = Array.new()
        #perform Solar Transmittance parametric analysis
        values.each do |value|
          runname = "Roof_R_Value_"+ value.to_s
          model = model_in.deep_copy()
          model.building.get.setName(runname)
          model.set_surface_RValues(["RoofCeiling"],["Outdoors"],value)
          modelArray.push(model)
        end

        #Run Files
        self.run_models(modelArray,folder_name)
        return modelArray
      end

      #This method performs a roof sensitivity analysis and returns a string model array.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params modelArray<Object> 
      #@params folder_name [String] 
      #@return [modelArray<String>]
      def self.run_models(modelArray,folder_name)
        process_manager = BTAP::SimManager::ProcessManager.new(folder_name)
        modelArray.each do |model|
          process_manager.addModel(model)
        end
        process_manager.start_sims
      end

      #This method performs a glazing solar transmittance sensitivity analysis and returns a model array.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model_in [OpenStudio::model::Model] A model object {http://openstudio.nrel.gov/latest-c-sdk-documentation/model}
      #@params folder_name [String] 
      #@params values<Fixnum>
      #@return [modelArray<String>]
      def self.solar_trans_sensitivity_model_analysis(model_in, folder_name, values = [0.1,0.2,0.4,0.6,0.8,1.00])
        modelArray = Array.new()
        #perform Solar Transmittance parametric analysis
        values.each do |value|
          runname = "Window-Tsol-"+ value.to_s
          model = model_in.deep_copy()
          model.building.get.setName(runname)
          model.set_subsurface_solar_transmittance(["FixedWindow","OperableWindow"],["Outdoors"],value)
          modelArray.push(model)
        end
        #Run Files
        self.run_models(modelArray,folder_name)
        return modelArray
      end

      #This method performs an rvalue sensitivity analysis and returns a model array.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model_in [OpenStudio::model::Model] A model object {http://openstudio.nrel.gov/latest-c-sdk-documentation/model}
      #@params folder_name [String] 
      #@params values<Fixnum>
      #@return [modelArray<String>]
      def self.window_rvalue_sensitivity_model_analysis(model_in, folder_name, values = [5,10,15,20,30,50,100])
        modelArray = Array.new()
        #perform Solar Transmittance parametric analysis
        values.each do |value|
          runname = "Window-R-Value="+ value.to_s
          model = model_in.deep_copy()
          model.building.get.setName(runname)
          model.set_subsurface_RValues(["FixedWindow","OperableWindow"],["Outdoors"],value)
          modelArray.push(model)
        end
        #Run Files
        self.run_models(modelArray,folder_name)
        return modelArray
      end

      #This method performs a full sensitivity analysis on the wall, roof, solar-trans,window,and ground surfaces.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object   {http://openstudio.nrel.gov/latest-c-sdk-documentation/model}
      #@params parent_folder [String]
      def self.full_sensitivity_analysis(model, parent_folder)
        self.wall_rvalue_sensitivity_model_analysis(model, (parent_folder + "/wall-r"))
        self.roof_rvalue_sensitivity_model_analysis(model, (parent_folder + "/roof-r"))
        self.solar_trans_sensitivity_model_analysis(model, (parent_folder + "/solar_trans"))
        self.window_rvalue_sensitivity_model_analysis(model, (parent_folder + "/window-r"))
        self.ground_wall_rvalue_sensitivity_model_analysis(model, (parent_folder + "/ground_wall-r"))
        self.ground_floor_rvalue_sensitivity_model_analysis(model, (parent_folder + "/ground-floor-r"))
      end

      #This method performs a full analysis (elimination and Sensitivity).
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object   {http://openstudio.nrel.gov/latest-c-sdk-documentation/model}
      #@params folder [String]
      def self.full_analysis(model, folder)
        FileUtils.rm_rf(folder)
        Dir::mkdir(folder) unless File.exists?(folder)
        self.full_elimination_analysis(model, folder + "/elimination")
        self.full_sensitivity_analysis(model, folder + "/sensitivity")
      end

      #Elimination Analysis. This will 'turn off' certain loads from the building
      #to see the effects. folder_name = the folder you wish to perform the analysis. weather_file = the path of the valid weather file.

      #This method performs an elimination analysis ( OA, H&C setpoints,infiltration,occupancy,lighting,plug_loads,gas_equipment, hotwater, steam, other) and returns a model array.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model_in [OpenStudio::model::Model] A model object {http://openstudio.nrel.gov/latest-c-sdk-documentation/model}
      #@params folder_name [String]
      #@return [modelArray<String>]
      def self.full_elimination_analysis(model_in, folder_name)
        modelArray = Array.new()
        #model_in.add_standard_schedules()

        model = model_in.deep_copy()
        model.building.get.setName("elim_outdoor_air")
        model.eliminate_from_model_outdoor_air()
        modelArray.push(model)

        model = model_in.deep_copy()
        model.building.get.setName("elim_H&C_setpoints")
        model.set_temp_to_free_float()
        modelArray.push(model)

        model = model_in.deep_copy()
        model.building.get.setName("elim_infilt")
        model.set_infiltration(0.0)
        modelArray.push(model)

        model = model_in.deep_copy()
        model.building.get.setName("elim_occup")
        model.set_occupancy_density(0.0)
        modelArray.push(model)

        model = model_in.deep_copy()
        model.building.get.setName("elim_lighting")
        model.set_lighting_power_density(0.0)
        modelArray.push(model)


        model = model_in.deep_copy()
        model.building.get.setName("elim_elec_equip")
        model.set_electric_equipment_power_density(0.0)
        modelArray.push(model)

        model = model_in.deep_copy()
        model.building.get.setName("elim_gas_equip")
        model.set_gas_equipment_power_density(0.0)
        modelArray.push(model)

        model = model_in.deep_copy()
        model.building.get.setName("elim_hot_water_equip")
        model.set_hot_water_equipment(0.0)
        modelArray.push(model)

        model = model_in.deep_copy()
        model.building.get.setName("elim_steam_equip")
        model.set_steam_equipment(0.0)
        modelArray.push(model)

        model = model_in.deep_copy()
        model.building.get.setName("elim_other_equip")
        model.set_other_equipment(0.0)
        modelArray.push(model)

        model = model_in.deep_copy()
        model.building.get.setName("elim_all")
        model.set_other_equipment(0.0)
        modelArray.push(model)
        #Run Files
        self.run_models(modelArray,folder_name)
        return modelArray
      end
    end #module Parametric
  end #module Analysis
end
