import sqlite3

from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

RECORD_HELP = """
Must provide a tuple that contains:
method: [BA, CS, SS]
lighting_primary_space_type: TEXT
lighting_secondary_space_type: TEXT
lighting_per_area: REAL
lighting_per_area_unit: TEXT
annotation: TEXT (optional)
"""

CREATE_LIGHT_DEF_90_1_TABLE = """
CREATE TABLE IF NOT EXISTS %s 
(id INTEGER PRIMARY KEY, 
method TEXT DEFAULT 'BA' NOT NULL, 
lighting_primary_space_type TEXT, 
lighting_per_area NUMERIC NOT NULL, 
lighting_secondary_space_type TEXT, 
lighting_per_area_unit TEXT DEFAULT 'w/ft2' NOT NULL, 
annotation TEXT);
"""

INSERT_A_LIGHT_RECORD = """
    INSERT INTO %s
    (method, lighting_primary_space_type, lighting_secondary_space_type, lighting_per_area, lighting_per_area_unit, annotation)
    VALUES (?, ?, ?, ? , ? ,?);
"""

RECORD_TEMPLATE = {
    "method": "",
    "lighting_primary_space_type": "",
    "lighting_secondary_space_type": "",
    "lighting_per_area": 0.0,
    "lighting_per_area_unit": "W/ft2",
    "annotation": "",
}


class LightDef901(DBOperation):
    def __init__(self, table_name, initial_data_directory):
        super(LightDef901, self).__init__(
            table_name=table_name,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=initial_data_directory,
            create_table_query=CREATE_LIGHT_DEF_90_1_TABLE % table_name,
            insert_record_query=INSERT_A_LIGHT_RECORD % table_name
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def validate_record_datatype(self, record):
        if record.get("method"):
            assert record["method"] in [
                "BA",
                "CS",
                "SS",
            ], f"method is provided with wrong choice value. Available: BA, CS, SS "
        if record.get("lighting_per_area"):
            assert is_float(
                record.get("lighting_per_area")
            ), f"lighting_per_area requires to be numeric data type, instead got {record['lighting_per_area']}"

    def _preprocess_record(self, record):
        """

        :param record: dictionary
        :return:
        """
        record_tuple = (
            getattr_either("method", record),
            getattr_either("lighting_primary_space_type", record),
            getattr_either("lighting_secondary_space_type", record),
            getattr_either("lighting_per_area", record),
            getattr_either("lighting_per_area_unit", record, "W/ft2"),
            getattr_either("annotation", record, ""),
        )
        return record_tuple

