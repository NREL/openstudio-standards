import sqlite3

from database_tables.hvac_minimum_requirement_motors import HVACMinimumRequirementMotors

TABLE_NAME = "hvac_minimum_requirement_motors_90_1"


class HVACMinimumRequirementMotors901Table(HVACMinimumRequirementMotors):
    def __init__(self):
        super(HVACMinimumRequirementMotors901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
