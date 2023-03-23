import sqlite3

from database_tables.hvac_minimum_requirement_water_source_heat_pumps_heating import (
    HVACMinimumRequirementWaterSourceHeatPumpsHeating,
)

TABLE_NAME = "hvac_minimum_requirement_water_source_heat_pumps_heating_90_1"


class HVACMinimumRequirementWaterSourceHeatPumpsHeating901Table(
    HVACMinimumRequirementWaterSourceHeatPumpsHeating
):
    def __init__(self):
        super(HVACMinimumRequirementWaterSourceHeatPumpsHeating901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
