import sqlite3

from database_tables.hvac_minimum_requirement_unitary_air_conditioners import (
    HVACMinimumRequirementUnitaryAirConditioners,
)

TABLE_NAME = "hvac_minimum_requirement_unitary_air_conditioners_90_1"


class HVACMinimumRequirementUnitaryAirConditioners901Table(
    HVACMinimumRequirementUnitaryAirConditioners
):
    def __init__(self):
        super(HVACMinimumRequirementUnitaryAirConditioners901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
