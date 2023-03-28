from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

RECORD_HELP = """
Must provide a tuple that contains:
template: TEXT
cooling_type: TEXT
condenser_type: TEXT
compressor_type: TEXT
absorption_type: TEXT
variable_speed_drive: TEXT
minimum_capacity: NUMERIC
maximum_capacity: NUMERIC
start_date: TEXT
end_date: TEXT
minimum_full_load_efficiency: NUMERIC
minimum_integrated_part_load_value: NUMERIC
capft: TEXT
eirft: TEXT
eirfplr: TEXT
annotation: TEXT (optional)
"""

CREATE_HVAC_REQUIREMENT_CHILLERS_TABLE = """
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY, 
template TEXT NOT NULL, 
cooling_type TEXT,
condenser_type TEXT,
compressor_type TEXT,
absorption_type TEXT,
variable_speed_drive TEXT,
minimum_capacity NUMERIC,
maximum_capacity NUMERIC,
start_date TEXT,
end_date TEXT,
minimum_full_load_efficiency NUMERIC,
minimum_integrated_part_load_value NUMERIC,
capft TEXT,
eirft TEXT,
eirfplr TEXT,
annotation TEXT);
"""

INSERT_A_CHILLER_RECORD = """
    INSERT INTO %s (
template, 
cooling_type,
condenser_type,
compressor_type,
absorption_type,
variable_speed_drive,
minimum_capacity,
maximum_capacity,
start_date,
end_date,
minimum_full_load_efficiency,
minimum_integrated_part_load_value,
capft,
eirft,
eirfplr,
annotation
) 
VALUES (?, ?, ?, ? ,? , ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
"""

RECORD_TEMPLATE = {
    "template": "",
    "cooling_type": "",
    "condenser_type": "",
    "compressor_type": "",
    "absorption_type": "",
    "variable_speed_drive": "",
    "minimum_capacity": 0.0,
    "maximum_capacity": 0.0,
    "start_date": "",
    "end_date": "",
    "minimum_full_load_efficiency": 0.0,
    "minimum_integrated_part_load_value": 0.0,
    "capft": "",
    "eirft": "",
    "eirfplr": "",
    "annotation": "",
}


class HVACMinimumRequirementChillers(DBOperation):
    def __init__(self, table_name, initial_data_directory):
        super(HVACMinimumRequirementChillers, self).__init__(
            table_name=table_name,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=initial_data_directory,
            create_table_query=CREATE_HVAC_REQUIREMENT_CHILLERS_TABLE % table_name,
            insert_record_query=INSERT_A_CHILLER_RECORD % table_name,
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
            "cooling_type",
            "condenser_type",
            "compressor_type",
            "absorption_type",
            "variable_speed_drive",
            "start_date",
            "end_date",
            "capft",
            "eirft",
            "eirfplr",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"

        float_expected = [
            "minimum_capacity",
            "maximum_capacity",
            "minimum_full_load_efficiency",
            "minimum_integrated_part_load_value",
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
            getattr_either("cooling_type", record),
            getattr_either("condenser_type", record),
            getattr_either("compressor_type", record),
            getattr_either("absorption_type", record),
            getattr_either("variable_speed_drive", record),
            getattr_either("minimum_capacity", record),
            getattr_either("maximum_capacity", record),
            getattr_either("start_date", record),
            getattr_either("end_date", record),
            getattr_either("minimum_full_load_efficiency", record),
            getattr_either("minimum_integrated_part_load_value", record),
            getattr_either("capft", record),
            getattr_either("eirft", record),
            getattr_either("eirfplr", record),
            getattr_either("annotation", record),
        )
