# Study SQL

Welcome to the Study SQL guide. This document provides a detailed explanation of various SQL concepts and examples using the SQL files from 01 to 95. Each section includes links to specific SQL files and lines for easy navigation.

## Table of Contents

1. [SQL Statements](#sql-statements)
   - [DDL (Data Definition Language)](#ddl-data-definition-language)
     - [Create](#create)
     - [Alter](#alter)
   - [DML (Data Manipulation Language)](#dml-data-manipulation-language)
   - [TCL (Transaction Control Language)](#tcl-transaction-control-language)
2. [Dynamic Management Views](#dynamic-management-views)
3. [Performance Monitoring](#performance-monitoring)
4. [Connection and Session Monitoring](#connection-and-session-monitoring)

## SQL Statements

### DDL (Data Definition Language)

#### Create

The `CREATE` statement is used to create databases, schemas, tables, indexes, views, stored procedures, triggers, and functions. For example, you can create a stored procedure as shown in [01_CREATE.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/01_CREATE.sql) line 99.

- **Database**: [01_CREATE.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/01_CREATE.sql) line 5
- **Schema**: [01_CREATE.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/01_CREATE.sql) line 11
- **Table**: [01_CREATE.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/01_CREATE.sql) line 19
- **Stored Procedure**: [01_CREATE.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/01_CREATE.sql) line 99

#### Alter

The `ALTER` statement is used to modify existing database objects. This includes adding or dropping columns in a table, changing data types, and more.

- **Example**: [02_ALTER.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/02_ALTER.sql)

### DML (Data Manipulation Language)

DML statements are used for managing data within schema objects. These include `INSERT`, `UPDATE`, `DELETE`, and `SELECT`.

- **Insert**: [03_INSERT.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/03_INSERT.sql)
- **Update**: [04_UPDATE.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/04_UPDATE.sql)
- **Delete**: [05_DELETE.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/05_DELETE.sql)

### TCL (Transaction Control Language)

TCL statements are used to manage transactions in the database. These include `COMMIT`, `ROLLBACK`, and `SAVEPOINT`.

- **Example**: [06_TCL.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/06_TCL.sql)

## Dynamic Management Views

Dynamic Management Views (DMVs) provide server state information that can be used to monitor the health of a server instance, diagnose problems, and tune performance.

- **Example**: [95_DYNAMIC_MANAGEMENT_VIEWS.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/SQL%20Objects/95_DYNAMIC_MANAGEMENT_VIEWS.sql)

## Performance Monitoring

Performance monitoring involves tracking various metrics to ensure the SQL Server is running efficiently. This includes CPU usage, memory usage, and I/O performance.

- **Example**: [95_DYNAMIC_MANAGEMENT_VIEWS.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/SQL%20Objects/95_DYNAMIC_MANAGEMENT_VIEWS.sql) line 20

## Connection and Session Monitoring

Monitoring connections and sessions helps in understanding the current load on the server and identifying any blocking issues.

- **Example**: [95_DYNAMIC_MANAGEMENT_VIEWS.sql](file:///c:/AI%20Use%20and%20Deveopment/Study%20SQL/SQL%20Objects/95_DYNAMIC_MANAGEMENT_VIEWS.sql) line 150

---

This document is a work in progress and will be updated with more detailed explanations and links as the analysis of each SQL file is completed.
