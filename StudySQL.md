# Comprehensive SQL Study Guide

Welcome to the comprehensive SQL Study Guide. This document provides detailed explanations of SQL concepts with examples from the included SQL files. Each section includes links to specific SQL files and line numbers for easy navigation.

## Table of Contents

1. [Introduction to SQL](#introduction-to-sql)
2. [SQL Data Definition Language (DDL)](#sql-data-definition-language-ddl)
   - [CREATE](#create)
   - [ALTER](#alter)
   - [DROP](#drop)
   - [TRUNCATE](#truncate)
3. [SQL Data Manipulation Language (DML)](#sql-data-manipulation-language-dml)
   - [SELECT](#select)
   - [INSERT](#insert)
   - [UPDATE](#update)
   - [DELETE](#delete)
4. [SQL Transaction Control Language (TCL)](#sql-transaction-control-language-tcl)
   - [COMMIT](#commit)
   - [ROLLBACK](#rollback)
   - [SAVEPOINT](#savepoint)
5. [SQL Data Control Language (DCL)](#sql-data-control-language-dcl)
   - [GRANT](#grant)
   - [REVOKE](#revoke)
6. [SQL Constraints](#sql-constraints)
7. [SQL Joins](#sql-joins)
8. [SQL Indexes](#sql-indexes)
9. [SQL Views](#sql-views)
10. [SQL Stored Procedures](#sql-stored-procedures)
11. [SQL Functions](#sql-functions)
12. [SQL Triggers](#sql-triggers)
13. [SQL Transactions](#sql-transactions)
14. [SQL Advanced Concepts](#sql-advanced-concepts)
    - [Common Table Expressions (CTE)](#common-table-expressions-cte)
    - [Window Functions](#window-functions)
    - [Pivot and Unpivot](#pivot-and-unpivot)
    - [Temporary Tables](#temporary-tables)
15. [SQL Performance Optimization](#sql-performance-optimization)
16. [SQL Server Dynamic Management Views](#sql-server-dynamic-management-views)

## Introduction to SQL

SQL (Structured Query Language) is a standard language for storing, manipulating, and retrieving data in relational database management systems. SQL is used to communicate with a database, and it is the standard language for relational database management systems.

## SQL Data Definition Language (DDL)

DDL statements are used to define the database structure or schema. These statements create, modify, and remove database objects such as tables, indexes, and users.

### CREATE

The `CREATE` statement is used to create new database objects.

#### CREATE DATABASE

Used to create a new database.

```sql
-- Example from [01_CREATE.sql](c:\AI Use and Deveopment\Study SQL\01_CREATE.sql#L5)
CREATE DATABASE HRSystem;