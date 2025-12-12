# Advanced Library Management System

A comprehensive Oracle PL/SQL-based library management system with automated operations, error handling, and reporting features.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Docker Setup](#docker-setup)
- [Connection Methods](#connection-methods)
- [Installation](#installation)
- [File Structure](#file-structure)
- [Features](#features)
- [Usage Examples](#usage-examples)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Overview

This system implements a complete library management solution with the following capabilities:

- **User Management**: Role-based access control with user creation logging
- **Book Management**: Track books, types, and availability
- **Borrowing System**: Automated validation, overdue tracking, and penalty calculation
- **Reporting**: Comprehensive reports on availability, borrowing history, and penalties
- **Audit Trail**: Complete logging of all changes to borrowing records
- **Transaction Safety**: Robust error handling with rollback capabilities
- **Blocking Detection**: Tools to identify and resolve database locking situations

## Prerequisites

- Docker and Docker Compose installed
- Oracle Database client tools (optional, for command-line access)
- Database visualization tool (DBeaver, SQL Developer, or similar)

## Docker Setup

### Prerequisites for Oracle Image

The Oracle Database 21c XE image requires:
1. Oracle account (free registration at oracle.com)
2. Accept license agreement for Oracle Database Express Edition
3. Login to Oracle Container Registry:
   ```bash
   docker login container-registry.oracle.com
   ```
4. Pull the image:
   ```bash
   docker pull container-registry.oracle.com/database/express:21.3.0-xe
   ```

**Alternative**: Use community image (no login required):
- Change image in `docker-compose.yml` to: `gvenzl/oracle-xe:21.3.0-slim`

### 1. Start Oracle Database Container

```bash
cd db
docker-compose up -d
```

This will:
- Pull Oracle Database 21c XE image (if not already present)
- Start the database container
- Create persistent volumes for data
- Expose ports 1521 (database) and 5500 (Enterprise Manager)

### 2. Wait for Database Initialization

The database takes approximately 2-3 minutes to initialize. Check the logs:

```bash
docker-compose logs -f oracle-db
```

Wait until you see: `DATABASE IS READY TO USE!`

### 3. Verify Container Status

```bash
docker-compose ps
```

The container should show status as "healthy" or "Up".

### 4. Stop the Database

```bash
docker-compose down
```

To remove volumes (⚠️ **WARNING**: This deletes all data):

```bash
docker-compose down -v
```

## Connection Methods

### Default Connection Details

- **Host**: `localhost`
- **Port**: `1521`
- **Service Name**: `XEPDB1`
- **Default Users**:
  - `SYSTEM` / `Oracle123` (or your ORACLE_PASSWORD)
  - `SYS` / `Oracle123` (as SYSDBA)

### 1. DBeaver

1. Open DBeaver
2. Create New Connection → Oracle
3. Enter connection details:
   - **Host**: `localhost`
   - **Port**: `1521`
   - **Database/SID**: `XEPDB1`
   - **Username**: `SYSTEM`
   - **Password**: `Oracle123` (or from `.env` file)
4. Test Connection → Finish

**JDBC URL Format**:
```
jdbc:oracle:thin:@localhost:1521/XEPDB1
```

### 2. Oracle SQL Developer

1. Open SQL Developer
2. New Connection → Basic
3. Enter details:
   - **Name**: Library System
   - **Username**: `SYSTEM`
   - **Password**: `Oracle123`
   - **Hostname**: `localhost`
   - **Port**: `1521`
   - **Service name**: `XEPDB1`
4. Test → Save → Connect

### 3. Command Line (sqlplus)

```bash
sqlplus SYSTEM/Oracle123@localhost:1521/XEPDB1
```

Or using Docker:

```bash
docker exec -it oracle-library-db sqlplus SYSTEM/Oracle123@XEPDB1
```

### 4. VS Code with Oracle Extension

1. Install "Oracle Developer Tools" extension
2. Add connection in settings:
   ```json
   {
     "oracle.connections": [{
       "name": "Library System",
       "username": "SYSTEM",
       "password": "Oracle123",
       "connectionString": "localhost:1521/XEPDB1"
     }]
   }
   ```

## Installation

### Option 1: Run Consolidated Script (Recommended)

Execute the complete system setup in one go:

```sql
@library_system_all.sql
```

Or from command line:

```bash
sqlplus SYSTEM/Oracle123@localhost:1521/XEPDB1 @library_system_all.sql
```

### Option 2: Run Individual Scripts (For Development)

Execute scripts in order:

```sql
-- 1. Create schema
@00_create_schema.sql

-- 2. Set up users and privileges
@01_users_and_privileges.sql

-- 3. Insert sample data
@02_sample_data.sql

-- 4. Create procedures and functions
@03_procedures_functions.sql

-- 5. Create triggers
@04_triggers.sql

-- 6. Create transaction procedures
@05_transactions.sql

-- 7. Create bonus tasks (blocking detection)
@06_bonus_blocking_demo.sql

-- 8. Run tests (optional)
@07_tests.sql
```

## File Structure

```
db/
├── docker-compose.yml              # Docker orchestration
├── .env.example                    # Environment variables template
├── .gitignore                      # Git ignore rules
├── README.md                       # This file
├── 00_create_schema.sql            # Schema creation (sequences, tables, indexes)
├── 01_users_and_privileges.sql    # User management (Task 1)
├── 02_sample_data.sql              # Sample data insertion
├── 03_procedures_functions.sql    # Procedures & functions (Tasks 2, 3, 6, 8, 9, 10A)
├── 04_triggers.sql                 # Triggers (Tasks 4, 5, 10B)
├── 05_transactions.sql             # Transaction handling (Task 7)
├── 06_bonus_blocking_demo.sql      # Bonus tasks (Tasks 11, 12)
├── 07_tests.sql                    # Comprehensive test scripts
└── library_system_all.sql          # Consolidated script (for submission)
```

## Features

### Task 1: User Management and Privileges
- Creates MANAGER, USER1, and USER2 users
- Implements user creation logging procedure
- Grants appropriate privileges to each user

### Task 2: Overdue Notifications
- **Procedure**: `proc_send_overdue_notifications`
- Identifies books overdue more than 7 days
- Logs notifications to `notification_logs` table

### Task 3: Dynamic Late Fee Calculation
- **Function**: `fn_calc_and_insert_penalty(p_borrowing_id)`
- Calculates fees based on book type:
  - Regular books: $1 per day
  - Reference books: $2 per day
- Automatically inserts penalty records

### Task 4: Borrowing Validation Trigger
- **Trigger**: `trg_borrowing_validation`
- Prevents borrowing if:
  - Student has 3 or more active books
  - Student has overdue books
  - Student is suspended
  - Book is already borrowed

### Task 5: Audit Trail
- **Triggers**: `trg_borrowing_audit_update`, `trg_borrowing_audit_delete`
- Logs all updates and deletes to `audit_trail` table
- Captures old and new data as CLOB

### Task 6: Borrowing History Report
- **Procedure**: `proc_borrowing_history(p_student_id)`
- Uses cursor to retrieve complete borrowing history
- Shows overdue status and associated penalties

### Task 7: Safe Return Process
- **Procedure**: `proc_return_books(p_student_id, p_borrowing_ids)`
- Handles multiple book returns in a single transaction
- Calculates penalties automatically
- Rolls back on any error

### Task 8: Books Availability Report
- **Procedure**: `proc_books_availability_report`
- Shows all books with current status
- Displays borrower information and overdue days

### Task 9: Automated Suspension
- **Procedure**: `proc_suspend_students(p_threshold)`
- Automatically suspends students with unpaid penalties exceeding threshold (default $50)

### Task 10: Advanced Data Integrity
- **Function**: `fn_total_currently_borrowed` - Returns count of currently borrowed books
- **Trigger**: `trg_update_book_availability` - Auto-updates book availability on return

### Task 11 & 12: Blocking Detection (Bonus)
- **View**: `v_blocking_sessions` - Shows blocking/waiting sessions
- **Procedure**: `proc_identify_blockers` - Identifies and provides resolution commands

## Usage Examples

### Send Overdue Notifications

```sql
BEGIN
    proc_send_overdue_notifications;
END;
/
```

### Calculate Penalty for a Borrowing Record

```sql
DECLARE
    v_penalty NUMBER;
BEGIN
    v_penalty := fn_calc_and_insert_penalty(3);
    DBMS_OUTPUT.PUT_LINE('Penalty: $' || v_penalty);
END;
/
```

### View Borrowing History

```sql
BEGIN
    proc_borrowing_history(1);  -- Student ID 1
END;
/
```

### Generate Availability Report

```sql
BEGIN
    proc_books_availability_report;
END;
/
```

### Return Multiple Books

```sql
DECLARE
    v_borrowing_ids SYS.ODCINUMBERLIST;
BEGIN
    v_borrowing_ids := SYS.ODCINUMBERLIST(1, 2, 3);
    proc_return_books(p_student_id => 1, p_borrowing_ids => v_borrowing_ids);
END;
/
```

### Suspend Students with High Penalties

```sql
BEGIN
    proc_suspend_students(p_threshold => 50);
END;
/
```

### Check Total Currently Borrowed

```sql
SELECT fn_total_currently_borrowed FROM dual;
```

### Identify Blocking Sessions

```sql
BEGIN
    proc_identify_blockers;
END;
/
```

## Testing

Run the comprehensive test suite:

```sql
@07_tests.sql
```

Or run individual tests from the test file. The test script verifies:
- Schema creation
- All procedures and functions
- Trigger validations
- Transaction handling
- Audit trail logging
- Blocking session detection

## Troubleshooting

### Database Won't Start

1. Check if port 1521 is already in use:
   ```bash
   netstat -an | grep 1521
   ```
2. Change port in `docker-compose.yml` if needed
3. Check Docker logs:
   ```bash
   docker-compose logs oracle-db
   ```

### Connection Refused

1. Verify container is running:
   ```bash
   docker-compose ps
   ```
2. Wait for database initialization (2-3 minutes)
3. Check if database is ready:
   ```bash
   docker exec -it oracle-library-db sqlplus SYSTEM/Oracle123@XEPDB1
   ```

### Permission Denied Errors

- Ensure you're connected as SYSTEM or a user with appropriate privileges
- Check user grants in `01_users_and_privileges.sql`

### Trigger Errors

- Verify all tables exist before creating triggers
- Check foreign key constraints
- Review trigger dependencies

### Transaction Rollback Issues

- Check error messages in DBMS_OUTPUT
- Verify all borrowing IDs exist and belong to the student
- Ensure no constraint violations

## Test User Credentials

- **MANAGER**: `manager` / `Manager123`
- **USER1**: `user1` / `User1Pass123`
- **USER2**: `user2` / `User2Pass123`
- **SYSTEM**: `SYSTEM` / `Oracle123` (default, change in `.env`)

## Environment Variables

Create a `.env` file (copy from `.env.example`):

```env
ORACLE_PASSWORD=Oracle123
ORACLE_PORT=1521
ORACLE_HTTP_PORT=5500
```

## Additional Resources

- [Oracle Database 21c Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/21/)
- [PL/SQL Language Reference](https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/)
- [Docker Oracle Database Images](https://github.com/oracle/docker-images)

## Notes

- All scripts include comprehensive error handling
- DBMS_OUTPUT is enabled for debugging (set `SET SERVEROUTPUT ON`)
- Sample data is included for testing
- All procedures and functions are documented with comments
- The consolidated script (`library_system_all.sql`) is ready for submission

## License

This project is for educational purposes as part of the Advanced Database Systems course.

