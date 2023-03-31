import sqlite3

from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

TABLE_NAME = "level_2_electric_equipment"


RECORD_HELP = """
Must provide a tuple that contains:
electric_equipment_space_type_name: TEXT
electric_equipment_minimum_epd: NUMERIC
electric_equipment_average_epd: NUMERIC
electric_equipment_median_epd: NUMERIC
electric_equipment_maximum_epd: NUMERIC
electric_equipment_epd_unit: TEXT
electric_equipment_fraction_latent: NUMERIC
electric_equipment_fraction_radiant: NUMERIC
electric_equipment_fraction_lost: NUMERIC
"""

CREATE_LEVEL_2_ELECTRIC_EQUIPMENT = """
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY,
electric_equipment_space_type_name TEXT NOT NULL,
electric_equipment_minimum_epd NUMERIC,
electric_equipment_average_epd NUMERIC,
electric_equipment_median_epd NUMERIC,
electric_equipment_maximum_epd NUMERIC,
electric_equipment_epd_unit TEXT,
electric_equipment_fraction_latent NUMERIC,
electric_equipment_fraction_radiant NUMERIC,
electric_equipment_fraction_lost NUMERIC
);
"""

INSERT_EQUIP_LOAD_RECORD = """
    INSERT INTO %s
    (
        electric_equipment_space_type_name,
        electric_equipment_minimum_epd,
        electric_equipment_average_epd,
        electric_equipment_median_epd,
        electric_equipment_maximum_epd,
        electric_equipment_epd_unit,
        electric_equipment_fraction_latent,
        electric_equipment_fraction_radiant,
        electric_equipment_fraction_lost
        )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
"""

RECORD_TEMPLATE = {
    "electric_equipment_space_type_name": "",
    "electric_equipment_minimum_epd": "",
    "electric_equipment_average_epd": "",
    "electric_equipment_median_epd": "",
    "electric_equipment_maximum_epd": "",
    "electric_equipment_epd_unit": "W/ft2",
    "electric_equipment_fraction_latent": 0.0,
    "electric_equipment_fraction_radiant": 0.0,
    "electric_equipment_fraction_lost": 0.0,
}


class EquipLoadTable(DBOperation):
    def __init__(self):
        super(EquipLoadTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
            create_table_query=CREATE_LEVEL_2_ELECTRIC_EQUIPMENT % TABLE_NAME,
            insert_record_query=INSERT_EQUIP_LOAD_RECORD % TABLE_NAME,
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def validate_record_datatype(self, record):
        float_expected = [
            "electric_equipment_minimum_epd",
            "electric_equipment_average_epd",
            "electric_equipment_median_epd",
            "electric_equipment_maximum_epd",
            "electric_equipment_fraction_latent",
            "electric_equipment_fraction_radiant",
            "electric_equipment_fraction_lost",
        ]

        for f in float_expected:
            if record.get(f):
                assert is_float(
                    record.get(f)
                ), f"{f} requires to be numeric data type, instead got {record[f]}"
        return True

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
            getattr_either("electric_equipment_fraction_latent", record),
            getattr_either("electric_equipment_fraction_radiant", record),
            getattr_either("electric_equipment_fraction_lost", record),
        )
        return record_tuple
