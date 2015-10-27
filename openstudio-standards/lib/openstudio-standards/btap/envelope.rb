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


require "#{File.dirname(__FILE__)}/btap"

module BTAP
  module Resources #Resources
    # This module contains methods that relate to Materials, Constructions and Construction Sets
    module Envelope #Resources::Envelope
     
      #This method removes all materials from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      def self.remove_all_materials( model )
        model.getMaterials().each  do |item|
          item.remove
        end unless model.getMaterials().empty?
      end

      #This method removes all constructions from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      def self.remove_all_constructions( model )
        model.getConstructions().each {|item| item.remove}
      end

      #This method removes all default surface constructions from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      def self.remove_all_default_surface_constructions( model )
        model.getDefaultSurfaceConstructionss().each { |item| item.remove }
      end

      #This method removes all default subsurface constructions from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      def self.remove_all_default_subsurface_constructions( model )
        model.getDefaultSubSurfaceConstructionss().each { |item| item.remove }
      end

      #This method removes all default construction sets from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      def self.remove_all_default_construction_sets( model )
        model.getDefaultConstructionSets().each { |item| item.remove }
        model.building.get.resetDefaultConstructionSet()
      end


      #This method assignes interior surface construction to adiabatic surfaces from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      def self.assign_interior_surface_construction_to_adiabatic_surfaces(model, runner = nil)
        BTAP::runner_register("Info","assign_interior_surface_construction_to_adiabatic_surfaces(#{model},#{runner}", runner) 
        unless model.building.get.defaultConstructionSet.empty? or model.building.get.defaultConstructionSet.get.defaultInteriorSurfaceConstructions.empty? or model.building.get.defaultConstructionSet.get.defaultInteriorSurfaceConstructions.get.wallConstruction.empty?
          #Give adiabatic surfaces a construction. Does not matter what. This is a bug in Openstudio that leave these surfaces unassigned by the default construction set.
          all_adiabatic_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces, "Adiabatic")
          unless all_adiabatic_surfaces.empty?
            wall_construction = model.building.get.defaultConstructionSet.get.defaultInteriorSurfaceConstructions.get.wallConstruction.get
            BTAP::Geometry::Surfaces::set_surfaces_construction( all_adiabatic_surfaces, wall_construction)
            names = ""
            all_adiabatic_surfaces.each {|surface| name = "#{names} , #{surface.name.to_s} " }
            BTAP::runner_register("Warning", "The following adiabatic surfaces have been assigned the construction #{wall_construction.name} : #{name}" , runner)
          end
        else
          BTAP::runner_register("Error", "default constructruction not defined",runner)
          return false
        end
        return true
      end
        
      #This method removes all thermal mass definitions from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      def self.remove_all_thermal_mass_definitions( model )
        model.getInternalMassDefinitions.each { |item| item.remove }
        model.getInternalMasss.each { |item| item.remove }
      end

      #This method removes all envelope information from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      def self.remove_all_envelope_information( model )
        BTAP::Resources::Envelope::remove_all_materials( model )
        BTAP::Resources::Envelope::remove_all_default_construction_sets( model )
        BTAP::Resources::Envelope::remove_all_default_subsurface_constructions( model )
        BTAP::Resources::Envelope::remove_all_default_surface_constructions( model )
        BTAP::Resources::Envelope::set_all_surfaces_to_default_construction( model )
        BTAP::Resources::Envelope::remove_all_constructions( model )
        BTAP::Resources::Envelope::remove_all_materials( model )
        BTAP::Resources::Envelope::remove_all_thermal_mass_definitions( model )
      end


      def self.set_all_surfaces_to_default_construction( model )
        model.getPlanarSurfaces.each { |item| item.resetConstruction }
      end



      # This module contains Materials, Constructions and ConstructionSets
      module Materials #Resources::Envelope::Materials
        #This method gets conductance.
        #@author phylroy.lopez@nrcan.gc.ca
        #@params material [OpenStudio::Model::StandardOpaqueMaterial]
        #@params temperature_c [Float]
        #@return conductance [Float]
        def self.get_conductance(material,temperature_c = 0.0)
          conductance = nil
          #this method is a wrapper around OS functions. No testing is required.
          #Convert C to K
          temperature_k =  temperature_c + 273.0
          conductance = material.to_SimpleGlazing.get.uFactor unless material.to_SimpleGlazing.empty?
          conductance = material.to_StandardGlazing.get.thermalConductance unless material.to_StandardGlazing.empty?
          conductance = material.to_OpaqueMaterial.get.thermalConductance unless material.to_OpaqueMaterial.empty?
          conductance = material.to_Shade.get.thermalConductance unless material.to_Shade.empty?
          conductance = material.to_Screen.get.thermalConductance unless material.to_Screen.empty?
          conductance = material.to_MasslessOpaqueMaterial.get.thermalConductance unless material.to_MasslessOpaqueMaterial.empty?
          conductance = 1.0/material.to_AirGap.get.getThermalResistance.get.value unless material.to_AirGap.empty?
          conductance = material.to_Gas.get.getThermalConductivity(temperature_k) unless material.to_Gas.empty?
          conductance = material.to_GasMixture.get.getThermalConductance(temperature_k) unless material.to_GasMixture.empty?
          conductance = material.to_RoofVegetation.get.thermalConductance unless material.to_RoofVegetation.empty?
          conductance = material.to_RefractionExtinctionGlazing.get.thermalConductance unless material.to_RefractionExtinctionGlazing.empty?
          conductance = 9999.9 unless material.to_Blind.empty?
          raise ("Conductance for Material: #{material.name} could not be set.") if conductance == nil
          return conductance
        end


        # This module contains methods to create opaque materials for Opaque constructions such as walls, roofs, floor and ceilings.
        module Opaque #Resources::Envelope::Materials::Opaque
          #Test Opaque Module
          if __FILE__ == $0
            require 'test/unit'
            class OpaqueTests < Test::Unit::TestCase

              #This method tests the creation of opaque materials.
              #@author phylroy.lopez@nrcan.gc.ca
              def test_create_opaque_material()
                model = OpenStudio::Model::Model.new()
                material = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material(model)
                assert( !(material.to_StandardOpaqueMaterial.empty?))
              end
              #This method tests the creation of massless opaque materials.
              #@author phylroy.lopez@nrcan.gc.ca
              def test_create_massless_opaque_material()
                model = OpenStudio::Model::Model.new()
                material = BTAP::Resources::Envelope::Materials::Opaque::create_massless_opaque_material(model)
                assert( !(material.to_MasslessOpaqueMaterial.empty?))
              end
              #This method tests the creation of air gap.
              #@author phylroy.lopez@nrcan.gc.ca
              def test_create_air_gap()
                model = OpenStudio::Model::Model.new()
                material = BTAP::Resources::Envelope::Materials::Opaque::create_air_gap(model)
                assert( !(material.to_AirGap.empty?) )
              end
            end
          end # End Test Opaque


          # This method will create a OpenStudio::Model::StandardOpaqueMaterial material layer.
          # BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material
          # @author Phylroy A. Lopez <plopez@nrcan.gc.ca>
          # @params model [OpenStudio::Model::Model]  {http://openstudio.nrel.gov/latest-c-sdk-documentation/model}
          # @params name [String] the name of the surface.
          # @params thickness [Float] meters.
          # @params conductivity [Float]  W/m*K.
          # @params density [Float]  kg/m3
          # @params specific_heat [Float]  J/kg*K
          # @params roughness [String]  valid values are  = ["VeryRough", "Rough", "MediumRough","Smooth","MediumSmooth","VerySmooth"]
          # @params thermal_absorptance [Float] range of 0 to 1.0
          # @params solar_absorptance [Float] range of 0 to 1.0
          # @params visible_absorptance [Float] range of 0 to 1.0
          # @return material [OpenStudio::Model::StandardOpaqueMaterial] {http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/classopenstudio_1_1model_1_1_standard_opaque_material.html}
          def self.create_opaque_material( model,name = "opaque material", thickness = 0.1 , conductivity = 0.1 , density = 0.1, specific_heat = 0.1, roughness = "Smooth", thermal_absorptance = 0.9, solar_absorptance = 0.7, visible_absorptance = 0.7 )
            # make sure the roughness value is acceptable.
            raise("Roughness Value \"#{roughness}\" is not a part of accepted values such as: #{OpenStudio::Model::StandardOpaqueMaterial::roughnessValues.join(",")}")  unless OpenStudio::Model::StandardOpaqueMaterial::roughnessValues.include?(roughness)
            # I was thinking of adding a suffix to the name to make it more descriptive, but this can be confusing. Keeping it here if I need it later.
            # name = name + " " + "t=" + sprintf("%.3f", thickness) + "c=" + sprintf("%.3f", conductance) + "d=" + sprintf("%.3f", density) + "s=" + sprintf("%.3", specific_heat)
            material = OpenStudio::Model::StandardOpaqueMaterial.new( model, roughness , thickness, conductivity , density, specific_heat )
            material.setName( name ) unless name == "" or name == nil
            material.setThermalAbsorptance( thermal_absorptance )
            material.setSolarAbsorptance( solar_absorptance )
            material.setVisibleAbsorptance( visible_absorptance )
            return material
          end



          # This method will create a new OpenStudio::Model::MasslessOpaqueMaterial material layer
          # @author Phylroy A. Lopez Natural Resources Canada <plopez@nrcan.gc.ca>
          # @params model [OpenStudio::Model::Model]  {http://openstudio.nrel.gov/latest-c-sdk-documentation/model OpenStudio::Model::Model}
          # @params name [String] the name of the surface.
          # @params roughness [String]  valid values are  = ["VeryRough", "Rough", "MediumRough","Smooth","MediumSmooth","VerySmooth"]
          # @params thermalResistance  [Float]  m*K/W
          # @return massless OpenStudio::Model::MasslessOpaqueMaterial {http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/classopenstudio_1_1model_1_1_massless_opaque_material.html OpenStudio::Model::MasslessOpaqueMaterial}
          def self.create_massless_opaque_material(model, name = "massless opaque", roughness = "Smooth", thermalResistance = 0.1)
            # make sure the roughness value is acceptable.
            raise("Roughness Value \"#{roughness}\" is not a part of accepted values: #{OpenStudio::Model::StandardOpaqueMaterial::roughnessValues.join(",")}")  unless OpenStudio::Model::StandardOpaqueMaterial::roughnessValues.include?(roughness)
            massless = OpenStudio::Model::MasslessOpaqueMaterial.new(model, roughness,thermalResistance)
            massless.setName( name)
            return massless
          end

          # This method will create a new OpenStudio::Model::AirGap material layer
          # @author Phylroy A. Lopez <plopez@nrcan.gc.ca>
          # @params model [OpenStudio::Model::Model]  {http://openstudio.nrel.gov/latest-c-sdk-documentation/model OpenStudio::Model::Model}
          # @params name [String] the name of the surface.
          # @params thermalResistance  [Float]  m2*K/W
          # @return air [OpenStudio::Model::AirGap]
          def self.create_air_gap(model,name = "air gap",resistance = 0.1)
            air = OpenStudio::Model::AirGap.new(model,resistance)
            air.setName( name)
            return air
          end
        end


        #This module contains methods to create  materials for  glazed construction such as windows, doors, and skylights.
        module Fenestration #Resources::Envelope::Materials::Fenestration

          #Test Fenestration Module
          if __FILE__ == $0
            require 'test/unit'
            class FenestrationTests < Test::Unit::TestCase
              #This method will test the creation of simple glazing
              #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
              def test_create_simple_glazing()
                model = OpenStudio::Model::Model.new()
                material = BTAP::Resources::Envelope::Materials::Fenestration::create_simple_glazing(model)
                assert( !(material.to_SimpleGlazing.empty?))
              end
              #This method will test the creation of standard glazing
              #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
              def test_create_standard_glazing()
                model = OpenStudio::Model::Model.new()
                material = BTAP::Resources::Envelope::Materials::Fenestration::create_standard_glazing(model)
                assert( !(material.to_StandardGlazing.empty?))
              end
              #This method will test the creation of simple gas
              #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
              def test_create_gas()
                model = OpenStudio::Model::Model.new()
                material = BTAP::Resources::Envelope::Materials::Fenestration::create_gas(model)
                assert( !(material.to_Gas.empty?))
              end
              #This method will test the creation of blind
              #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
              def test_create_blind()
                model = OpenStudio::Model::Model.new()
                material = BTAP::Resources::Envelope::Materials::Fenestration::create_blind(model)
                assert( !(material.to_Blind.empty?))
              end
              #This method will test the creation of screen
              #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
              def test_create_screen()
                model = OpenStudio::Model::Model.new()
                material = BTAP::Resources::Envelope::Materials::Fenestration::create_screen(model)
                assert( !(material.to_Screen.empty?))
              end
              #This method will test the creation of shade
              #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
              def test_create_shade()
                model = OpenStudio::Model::Model.new()
                material = BTAP::Resources::Envelope::Materials::Fenestration::create_shade(model)
                assert( !(material.to_Shade.empty?))
              end

            end
          end # End Test Fenestration


          # This method creates a OpenStudio::Model::SimpleGlazing material layer
          # @author Phylroy A. Lopez <plopez@nrcan.gc.ca>
          # @params model [OpenStudio::Model::Model]
          # @params name [String] the name of the material.
          # @params shgc [Float]  solar heat gain coeff.
          # @params ufactor [Float]  W/m2*K
          # @params thickness  [Float] m
          # @params visible_transmittance [Float]
          # @return simpleglazing [OpenStudio::Model::SimpleGlazing]
          def self.create_simple_glazing(model,name = "simple glazing test",shgc  = 0.10 ,ufactor = 0.10,thickness = 0.005,visible_transmittance = 0.8)
            simpleglazing = OpenStudio::Model::SimpleGlazing.new(model)
            simpleglazing.setSolarHeatGainCoefficient(shgc)
            simpleglazing.setUFactor(ufactor)
            simpleglazing.setThickness(thickness)
            simpleglazing.setVisibleTransmittance(visible_transmittance)
            simpleglazing.setName( name)
            return simpleglazing
          end



          # This method creates a OpenStudio::Model::StandardGlazing material layer
          # @author Phylroy A. Lopez <plopez@nrcan.gc.ca>
          # @params model [OpenStudio::Model::Model]
          # @params name = "Standard Glazing Test", of the material.
          # @params thickness [Float] m
          # @params conductivity [Float] W/m*K
          # @params solarTransmittanceatNormalIncidence [Float]
          # @params frontSideSolarReflectanceatNormalIncidence [Float]
          # @params backSideSolarReflectanceatNormalIncidence = [Float]
          # @params visibleTransmittance [Float]
          # @params frontSideVisibleReflectanceatNormalIncidence[Float]
          # @params backSideVisibleReflectanceatNormalIncidence [Float]
          # @params infraredTransmittanceatNormalIncidence [Float]
          # @params frontSideInfraredHemisphericalEmissivity [Float]
          # @params backSideInfraredHemisphericalEmissivity [Float]
          # @return stdglazing [OpenStudio::Model::StandardGlazing]
          def self.create_standard_glazing(
              model,
              name = "Standard Glazing Test",
              thickness = 0.003,
              conductivity = 0.9,
              solarTransmittanceatNormalIncidence = 0.84,
              frontSideSolarReflectanceatNormalIncidence = 0.075,
              backSideSolarReflectanceatNormalIncidence = 0.075,
              visibleTransmittance = 0.9,
              frontSideVisibleReflectanceatNormalIncidence = 0.081,
              backSideVisibleReflectanceatNormalIncidence = 0.081,
              infraredTransmittanceatNormalIncidence = 0.0,
              frontSideInfraredHemisphericalEmissivity = 0.84,
              backSideInfraredHemisphericalEmissivity = 0.84,
              opticalDataType = "SpectralAverage",
              dirt_correction_factor = 1.0,
              is_solar_diffusing = false
            )
            raise("Roughness Value \"#{roughness}\" is not a part of accepted values: #{OpenStudio::Model::StandardGlazing::opticalDataTypeValues().join(",")}")  unless OpenStudio::Model::StandardGlazing::opticalDataTypeValues().include?(opticalDataType)
            stdglazing = OpenStudio::Model::StandardGlazing.new(model)
            stdglazing.setThickness(thickness.to_f)
            stdglazing.setSolarTransmittanceatNormalIncidence(solarTransmittanceatNormalIncidence.to_f)
            stdglazing.setFrontSideSolarReflectanceatNormalIncidence(frontSideSolarReflectanceatNormalIncidence.to_f)
            stdglazing.setBackSideSolarReflectanceatNormalIncidence(backSideSolarReflectanceatNormalIncidence.to_f)
            stdglazing.setVisibleTransmittance(visibleTransmittance.to_f)
            stdglazing.setFrontSideVisibleReflectanceatNormalIncidence(frontSideVisibleReflectanceatNormalIncidence.to_f)
            stdglazing.setBackSideVisibleReflectanceatNormalIncidence(backSideVisibleReflectanceatNormalIncidence.to_f)
            stdglazing.setInfraredTransmittanceatNormalIncidence(infraredTransmittanceatNormalIncidence.to_f)
            stdglazing.setFrontSideInfraredHemisphericalEmissivity(frontSideInfraredHemisphericalEmissivity.to_f)
            stdglazing.setBackSideInfraredHemisphericalEmissivity(backSideInfraredHemisphericalEmissivity.to_f)
            stdglazing.setConductivity(conductivity.to_f)
            stdglazing.setName(name)
            stdglazing.setOpticalDataType(opticalDataType)
            stdglazing.setDirtCorrectionFactorforSolarandVisibleTransmittance(dirt_correction_factor)
            stdglazing.setSolarDiffusing(is_solar_diffusing)
            return stdglazing
          end


          #This method creates an gas material layer. gas_type can be "Air", "Argon","Krypton","Xenon",or "Custom"
          # @author Phylroy A. Lopez <plopez@nrcan.gc.ca>
          # @params model [OpenStudio::Model::Model]
          # @params name [String] = "air test", of the material.
          # @params gas_type [String] = "Air"
          # @params thickness [Float] = 0.003
          # @return gas [OpenStudio::Model::Gas::validGasTypes]
          def self.create_gas(model,name = "air test",gas_type = "Air", thickness=0.003)
            raise "gas_type #{gas_type} is not part of the allow values: #{OpenStudio::Model::Gas::validGasTypes()}" unless OpenStudio::Model::Gas::validGasTypes().include?(gas_type)
            gas = OpenStudio::Model::Gas.new(model)
            gas.setGasType(gas_type)
            gas.setThickness(thickness)
            gas.setName(name)
            return gas
          end


          #This method will create a blind layer.
          # @author Phylroy A. Lopez <plopez@nrcan.gc.ca>
          # @params model [OpenStudio::Model::Model]
          # @params name [String] = "blind test"
          # @params slatWidth [Float] = 0.1
          # @params slatSeparation [Float] = 0.1
          # @params frontSideSlatBeamSolarReflectance [Float] = 0.1
          # @params backSideSlatBeamSolarReflectance [Float] = 0.1
          # @params frontSideSlatDiffuseSolarReflectance [Float] = 0.1
          # @params backSideSlatDiffuseSolarReflectance [Float] = 0.1
          # @params slatBeamVisibleTransmittance [Float] = 0.1
          # @return blind [OpenStudio::Model::Blind]
          def self.create_blind(model,name = "blind test", slatWidth=0.1, slatSeparation=0.1, frontSideSlatBeamSolarReflectance=0.1, backSideSlatBeamSolarReflectance=0.1, frontSideSlatDiffuseSolarReflectance=0.1, backSideSlatDiffuseSolarReflectance=0.1, slatBeamVisibleTransmittance=0.1)
            blind = OpenStudio::Model::Blind.new(model, slatWidth, slatSeparation, frontSideSlatBeamSolarReflectance, backSideSlatBeamSolarReflectance, frontSideSlatDiffuseSolarReflectance, backSideSlatDiffuseSolarReflectance, slatBeamVisibleTransmittance)
            blind.setName(name)
            return blind
          end


          #This method will create a screen layer.
          # @author Phylroy A. Lopez <plopez@nrcan.gc.ca>
          # @params model [OpenStudio::Model::Model]
          # @params name [String] = "screen test"
          # @params diffuseSolarReflectance [Float] = 0.1
          # @params diffuseVisibleReflectance [Float] = 0.1
          # @params screenMaterialSpacing [Float] = 0.1
          # @params screenMaterialDiameter [Float] = 0.1
          # @return screen [OpenStudio::Model::Screen]
          def self.create_screen(model,name = "screen test", diffuseSolarReflectance=0.1, diffuseVisibleReflectance=0.1, screenMaterialSpacing=0.1, screenMaterialDiameter=0.1)
            screen = OpenStudio::Model::Screen.new(model, diffuseSolarReflectance, diffuseVisibleReflectance, screenMaterialSpacing, screenMaterialDiameter)
            screen.setName(name)
            return screen
          end


          #This method will create a shade layer.
          # @author Phylroy A. Lopez <plopez@nrcan.gc.ca>
          # @params model [OpenStudio::Model::Model]
          # @params name [String] = "shade test"
          # @params solarTransmittance [Float] = 0.1
          # @params solarReflectance [Float] = 0.1
          # @params visibleTransmittance [Float] = 0.1
          # @params visibleReflectance [Float] = 0.1
          # @params thermalHemisphericalEmissivity [Float] = 0.1
          # @params thermalTransmittance [Float] = 0.1
          # @params thickness [Float] = 0.1
          # @params conductivity [Float] = 0.1
          # @return shade [OpenStudio::Model::Shade.new]
          def self.create_shade(model,name ="shade test", solarTransmittance=0.1, solarReflectance=0.1, visibleTransmittance=0.1, visibleReflectance=0.1, thermalHemisphericalEmissivity=0.1, thermalTransmittance=0.1, thickness=0.1, conductivity=0.1)
            shade = OpenStudio::Model::Shade.new(model, solarTransmittance, solarReflectance,visibleTransmittance, visibleReflectance, thermalHemisphericalEmissivity, thermalTransmittance, thickness, conductivity)
            shade.setName(name)
            return shade
          end


        end #module Fenestration


      end #module materials


      #This module contains methods dealing with the creation and modification of constructions.
      module Constructions #Resources::Envelope::Constructions


        #Test Constructions Module
        if __FILE__ == $0
          require 'test/unit'
          class ConstructionsTests < Test::Unit::TestCase

            #This method sets up the model.
            #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
            def setup
              @model = OpenStudio::Model::Model.new()
              #Create opaque layers from defaults
              @insulation = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material(@model,"insulation", 0.1 , 0.001 ,  0.1, 0.1, "Smooth", 0.9, 0.7, 0.7 )
              @opaque = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material(@model)
              @air_gap = BTAP::Resources::Envelope::Materials::Opaque::create_air_gap(@model)
              @massless = BTAP::Resources::Envelope::Materials::Opaque::create_massless_opaque_material(@model)
              #Create fenestration layer from defaults.
              @simple = BTAP::Resources::Envelope::Materials::Fenestration::create_simple_glazing(@model)
              @standard = BTAP::Resources::Envelope::Materials::Fenestration::create_standard_glazing(@model)
              @gas = BTAP::Resources::Envelope::Materials::Fenestration::create_gas(@model)
              @blind = BTAP::Resources::Envelope::Materials::Fenestration::create_blind(@model)
              @screen = BTAP::Resources::Envelope::Materials::Fenestration::create_screen(@model)
              @shade = BTAP::Resources::Envelope::Materials::Fenestration::create_shade(@model)
              @opaque_construction = BTAP::Resources::Envelope::Constructions::create_construction(@model, "test construction",[@opaque,@air_gap,@insulation,@massless,@opaque],@insulation )
              @fenestration_construction = BTAP::Resources::Envelope::Constructions::create_construction(@model, "test construction",[ @simple,@standard],@gas )

              array = [@opaque,"insulation",@air_gap]
              BTAP::Common::validate_array(@model,array,"Material")

            end

            #This method will create a test opaque construction.
            #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
            def test_create_opaque_construction()
              construction = BTAP::Resources::Envelope::Constructions::create_construction(@model, "test construction",[@opaque,@air_gap,@insulation,@massless,@opaque],@insulation )
              #Check that the construction was created
              assert( !(construction.to_Construction.empty?))
              #check that all layers were entered
              assert_equal(5, construction.layers.size )
              #check insulation was set.
              assert( construction.insulation().get == @insulation )
            end

            #This method will test find and set insulation layer.
            # @author Phylroy A. Lopez <plopez@nrcan.gc.ca>
            def test_find_and_set_insulaton_layer()
              construction = BTAP::Resources::Envelope::Constructions::create_construction(@model, "test construction",[@opaque,@air_gap,@insulation,@massless,@opaque] )

              #check insulation was not set.
              assert( (construction.insulation().empty?) )
              #now set it.
              BTAP::Resources::Envelope::Constructions::find_and_set_insulaton_layer(@model, [construction])
              #Now check that it found the insulation  value.
              assert( construction.insulation().get == @insulation )
            end

            #This method will test creation of fenestration construction.
            #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
            def test_create_fenestration_construction()
              construction = BTAP::Resources::Envelope::Constructions::create_construction(@model, "test construction",[ @simple,@standard,@gas,@blind,@screen,@shade],@gas )
              assert_equal(6, construction.layers.size )
              assert( !(construction.to_Construction.empty?))
            end

            #This method will create new construction based on exisiting.
            #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
            def test_create_new_construction_based_on_exisiting()
              #              opaque
              new_construction = BTAP::Resources::Envelope::Constructions::customize_opaque_construction(@model, @opaque_construction,0.05)
              assert_in_delta(0.05,new_construction.thermalConductance.to_f,0.00001 )
              #              fenestration
              new_construction = BTAP::Resources::Envelope::Constructions::customize_fenestration_construction(@model,@fenestration_construction,0.5,nil, nil,0.0)
              assert_in_delta(0.5,Resources::Envelope::Constructions::get_conductance(new_construction).to_f,0.00001 )
            end
          end
        end # End Test Constructions

        #This method will search through the layers and find the layer with the
        #lowest conductance and set that as the insulation layer. Note: Concrete walls
        #or slabs with no insulation layer but with a carper will see the carpet as the
        #insulation layer.
        #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
        #@params model [OpenStudio::Model::Model]
        #@params constructions_array [BTAP::Common::validate_array]
        #@return insulating_layers <String>
        def self.find_and_set_insulaton_layer(model,constructions_array)
          constructions_array = BTAP::Common::validate_array(model,constructions_array,"Construction")
          insulating_layers = Array.new()
          constructions_array.each do |construction|
            return_material = ""
            #skip if already has an insulation layer set.
            next unless construction.insulation.empty?
            #set insulation layer.
            #find insulation layer
            min_conductance = 100.0
            #loop through Layers
            construction.layers.each do |layer|
              #try casting the layer to an OpaqueMaterial.
              material = nil
              material = layer.to_OpaqueMaterial.get unless layer.to_OpaqueMaterial.empty?
              material = layer.to_FenestrationMaterial.get unless layer.to_FenestrationMaterial.empty?
              #check if the cast was successful, then find the insulation layer.
              unless nil == material

                if BTAP::Resources::Envelope::Materials::get_conductance(material) < min_conductance
                  #Keep track of the highest thermal resistance value.
                  min_conductance = BTAP::Resources::Envelope::Materials::get_conductance(material)
                  return_material = material
                  unless material.to_OpaqueMaterial.empty?
                    construction.setInsulation(material)
                  end
                end
              end
            end
            if construction.insulation.empty? and construction.isOpaque
              raise ("construction #{construction.getAttribute("name").get.to_s} insulation layer could not be set!. This occurs when a insulation layer is duplicated in the construction.")
            end

            insulating_layers << return_material
          end

          return insulating_layers
        end

        #This method will create a new construction based on self and a new conductance value.
        #It will check to see if a similar construction has already been created by this method
        #if so it will return the existing construction. If you wish to keep some of the properties, enter the
        #string "default" instead of a numerical value.
        #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
        #@params model [OpenStudio::Model::Model]
        #@params construction <String>
        #@param conductance [Fixnum]
        #@return new_construction [<String]OpenStudio::Model::getConstructionByName]
        def self.customize_opaque_construction(model,construction,conductance)
          #Will convert from a string identifier to an object if required.
          construction = BTAP::Common::validate_array(model,construction,"Construction").first
          #If it is Opaque
          raise ("This construction is not opaque :#{construction.name}") unless (construction.isOpaque)
          minimum_resistance = 0
          name_prefix = "Customized opaque construction #{construction.handle()} to conductance of #{conductance}"

          #Check to see if we already made one like this.
          existing_construction = OpenStudio::Model::getConstructionByName(construction.model,name_prefix)
          if not existing_construction.empty?
            # if so, return existing construction
            return existing_construction.get
          end

          #create a copy
          new_construction = self.deep_copy(model,construction)

          #Change Construction name in clone
          new_construction.setName( name_prefix)

          if  conductance.kind_of?(Float)
            #re-find insulation layer
            find_and_set_insulaton_layer(model,new_construction)

            #There is a limit of 3 meters for material thickness. To avoid hitting that
            #limit, let's adjust the conductivity of the materials to a very low value.
            #construction.insulation.get.setThermalConductivity(0.001)
            #
            #Determine how low the resistance can be set. Subtract exisiting insulation
            #Values from the total resistance to see how low we can go.
            minimum_resistance = (1 / new_construction.thermalConductance.to_f) - (1.0 / new_construction.insulation.get.thermalConductance.to_f)

            #Check if the requested resistance is smaller than the minimum
            # resistance. If so, use the minimum resistance instead.
            if minimum_resistance > 1 / conductance
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
        end

        #This model gets tsol
        #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
        #@params model [OpenStudio::Model::Model]
        #@params construction <String>
        #@return tsol [Float]
        def self.get_tsol(model,construction)
          construction = BTAP::Common::validate_array(model,construction,"Construction").first
          construction = OpenStudio::Model::getConstructionByName(model,construction.name.to_s).get
          tsol = 1.0
          if construction.isFenestration

            construction.layers.each do |layer|
              #check to see if it is a simple glazing. If so use the SHGC method.
              tsol = tsol * layer.to_SimpleGlazing.get.getSolarHeatGainCoefficient().value unless layer.to_SimpleGlazing.empty?
              #check to see if it is a standard glazing. If so use the solar transmittance method.
              tsol = tsol * layer.to_StandardGlazing.get.solarTransmittance() unless layer.to_StandardGlazing.empty?
            end
          end
          return tsol
        end

        #This model gets tvis
        #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
        #@params model [OpenStudio::Model::Model]
        #@params construction <String>
        #@return tvis [Float]
        def self.get_tvis(model,construction)
          construction = BTAP::Common::validate_array(model,construction,"Construction").first
          construction = OpenStudio::Model::getConstructionByName(model,construction.name.to_s).get
          tvis = 1.0
          if construction.isFenestration
            construction.layers.each do |layer|
              #check to see if it is a simple glazing. If so use the SHGC method.
              tvis = tvis * layer.to_SimpleGlazing.get.getVisibleTransmittance().get.value unless layer.to_SimpleGlazing.empty?
              #check to see if it is a standard glazing. If so use the solar transmittance method.
              tvis = tvis * layer.to_StandardGlazing.get.visibleTransmittanceatNormalIncidence().get unless layer.to_StandardGlazing.empty?
            end
          end
          return tvis
        end

        #this method will get the conductance (metric) of the construction.
        #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
        #@params construction <String>
        #@params at_temperature_c [Float]  = 0.0
        #@return 1.0
        def self.get_conductance(construction, at_temperature_c = 0.0)
          #if , by accidnet a construction base was passed...convert it to a construction object.
          construction = OpenStudio::Model::getConstructionByName(construction.model,construction.name.to_s).get unless construction.to_ConstructionBase.empty?
          total = 0.0
          construction.layers.each do |material|

            total = total + 1.0 / BTAP::Resources::Envelope::Materials::get_conductance(material,at_temperature_c)
          end
          return 1.0 / total
        end

        #this method will get the rsi (metric) of the construction.
        #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
        #@params construction <String>
        #@params at_temperature_c [Float] = 0.0
        #@return 1.0 / self.get_conductance(construction, at_temperature_c
        def self.get_rsi(construction, at_temperature_c = 0.0)
          return 1.0 / self.get_conductance(construction, at_temperature_c)
        end


        #This will create a deep copy of the construction
        #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
        #@params model [OpenStudio::Model::Model]
        #@params construction <String>
        #@return new_construction <String>
        def self.deep_copy(model, construction)
          construction = BTAP::Common::validate_array(model,construction,"Construction").first
          new_construction = construction.clone.to_Construction.get
          #interating through layers."
          (0..new_construction.layers.length-1).each do |layernumber|
            #cloning material"
            cloned_layer = new_construction.getLayer(layernumber).clone.to_Material.get
            #"setting material to new construction."
            new_construction.setLayer(layernumber,cloned_layer )
          end
          return new_construction
        end

        #This will create construction model
        #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
        #@params model [OpenStudio::Model::Model]
        #@params name <String>
        #@params materials <String>
        #@params insulationLayer = nil
        #@return construction <String>
        def self.create_construction(model, name, materials, insulationLayer = nil)
          construction = OpenStudio::Model::Construction.new(model)
          construction.setName( name)
          #check to see if they are all Fenestation or Opaque. Can't mix and match.
          is_fenestration = false
          is_opaque = false
          #check to see if materials are all the same type.
          materials.each do |material|
            is_fenestration = true unless material.to_FenestrationMaterial.empty?
            is_opaque = true unless material.to_OpaqueMaterial.empty?
          end
          raise ("Materials Passed are not valid. Either they are mixed Opaque/Fenestration or invalid materials") if (is_fenestration and is_opaque) or (not is_fenestration and not is_opaque)
          construction.setLayers(materials)
          construction.setInsulation(insulationLayer) unless nil == insulationLayer or is_fenestration
          return construction
        end

        #This will customize fenestration construction
        #@author Phylroy A. Lopez <plopez@nrcan.gc.ca>
        #@params model [OpenStudio::Model::Model]
        #@params construction <String>
        #@params conductance <String> = nil
        #@params solarTransmittanceatNormalIncidence [Float] = nil
        #@params visibleTransmittance [Float] = nil
        #@params at_temperature_c [Float] = 0.0
        #@return create_construction <String>
        def self.customize_fenestration_construction(
            model,
            construction,
            conductance = nil,
            solarTransmittanceatNormalIncidence = nil,
            visibleTransmittance = nil,
            at_temperature_c = 0.0)
          construction = OpenStudio::Model::getConstructionByName(model,construction.name.to_s).get
          raise ("This is not a fenestration!") unless construction.isFenestration
          #get equivilant values for tsol, tvis, and conductances.
          solarTransmittanceatNormalIncidence = self.get_tsol(model, construction) if solarTransmittanceatNormalIncidence == nil
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



          #          glazing = BTAP::Resources::Envelope::Materials::Fenestration::create_standard_glazing(
          #            construction.model,
          #            glazing_name,
          #            thickness,
          #            conductivity,
          #            solarTransmittanceatNormalIncidence ,
          #            frontSideSolarReflectanceatNormalIncidence ,
          #            backSideSolarReflectanceatNormalIncidence ,
          #            visibleTransmittance ,
          #            frontSideVisibleReflectanceatNormalIncidence ,
          #            backSideVisibleReflectanceatNormalIncidence ,
          #            infraredTransmittanceatNormalIncidence,
          #            frontSideInfraredHemisphericalEmissivity,
          #            backSideInfraredHemisphericalEmissivity ,
          #            "SpectralAverage",
          #            1.0,
          #            false
          #          )
          #add the glazing and any shading materials to the array and create construction based on this.
          new_materials_array = Array.new()
          new_materials_array << glazing
          new_materials_array.concat(shading_material_array) unless shading_material_array.empty?
          puts new_materials_array.size
          return self.create_construction(construction.model, cons_name, new_materials_array)
        end

      end #module Constructions


      #This module contains methods for creating ConstructionSets.
      module ConstructionSets #Resources::Envelope::ConstructionSets

        #Test Constructions Module
        if __FILE__ == $0
          require 'test/unit'
          class ConstructionsSetTests < Test::Unit::TestCase

            #This method creates default surface constructions
            #@author phylroy.lopez@nrcan.gc.ca
            def test_create_default_surface_constructions()
              model = OpenStudio::Model::Model.new()
              #Create layers from defaults
              insulation = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material(model)
              opaque = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material(model)
              air_gap = BTAP::Resources::Envelope::Materials::Opaque::create_air_gap(model)
              massless = BTAP::Resources::Envelope::Materials::Opaque::create_massless_opaque_material(model)
              construction = BTAP::Resources::Envelope::Constructions::create_construction(model, "test construction",[opaque,air_gap,insulation,massless,opaque],insulation )
              walls_cons = floor_cons = roof_cons = construction
              construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions(model,"test construction set",walls_cons,floor_cons,roof_cons)
              #Check that the construction was created
              assert( !(construction_set.to_DefaultSurfaceConstructions.empty?))
            end

            #This method customizes default surface constructions
            #@author phylroy.lopez@nrcan.gc.ca
            def test_customize_default_surface_constructions_rsi()
              model = OpenStudio::Model::Model.new()
              #Create layers from defaults
              insulation = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material(model)
              opaque = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material(model)
              air_gap = BTAP::Resources::Envelope::Materials::Opaque::create_air_gap(model)
              massless = BTAP::Resources::Envelope::Materials::Opaque::create_massless_opaque_material(model)
              construction = BTAP::Resources::Envelope::Constructions::create_construction(model, "test construction",[opaque,air_gap,insulation,massless,opaque],insulation )
              walls_cons = floor_cons = roof_cons = construction
              construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions(model,"test construction set",walls_cons,floor_cons,roof_cons)
              #Check that the construction was created
              assert( !(construction_set.to_DefaultSurfaceConstructions.empty?))
              new_set = BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_constructions_rsi(model,"changed_rsi",construction_set,1.0/2.45,1.0/2.55 , 1.0/2.65)
              assert_in_delta(1.0/2.45,BTAP::Resources::Envelope::Constructions::get_conductance(new_set.wallConstruction.get).to_f,0.00001 )
              assert_in_delta(1.0/2.55,BTAP::Resources::Envelope::Constructions::get_conductance(new_set.floorConstruction.get).to_f,0.00001 )
              assert_in_delta(1.0/2.65,BTAP::Resources::Envelope::Constructions::get_conductance(new_set.roofCeilingConstruction.get).to_f,0.00001 )
            end


            #This method creates default subsurface constructions
            #@author phylroy.lopez@nrcan.gc.ca
            def test_create_default_subsurface_constructions()
              model = OpenStudio::Model::Model.new()
              #Create layers from defaults
              simple = BTAP::Resources::Envelope::Materials::Fenestration::create_simple_glazing(model)
              standard = BTAP::Resources::Envelope::Materials::Fenestration::create_standard_glazing(model)
              gas = BTAP::Resources::Envelope::Materials::Fenestration::create_gas(model)
              blind = BTAP::Resources::Envelope::Materials::Fenestration::create_blind(model)
              screen = BTAP::Resources::Envelope::Materials::Fenestration::create_screen(model)
              shade = BTAP::Resources::Envelope::Materials::Fenestration::create_shade(model)
              fixedWindowConstruction = BTAP::Resources::Envelope::Constructions::create_construction(model, "test construction",[ simple,standard,gas,blind,screen,shade],gas )
              operableWindowConstruction = setDoorConstruction = setGlassDoorConstruction = overheadDoorConstruction = skylightConstruction = tubularDaylightDomeConstruction = tubularDaylightDiffuserConstruction = fixedWindowConstruction
              default_subsurface_constructions = BTAP::Resources::Envelope::ConstructionSets::create_subsurface_construction_set(
                model,
                fixedWindowConstruction,
                operableWindowConstruction,
                setDoorConstruction,
                setGlassDoorConstruction,
                overheadDoorConstruction,
                skylightConstruction,
                tubularDaylightDomeConstruction,
                tubularDaylightDiffuserConstruction)
              assert( !(default_subsurface_constructions.to_DefaultSubSurfaceConstructions.empty?))
            end


            #This method creates default constructions
            #@author phylroy.lopez@nrcan.gc.ca
            def test_create_default_construction_set()
              model = OpenStudio::Model::Model.new()
              #Create layers from defaults
              insulation = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material(model)
              opaque = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material(model)
              air_gap = BTAP::Resources::Envelope::Materials::Opaque::create_air_gap(model)
              massless = BTAP::Resources::Envelope::Materials::Opaque::create_massless_opaque_material(model)
              construction = BTAP::Resources::Envelope::Constructions::create_construction(model, "test construction",[opaque,air_gap,insulation,massless,opaque],insulation )
              walls_cons = floor_cons = roof_cons = construction
              exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions(model,"test construction set",walls_cons,floor_cons,roof_cons)
              interior_construction_set = ground_construction_set = exterior_construction_set

              #Create layers from defaults
              simple = BTAP::Resources::Envelope::Materials::Fenestration::create_simple_glazing(model)
              standard = BTAP::Resources::Envelope::Materials::Fenestration::create_standard_glazing(model)
              gas = BTAP::Resources::Envelope::Materials::Fenestration::create_gas(model)
              blind = BTAP::Resources::Envelope::Materials::Fenestration::create_blind(model)
              screen = BTAP::Resources::Envelope::Materials::Fenestration::create_screen(model)
              shade = BTAP::Resources::Envelope::Materials::Fenestration::create_shade(model)
              fixedWindowConstruction = BTAP::Resources::Envelope::Constructions::create_construction(model, "test construction",[ simple,standard,gas,blind,screen,shade],gas )
              operableWindowConstruction = setDoorConstruction = setGlassDoorConstruction = overheadDoorConstruction = skylightConstruction = tubularDaylightDomeConstruction = tubularDaylightDiffuserConstruction = fixedWindowConstruction
              ext_subsurface_constructions = BTAP::Resources::Envelope::ConstructionSets::create_subsurface_construction_set(
                model,
                fixedWindowConstruction,
                operableWindowConstruction,
                setDoorConstruction,
                setGlassDoorConstruction,
                overheadDoorConstruction,
                skylightConstruction,
                tubularDaylightDomeConstruction,
                tubularDaylightDiffuserConstruction)

              int_subsurface_constructions = ext_subsurface_constructions

              construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_construction_set(
                model,
                "default construction set test",
                exterior_construction_set,
                interior_construction_set,
                ground_construction_set,
                ext_subsurface_constructions,
                int_subsurface_constructions)

              #Check that the construction was created
              assert( !(construction_set.to_DefaultConstructionSet.empty?))
            end
          end
        end

        
        #This method set the default construction set from an OSM library file and the construction set name. 
        #params construction_library_file [String] Path to osm file that contains the contruction set to be used. 
        #params construction_set_name [String] Name of the construction set to be used. 
        def self.set_construction_set_by_file(model, construction_library_file, construction_set_name,runner = nil)
          BTAP::runner_register("Info","set_construction_set_by_file(#{construction_library_file}, #{construction_set_name})")
          #check if file exists
          unless File.exist?(construction_library_file) == true
            BTAP::runner_register("Error", "Could not find #{construction_library_file}", runner) 
            return false
          end
          construction_set = BTAP::Resources::Envelope::ConstructionSets::get_construction_set_from_library( construction_library_file, construction_set_name )
          #check if construction set name exists and can apply to the model. 
          unless model.building.get.setDefaultConstructionSet( construction_set.clone( model ).to_DefaultConstructionSet.get ) 
            BTAP::runner_register("Error", "Could not use default construction set #{construction_set_name} from #{construction_library_file} ", runner) 
            return false
          end
          #sets all surfaces to use default constructions except adiabatic, where it does a hard assignment of the interior wall construction type. 
          model.getPlanarSurfaces.each { |item| item.resetConstruction }
          #if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
          BTAP::Resources::Envelope::assign_interior_surface_construction_to_adiabatic_surfaces( model, runner)
          BTAP::runner_register("Info","set_construction_set_by_file(#{construction_library_file}, #{construction_set_name}) Completed Sucessfully.")
          return true
        end
        
        

        
        #This method customizes default surface construction and sets RSI
        #@author phylroy.lopez@nrcan.gc.ca
        #@params model [OpenStudio::Model::Model]
        #@params name [String]
        #@params default_surface_construction_set <String> 
        #@params ext_wall_rsi [Float] = nil
        #@params ext_floor_rsi [Float] = nil
        #@params ext_roof_rsi [Float] = nil
        #@params ground_wall_rsi [Float] = nil
        #@params ground_floor_rsi [Float] = nil
        #@params ground_roof_rsi [Float] = nil
        #@params fixed_window_rsi [Float] = nil
        #@params fixed_wind_solar_trans [Float] = nil
        #@params fixed_wind_vis_trans [Float] = nil
        #@params operable_window_rsi [Float] = nil
        #@params operable_wind_solar_trans [Float] = nil
        #@params operable_wind_vis_trans [Float] = nil
        #@params door_construction_rsi [Float] = nil
        #@params glass_door_rsi [Float] = nil
        #@params glass_door_solar_trans [Float] = nil
        #@params glass_door_vis_trans [Float] = nil
        #@params overhead_door_rsi [Float] = nil
        #@params skylight_rsi [Float] = nil
        #@params skylight_solar_trans [Float] = nil
        #@params skylight_vis_trans [Float] = nil,
        #@params tubular_daylight_dome_rsi [Float] = nil
        #@params tubular_daylight_dome_solar_trans [Float] = nil
        #@params tubular_daylight_dome_vis_trans [Float] = nil,
        #@params tubular_daylight_diffuser_rsi [Float] = nil
        #@params tubular_daylight_diffuser_solar_trans [Float] = nil
        #@params tubular_daylight_diffuser_vis_trans [Float] = nil
        def self.customize_default_surface_construction_set_rsi!(model,name,default_surface_construction_set,
            ext_wall_rsi = nil, ext_floor_rsi = nil, ext_roof_rsi = nil,
            ground_wall_rsi = nil, ground_floor_rsi = nil, ground_roof_rsi = nil,
            fixed_window_rsi = nil, fixed_wind_solar_trans = nil , fixed_wind_vis_trans = nil,
            operable_window_rsi = nil, operable_wind_solar_trans = nil , operable_wind_vis_trans = nil,
            door_construction_rsi = nil,
            glass_door_rsi = nil,  glass_door_solar_trans = nil , glass_door_vis_trans = nil,
            overhead_door_rsi = nil,
            skylight_rsi = nil,  skylight_solar_trans = nil , skylight_vis_trans = nil,
            tubular_daylight_dome_rsi = nil,  tubular_daylight_dome_solar_trans = nil , tubular_daylight_dome_vis_trans = nil,
            tubular_daylight_diffuser_rsi = nil, tubular_daylight_diffuser_solar_trans = nil , tubular_daylight_diffuser_vis_trans = nil
          )
          #Change name if required.
          default_surface_construction_set.setName( name) unless name.nil?
          ext_surface_set = default_surface_construction_set.defaultExteriorSurfaceConstructions.get
          new_ext_surface_set = self.customize_default_surface_constructions_rsi(model, name, ext_surface_set, ext_wall_rsi, ext_floor_rsi, ext_roof_rsi)
          raise ("Could not customized exterior constructionset") unless default_surface_construction_set.setDefaultExteriorSurfaceConstructions(new_ext_surface_set)

          ground_surface_set = default_surface_construction_set.defaultGroundContactSurfaceConstructions.get
          new_ground_surface_set = self.customize_default_surface_constructions_rsi(model, name, ground_surface_set, ground_wall_rsi, ground_floor_rsi, ground_roof_rsi)
          raise ("Could not customized ground constructionset") unless default_surface_construction_set.setDefaultGroundContactSurfaceConstructions(new_ground_surface_set)

          ext_subsurface_set = default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get
          new_ext_subsurface_set = self.customize_default_sub_surface_constructions_rsi(
            model,
            name,
            ext_subsurface_set,
            fixed_window_rsi, fixed_wind_solar_trans , fixed_wind_vis_trans,
            operable_window_rsi, operable_wind_solar_trans, operable_wind_vis_trans,
            door_construction_rsi,
            glass_door_rsi,  glass_door_solar_trans, glass_door_vis_trans,
            overhead_door_rsi,
            skylight_rsi,  skylight_solar_trans, skylight_vis_trans,
            tubular_daylight_dome_rsi,  tubular_daylight_dome_solar_trans, tubular_daylight_dome_vis_trans,
            tubular_daylight_diffuser_rsi, tubular_daylight_diffuser_solar_trans, tubular_daylight_diffuser_vis_trans
          )
          raise ("Could not customized ground constructionset") unless default_surface_construction_set.setDefaultExteriorSubSurfaceConstructions(new_ext_subsurface_set)
        end


        #This will remove all associated construction costs for each construction
        #type associated with the construction set. Unless the value is set to nil, in which case it will do nothing.
        #@author phylroy.lopez@nrcan.gc.ca
        #@params model [OpenStudio::Model::Model]
        #@params default_surface_construction_set <String>
        #@params ext_wall_cost [Float] = nil
        #@params ext_floor_cost [Float] = nil
        #@params ext_roof_cost [Float] = nil
        #@params ground_wall_cost [Float] = nil
        #@params ground_floor_cost [Float] = nil
        #@params ground_roof_cost [Float] = nil
        #@params fixed_window_cost [Float] = nil
        #@params operable_window_cost [Float] = nil
        #@params door_construction_cost [Float] = nil
        #@params glass_door_cost [Float] = nil
        #@params overhead_door_cost [Float] = nil
        #@params skylight_cost [Float] = nil
        #@params tubular_daylight_dome_cost [Float] = nil
        #@params tubular_daylight_diffuser_cost [Float] = nil
        #@params total_building_construction_set_cost [Float] = nil
        def self.customize_default_surface_construction_set_costs(default_surface_construction_set,
            ext_wall_cost = nil,
            ext_floor_cost = nil,
            ext_roof_cost = nil,
            ground_wall_cost = nil,
            ground_floor_cost = nil,
            ground_roof_cost = nil,
            fixed_window_cost = nil,
            operable_window_cost = nil,
            door_construction_cost = nil,
            glass_door_cost = nil,
            overhead_door_cost = nil,
            skylight_cost = nil,
            tubular_daylight_dome_cost = nil,
            tubular_daylight_diffuser_cost = nil,
            total_building_construction_set_cost = nil
          )

          constructions_and_cost = [
            ["ext_wall_cost_m3",ext_wall_cost, default_surface_construction_set.defaultExteriorSurfaceConstructions.get.wallConstruction.get],
            ["ext_floor_cost_m3", ext_floor_cost, default_surface_construction_set.defaultExteriorSurfaceConstructions.get.floorConstruction.get],
            ["ext_roof_cost_m3",ext_roof_cost, default_surface_construction_set.defaultExteriorSurfaceConstructions.get.roofCeilingConstruction.get],
            ["ground_wall_cost_m3",ground_wall_cost, default_surface_construction_set.defaultGroundContactSurfaceConstructions.get.wallConstruction.get],
            ["ground_floor_cost_m3",ground_floor_cost, default_surface_construction_set.defaultGroundContactSurfaceConstructions.get.floorConstruction.get],
            ["ground_roof_cost_m3",ground_roof_cost, default_surface_construction_set.defaultGroundContactSurfaceConstructions.get.roofCeilingConstruction.get],
            ["fixed_window_cost_m3",fixed_window_cost, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.fixedWindowConstruction.get],
            ["operable_window_cost_m3",operable_window_cost, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.operableWindowConstruction.get],
            ["door_construction_cost_m3",door_construction_cost, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.doorConstruction.get],
            ["glass_door_cost_m3",glass_door_cost, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.glassDoorConstruction.get],
            ["overhead_door_cost_m3",overhead_door_cost, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.overheadDoorConstruction.get],
            ["skylight_cost_m3",skylight_cost, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.skylightConstruction.get],
            ["tubular_daylight_dome_cost_m3",tubular_daylight_dome_cost, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.tubularDaylightDomeConstruction.get],
            ["tubular_daylight_diffuser_cost_m3" ,tubular_daylight_diffuser_cost , default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.tubularDaylightDiffuserConstruction.get]
          ]


          #Assign cost to each construction.
          constructions_and_cost.each do |item|
            unless item[1].nil?
              item[2].removeLifeCycleCosts()
              raise("Could not remove LCC info from construction #{item[2]}") unless item[2].lifeCycleCosts.size == 0
              construction_cost_object = OpenStudio::Model::LifeCycleCost.new(item[2])
              construction_cost_object.setName(item[0])
              construction_cost_object.setCost(item[1])
              construction_cost_object.setCostUnits("CostPerArea")
            end
          end
          #create building total construction cost if needed.
          building = default_surface_construction_set.model.building.get
          BTAP::Resources::Economics::object_cost(building, "Builing Contruction Set Whole Building Capital Cost", total_building_construction_set_cost, "CostPerEach")
        end

        #This will customize default surface construction.
        #@author phylroy.lopez@nrcan.gc.ca
        #@params model [OpenStudio::Model::Model]
        #@params name [String]
        #@params subsurface_set [Float] = nil
        #@params fixed_window_rsi [Float] = nil
        #@paramsfixed_wind_solar_trans [Float] = nil
        #@paramsfixed_wind_vis_trans [Float] = nil,
        #@paramsoperable_window_rsi [Float] = nil
        #@params operable_wind_solar_trans [Float] = nil
        #@params operable_wind_vis_trans [Float] = nil
        #@params door_construction_rsi [Float] = nil
        #@params glass_door_rsi [Float] = nil
        #@params glass_door_solar_trans [Float] = nil
        #@params glass_door_vis_trans [Float] = nil
        #@params overhead_door_rsi [Float] = nil
        #@params skylight_rsi [Float] = nil
        #@params skylight_solar_trans [Float] = nil
        #@params skylight_vis_trans [Float] = nil,
        #@params tubular_daylight_dome_rsi [Float] = nil
        #@params tubular_daylight_dome_solar_trans [Float] = nil
        #@params tubular_daylight_dome_vis_trans [Float] = nil
        #@params tubular_daylight_diffuser_rsi [Float] = nil
        #@params tubular_daylight_diffuser_solar_trans [Float] = nil
        #@params tubular_daylight_diffuser_vis_trans [Float] = nil
        def self.customize_default_sub_surface_constructions_rsi(
            model,
            name,
            subsurface_set,
            fixed_window_rsi = nil, fixed_wind_solar_trans = nil , fixed_wind_vis_trans = nil,
            operable_window_rsi = nil, operable_wind_solar_trans = nil , operable_wind_vis_trans = nil,
            door_construction_rsi = nil,
            glass_door_rsi = nil,  glass_door_solar_trans = nil , glass_door_vis_trans = nil,
            overhead_door_rsi = nil,
            skylight_rsi = nil,  skylight_solar_trans = nil , skylight_vis_trans = nil,
            tubular_daylight_dome_rsi = nil,  tubular_daylight_dome_solar_trans = nil , tubular_daylight_dome_vis_trans = nil,
            tubular_daylight_diffuser_rsi = nil, tubular_daylight_diffuser_solar_trans = nil , tubular_daylight_diffuser_vis_trans = nil
          )

          fixed_window_rsi.nil? ? fixed_window_conductance = nil : fixed_window_conductance = 1.0 / fixed_window_rsi
          operable_window_rsi.nil? ? operable_window_conductance = nil : operable_window_conductance = 1.0 / operable_window_rsi
          door_construction_rsi.nil? ? door_construction_conductance = nil : door_construction_conductance = 1.0 / door_construction_rsi
          glass_door_rsi.nil? ? glass_door_conductance = nil : glass_door_conductance = 1.0 / glass_door_rsi
          overhead_door_rsi.nil? ? overhead_door_conductance = nil : overhead_door_conductance = 1.0 / overhead_door_rsi
          skylight_rsi.nil? ? skylight_conductance = nil : skylight_conductance = 1.0 / skylight_rsi
          tubular_daylight_dome_rsi.nil? ? tubular_daylight_dome_conductance = nil : tubular_daylight_dome_conductance = 1.0 / tubular_daylight_dome_rsi
          tubular_daylight_diffuser_rsi.nil? ? tubular_daylight_diffuser_conductance = nil : tubular_daylight_diffuser_conductance = 1.0 / tubular_daylight_diffuser_rsi

          self.customize_default_sub_surface_constructions_conductance(
            model,
            name,
            subsurface_set,
            fixed_window_conductance, fixed_wind_solar_trans  , fixed_wind_vis_trans ,
            operable_window_conductance , operable_wind_solar_trans  , operable_wind_vis_trans ,
            door_construction_conductance ,
            glass_door_conductance ,  glass_door_solar_trans  , glass_door_vis_trans ,
            overhead_door_conductance ,
            skylight_conductance ,  skylight_solar_trans  , skylight_vis_trans ,
            tubular_daylight_dome_conductance ,  tubular_daylight_dome_solar_trans  , tubular_daylight_dome_vis_trans ,
            tubular_daylight_diffuser_conductance , tubular_daylight_diffuser_solar_trans  , tubular_daylight_diffuser_vis_trans
          )

        end


        #This will customize default subsurface construction conductances.
        #@author phylroy.lopez@nrcan.gc.ca
        #@params model [OpenStudio::Model::Model]
        #@params name [String]
        #@params subsurface_set,
        #@params fixed_window_conductance [Float] = nil
        #@params fixed_wind_solar_trans [Float] = nil
        #@params fixed_wind_vis_trans [Float] = nil
        #@params operable_window_conductance [Float] = nil
        #@params operable_wind_solar_trans [Float] = nil
        #@params  perable_wind_vis_trans [Float] = nil
        #@params door_construction_conductance [Float] = nil
        #@params glass_door_conductance [Float] = nil
        #@params glass_door_solar_trans [Float] = nil
        #@params glass_door_vis_trans [Float] = nil
        #@params overhead_door_conductance [Float] = nil
        #@params skylight_conductance [Float] = nil
        #@params skylight_solar_trans [Float] = nil
        #@params skylight_vis_trans [Float] = nil
        #@params tubular_daylight_dome_conductance [Float] = nil
        #@params tubular_daylight_dome_solar_trans [Float] = nil
        #@params tubular_daylight_dome_vis_trans [Float] = nil
        #@params tubular_daylight_diffuser_conductance [Float] = nil
        #@params tubular_daylight_diffuser_solar_trans [Float] = nil
        #@params tubular_daylight_diffuser_vis_trans [Float] = nil
        #@return set [Object]
        def self.customize_default_sub_surface_constructions_conductance(
            model,
            name,
            subsurface_set,
            fixed_window_conductance = nil, fixed_wind_solar_trans = nil , fixed_wind_vis_trans = nil,
            operable_window_conductance = nil, operable_wind_solar_trans = nil , operable_wind_vis_trans = nil,
            door_construction_conductance = nil,
            glass_door_conductance = nil,  glass_door_solar_trans = nil , glass_door_vis_trans = nil,
            overhead_door_conductance = nil,
            skylight_conductance = nil,  skylight_solar_trans = nil , skylight_vis_trans = nil,
            tubular_daylight_dome_conductance = nil,  tubular_daylight_dome_solar_trans = nil , tubular_daylight_dome_vis_trans = nil,
            tubular_daylight_diffuser_conductance = nil, tubular_daylight_diffuser_solar_trans = nil , tubular_daylight_diffuser_vis_trans = nil
          )
          set = OpenStudio::Model::DefaultSubSurfaceConstructions.new(model)
          set.setName( name )
          set.setFixedWindowConstruction( BTAP::Resources::Envelope::Constructions::customize_fenestration_construction(model, subsurface_set.fixedWindowConstruction.get, fixed_window_conductance, fixed_wind_solar_trans, fixed_wind_vis_trans) )
          set.setOperableWindowConstruction( BTAP::Resources::Envelope::Constructions::customize_fenestration_construction(model, subsurface_set.operableWindowConstruction.get, operable_window_conductance, operable_wind_solar_trans, operable_wind_vis_trans) )
          set.setDoorConstruction( BTAP::Resources::Envelope::Constructions::customize_opaque_construction(model, subsurface_set.doorConstruction.get, door_construction_conductance) )
          set.setGlassDoorConstruction( BTAP::Resources::Envelope::Constructions::customize_fenestration_construction(model, subsurface_set.glassDoorConstruction.get, glass_door_conductance, glass_door_solar_trans, glass_door_vis_trans) )
          set.setOverheadDoorConstruction( BTAP::Resources::Envelope::Constructions::customize_opaque_construction(model, subsurface_set.overheadDoorConstruction.get, overhead_door_conductance) )
          set.setSkylightConstruction( BTAP::Resources::Envelope::Constructions::customize_fenestration_construction(model, subsurface_set.skylightConstruction.get, skylight_conductance, skylight_solar_trans, skylight_vis_trans) )
          set.setTubularDaylightDomeConstruction( BTAP::Resources::Envelope::Constructions::customize_fenestration_construction(model, subsurface_set.tubularDaylightDomeConstruction.get, tubular_daylight_dome_conductance, tubular_daylight_dome_solar_trans, tubular_daylight_dome_vis_trans) )
          set.setTubularDaylightDiffuserConstruction( BTAP::Resources::Envelope::Constructions::customize_fenestration_construction(model, subsurface_set.tubularDaylightDiffuserConstruction.get, tubular_daylight_diffuser_conductance, tubular_daylight_diffuser_solar_trans, tubular_daylight_diffuser_vis_trans) )
          return set
        end

        #This will customize default surface construction rsi.
        #@author phylroy.lopez@nrcan.gc.ca
        #@params model [OpenStudio::Model::Model]
        #@params name [String] = nil
        #@params default_surface_constructions [Float] = nil
        #@params wall_rsi [Float] = nil
        #@params floor_rsi [Float] = nil
        #@params roof_rsi [Float] = nil
        def self.customize_default_surface_constructions_rsi(model,name,default_surface_constructions,wall_rsi = nil, floor_rsi = nil, roof_rsi = nil)

          wall_rsi.nil? ? wall_conductance  = nil  : wall_conductance  = 1.0 / wall_rsi
          floor_rsi.nil? ? floor_conductance = nil : floor_conductance = 1.0 / floor_rsi
          roof_rsi.nil? ? roof_conductance  = nil  : roof_conductance  = 1.0 / roof_rsi

          self.customize_default_surface_constructions_conductance(model,name,default_surface_constructions,wall_conductance , floor_conductance, roof_conductance)
        end

        #This will customize default surface construction conductance.
        #@author phylroy.lopez@nrcan.gc.ca
        #@params model [OpenStudio::Model::Model]
        #@params name [String] = nil
        #@params default_surface_constructions [Float] = nil
        #@params wall_conductance [Float] = nil
        #@params floor_conductance [Float] = nil
        #@params roof_conductance [Float] = nil
        #@return set [Object]
        def self.customize_default_surface_constructions_conductance(model,name,default_surface_constructions,wall_conductance = nil, floor_conductance = nil, roof_conductance = nil)
          set = OpenStudio::Model::DefaultSurfaceConstructions.new(model)
          set.setName( name)
          set.setFloorConstruction(Resources::Envelope::Constructions::customize_opaque_construction(model, default_surface_constructions.floorConstruction.get, floor_conductance)) unless floor_conductance.nil?
          set.setWallConstruction(Resources::Envelope::Constructions::customize_opaque_construction(model, default_surface_constructions.wallConstruction.get, wall_conductance)) unless wall_conductance.nil?
          set.setRoofCeilingConstruction(Resources::Envelope::Constructions::customize_opaque_construction(model, default_surface_constructions.roofCeilingConstruction.get, roof_conductance)) unless roof_conductance.nil?
          return set
        end



        #This creates a new construction set of wall, floor and roof/ceiling objects.
        #@author phylroy.lopez@nrcan.gc.ca
        #@params model [OpenStudio::Model::Model]
        #@params name [String] = nil
        #@params wall [Float] = nil
        #@params floor [Float] = nil
        #@params roof [Float] = nil
        #@return set [Object]
        def self.create_default_surface_constructions(model,name,wall,floor,roof)
          wall = BTAP::Common::validate_array(model,wall,"Construction").first
          floor = BTAP::Common::validate_array(model,floor,"Construction").first
          roof = BTAP::Common::validate_array(model,roof,"Construction").first
          set = OpenStudio::Model::DefaultSurfaceConstructions.new(model)
          set.setFloorConstruction(floor)
          set.setWallConstruction(wall)
          set.setRoofCeilingConstruction(roof)
          set.setName( name)
          return set
        end

        #This method creates a subsurface construction set (windows, doors, skylights, etc)
        #@author phylroy.lopez@nrcan.gc.ca
        #@params model [OpenStudio::Model::Model]
        #@params fixedWindowConstruction <String>
        #@params operableWindowConstruction <String>
        #@params setDoorConstruction <String>
        #@params setGlassDoorConstruction <String>
        #@params overheadDoorConstruction <String>
        #@params skylightConstruction <String>
        #@params tubularDaylightDomeConstruction <String>
        #@params tubularDaylightDiffuserConstruction <String>
        #@return set [Object]
        def self.create_subsurface_construction_set(
            model,
            fixedWindowConstruction,
            operableWindowConstruction,
            setDoorConstruction,
            setGlassDoorConstruction,
            overheadDoorConstruction,
            skylightConstruction,
            tubularDaylightDomeConstruction,
            tubularDaylightDiffuserConstruction)
          fixedWindowConstruction = BTAP::Common::validate_array(model,fixedWindowConstruction,"Construction").first
          operableWindowConstruction = BTAP::Common::validate_array(model,operableWindowConstruction,"Construction").first
          setDoorConstruction =  BTAP::Common::validate_array(model,setDoorConstruction,"Construction").first
          setGlassDoorConstruction =  BTAP::Common::validate_array(model,setGlassDoorConstruction,"Construction").first
          overheadDoorConstruction  = BTAP::Common::validate_array(model,overheadDoorConstruction,"Construction").first
          skylightConstruction=  BTAP::Common::validate_array(model,skylightConstruction,"Construction").first
          tubularDaylightDomeConstruction =  BTAP::Common::validate_array(model,tubularDaylightDomeConstruction,"Construction").first
          tubularDaylightDiffuserConstruction = BTAP::Common::validate_array(model,tubularDaylightDiffuserConstruction,"Construction").first

          set = OpenStudio::Model::DefaultSubSurfaceConstructions.new(model)
          set.setFixedWindowConstruction(             fixedWindowConstruction) unless fixedWindowConstruction.nil?
          set.setOperableWindowConstruction(          operableWindowConstruction) unless operableWindowConstruction.nil?
          set.setDoorConstruction(                    setDoorConstruction) unless setDoorConstruction.nil?
          set.setGlassDoorConstruction(               setGlassDoorConstruction) unless setGlassDoorConstruction.nil?
          set.setOverheadDoorConstruction(            overheadDoorConstruction) unless overheadDoorConstruction.nil?
          set.setSkylightConstruction(                skylightConstruction) unless skylightConstruction.nil?
          set.setTubularDaylightDomeConstruction(     tubularDaylightDomeConstruction) unless tubularDaylightDomeConstruction.nil?
          set.setTubularDaylightDiffuserConstruction( tubularDaylightDiffuserConstruction) unless tubularDaylightDiffuserConstruction.nil?
          return set
        end
        
        #This method gets construction set object from external library
        #@author phylroy.lopez@nrcan.gc.ca
        #@params construction_library_file [String]
        #@params construction_set_name [String]
        #@return optional_construction_set [Boolean]
        def self.get_construction_set_from_library( construction_library_file, construction_set_name )
          #Load Contruction osm library.
          if File.exists?(construction_library_file) 
            construction_lib = BTAP::FileIO::load_osm( construction_library_file )
            #Get construction set.. 
            optional_construction_set = construction_lib.getDefaultConstructionSetByName(construction_set_name)
            if optional_construction_set.empty?
              raise("#{construction_set_name} does not exist in #{construction_library_file} library ")
            else
              return optional_construction_set.get
            end
          else
            raise("Error : Construction Lib #{construction_library_file} does not exist!")
          end
          return false
        end 
        

        #This method creates a default construction set. A construction set for
        #exterior, interior,ground and subsurface must be created prior to populate
        #this object.
        #@author phylroy.lopez@nrcan.gc.ca
        #@params model [OpenStudio::Model::Model]
        #@params name [String]
        #@params exterior_construction_set
        #@params interior_construction_set
        #@params ground_construction_set
        #@params subsurface_exterior_construction_set
        #@params subsurface_interior_construction_set
        #@return set [Object]
        def self.create_default_construction_set(
            model,
            name,
            exterior_construction_set,
            interior_construction_set,
            ground_construction_set,
            subsurface_exterior_construction_set,
            subsurface_interior_construction_set)
          exterior_construction_set = BTAP::Common::validate_array(model,exterior_construction_set,"DefaultSurfaceConstructions").first
          interior_construction_set = BTAP::Common::validate_array(model,interior_construction_set,"DefaultSurfaceConstructions").first
          ground_construction_set   = BTAP::Common::validate_array(model,ground_construction_set,"DefaultSurfaceConstructions").first
          subsurface_exterior_construction_set =  BTAP::Common::validate_array(model,subsurface_exterior_construction_set,"DefaultSubSurfaceConstructions").first
          subsurface_interior_construction_set  = BTAP::Common::validate_array(model,subsurface_interior_construction_set,"DefaultSubSurfaceConstructions").first


          set = OpenStudio::Model::DefaultConstructionSet.new(model)
          set.setDefaultExteriorSurfaceConstructions(exterior_construction_set) unless exterior_construction_set.nil?
          set.setDefaultGroundContactSurfaceConstructions(ground_construction_set) unless ground_construction_set.nil?
          set.setDefaultInteriorSurfaceConstructions(interior_construction_set) unless interior_construction_set.nil?
          set.setDefaultExteriorSubSurfaceConstructions(subsurface_exterior_construction_set) unless subsurface_exterior_construction_set.nil?
          set.setDefaultInteriorSubSurfaceConstructions(subsurface_interior_construction_set) unless subsurface_interior_construction_set.nil?
          set.setName( name)
          return set
        end

        #This method creates a default construction set. A construction set for
        #exterior, interior,ground and subsurface must be created prior to populate
        #this object.
        #@author phylroy.lopez@nrcan.gc.ca
        #@params default_surface_construction_set [Object]
        #@return table [String]
        def self.get_construction_set_info(default_surface_construction_set)
          #######################
          constructions_and_cost = [
            ["ext_wall",default_surface_construction_set.defaultExteriorSurfaceConstructions.get.wallConstruction.get],
            ["ext_floor", default_surface_construction_set.defaultExteriorSurfaceConstructions.get.floorConstruction.get],
            ["ext_roof",default_surface_construction_set.defaultExteriorSurfaceConstructions.get.roofCeilingConstruction.get],
            ["ground_wall",default_surface_construction_set.defaultGroundContactSurfaceConstructions.get.wallConstruction.get],
            ["ground_floor", default_surface_construction_set.defaultGroundContactSurfaceConstructions.get.floorConstruction.get],
            ["ground_roof",default_surface_construction_set.defaultGroundContactSurfaceConstructions.get.roofCeilingConstruction.get],
            ["fixed_window", default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.fixedWindowConstruction.get],
            ["operable_window", default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.operableWindowConstruction.get],
            ["door_construction", default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.doorConstruction.get],
            ["glass_door", default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.glassDoorConstruction.get],
            ["overhead_door", default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.overheadDoorConstruction.get],
            ["skylight", default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.skylightConstruction.get],
            ["tubular_daylight_dome", default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.tubularDaylightDomeConstruction.get],
            ["tubular_daylight_diffuser" , default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.tubularDaylightDiffuserConstruction.get]
          ]
          default_surface_construction_set.name
          table = "construction,rsi,cost_m3\n"
          constructions_and_cost.each do |item|
            cost_item = OpenStudio::Model::getLifeCycleCostByName(default_surface_construction_set.model,"#{item[0]}_cost_m3")
            #ensure it exists
            cost = "NA"
            cost = cost_item.cost unless cost_item.empty?
            rsi = BTAP::Resources::Envelope::Constructions::get_rsi(item[1])
            table << "#{item[0]},#{rsi},#{cost}\n"
          end
          return table
        end
      end #module ConstructionSet
    end #Envelope
  end #module Resources
end