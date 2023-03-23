import sqlite3

from database_tables.system_requirement_economizer import SystemRequirementEconomizer

TABLE_NAME = "system_requirement_economizer_90_1"


class SystemRequirementEconomizer901Table(SystemRequirementEconomizer):
    def __init__(self):
        super(SystemRequirementEconomizer901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
