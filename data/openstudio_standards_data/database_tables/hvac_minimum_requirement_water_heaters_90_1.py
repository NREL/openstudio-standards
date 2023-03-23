import sqlite3

from database_tables.hvac_minimum_requirement_water_heaters import (
    HVACMinimumRequirementWaterHeaters,
)

TABLE_NAME = "hvac_minimum_requirement_water_heaters_90_1"


class HVACMinimumRequirementWaterHeaters901Table(HVACMinimumRequirementWaterHeaters):
    def __init__(self):
        super(HVACMinimumRequirementWaterHeaters901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
