import sqlite3

from database_tables.hvac_minimum_requirement_water_source_heat_pumps_cooling import (
    HVACMinimumRequirementWaterSourceHeatPumpsCooling,
)

TABLE_NAME = "hvac_minimum_requirement_water_source_heat_pumps_cooling_90_1"


class HVACMinimumRequirementWaterSourceHeatPumpsCooling901Table(
    HVACMinimumRequirementWaterSourceHeatPumpsCooling
):
    def __init__(self):
        super(HVACMinimumRequirementWaterSourceHeatPumpsCooling901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
