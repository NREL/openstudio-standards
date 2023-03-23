import sqlite3

from database_tables.system_requirement_energy_recovery import (
    SystemRequirementEnergyRecovery,
)

TABLE_NAME = "system_requirement_energy_recovery_90_1"


class SystemRequirementEnergyRecovery901Table(SystemRequirementEnergyRecovery):
    def __init__(self):
        super(SystemRequirementEnergyRecovery901Table, self).__init__(
            table_name=TABLE_NAME,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )
