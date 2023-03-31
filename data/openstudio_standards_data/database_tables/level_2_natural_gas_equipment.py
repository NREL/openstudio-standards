import sqlite3

from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

TABLE_NAME = "level_2_natural_gas_equipment"


RECORD_HELP = """
Must provide a tuple that contains:
natural_gas_equipment_space_type_name: TEXT
natural_gas_equipment_minimum_epd: NUMERIC
natural_gas_equipment_average_epd: NUMERIC
natural_gas_equipment_median_epd: NUMERIC
natural_gas_equipment_maximum_epd: NUMERIC
natural_gas_equipment_epd_unit: TEXT
natural_gas_equipment_fraction_latent: NUMERIC
natural_gas_equipment_fraction_radiant: NUMERIC
natural_gas_equipment_fraction_lost: NUMERIC
"""

CREATE_NATURAL_GAS_EQUIPMENT_TABLE = """
CREATE TABLE IF NOT EXISTS %s 
(id INTEGER PRIMARY KEY, 
natural_gas_equipment_space_type_name TEXT NOT NULL, 
natural_gas_equipment_minimum_epd NUMERIC, 
natural_gas_equipment_average_epd NUMERIC, 
natural_gas_equipment_median_epd NUMERIC, 
natural_gas_equipment_maximum_epd NUMERIC, 
natural_gas_equipment_epd_unit TEXT,
natural_gas_equipment_fraction_latent NUMERIC,
natural_gas_equipment_fraction_radiant NUMERIC,
natural_gas_equipment_fraction_lost NUMERIC
);
"""

INSERT_NATURAL_GAS_EQUIP_LOAD_RECORD = """
    INSERT INTO %s
    (
        natural_gas_equipment_space_type_name,
        natural_gas_equipment_minimum_epd,
        natural_gas_equipment_average_epd,
        natural_gas_equipment_median_epd,
        natural_gas_equipment_maximum_epd,
        natural_gas_equipment_epd_unit,
        natural_gas_equipment_fraction_latent,
        natural_gas_equipment_fraction_radiant,
        natural_gas_equipment_fraction_lost
        )
    VALUES (?, ?, ?, ?, ? , ?, ?, ?, ?);
"""

RECORD_TEMPLATE = {
    "natural_gas_equipment_space_type_name": "",
    "natural_gas_equipment_minimum_epd": "",
    "natural_gas_equipment_average_epd": "",
    "natural_gas_equipment_median_epd": "",
    "natural_gas_equipment_maximum_epd": "",
    "natural_gas_equipment_epd_unit": "Btu/hr.ft2",
    "natural_gas_equipment_fraction_latent": 0.0,
    "natural_gas_equipment_fraction_radiant": 0.0,
    "natural_gas_equipment_fraction_lost": 0.0,
}


class EquipLoadTable(DBOperation):
    def __init__(self):
        super(EquipLoadTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
            create_table_query=CREATE_NATURAL_GAS_EQUIPMENT_TABLE % TABLE_NAME,
            insert_record_query=INSERT_NATURAL_GAS_EQUIP_LOAD_RECORD % TABLE_NAME,
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def validate_record_datatype(self, record):
        float_expected = [
            "natural_gas_equipment_minimum_epd",
            "natural_gas_equipment_average_epd",
            "natural_gas_equipment_median_epd",
            "natural_gas_equipment_maximum_epd",
            "natural_gas_equipment_fraction_latent",
            "natural_gas_equipment_fraction_radiant",
            "natural_gas_equipment_fraction_lost",
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
            getattr_either("natural_gas_equipment_space_type_name", record),
            getattr_either("natural_gas_equipment_minimum_epd", record),
            getattr_either("natural_gas_equipment_average_epd", record),
            getattr_either("natural_gas_equipment_median_epd", record),
            getattr_either("natural_gas_equipment_maximum_epd", record),
            getattr_either("natural_gas_equipment_epd_unit", record, ""),
            getattr_either("natural_gas_equipment_fraction_latent", record),
            getattr_either("natural_gas_equipment_fraction_radiant", record),
            getattr_either("natural_gas_equipment_fraction_lost", record),
        )
        return record_tuple
