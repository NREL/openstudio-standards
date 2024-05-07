class ACM179dASHRAE9012007
    def sub_surface_get_window_property(sub_surface)
        sql = sub_surface.model.sqlFile.get
        if not sql.is_initialized
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.SubSurface', 'Model has no sql file containing results, cannot lookup data.')
            return nil
        end
    
        window_property = {}
        sub_surface_name = sub_surface.name.to_s
        # get SHGC
        # Note that the SQL Queries can be swapped out for SDK functions
        # https://github.com/NREL/OpenStudio/blob/develop/src/model/SubSurface.cpp#L1305-L1348
        var_val_query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName = 'EnvelopeSummary' AND ReportForString = 'Entire Facility' AND TableName = 'Exterior Fenestration' AND RowName = '#{sub_surface_name.upcase}' AND ColumnName = 'Assembly SHGC'"
        val = sqlFile.execAndReturnFirstDouble(var_val_query)
        window_shgc = val.to_f.round(3)
        # get U-value
        var_val_query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName = 'EnvelopeSummary' AND ReportForString = 'Entire Facility' AND TableName = 'Exterior Fenestration' AND RowName = '#{sub_surface_name.upcase}' AND ColumnName = 'Assembly U-Factor' AND Units = 'W/m2-K'"
        val = sqlFile.execAndReturnFirstDouble(var_val_query)
        window_u_value = val.to_f.round(3)
        # get opening area
        var_val_query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName = 'EnvelopeSummary' AND ReportForString = 'Entire Facility' AND TableName = 'Exterior Fenestration' AND RowName = '#{sub_surface_name.upcase}' AND ColumnName = 'Area of Multiplied Openings' AND Units = 'm2'"
        val = sqlFile.execAndReturnFirstDouble(var_val_query)
        window_area = val.to_f.round(3)
        # get surface type
        surface_type = sub_surface.surface.surfaceType
        # get window type
        window_type = sub_surface.subSurfaceType
        # add window information to hash
        window_property[surface_type][window_type][sub_surface_name]['area_m2'] = window_area
        window_property[surface_type][window_type][sub_surface_name]['shgc'] = window_shgc
        window_property[surface_type][window_type][sub_surface_name]['u_value'] = window_u_value
        return window_property   
    end
end