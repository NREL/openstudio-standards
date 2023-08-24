import importlib
import inspect

import database_engine.database as database_classes
import database_tables as db_tables

# need to be in orders of complexity
# Tables with no foreign key need to be created
# before other tables
__all__ = [
    # tables no foreign keys
    "hvac_minimum_requirement_motors_90_1",
    "hvac_minimum_requirement_water_heaters_90_1",
    "hvac_minimum_requirement_heat_rejection_90_1",
    "hvac_minimum_requirement_water_source_heat_pumps_cooling_90_1",
    "hvac_minimum_requirement_water_source_heat_pumps_heating_90_1",
    "hvac_minimum_requirement_unitary_air_conditioners_90_1",
    "hvac_minimum_requirement_heat_pump_cooling_90_1",
    "hvac_minimum_requirement_heat_pump_heating_90_1",
    "hvac_minimum_requirement_chillers_90_1",
    "hvac_minimum_requirement_boilers_90_1",
    "hvac_minimum_requirement_furnaces_90_1",
    "level_3_lighting_90_1_2019",
    "level_3_lighting_90_1_2016",
    "level_3_lighting_90_1_2013",
    "level_3_lighting_90_1_2010",
    "level_3_lighting_90_1_2007",
    "level_3_lighting_90_1_2004",
    "level_3_ventilation_62_1_2019",
    "level_3_ventilation_62_1_2016",
    "level_3_ventilation_62_1_2013",
    "level_3_ventilation_62_1_2010",
    "level_3_ventilation_62_1_2007",
    "level_3_ventilation_62_1_2004",
    "level_3_ventilation_62_1_1999",
    "level_2_electric_equipment",
    "level_2_natural_gas_equipment",
    "support_lighting_technologies",
    "support_standard_templates",
    "support_lighting_space_type_name_tags",
    "support_ventilation_space_type_name_tags",
    "support_electric_equipment_space_type_name_tags",
    "support_materials",
    "support_performance_curves",
    "support_schedules",
    "system_requirement_energy_recovery_90_1",
    "system_requirement_economizer_90_1",
    # tables with foreign keys
    "level_2_lighting_space_types",
    "level_2_ventilation_space_types",
    "level_1_space_types",
    "support_constructions",
    "envelope_requirement",
]


def __get_light_tables__():
    available_tables = __gettables__()
    return [table for table in available_tables if table[0].startswith("LightDef")]


def __gettables__():
    tables = inspect.getmembers(db_tables, inspect.ismodule)
    # sort the list tuples to the same order as __all__
    tables_sorted = [
        table for table_name in __all__ for table in tables if table_name == table[0]
    ]
    base_class_names = [
        f[0] for f in inspect.getmembers(database_classes, inspect.isclass)
    ]
    available_tables = []
    for table in tables_sorted:
        available_tables += [
            f
            for f in inspect.getmembers(
                table[1],
                lambda obj: inspect.isclass(obj)
                and issubclass(obj, database_classes.DBOperation),
            )
            if (not f[0].startswith("_"))
            and (not f[0] in base_class_names)
            and (f[0].endswith("Table"))
        ]

    return available_tables


def __getattr__(name):
    if name in __all__:
        return importlib.import_module("." + name, __name__)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


def __dir__():
    return __all__
