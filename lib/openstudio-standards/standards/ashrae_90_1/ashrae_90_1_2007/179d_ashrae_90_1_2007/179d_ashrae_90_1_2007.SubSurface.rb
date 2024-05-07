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
        window_shgc = sub_surface.assemblySHGC.get

        # get U-value
        window_u_value = sub_surface.assemblyUFactor.get

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
