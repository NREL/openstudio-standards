import unittest
from unittest import TestCase
from unittest import mock
import os
import sqlite3
import difflib
import glob
import shutil
from applications.database_maintenance import (
    create_openstudio_standards_database_from_csv,
    create_openstudio_standards_database_from_json,
    export_openstudio_standards_database_to_csv,
    export_openstudio_standards_database_to_json,
)
from database_engine.database import DBOperation


CREATE_L3_TEST_TABLE = """
CREATE TABLE level_3_table (id INTEGER PRIMARY KEY, name TEXT);
"""
INSERT_L3_TEST_TABLE = f"""
    INSERT INTO level_3_table
    (name)
    VALUES (?);
"""

CREATE_L2_TABLE = """
CREATE TABLE level_2_table (id INTEGER PRIMARY KEY, associate_table TEXT, foreign_key TEXT)
"""

INSERT_L2_TABLE = f"""
    INSERT INTO level_2_table
    (associate_table, foreign_key)
    VALUES (?, ?);
"""


class SampleL3TestTable(DBOperation):
    def __init__(self):
        super(SampleL3TestTable, self).__init__(
            table_name="l3_table",
            record_template={},
            initial_data_directory="",
            create_table_query=CREATE_L3_TEST_TABLE,
            insert_record_query=INSERT_L3_TEST_TABLE,
        )

    def _preprocess_record(self, record):
        return (record["name"],)


class SampleL2TestTable(DBOperation):
    def __init__(self):
        super(SampleL2TestTable, self).__init__(
            table_name="test_table",
            record_template={},
            initial_data_directory="",
            create_table_query=CREATE_L2_TABLE,
            insert_record_query=INSERT_L2_TABLE,
        )

    def _preprocess_record(self, record):
        return (record["associate_table"], record["foreign_key"])

    def _get_weak_foreign_key_value(self, record):
        return record["associate_table"], "id", record["foreign_key"]


class TestWeakForeignKeyAssociation(unittest.TestCase):
    def setUp(self):
        # Create a test database with two tables and index
        self.conn = sqlite3.connect(":memory:")
        self.cur = self.conn.cursor()
        self.level_2_table = SampleL2TestTable()
        self.level_3_table = SampleL3TestTable()
        self.level_2_table.create_a_table(self.conn)
        self.level_3_table.create_a_table(self.conn)
        self.level_3_table.add_a_record(self.conn, {"name": "test_value_1"})  # index 1
        self.level_3_table.add_a_record(self.conn, {"name": "test_value_2"})  # index 2

    def tearDown(self):
        # close the database connection
        self.cur.close()
        self.conn.close()

    def test_index_exists(self):
        # Test that the function correctly identifies an existing index
        add_success = self.level_2_table.add_a_record(
            self.conn, {"associate_table": "level_3_table", "foreign_key": "1"}
        )
        self.assertTrue(add_success)

    def test_index_does_not_exist(self):
        # Test that the function validated the index is not exist
        add_success = self.level_2_table.add_a_record(
            self.conn, {"associate_table": "level_3_table", "foreign_key": "3"}
        )
        self.assertFalse(add_success)

    def test_table_does_not_exist(self):
        # Test if the table is not exist
        add_success = self.level_2_table.add_a_record(
            self.conn, {"associate_table": "missing_table", "foreign_key": "1"}
        )
        self.assertFalse(add_success)


def create_db(db_name, from_type=""):
    # Delete DB if already exists
    if os.path.isfile(f"{db_name}.db"):
        os.remove(f"{db_name}.db")
    conn = sqlite3.connect(f"{db_name}.db")
    # Create DB
    if from_type == "json":
        create_openstudio_standards_database_from_json(conn)
    else:
        create_openstudio_standards_database_from_csv(conn)
    return conn


def test_create_export_database():
    # Create DB from JSON file
    db_name = "openstudio_standards_data"
    conn = create_db(db_name=db_name, from_type="json")

    # Check that DB exists
    assert os.path.isfile(f"{db_name}.db")

    # Foreign key check
    cur = conn.cursor()
    cur.execute("PRAGMA foreign_key_check;")
    res = cur.fetchall()
    assert len(res) == 0, f"Foreign key issue: {res}"

    # Create a copy of original JSON files
    if os.path.isdir("./original_database_files"):
        shutil.rmtree("./original_database_files", ignore_errors=True)
    shutil.copytree("./database_files", "./original_database_files")

    # Export data to JSON and CSV files
    export_openstudio_standards_database_to_json(conn, save_dir="./database_files/")
    export_openstudio_standards_database_to_csv(conn, save_dir="./database_files/")
    conn.close()

    # Regenerate DB from JSON and CSV files
    db_name = "openstudio_standards_data_from_csv"
    conn_csv = create_db(db_name=db_name, from_type="csv")
    db_name = "openstudio_standards_data_from_json"
    conn_json = create_db(db_name=db_name, from_type="json")

    # Export both DB to JSON files
    if not os.path.isdir("./test/database_files_from_json"):
        os.mkdir("./test/database_files_from_json")
    if not os.path.isdir("./test/database_files_from_csv"):
        os.mkdir("./test/database_files_from_csv")
    export_openstudio_standards_database_to_json(
        conn_json, save_dir="./test/database_files_from_json/"
    )
    export_openstudio_standards_database_to_json(
        conn_csv, save_dir="./test/database_files_from_csv/"
    )
    conn.close()

    # Compare original JSON files with the ones generated from both DB
    # There should be no difference between the JSON files originating
    # from a DB generated from JSON or CSV files
    filenames = glob.glob("./test/database_files_from_json/*.json")
    filenames = [os.path.basename(f) for f in filenames]
    for f in filenames:
        with open(f"./test/database_files_from_json/{f}") as f_from_json:
            fc_from_json = f_from_json.readlines()
        with open(f"./test/database_files_from_csv/{f}") as f_from_csv:
            fc_from_csv = f_from_csv.readlines()
        with open(f"./original_database_files/{f}") as f_org:
            fc_org = f_org.readlines()
            assert (
                fc_from_json == fc_from_csv == fc_org
            ), f"Content is different in {f}.json files"
