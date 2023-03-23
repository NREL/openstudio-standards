import sqlite3

from database_tables.hvac_minimum_requirement_heat_pump_heating import (
    HVACMinimumRequirementHeatPumpHeating,
)

TABLE_NAME = "hvac_minimum_requirement_heat_pump_heating_90_1"


class HVACMinimumRequirementHeatPumpHeating901Table(
    HVACMinimumRequirementHeatPumpHeating
):
    def __init__(self):
        super(HVACMinimumRequirementHeatPumpHeating901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
