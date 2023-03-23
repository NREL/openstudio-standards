import sqlite3

from database_tables.hvac_minimum_requirement_chillers import (
    HVACMinimumRequirementChillers,
)

TABLE_NAME = "hvac_minimum_requirement_chillers_90_1"


class HVACMinimumRequirementChillers901Table(HVACMinimumRequirementChillers):
    def __init__(self):
        super(HVACMinimumRequirementChillers901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
