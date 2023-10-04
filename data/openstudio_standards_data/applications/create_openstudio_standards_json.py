import json
import sqlite3
import logging

from database_tables.level_2_electric_equipment import (
    RECORD_TEMPLATE as plug_load_record_template,
)
from query.fetch.space import fetch_space_data
from query.fetch.database_table import (
    fetch_table,
    fetch_records_from_table_by_key_values,
)


def create_openstudio_standards_space_data_json_ashrae_90_1(
    conn: sqlite3.Connection, version_90_1: str
):
    """Create and export space type related data for a specific version of ASHRAE 90.1 to be used by OpenStudio Standards

    :param conn (sqlite3.Connection): database connection
    :param version_90_1 (str): code version of ASHRAE 90.1, e.g. "2004", "2007", etc.
    """
    missing_data_lookup_hierarchy = [
        "1999",
        "2004",
        "2007",
        "2010",
        "2013",
        "2016",
        "2019",
    ]
    code = "ashrae_90_1"
    template = f"90.1-{version_90_1}"
    create_openstudio_standards_space_data_json(
        conn, template, version_90_1, missing_data_lookup_hierarchy, code
    )


def is_record_present(records: list, field: str, value: str) -> bool | dict:
    """Check if a record (field, value pair) is available among a set of records

    :param records (list): list of records
    :param field (str): field to search
    :param value (str): targeted value of the field
    :return: false if record cannot be found otherwise record (dict)
    """
    for r in records:
        if value in r[field]:
            return r
    return False


def find_closest_record(
    records: list, field: str, value: str, missing_data_lookup_hierarchy: list
) -> dict:
    """Find closest available record to a value from a data lookup hierarchy

    :param records (list): list of records
    :param field (str): field to search
    :param value (str): targeted value of the field
    :param missing_data_lookup_hierarchy (list): list (ordered) of values to use to look up record if targeted value cannot be found
    :return: record (dict)
    """
    r = is_record_present(records, field, value)
    if r is False:
        for code in missing_data_lookup_hierarchy:
            r_next = is_record_present(records, field, code)
            if isinstance(r_next, dict):
                return r_next
        assert r
    else:
        return r


