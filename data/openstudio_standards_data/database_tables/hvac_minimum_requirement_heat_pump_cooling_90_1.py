import sqlite3

from database_tables.hvac_minimum_requirement_heat_pump_cooling import (
    HVACMinimumRequirementHeatPumpCooling,
)

TABLE_NAME = "hvac_minimum_requirement_heat_pump_cooling_90_1"


class HVACMinimumRequirementHeatPumpCooling901Table(
    HVACMinimumRequirementHeatPumpCooling
):
    def __init__(self):
        super(HVACMinimumRequirementHeatPumpCooling901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
