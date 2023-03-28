from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

RECORD_HELP = """
Must provide a tuple that contains:
template: TEXT
number_of_poles: NUMERIC
type: TEXT
synchronous_speed: TEXT
minimum_capacity: NUMERIC
maximum_capacity: NUMERIC
nominal_full_load_efficiency: NUMERIC
annotation: TEXT (optional)
"""

CREATE_HVAC_REQUIREMENT_MOTORS_TABLE = """
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY, 
template TEXT NOT NULL, 
number_of_poles NUMERIC,
type TEXT NOT NULL,
synchronous_speed NUMERIC NOT NULL,
minimum_capacity NUMERIC,
maximum_capacity NUMERIC NOT NULL,
nominal_full_load_efficiency NUMERIC NOT NULL,
annotation TEXT);
"""

INSERT_A_MOTOR_RECORD = """
    INSERT INTO %s (
template, 
number_of_poles,
type,
synchronous_speed,
minimum_capacity,
maximum_capacity,
nominal_full_load_efficiency,
annotation
) 
VALUES (?, ?, ?, ? , ?, ?, ?, ?);
"""

RECORD_TEMPLATE = {
    "template": "",
    "number_of_poles": 0.0,
    "type": "",
    "synchronous_speed": 0.0,
    "minimum_capacity": 0.0,
    "maximum_capacity": 0.0,
    "nominal_full_load_efficiency": 0.0,
    "annotation": "",
}


class HVACMinimumRequirementMotors(DBOperation):
    def __init__(self, table_name, initial_data_directory):
        super(HVACMinimumRequirementMotors, self).__init__(
            table_name=table_name,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=initial_data_directory,
            create_table_query=CREATE_HVAC_REQUIREMENT_MOTORS_TABLE % table_name,
            insert_record_query=INSERT_A_MOTOR_RECORD % table_name,
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
            "type",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"

        float_expected = [
            "number_of_poles",
            "synchronous_speed",
            "minimum_capacity",
            "maximum_capacity",
            "nominal_full_load_efficiency",
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
            getattr_either("number_of_poles", record),
            getattr_either("type", record),
            getattr_either("synchronous_speed", record),
            getattr_either("minimum_capacity", record),
            getattr_either("maximum_capacity", record),
            getattr_either("nominal_full_load_efficiency", record),
            getattr_either("annotation", record),
        )
