"""
This module contains functions that help to fetch data from tables
"""
import sqlite3

from query.util import (
    _convert_list_tuple_to_list_dict,
    _convert_tuple_to_dict,
    is_table_exist,
)


def fetch_table(conn: sqlite3.Connection, table_name: str):
    """
    Fetch all data from a specific table
    :param conn:
    :param table_name: String data table
    :return: list of data or empty list
    """
    # Make sure the table exist
    if is_table_exist(conn, table_name):
        fetch_query = f"""SELECT * FROM {table_name}"""
        cur = conn.execute(fetch_query)
        data_header = list(map(lambda x: x[0], cur.description))

        return _convert_list_tuple_to_list_dict(cur.fetchall(), data_header)
    return []


def fetch_a_record_from_table_by_id(
    conn: sqlite3.Connection, table_name: str, index: int
):
    """
    Fetch a data record matched by ID from a specific table
    :param conn:
    :param table_name: String lighting data table
    :param index: Integer, lighting object ID
    :return: dict
    """
    # Make sure the table exist
    if is_table_exist(conn, table_name):
        fetch_query = f"""SELECT * FROM {table_name} WHERE id={index}"""
        cur = conn.execute(fetch_query)
        data_header = list(map(lambda x: x[0], cur.description))

        return _convert_tuple_to_dict(cur.fetchone(), data_header)
    return dict()


def fetch_records_from_table_by_key_values(
    conn: sqlite3.Connection, table_name: str, key_value_dict: dict
):
    """
    Fetch a data record matched by key value pairs in the dict from a specific table
    :param conn:
    :param table_name: String data table
    :param key_value_dict: Dict, key value pair where Key shall be the column name and value shall be the value
    :return: dict
    """
    # Make sure the table exist
    if is_table_exist(conn, table_name):
        condition = " AND ".join(
            [f"{key} = '{key_value_dict[key]}'" for key in key_value_dict.keys()]
        )
        fetch_query = f"""SELECT * FROM  {table_name} WHERE {condition}"""
        cur = conn.execute(fetch_query)
        data_header = list(map(lambda x: x[0], cur.description))
        return _convert_list_tuple_to_list_dict(cur.fetchall(), data_header)
    return []
