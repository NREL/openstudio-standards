import sqlite3

from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

TABLE_NAME = "level_2_electric_equipment"


RECORD_HELP = """
Must provide a tuple that contains:
electric_equipment_space_type_name: TEXT
electric_equipment_minimum_epd: REAL
electric_equipment_average_epd: REAL
electric_equipment_median_epd: REAL
electric_equipment_maximum_epd: REAL
electric_equipment_epd_unit: TEXT
"""

CREATE_level_2_electric_equipment = """
CREATE TABLE IF NOT EXISTS %s 
(id INTEGER PRIMARY KEY, 
electric_equipment_space_type_name TEXT NOT NULL, 
electric_equipment_minimum_epd NUMERIC, 
electric_equipment_average_epd NUMERIC, 
electric_equipment_median_epd NUMERIC, 
electric_equipment_maximum_epd NUMERIC, 
electric_equipment_epd_unit TEXT);
"""

INSERT_EQUIP_LOAD_RECORD = """
    INSERT INTO %s
    (electric_equipment_space_type_name, electric_equipment_minimum_epd, electric_equipment_average_epd, electric_equipment_median_epd, electric_equipment_maximum_epd, electric_equipment_epd_unit)
    VALUES (?, ?, ?, ? , ? ,?);
"""

RECORD_TEMPLATE = {
    "electric_equipment_space_type_name": "",
    "electric_equipment_minimum_epd": "",
    "electric_equipment_average_epd": "",
    "electric_equipment_median_epd": "",
    "electric_equipment_maximum_epd": "",
    "electric_equipment_epd_unit": "W/ft2",
}


class EquipLoadTable(DBOperation):
    def __init__(self):
        super(EquipLoadTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"initial_data/{TABLE_NAME}",
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def validate_record_datatype(self, record):
        if record.get("electric_equipment_minimum_epd"):
            assert is_float(
                record["electric_equipment_minimum_epd"]
            ), f"electric_equipment_minimum_epd requires to be numeric data type, instead got {record['electric_equipment_minimum_epd']}"
        if record.get("electric_equipment_average_epd"):
            assert is_float(
                record["electric_equipment_average_epd"]
            ), f"electric_equipment_average_epd requires to be numeric data type, instead got {record['electric_equipment_average_epd']}"
        if record.get("electric_equipment_median_epd"):
            assert is_float(
                record["electric_equipment_median_epd"]
            ), f"electric_equipment_median_epd requires to be numeric data type, instead got {record['electric_equipment_median_epd']}"
        if record.get("electric_equipment_maximum_epd"):
            assert is_float(
                record["electric_equipment_maximum_epd"]
            ), f"electric_equipment_maximum_epd requires to be numeric data type, instead got {record['electric_equipment_maximum_epd']}"

    def _preprocess_record(self, record):
        """

        :param record: dictionary
        :return:
        """
        record_tuple = (
            getattr_either("electric_equipment_space_type_name", record),
            getattr_either("electric_equipment_minimum_epd", record),
            getattr_either("electric_equipment_average_epd", record),
            getattr_either("electric_equipment_median_epd", record),
            getattr_either("electric_equipment_maximum_epd", record),
            getattr_either("electric_equipment_epd_unit", record, ""),
        )
        return record_tuple

    def _get_create_table_query(self):
        return CREATE_level_2_electric_equipment % self.data_table_name

    def _get_insert_record_query(self):
        return INSERT_EQUIP_LOAD_RECORD % self.data_table_name
