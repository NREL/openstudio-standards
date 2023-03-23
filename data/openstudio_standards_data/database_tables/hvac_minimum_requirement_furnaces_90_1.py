import sqlite3

from database_tables.hvac_minimum_requirement_furnaces import (
    HVACMinimumRequirementFurnaces,
)

TABLE_NAME = "hvac_minimum_requirement_furnaces_90_1"


class HVACMinimumRequirementFurnaces901Table(HVACMinimumRequirementFurnaces):
    def __init__(self):
        super(HVACMinimumRequirementFurnaces901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
