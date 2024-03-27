# This class holds methods that apply NECB2020 rules.

# Notes for adding new version of NECB:
#  Essentially all you need to do is copy this file to a new folder and update the class name (only the initialize and load_standards_database_new methods are required,
#  everything else will be inherited. Only add methods, json files and other rb files if the content/functionality has changed. Do not forget to update the class name in the rb files!
#  The spacetypes and led lighting json files are required (in the data folder) as they have the NECB version hardcoded (which requires updating).
#  However there are a few other files to update:
#  1) NECB2011/necb_2011.rb:determine_spacetype_vintage method has an array of available versions of NECB hardcoded. Add the new one.
#  2) common/space_type_upgrade_map.json needs all the space types for the new version defined (386 in NECB 2020).
#  3) Add references to the rb files in this folder to openstudio_standards.rb

# @ref [References::NECB2020]
class NECB2020 < NECB2017
  @template = self.new.class.name # rubocop:disable Style/ClassVars
  register_standard(@template)

  def initialize
    super()
    @template = self.class.name
    @standards_data = self.load_standards_database_new()
    self.corrupt_standards_database()
  end

  def load_standards_database_new
    # load NECB2020 data.
    super()

    if __dir__[0] == ':' # Running from OpenStudio CLI
      embedded_files_relative('data/', /.*\.json/).each do |file|
        data = JSON.parse(EmbeddedScripting.getFileAsString(file))
        if !data['tables'].nil?
          @standards_data['tables'] = [*@standards_data['tables'], *data['tables']].to_h
        elsif !data['constants'].nil?
          @standards_data['constants'] = [*@standards_data['constants'], *data['constants']].to_h
        elsif !data['constants'].nil?
          @standards_data['formulas'] = [*@standards_data['formulas'], *data['formulas']].to_h
        end
      end
    else
      files = Dir.glob("#{File.dirname(__FILE__)}/data/*.json").select { |e| File.file? e }
      files.each do |file|
        data = JSON.parse(File.read(file))
        if !data['tables'].nil?
          @standards_data['tables'] = [*@standards_data['tables'], *data['tables']].to_h
        elsif !data['constants'].nil?
          @standards_data['constants'] = [*@standards_data['constants'], *data['constants']].to_h
        elsif !data['formulas'].nil?
          @standards_data['formulas'] = [*@standards_data['formulas'], *data['formulas']].to_h
        end
      end
    end
    # Write test report file.
    # Write database to file.
    # File.open(File.join(File.dirname(__FILE__), '..', 'NECB2017.json'), 'w') {|f| f.write(JSON.pretty_generate(@standards_data))}
    return @standards_data
  end

  # Set the infiltration rate for this space to include
  # the impact of air leakage requirements in the standard.
  #
  # Note that this is significantly different for NECB 2020 compared to previous codes.
  #  The value is now specified at 75 Pa normalised by entire building surface area (previously 5 Pa
  #  and for above grade surfaces only). Need to convert to 5 Pa and for the different surface area.
  #
  # @return [Double] true if successful, false if not
  # @todo handle doors and vestibules
  def space_apply_infiltration_rate(space)

    # Remove infiltration rates set at the space type.
    infiltration_data = @standards_data['infiltration']
    unless space.spaceType.empty?
      space.spaceType.get.spaceInfiltrationDesignFlowRates.each(&:remove)
    end
    # Remove infiltration rates set at the space object.
    space.spaceInfiltrationDesignFlowRates.each(&:remove)

    # Don't create an object if there is no exterior wall area.
    exterior_wall_and_roof_and_subsurface_area = OpenstudioStandards::Geometry.space_get_exterior_wall_and_subsurface_and_roof_area(space)
    if exterior_wall_and_roof_and_subsurface_area <= 0.0
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Standards.Model', "For #{template}, no exterior wall area was found in #{space.name}; no infiltration will be added.")
      return true
    end

    # Calculate total area of above and below grade envelope area in the entire model.
    totalAreaBuildingEnvelope = 0.0
    totalAboveGradeArea = 0.0

	space.model.getSpaces.each do |modelspace|
	  multiplier = modelspace.multiplier
	  modelspace.surfaces.each do |surface|
	    if surface.outsideBoundaryCondition == "Outdoors" then
		  area = surface.grossArea * multiplier
          totalAreaBuildingEnvelope += area
          totalAboveGradeArea += area
		elsif surface.outsideBoundaryCondition == "Ground" then
		  area = surface.grossArea * multiplier
          totalAreaBuildingEnvelope += area
		end
	  end
	end

	# Get infiltration rate from standards and convert to value at 5 Pa applied to all above grade surfaces.
    infil_75Pa_all_surf = self.get_standards_constant('infiltration_rate_m3_per_s_per_m2')
    infil_5Pa_above_grade = infil_75Pa_all_surf * ((5.0 / 75.0) ** (0.6)) * totalAreaBuildingEnvelope / totalAboveGradeArea
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Space', "For #{space.name}, adj infil = #{infil_5Pa_above_grade.round(5)} m^3/s*m^2.")

    # Get any infiltration schedule already assigned to this space or its space type
    # If not, the always on schedule will be applied.
    infil_sch = nil
    unless space.spaceInfiltrationDesignFlowRates.empty?
      old_infil = space.spaceInfiltrationDesignFlowRates[0]
      if old_infil.schedule.is_initialized
        infil_sch = old_infil.schedule.get
      end
    end

    if infil_sch.nil? && space.spaceType.is_initialized
      space_type = space.spaceType.get
      unless space_type.spaceInfiltrationDesignFlowRates.empty?
        old_infil = space_type.spaceInfiltrationDesignFlowRates[0]
        if old_infil.schedule.is_initialized
          infil_sch = old_infil.schedule.get
        end
      end
    end

    if infil_sch.nil?
      infil_sch = space.model.alwaysOnDiscreteSchedule
    end

    # Create an infiltration rate object for this space.
    infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(space.model)
    infiltration.setName("#{space.name} Infiltration")
    infiltration.setFlowperExteriorSurfaceArea(infil_5Pa_above_grade)
    infiltration.setSchedule(infil_sch)
    infiltration.setConstantTermCoefficient(self.get_standards_constant('infiltration_constant_term_coefficient'))
    infiltration.setTemperatureTermCoefficient(self.get_standards_constant('infiltration_constant_term_coefficient'))
    infiltration.setVelocityTermCoefficient(self.get_standards_constant('infiltration_velocity_term_coefficient'))
    infiltration.setVelocitySquaredTermCoefficient(self.get_standards_constant('infiltration_velocity_squared_term_coefficient'))
    infiltration.setSpace(space)
    return true
  end
end
