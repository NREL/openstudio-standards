from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

RECORD_HELP = """
Must provide a tuple that contains:
template: TEXT
climate_zone: TEXT
data_center: TEXT
capacity_limit: NUMERIC
fixed_dry_bulb_high_limit_shutoff_temp: NUMERIC
annotation: TEXT (optional)
"""

CREATE_SYSTEM_REQUIREMENT_ECONOMIZER_TABLE = """
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY, 
template TEXT NOT NULL, 
climate_zone TEXT NOT NULL,
data_center TEXT,
capacity_limit NUMERIC,
fixed_dry_bulb_high_limit_shutoff_temp NUMERIC,
annotation TEXT);
"""

INSERT_A_SYSTEM_REQUIREMENT_ECONOMIZER = """
    INSERT INTO %s (
template,
climate_zone,
data_center,
capacity_limit,
fixed_dry_bulb_high_limit_shutoff_temp,
annotation
) 
VALUES (?, ?, ?, ?, ?, ?);
"""

RECORD_TEMPLATE = {
    "template": "",
    "climate_zone": "",
    "data_center": "",
    "capacity_limit": 0.0,
    "fixed_dry_bulb_high_limit_shutoff_temp": 0.0,
    "annotation": "",
}


class SystemRequirementEconomizer(DBOperation):
    def __init__(self, table_name, initial_data_directory):
        super(SystemRequirementEconomizer, self).__init__(
            table_name=table_name,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=initial_data_directory,
            create_table_query=CREATE_SYSTEM_REQUIREMENT_ECONOMIZER_TABLE % table_name,
            insert_record_query=INSERT_A_SYSTEM_REQUIREMENT_ECONOMIZER % table_name,
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
            "climate_zone",
            "data_center",
            "subcategory",
            "start_date",
            "end_date",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"

        float_expected = [
            "capacity_limit",
            "fixed_dry_bulb_high_limit_shutoff_temp",
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
            getattr_either("climate_zone", record),
            getattr_either("data_center", record),
            getattr_either("capacity_limit", record),
            getattr_either("fixed_dry_bulb_high_limit_shutoff_temp", record),
            getattr_either("annotation", record),
        )
