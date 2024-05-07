# frozen_string_literal: true

class ACM179dASHRAE9012007
  def sub_surface_get_window_property(sub_surface)
    sql_file = sub_surface.model.sqlFile
    if !sql_file.is_initialized
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.SubSurface', 'Model has no sql file containing results, cannot lookup data.')
      return nil
    end
    sql_file = sql_file.get

    sub_surface_name = sub_surface.name.to_s

    # get SHGC
    window_shgc = sub_surface.assemblySHGC.get

    # get U-value
    window_u_value = sub_surface.assemblyUFactor.get

    # get opening area, including the frame (with is added to the sub_surface vertices)
    window_area = sub_surface.roughOpeningArea
    window_area *= sub_surface.multiplier
    space_ = sub_surface.space
    if space_.is_initialized
      window_area *= space_.get.multiplier
    end
    var_val_query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName = 'EnvelopeSummary' AND ReportForString = 'Entire Facility' AND TableName = 'Exterior Fenestration' AND RowName = '#{sub_surface_name.upcase}' AND ColumnName = 'Area of Multiplied Openings' AND Units = 'm2'"
    val = sql_file.execAndReturnFirstDouble(var_val_query)
    window_area = val.to_f.round(3)

    # get surface type
    surface_type = nil
    surface_ = sub_surface.surface
    if surface_.is_initialized
      surface_type = surface_.get.surfaceType
    end

    # get window type
    window_type = sub_surface.subSurfaceType

    window_property = {
      'name' => sub_surface_name,
      'window_type' => window_type,
      'surface_type' => surface_type,
      'area_m2' => window_area,
      'shgc' => window_shgc,
      'u_value' => window_u_value
    }
    return window_property
  end
end
