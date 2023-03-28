from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

RECORD_HELP = """
Must provide a tuple that contains:
template: TEXT
fluid_type: TEXT
fuel_type: TEXT
condensing: NUMERIC
condensing_control: NUMERIC
minimum_capacity: NUMERIC
maximum_capacity: NUMERIC
start_date: TEXT
end_date: TEXT
minimum_annual_fuel_utilization_efficiency: NUMERIC
minimum_thermal_efficiency: NUMERIC
minimum_combustion_efficiency: NUMERIC
efffplr: NUMERIC
annotation: TEXT (optional)
"""

CREATE_HVAC_REQ_BOILER_TABLE = """
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY, 
template TEXT NOT NULL, 
fluid_type TEXT NOT NULL,
fuel_type TEXT NOT NULL,
condensing TEXT,
condensing_control TEXT,
minimum_capacity NUMERIC,
maximum_capacity NUMERIC,
start_date TEXT NOT NULL,
end_date TEXT NOT NULL,
minimum_annual_fuel_utilization_efficiency NUMERIC,
minimum_thermal_efficiency NUMERIC,
minimum_combustion_efficiency NUMERIC,
efffplr NUMERIC,
annotation TEXT);
"""

INSERT_A_BOILER_RECORD = """
    INSERT INTO %s (
template, 
fluid_type,
fuel_type,
condensing,
condensing_control,
minimum_capacity,
maximum_capacity,
start_date,
end_date,
minimum_annual_fuel_utilization_efficiency,
minimum_thermal_efficiency,
minimum_combustion_efficiency,
efffplr,
annotation
) 
VALUES (?, ?, ?, ? ,? , ?, ?, ?, ?, ?, ?, ?, ?, ?);
"""

RECORD_TEMPLATE = {
    "template": "",
    "fluid_type": "",
    "fuel_type": "",
    "condensing": 0.0,
    "condensing_control": 0.0,
    "minimum_capacity": 0.0,
    "maximum_capacity": 0.0,
    "start_date": "",
    "end_date": "",
    "minimum_annual_fuel_utilization_efficiency": 0.0,
    "minimum_thermal_efficiency": 0.0,
    "minimum_combustion_efficiency": 0.0,
    "efffplr": "",
    "annotation": "",
}


class HVACMinReqBoilers(DBOperation):
    def __init__(self, table_name, initial_data_directory):
        super(HVACMinReqBoilers, self).__init__(
            table_name=table_name,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=initial_data_directory,
            create_table_query=CREATE_HVAC_REQ_BOILER_TABLE % table_name,
            insert_record_query=INSERT_A_BOILER_RECORD % table_name,
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def validate_record_datatype(self, record):
        str_expected = [
            "template",
            "fluid_type",
            "condensing",
            "condensing_control",
            "start_date",
            "end_date",
            "efffplr",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"

        float_expected = [
            "minimum_capacity",
            "maximum_capacity",
            "minimum_annual_fuel_utilization_efficiency",
            "minimum_thermal_efficiency",
            "minimum_combustion_efficiency",
        ]

        for f in float_expected:
            if record.get(f):
                assert is_float(
                    record.get(f)
                ), f"{f} requires to be numeric data type, instead got {record[f]}"
        return True

    def _preprocess_record(self, record):
        """

        :param record: dict
        :return:
        """
        return (
            getattr_either("template", record),
            getattr_either("fluid_type", record),
            getattr_either("fuel_type", record),
            getattr_either("condensing", record),
            getattr_either("condensing_control", record),
            getattr_either("minimum_capacity", record),
            getattr_either("maximum_capacity", record),
            getattr_either("start_date", record),
            getattr_either("end_date", record),
            getattr_either("minimum_annual_fuel_utilization_efficiency", record),
            getattr_either("minimum_thermal_efficiency", record),
            getattr_either("minimum_combustion_efficiency", record),
            getattr_either("efffplr", record),
            getattr_either("annotation", record, ""),
        )