def create_openstudio_standards_space_data_json(
    conn: sqlite3.Connection,
    template: str,
    code_version: str,
    missing_data_lookup_hierarchy: list,
    code: str,
):
    """Extract code- and code version-specific OpenStudio Standards space type data from the database and export it to JSON files
    :param conn (sqlite3.Connection): database connection
    :param template (str): template corresponding to the code and code version, e.g. "90.1-2004", or "90.1-2007"
    :param code_version (str): verion of the code, e.g. "2004", "2007", etc.
    :param missing_data_lookup_hierarchy (list): list (ordered) of values to use to look up record if targeted value cannot be found
    :param code (str): name of the building energy code, e.g. "ashrae_90_1"
    """
    space_map_table = fetch_space_data(conn)
    # Drop other code versions
    space_map_table = [
        rec
        for rec in space_map_table
        if f"{code.replace('ashrae_', '')}_{code_version}"
        in rec["level_3_lighting_code_definition_table"]
    ]

    space_types = {"space_types": []}
    space_type_names = []
    for space_type_infos in space_map_table:
        space_type_name = space_type_infos["space_type_name"]
        if not space_type_name in space_type_names:
            space_type_names.append(space_type_name)
            lighting_space_type_name = space_type_infos["LS.lighting_space_type_name"]
            space_type_data = {"template": template, "space_type": space_type_name}

            # Get lighting space type data
            lighting_space_type_data = fetch_records_from_table_by_key_values(
                conn,
                "level_2_lighting_space_types",
                {"lighting_space_type_name": lighting_space_type_name},
            )
            assert len(lighting_space_type_data) > 0
            r = find_closest_record(
                lighting_space_type_data,
                "level_3_lighting_code_definition_table",
                code_version,
                missing_data_lookup_hierarchy,
            )

            # Get illuminance SP
            space_type_data["target_illuminance_setpoint"] = r[
                "lighting_space_type_target_illuminance_setpoint"
            ]

            # Get LPD
            lighting_records = fetch_records_from_table_by_key_values(
                conn,
                r["level_3_lighting_code_definition_table"],
                {"id": r["level_3_lighting_code_definition_id"]},
            )[0]

            space_lpd = float(lighting_records["lighting_power_density"])
            space_lpd_unit = lighting_records["lighting_power_density_unit"]
            if space_lpd_unit.lower() == "w/ft2":
                space_type_data["lighting_per_area"] = space_lpd
                space_type_data["lighting_per_height"] = 0.0
            elif space_lpd_unit.lower() == "w/ft":
                space_type_data["lighting_per_area"] = 0.0
                space_type_data["lighting_per_height"] = space_lpd
            space_type_data["lighting_per_person"] = 0.0
            space_type_data["rcr"] = lighting_records["rcr_threshold"]

            # Get space technology-based lighting information
            lighting_tech_name = r["lighting_technology_name"]
            lighting_tech_records = fetch_records_from_table_by_key_values(
                conn,
                "support_lighting_technologies",
                {"lighting_technology_definition_name": lighting_tech_name},
            )[0]
            lighting_tech_fields = [
                "lighting_fraction_to_return_air",
                "lighting_fraction_radiant",
                "lighting_fraction_visible",
                "lighting_fraction_replaceable",
                "lpd_fraction_linear_fluorescent",
                "lpd_fraction_compact_fluorescent",
                "lpd_fraction_high_bay",
                "lpd_fraction_specialty_lighting",
                "lpd_fraction_exit_lighting",
                "compact_fluorescent_lighting_schedule",
                "high_bay_lighting_schedule",
                "specialty_lighting_schedule",
                "exit_lighting_schedule",
            ]
            for f in lighting_tech_fields:
                space_type_data[f] = lighting_tech_records[f]

            # Get equipment space type data
            electric_equipment_space_type_name = space_type_infos[
                "ES.electric_equipment_space_type_name"
            ]
            electric_equipment_space_type_data = fetch_records_from_table_by_key_values(
                conn,
                "level_2_electric_equipment",
                {
                    "electric_equipment_space_type_name": electric_equipment_space_type_name
                },
            )
            equipment_tech_fields = [
                "electric_equipment_fraction_latent",
                "electric_equipment_fraction_radiant",
                "electric_equipment_fraction_lost",
            ]
            if isinstance(electric_equipment_space_type_data, list):
                if len(electric_equipment_space_type_data) > 0:
                    space_type_data["electric_equipment_per_area"] = float(
                        electric_equipment_space_type_data[0][
                            "electric_equipment_average_epd"
                        ]
                    )
                    for f in equipment_tech_fields:
                        space_type_data[f] = electric_equipment_space_type_data[0][f]
                else:
                    space_type_data["electric_equipment_per_area"] = 0.0
                    for f in equipment_tech_fields:
                        space_type_data[f] = 0.0
            else:
                space_type_data["electric_equipment_per_area"] = 0.0
                space_type_data["electric_equipment_per_area"] = 0.0
                for f in equipment_tech_fields:
                    space_type_data[f] = 0.0

            natural_gas_equipment_space_type_name = space_type_infos[
                "EGS.natural_gas_equipment_space_type_name"
            ]
            natural_gas_equipment_space_type_data = fetch_records_from_table_by_key_values(
                conn,
                "level_2_natural_gas_equipment",
                {
                    "natural_gas_equipment_space_type_name": natural_gas_equipment_space_type_name
                },
            )
            equipment_tech_fields = [
                "natural_gas_equipment_fraction_latent",
                "natural_gas_equipment_fraction_radiant",
                "natural_gas_equipment_fraction_lost",
            ]
            if isinstance(natural_gas_equipment_space_type_data, list):
                if len(natural_gas_equipment_space_type_data) > 0:
                    space_type_data["natural_gas_equipment_per_area"] = float(
                        natural_gas_equipment_space_type_data[0][
                            "natural_gas_equipment_average_epd"
                        ]
                    )
                    for f in equipment_tech_fields:
                        space_type_data[f] = natural_gas_equipment_space_type_data[0][f]
                else:
                    space_type_data["natural_gas_equipment_per_area"] = 0.0
                    for f in equipment_tech_fields:
                        space_type_data[f] = 0.0
            else:
                space_type_data["natural_gas_equipment_per_area"] = 0.0
                for f in equipment_tech_fields:
                    space_type_data[f] = 0.0

            # Get ventilation and occupancy space type data
            ventilation_space_type_name = space_type_infos[
                "VS.ventilation_space_type_name"
            ]
            ventilation_space_type_data = fetch_records_from_table_by_key_values(
                conn,
                "level_2_ventilation_space_types",
                {"ventilation_space_type_name": ventilation_space_type_name},
            )
            assert len(ventilation_space_type_data) > 0
            r = find_closest_record(
                ventilation_space_type_data,
                "level_3_ventilation_definition_table",
                code_version,
                missing_data_lookup_hierarchy,
            )
            ventilation_records = fetch_records_from_table_by_key_values(
                conn,
                r["level_3_ventilation_definition_table"],
                {"id": r["level_3_ventilation_definition_id"]},
            )[0]
            vent_per_pers = (
                ventilation_records["ventilation_rate_occupant"]
                if not ventilation_records["ventilation_rate_occupant"] is None
                else 0.0
            )
            vent_per_area = (
                ventilation_records["ventilation_rate_area"]
                if not ventilation_records["ventilation_rate_area"] is None
                else 0.0
            )
            occ_per_area = (
                ventilation_records["occupancy_per_area"]
                if not ventilation_records["occupancy_per_area"] is None
                else 0.0
            )
            space_type_data["ventilation_per_person"] = vent_per_pers
            # assume unit is cfm/pers; TODO: unit check
            space_type_data["ventilation_per_area"] = vent_per_area
            # assume unit is cfm/ft2; TODO: unit check
            space_type_data["ventilation_air_changes"] = 0.0
            space_type_data[
                "occupancy_per_area"
            ] = occ_per_area  # assume unit is people / 1000 ft2; TODO: unit check

            # Schedules
            schedule_set_name = space_type_infos["schedule_set_name"]
            space_type_data[
                "electric_equipment_schedule"
            ] = f"{schedule_set_name}_equipment"
            space_type_data["gas_equipment_schedule"] = f"{schedule_set_name}_equipment"
            space_type_data["lighting_schedule"] = f"{schedule_set_name}_lighting"
            space_type_data["occupancy_schedule"] = f"{schedule_set_name}_occupancy"

            space_types["space_types"].append(space_type_data)

    # Export retrieved data
    if len(space_types) > 0:
        with open(
            f"../../lib/openstudio-standards/standards/{code}/{code}_{code_version}/data/{code}_{code_version}.space_types.json",
            "w+",
        ) as output_report:
            output_report.write(json.dumps(space_types, indent=2))
    else:
        logging.warning(f"No records were found")


