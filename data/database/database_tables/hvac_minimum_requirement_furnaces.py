from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

RECORD_HELP = """
Must provide a tuple that contains:
template: TEXT
minimum_capacity: NUMERIC
maximum_capacity: NUMERIC
start_date: TEXT
end_date: TEXT
minimum_annual_fuel_utilization_efficiency: NUMERIC
minimum_thermal_efficiency: NUMERIC
minimum_combustion_efficiency: NUMERIC
annotation: TEXT (optional)
"""

CREATE_HVAC_REQUIREMENT_FURNACES_TABLE = """
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY, 
template TEXT NOT NULL, 
minimum_capacity NUMERIC,
maximum_capacity NUMERIC,
start_date TEXT NOT NULL,
end_date TEXT NOT NULL,
minimum_annual_fuel_utilization_efficiency NUMERIC,
minimum_thermal_efficiency NUMERIC,
minimum_combustion_efficiency NUMERIC,
annotation TEXT);
"""

INSERT_A_FURNACE_RECORD = """
    INSERT INTO %s (
template, 
minimum_capacity,
maximum_capacity,
start_date,
end_date,
minimum_annual_fuel_utilization_efficiency,
minimum_thermal_efficiency,
minimum_combustion_efficiency,
annotation
) 
VALUES (?, ?, ?, ? ,? , ?, ?, ?, ?);
"""

RECORD_TEMPLATE = {
    "template": "",
    "minimum_capacity": 0.0,
    "maximum_capacity": 0.0,
    "start_date": "",
    "end_date": "",
    "minimum_annual_fuel_utilization_efficiency": 0.0,
    "minimum_thermal_efficiency": 0.0,
    "minimum_combustion_efficiency": 0.0,
    "annotation": "",
}


class HVACMinimumRequirementFurnaces(DBOperation):
    def __init__(self, table_name, initial_data_directory):
        super(HVACMinimumRequirementFurnaces, self).__init__(
            table_name=table_name,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=initial_data_directory,
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def validate_record_datatype(self, record):
        if record.get("minimum_capacity"):
            assert is_float(
                record.get("minimum_capacity")
            ), f"minimum_capacity requires to be numeric data type, instead got {record['minimum_capacity']}"
        if record.get("maximum_capacity"):
            assert is_float(
                record.get("maximum_capacity")
            ), f"maximum_capacity requires to be numeric data type, instead got {record['minimum_capacity']}"
        if record.get("minimum_annual_fuel_utilization_efficiency"):
            assert is_float(
                record.get("minimum_annual_fuel_utilization_efficiency")
            ), f"minimum_annual_fuel_utilization_efficiency requires to be numeric data type, instead got {record['minimum_capacity']}"
        if record.get("minimum_thermal_efficiency"):
            assert is_float(
                record.get("minimum_thermal_efficiency")
            ), f"minimum_thermal_efficiency requires to be numeric data type, instead got {record['minimum_capacity']}"
        if record.get("minimum_combustion_efficiency"):
            assert is_float(
                record.get("minimum_combustion_efficiency")
            ), f"minimum_combustion_efficiency requires to be numeric data type, instead got {record['minimum_capacity']}"
        if record.get("template"):
            assert isinstance(
                record["template"], str
            ), f"template requires to be a string, instead got {record['template']}"
        if record.get("start_date"):
            assert isinstance(
                record["start_date"], str
            ), f"start_date requires to be a string, instead got {record['start_date']}"
        if record.get("end_date"):
            assert isinstance(
                record["end_date"], str
            ), f"end_date requires to be a string, instead got {record['end_date']}"

    def _preprocess_record(self, record):
        """

        :param record: dict
        :return:
        """

        return (
            getattr_either("template", record),
            getattr_either("minimum_capacity", record),
            getattr_either("maximum_capacity", record),
            getattr_either("start_date", record),
            getattr_either("end_date", record),
            getattr_either("minimum_annual_fuel_utilization_efficiency", record),
            getattr_either("minimum_thermal_efficiency", record),
            getattr_either("minimum_combustion_efficiency", record),
            getattr_either("annotation", record),
        )

    def _get_create_table_query(self):
        return CREATE_HVAC_REQUIREMENT_FURNACES_TABLE % self.data_table_name

    def _get_insert_record_query(self):
        return INSERT_A_FURNACE_RECORD % self.data_table_name
