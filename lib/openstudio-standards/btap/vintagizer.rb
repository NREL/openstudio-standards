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

# To change this template, choose Tools | Templates
# and open the template in the editor.

class Vintagizer

  #This method loads Vintage database information.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::Model::Model] A model object
  #@param file [String]
  #@param selectionHash [???]
  def initialize(model,file,selectionHash)
    #Load Vintage database information.
  end

  #This method will (????).
  #@author phylroy.lopez@nrcan.gc.ca
  #@param construction_file [String]
  #@param construction_set_name [String]
  #@param vintage [String]
  #@param building_type [String]
  #@param climate_zone [String]
  #@return [String] climate_zone
  def envelope(construction_file,construction_set_name,vintage,building_type,climate_zone)

    #Load Construction Lib set. "C:/OSRuby/Resources/DND/Trenton/TrentonConstructionsLibrary.osm"
    construction_lib = BTAP::FileIO::load_osm(construction_file)
    #Create temp model library.
    library = BTAP::FileIO::load_osm("C:/OSRuby/Resources/DOEArchetypes/blank.osm", "blank")
    #get construction set by type and vintage.. I/O expensive so doing it here.
    vintage_construction_set = construction_lib.getDefaultConstructionSetByName("#{ construction_type[0] }#{ vintage }").get

    #Construct name for new construction set.
    construction_id = "#{construction_type[0]}-#{vintage}-#{wall_retrofit[0]}-#{roof_retrofit[0]}-#{glazing_retrofit[0]}"

    new_construction_set =vintage_construction_set.clone(library).to_DefaultConstructionSet.get

    new_construction_set =vintage_construction_set.clone(library).to_DefaultConstructionSet.get
    #Set conductances to needed values in construction set if possible.
    BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(
      library,
      construction_id,
      new_construction_set,
      1.0 / ext_wall_ecm_info[0],
      1.0 / ext_roof_ecm_info[0],
      1.0 / ext_roof_ecm_info[0],
      1.0 / ground_cond[0],
      1.0 / ground_cond[0],
      1.0 / ground_cond[0],
      glazing_ecm_info[0],
      glazing_ecm_info[1],
      glazing_ecm_info[2],
      glazing_ecm_info[0],
      glazing_ecm_info[1],
      glazing_ecm_info[2]
    )

    #Define costs
    BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_costs(new_construction_set,
      ext_wall_ecm_info[1],
      ext_roof_ecm_info[1],
      ext_roof_ecm_info[1],
      ground_cond[1],
      ground_cond[1],
      ground_cond[1],
      glazing_ecm_info[3],
      glazing_ecm_info[3],
      0.0, #doors
      0.0, #glass doors
      0.0, #overhead doors
      0.0, #skylight
      0.0, #tubular_daylight_dome_cost =
      0.0 #tubular_daylight_diffuser_cost
    )

    #Remove all existing constructions from model.
    BTAP::Resources::Envelope::remove_all_envelope_information( constructions_model )
    #Save to model.
    new_construction_set.setName(construction_id)
    constructions_model.building.get.setDefaultConstructionSet( new_construction_set.clone( constructions_model ).to_DefaultConstructionSet.get )

    #Give adiabatic surfaces a construction. Does not matter what. This is a bug in OpenStudio that leave these surfaces unassigned by the default construction set.
    all_adiabatic_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(constructions_model.getSurfaces, "Adiabatic")
    wall_construction = constructions_model.building.get.defaultConstructionSet.get.defaultInteriorSurfaceConstructions.get.wallConstruction.get
    all_adiabatic_surfaces.each { |surface| surface.setConstruction(wall_construction) }
  end

  #This method will set infiltration magnitude.
  #@author phylroy.lopez@nrcan.gc.ca
  def infiltration()
    BTAP::Resources::SpaceLoads::ScaleLoads::set_inflitration_magnitude( constructions_model,
      0.0, #setDesignFlowRate,
      0.0, #setFlowperSpaceFloorArea,
      0.0, #setFlowperExteriorSurfaceArea,
      0.0  #setAirChangesperHour
    )
  end

  #This method will get and set the coiling coil fan Speed COP
  #@author phylroy.lopez@nrcan.gc.ca
  def fan_eff()
    #DX Coil COP ECMs
    unless 'default' == cop_info[1]
      constructions_model.getCoilCoolingDXSingleSpeeds.sort.each do |cooling_coil|
        cooling_coil.setRatedCOP( OpenStudio::OptionalDouble.new( cop_info[1][0] ))
      end
      constructions_model.getCoilCoolingDXTwoSpeeds.sort.each do |cooling_coil|
        cooling_coil.setRatedHighSpeedCOP( OpenStudio::OptionalDouble.new( cop_info[1][0] ) )
        cooling_coil.setRatedLowSpeedCOP( OpenStudio::OptionalDouble.new( cop_info[1][0] ))
      end
    end
  end

  #This method will get and set the coiling coil pump Speed COP
  #@author phylroy.lopez@nrcan.gc.ca
  def pump_eff()
    #DX Coil COP ECMs
    unless 'default' == cop_info[1]
      constructions_model.getCoilCoolingDXSingleSpeeds.sort.each do |cooling_coil|
        cooling_coil.setRatedCOP( OpenStudio::OptionalDouble.new( cop_info[1][0] ))
      end
      constructions_model.getCoilCoolingDXTwoSpeeds.sort.each do |cooling_coil|
        cooling_coil.setRatedHighSpeedCOP( OpenStudio::OptionalDouble.new( cop_info[1][0] ) )
        cooling_coil.setRatedLowSpeedCOP( OpenStudio::OptionalDouble.new( cop_info[1][0] ))
      end
    end
  end

  #This method will set the coiling coil COP
  #@author phylroy.lopez@nrcan.gc.ca
  def cop()
    #DX Coil COP ECMs
    unless 'default' == cop_info[1]
      constructions_model.getCoilCoolingDXSingleSpeeds.sort.each do |cooling_coil|
        cooling_coil.setRatedCOP( OpenStudio::OptionalDouble.new( cop_info[1][0] ) )
      end
      constructions_model.getCoilCoolingDXTwoSpeeds.sort.each do |cooling_coil|
        cooling_coil.setRatedHighSpeedCOP( OpenStudio::OptionalDouble.new( cop_info[1][0] ) )
        cooling_coil.setRatedLowSpeedCOP( OpenStudio::OptionalDouble.new( cop_info[1][0] ) )
      end
    end
  end
end