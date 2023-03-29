import sqlite3

from database_tables.level_3_ventilation_62_1_definition import VentDef621

TABLE_NAME = "level_3_ventilation_62_1_1999"


class VentDef6211999Table(VentDef621):
    def __init__(self):
        super(VentDef6211999Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
