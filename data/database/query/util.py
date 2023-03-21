import sqlite3
from typing import List


def _convert_list_tuple_to_list_dict(data: List[tuple], data_head_list: List[str]):
    """
    convert list of tuples of data to list of dictionary
    :param data: list[tuple] data list
    :param data_head_list: list[string] data header list
    :return: list[dict]
    """
    return [dict(zip(data_head_list, data_tuple)) for data_tuple in data]


def _convert_tuple_to_dict(data: tuple, data_head_list: List[str]):
    """
    convert a tuple to a dictionary
    :param data: tuple
    :param data_head_list: list[str]
    :return: dict
    """
    return dict(zip(data_head_list, data))


def is_table_exist(conn: sqlite3.Connection, table_name):
    """
    Utility function to ensure the table name provided is correct and exist in the OSSTD data tables
    :param conn:
    :param table_name:
    :return:
    """
    cur = conn.cursor()
    list_of_tables = cur.execute(
        f"""SELECT tbl_name FROM sqlite_master WHERE type='table' AND tbl_name='{table_name}'"""
    ).fetchall()
    return True if list_of_tables else False


def match_dict_data_by_key(primary_data: dict, secondary_data: dict):
    """
    This function matches two data dictionaries (primary_data, secondary_data) and return only the matched portion of the dictionary
    Match only applies when only key is matched.

    If key matched, the value will use the one_data value

    :param primary_data:
    :param secondary_data:
    :return:
    """
    return {
        key: primary_data[key]
        for key in primary_data.keys()
        if key in secondary_data.keys()
    }
