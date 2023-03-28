import sqlite3
import logging

import database_tables as tables
from database_engine.assertions import assert_
from database_engine.database_util import read_csv_to_list_dict, read_json_to_list_dict


def create_openstudio_standards_database_from_csv(conn: sqlite3.Connection):
    database_available_tables = tables.__gettables__()
    table_list = [table[1]() for table in database_available_tables]
    with conn:
        for datatable in table_list:
            datatable.create_a_table(conn)
            data = read_csv_to_list_dict(f"{datatable.initial_data_directory}.csv")
            for record in data:
                logging.info(record)
                assert_(
                    datatable.add_a_record(conn, record),
                    f"Unsuccessful adding a new record: {record} to table {datatable.data_table_name}",
                )


def create_openstudio_standards_database_from_json(conn: sqlite3.Connection):
    database_available_tables = tables.__gettables__()
    table_list = [table[1]() for table in database_available_tables]
    with conn:
        for datatable in table_list:
            datatable.create_a_table(conn)
            data = read_json_to_list_dict(f"{datatable.initial_data_directory}.json")
            for record in data:
                logging.info(record)
                assert_(
                    datatable.add_a_record(conn, record),
                    f"Unsuccessful adding a new record: {record} to table {datatable.data_table_name}",
                )


def export_openstudio_standards_database_to_csv(conn: sqlite3.Connection, save_dir=""):
    database_available_tables = tables.__gettables__()
    table_list = [table[1]() for table in database_available_tables]
    with conn:
        for datatable in table_list:
            datatable.export_table_to_csv(conn, save_dir)


def export_openstudio_standards_database_to_json(conn: sqlite3.Connection, save_dir=""):
    database_available_tables = tables.__gettables__()
    table_list = [table[1]() for table in database_available_tables]
    with conn:
        for datatable in table_list:
            datatable.export_table_to_json(conn, save_dir)