def create_openstudio_standards_data_json_ashrae_90_1(
    conn: sqlite3.Connection, version_90_1: str
) -> None:
    """
    Create and export data for a specific version of ASHRAE 90.1 to be used by OpenStudio Standards

    :param conn (sqlite3.Connection): database connection
    :param version_90_1 (str): code version of ASHRAE 90.1, e.g. "2004", "2007", etc.
    """
    # Dictionary that maps OpenStudio Standards JSON data file names to database table(s)
    # The mapping defined here covers data that varies based on code version
    tables_to_export_90_1 = {
        "chillers": ["hvac_minimum_requirement_chillers_90_1"],
        "boilers": ["hvac_minimum_requirement_boilers_90_1"],
        "furnaces": ["hvac_minimum_requirement_furnaces_90_1"],
        "heat_rejection": ["hvac_minimum_requirement_heat_rejection_90_1"],
        "motors": ["hvac_minimum_requirement_motors_90_1"],
        "unitary_acs": ["hvac_minimum_requirement_unitary_air_conditioners_90_1"],
        "water_source_heat_pumps_heating": [
            "hvac_minimum_requirement_water_source_heat_pumps_heating_90_1"
        ],
        "water_source_heat_pumps": [
            "hvac_minimum_requirement_water_source_heat_pumps_cooling_90_1"
        ],
        "water_heaters": ["hvac_minimum_requirement_water_heaters_90_1"],
        "heat_pumps": ["hvac_minimum_requirement_heat_pump_cooling_90_1"],
        "heat_pumps_heating": ["hvac_minimum_requirement_heat_pump_heating_90_1"],
        "economizers": ["system_requirement_economizer_90_1"],
        "energy_recovery": ["system_requirement_energy_recovery_90_1"],
        "construction_properties": ["envelope_requirement"],
    }

    # Generate and "export" the data to the correct location within the OpenStudio Standards repository
    create_openstudio_standards_code_version_data_json(
        conn,
        code="ashrae_90_1",
        code_version=version_90_1,
        template=f"90.1-{version_90_1}",
        tables_to_export=tables_to_export_90_1,
    )

    # The mapping defined here covers data that does NOT vary based on code version
    tables_to_export_90_1 = {
        "materials": "support_materials",
        "constructions": "support_constructions",
        "curves": "support_performance_curves",
        "space_type_schedules": "support_schedules",
    }

    # Generate and "export" the data to the correct location within the OpenStudio Standards repository
    create_openstudio_standards_code_data_json(
        conn, code="ashrae_90_1", tables_to_export=tables_to_export_90_1
    )


