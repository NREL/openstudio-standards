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
from query.fetch.template import fetch_templates


def create_openstudio_standards_space_data_json(
    conn: sqlite3.Connection, json_data_dir: str
):
    """
    Extract OpenSutdio Standards building data to a json file.
    :param conn: database connection
    :param json_data_dir: directory
    :return:
    """
    space_data = []

    # Step 1, we need to get the template table and loop in the table
    standard_templates = fetch_templates(conn)
    # Step 2, get all building -> light and vent map table
    space_map_table = fetch_space_data(conn)
    # Step 3, create an empty data holder to serve a memoize storage for standard tables
    standard_data_tables = dict()

    for template in standard_templates:
        lighting_standard_table = template["lighting_standard_table"]
        ventilation_standard_table = template["ventilation_standard_table"]
        # filter out the matching lighting standard table and ventilation standard table
        subset_space_map_table = filter(
            lambda bldg: bldg["level_3_lighting_definition_table"]
            == lighting_standard_table
            and bldg["level_3_ventilation_definition_table"]
            == ventilation_standard_table,
            space_map_table,
        )
        for space in subset_space_map_table:
            # WX: I tried to avoid having queries inside the loop but this seems to be a decision to make either loop
            # the queries or pre-query each standard version tables outside the loop but increase the maintenance effort
            sp_data = dict()
            sp_data["template"] = template["template"]
            sp_data["lighting_standard"] = template["lighting_standard"]
            sp_data["ventilation_standard"] = template["ventilation_standard"]
            sp_data["space_type"] = space["space_type"]

            lpd_id = int(space["level_3_lighting_definition_id"])
            vent_id = int(space["level_3_ventilation_definition_id"])
            if lighting_standard_table not in standard_data_tables.keys():
                light_table = fetch_table(conn, lighting_standard_table)
                standard_data_tables[lighting_standard_table] = light_table
            if ventilation_standard_table not in standard_data_tables.keys():
                vent_table = fetch_table(conn, ventilation_standard_table)
                standard_data_tables[ventilation_standard_table] = vent_table
            if space.get("electric_equipment_space_type_name"):
                plug_load_record = fetch_records_from_table_by_key_values(
                    conn,
                    "equip_load",
                    {
                        "electric_equipment_space_type_name": space[
                            "electric_equipment_space_type_name"
                        ]
                    },
                )
                if plug_load_record:
                    # Get the first record in the list.
                    plug_load_record = plug_load_record[0]
            else:
                plug_load_record = plug_load_record_template
            light = next(
                ltg
                for ltg in standard_data_tables[lighting_standard_table]
                if ltg["id"] == lpd_id
            )
            vent = next(
                vt
                for vt in standard_data_tables[ventilation_standard_table]
                if vt["id"] == vent_id
            )
            sp_data.update(light)
            sp_data.update(vent)
            sp_data.update(plug_load_record)
            # delete ID parameter, the ID is database specific and does not need
            # included in the json
            sp_data.pop("id", None)

            space_data.append(sp_data)

    with open(json_data_dir, "w") as output_report:
        output_report.write(json.dumps(space_data, indent=4))


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
    """
    Extract code- and code version-specific OpenStudio Standards data from the database and export it to JSON files
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

        materials = []
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

            # Identify of the data is part of an "enumeration" of material
            # e.g., is the key "material_1", or "material_2", etc.
            material_id = key.split("material_")[-1]
            try:
                material_id = int(material_id)
            except:
                pass
            if isinstance(material_id, int) and not value is None:
                materials.append(value)

        # Create a list of materials instead of having multiple material key/value pairs
        if len(materials) > 0:
            for i in range(1, 7):
                del record[f"material_{i}"]
            record["materials"] = materials
    return records
