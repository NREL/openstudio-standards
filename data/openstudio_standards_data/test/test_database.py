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


class TestDatabaseQueries(TestCase):
    """
    Test database - unfinished
    """

    def fix_dbc(self):
        dbc = mock.MagicMock(spec=["cursor"])
        dbc.autocommit = True
        return dbc

    def fix_rows(self):
        rows = [{"id": 1, "name": "John"}, {"id": 2, "name": "Jane"}]
        return rows

    def test_insert_rows_calls_cursor_method(self):
        dbc = self.fix_dbc()
        rows = self.fix_rows()
        pass


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
    filenames = [f.split("\\")[-1] for f in filenames]
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
