import sqlite3

from database_tables.hvac_minimum_requirement_heat_rejection import (
    HVACMinimumRequirementHeatRejection,
)

TABLE_NAME = "hvac_minimum_requirement_heat_rejection_90_1"


class HVACMinimumRequirementHeatRejection901Table(HVACMinimumRequirementHeatRejection):
    def __init__(self):
        super(HVACMinimumRequirementHeatRejection901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
