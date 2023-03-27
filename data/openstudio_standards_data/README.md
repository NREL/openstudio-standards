# OpenStudio-Standards Data
This folder contains the code that manages the data needed by OpenStudio-Standards to operate. The data is managed through a SQLite database. The database is not hosted on the repository but can be easily and quickly be created with a few lines of code (see [Quick Start Guide](#markdown-header-quick-start-guide)). The database is managed by code located in the `./database_engine` and `./database_tables` folders. Data used to populate the database tables is located in `./database_files`. Pre-constructed queries and code for other type of applications for the database is located in `./query` and in `./applications`. Some tests to ensure that the database can be successfully created are located in `./test`.

## Motivation
Using a relational database make the management of data seamless as the database maintains relationships among the different data tables and performs automatic data validation. Data fed to the database is currently stored in JSON files. This enable version control of the content of the database. As the format of these JSON files is currently different than the one needed by OpenStudio Standard, functions have been built to automate the export of the data to the required format (see [Quick Start Guide](#markdown-header-quick-start-guide)).
## Prerequisites
Below are listed the prerequisites to any of the database related code.
- Python 3.10
## Database Structure and Covered Data
### Structure
The figure below shows an overview of the structure of the database and of the data management approach.
![Overview of the Database Structure](database_structure.png "Database Structure")
### Covered Data
The space type related data is made of three distinct but interconnected levels. The first level, level 1, contains the main space type name list and their related sub-space types. Sub-space types are a reference 
## Quick Start Guide
### Create the Database
```python
import sqlite3
from applications.database_maintenance import create_openstudio_standards_database_from_json

conn = sqlite3.connect('openstudio_standards.db')
create_openstudio_standards_database_from_json(conn)
conn.close()
```

This code will generate an `openstudio_standards_database.sql` file in the same file directory. The database can be opened using a software such as [DB Browser for SQLite](https://sqlitebrowser.org/).
### Export the Database Data
```python
from applications.database_maintenance import export_openstudio_standards_database_to_json
conn = sqlite3.connect('openstudio_standards.db')
export_openstudio_standards_database_to_json(conn, save_dir='./database_files/')
```
Assuming that `openstudio_standards.db` is a valid SQLite database name, the code above will export the content of the database tables to JSON files located in `./database_files/`. Because data tables are typically easier to read and parse in a spreadsheet format, the data tables can also be exported to CSV files. The code block below shows an example of how one can do so.
```python
from applications.database_maintenance import export_openstudio_standards_database_to_csv
conn = sqlite3.connect('openstudio_standards.db')
export_openstudio_standards_database_to_csv(conn, save_dir='./database_files/')
```
## Future Enhancements
- Additional code versions
- Potentially direct query to the database to avoid having to store two sets of JSON data files
- Move this whole folder to a different repository; Updates to the OpenStudio-Standards data would be made through automated PRs every time updates would be made to the data repository

## Contribute
### Code Formatting
Consistent code formatting is enforced by using the [Black Python code formatter](https://github.com/psf/black). Tests are run to make sure that any changes to the code is consistent with Black's formatting standards. Before creating a pull request and after installing Black, run `black -l 88 ./` to format all Python files within this directory.
### Tests
A small set of test have been implemented, mostly to make sure that further edits to the data or database structure is valid, and that JSON and CSV files generated from the database include the same content. Tests are run using a GitHub action, see the workflow YAML file in `../../.github/workflow/openstudio_standards_database.yml`.