def create_openstudio_standards_code_version_data_json(
    conn: sqlite3.Connection,
    code: str,
    code_version: str,
    template: str,
    tables_to_export: dict,
) -> None:
    """Extract code- and code version-specific OpenStudio Standards data from the database and export it to JSON files
    :param conn (sqlite3.Connection): database connection
    :param code (str): name of the building energy code, e.g. "ashrae_90_1"
    :param code_version (str): verion of the code, e.g. "2004", "2007", etc.
    :param template (str): template corresponding to the code and code version, e.g. "90.1-2004", or "90.1-2007"
    :param tables_to_export (dict): mapping of name of OpenStudio Standards JSON file name to corresponding tables from the database that contains the data for the code and code version data
    """
    for table_type, tables in tables_to_export.items():
        logging.info(f"Creating {table_type} data")

        # Store the retrieved content from the database
        file_content = {f"{table_type}": []}

        # Iterate through the database tables to retrieve necessary tables
        for table in tables:
            logging.info(f"Processing data in {table} table")

            # Get data
            records = fetch_records_from_table_by_key_values(
                conn, table, {"template": template}
            )
            logging.info(f"{len(records)} found")

            # Process/clean retrieved data
            if len(records) > 0:
                file_content[table_type].extend(process_records(records))

        # Export retrieved data
        if len(file_content[table_type]) > 0:
            with open(
                f"../../lib/openstudio-standards/standards/{code}/{code}_{code_version}/data/{code}_{code_version}.{table_type}.json",
                "w+",
            ) as output_report:
                output_report.write(json.dumps(file_content, indent=2))
        else:
            logging.warning(
                f"No records were found, so {table} won't be created for {code} {code_version}"
            )


def create_openstudio_standards_code_data_json(
    conn: sqlite3.Connection, code: str, tables_to_export: dict
) -> None:
    """
    Extract code version-specific OpenStudio Standards data from the database and export it to JSON files
    :param conn (sqlite3.Connection): database connection
    :param code (str): name of the building energy code, e.g. "ashrae_90_1"
    :param tables_to_export (dict): mapping of name of OpenStudio Standards JSON file name to corresponding tables from the database that contains the data for the code and code version data
    """
    for table_type, table in tables_to_export.items():
        # Store the retrieved content from the database
        file_content = {f"{table_type}": []}

        logging.info(f"Processing data in {table} table")

        # Get data
        records = fetch_table(conn, table)
        logging.info(f"{len(records)} found")

        # Process/clean retrieved data
        if len(records) > 0:
            file_content[table_type].extend(process_records(records))

        # Export retrieved data
        if len(file_content[table_type]) > 0:
            with open(
                f"../../lib/openstudio-standards/standards/{code}/data/{code}.{table_type}.json",
                "w+",
            ) as output_report:
                output_report.write(json.dumps(file_content, indent=2))
        else:
            logging.warning(
                f"No records were found, so {table} won't be created for {code}"
            )


def process_records(records: list) -> list:
    """Process/clean the data retrieved from the database to match the format expected by OpenStudio Standards
    :param records (list): record(s) retrieved from the database that require processing/cleaning to match the expected format
    :returns list: processed/cleaned records
    """
    # Sort records by IDs (if exists in the data) to ensure consistent ordering of the exported data
    if "id" in list(records[0].keys()):
        records = sorted(records, key=lambda d: d["id"])

    # Iterate through the records to perform key/value pair modifications
    for record in records:
        # Remove unnecessary key/value pairs
        for key in ["template", "id", "annotation"]:
            if key in list(record.keys()):
                del record[key]

        # Concatenate schedule name a category
        schedule_record = False
        if all(
            i in list(record.keys()) for i in ["name", "category", "day_types", "hr_1"]
        ):
            record["name"] = f"{record['name']}_{record['category'].lower()}"
            schedule_record = True

        materials = []
        hr_values = []
        for key, value in record.items():
            # Reformat date
            if "_date" in key:
                # '9/9/1919'
                date = value.split("/")
                year = date[2] if len(date[2]) > 1 else f"0{date[2]}"
                month = date[0] if len(date[0]) > 1 else f"0{date[0]}"
                day = date[1] if len(date[1]) > 1 else f"0{date[1]}"
                record[key] = f"{year}-{month}-{day}T00:00:00+00:00"

            # Convert string booleans to actual booleans
            if value == "TRUE":
                record[key] = True
            if value == "FALSE":
                record[key] = False

            # Identify of the data is part of an "enumeration" of material or schedules
            # e.g., is the key "material_1", or "material_2", etc.
            material_id = key.split("material_")[-1]
            hour_id = key.split("hr_")[-1]
            try:
                material_id = int(material_id)
            except:
                pass
            try:
                hour_id = int(hour_id)
            except:
                pass
            if isinstance(material_id, int) and not value is None:
                materials.append(value)
            if isinstance(hour_id, int) and not value is None:
                hr_values.append(value)

        # Create a list of materials instead of having multiple material key/value pairs
        if len(materials) > 0:
            for i in range(1, 7):
                del record[f"material_{i}"]
            record["materials"] = materials
        # Create a list of schedule values instead of having multiple hour key/value pairs
        if len(hr_values) > 0:
            for i in range(1, 25):
                del record[f"hr_{i}"]
            record["values"] = hr_values
    return records
