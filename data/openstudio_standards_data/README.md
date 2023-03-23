# OpenStudio Standards Data
This folder contains code that manages the data needed by OpenStudio Standards to operate

## Prerequisites
Python 3.10 (3.9 could work but not tested)

## Quick Start Guide
Clone this repo
To create the full database in your local repo:

```python
import sqlite3
from applications.database_maintenance import create_openstudio_standards_database_from_csv

conn = sqlite3.connect('openstudio_standards.db')
create_openstudio_standards_database(conn)
conn.close()

```

This code will generate an `openstudio_standards_database.sql` in the same file directory.

## How to contribute
1. Create a new branch
2. Write code
3. Run `pipenv run black .` -> format your code
4. Run `pipenv run pytest` -> make sure all unit test is passed (NOTE: you must run pytest under data-refactor folder)

Push your changes.
