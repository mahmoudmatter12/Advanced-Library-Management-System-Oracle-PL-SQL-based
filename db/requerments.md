# Advanced Library Management System — Implementation Checklist
---

# 1. Overview

This document enumerates all steps and requirements for the **Advanced Library Management System** task. It is organized by the task numbers from the assignment and includes:

* Schema / object creation steps
* PL/SQL procedures, functions, triggers and transactions to implement
* Test cases and verification queries
* Suggested order and filenames

---

# 2. Setup & Conventions

* Oracle conventions used:

  * Primary key columns named `id` (NUMBER).
  * Use sequences for auto-increment: `seq_<table>`.
  * Use `created_at` / `timestamp` columns of type `DATE` where needed.
  * All DDL and DML scripts will be placed in one `.sql` file for submission (e.g., `library_system_all.sql`).
  * Use `DBMS_OUTPUT.PUT_LINE` for reporting statements in PL/SQL blocks.
* Suggested files:

  * `00_create_schema.sql` — create tables, sequences, constraints.
  * `01_users_and_privileges.sql` — user / role creation and grants.
  * `02_triggers_audit_and_validation.sql` — triggers for audit and borrowing validation.
  * `03_procedures_functions.sql` — PL/SQL procedures and functions (notifications, penalties, suspension, reports).
  * `04_transactions_and_examples.sql` — transaction blocks, blocker-wait examples, and test cases.
  * `README.md` — short usage and running instructions.

---

# 3. Schema Creation (DDL) — Step-by-step

1. Create sequences:

   * `seq_booktypes`
   * `seq_books`
   * `seq_students`
   * `seq_borrowing`
   * `seq_penalties`
   * `seq_audit`
   * `seq_notification`
   * `seq_usercreationlog`

2. Create tables:

   * `book_types`

     * `id` NUMBER PK
     * `type_name` VARCHAR2(50) NOT NULL
     * `fee_rate` NUMBER NOT NULL
   * `books`

     * `id` NUMBER PK
     * `title` VARCHAR2(200) NOT NULL
     * `author` VARCHAR2(100)
     * `availability` VARCHAR2(20) NOT NULL DEFAULT 'Available' CHECK(availability IN ('Available','Borrowed'))
     * `type_id` NUMBER FK → `book_types(id)`
   * `students`

     * `id` NUMBER PK
     * `name` VARCHAR2(200) NOT NULL
     * `membership_status` VARCHAR2(20) NOT NULL DEFAULT 'active' CHECK(membership_status IN ('active','suspended'))
   * `borrowing_records`

     * `id` NUMBER PK
     * `book_id` NUMBER FK → `books(id)` NOT NULL
     * `student_id` NUMBER FK → `students(id)` NOT NULL
     * `borrow_date` DATE DEFAULT SYSDATE NOT NULL
     * `return_date` DATE NULL
     * `status` VARCHAR2(20) DEFAULT 'Borrowed' CHECK(status IN ('Borrowed','Returned','Overdue')) NOT NULL
   * `penalties`

     * `id` NUMBER PK
     * `student_id` NUMBER FK → `students(id)` NOT NULL
     * `amount` NUMBER NOT NULL
     * `reason` VARCHAR2(200)
     * `paid_status` VARCHAR2(10) DEFAULT 'unpaid' CHECK(paid_status IN ('unpaid','paid'))
   * `audit_trail`

     * `id` NUMBER PK
     * `table_name` VARCHAR2(100) NOT NULL
     * `operation` VARCHAR2(20) NOT NULL
     * `old_data` CLOB NULL
     * `new_data` CLOB NULL
     * `created_at` DATE DEFAULT SYSDATE NOT NULL
   * `notification_logs`

     * `id` NUMBER PK
     * `student_id` NUMBER NOT NULL
     * `book_id` NUMBER NOT NULL
     * `overdue_days` NUMBER NOT NULL
     * `notification_date` DATE DEFAULT SYSDATE NOT NULL
   * `user_creation_log`

     * `id` NUMBER PK
     * `username` VARCHAR2(100) NOT NULL
     * `created_by` VARCHAR2(100) NOT NULL
     * `created_at` DATE DEFAULT SYSDATE NOT NULL

3. Add constraints:

   * Foreign keys for `books.type_id`, `borrowing_records.book_id`, `borrowing_records.student_id`, `penalties.student_id`.
   * Indexes where appropriate (e.g., `borrowing_records(student_id)`, `borrowing_records(status)`).

---

# 4. Task-by-Task Implementation Steps

Below each task number, write the exact PL/SQL object to implement and simple test steps.

## Task 1 — User Management and Privileges

* Steps:

  1. Create `MANAGER` user and password (scripted).
  2. Create `USER1` and `USER2` users (created by `MANAGER`).
  3. Grant `MANAGER` the ability to create users (GRANT CREATE USER) or provide `MANAGER` role with necessary privileges.
  4. Set `USER1` to create `books` and `book_types` tables (or simulate by running the DDL as USER1).
  5. Using `USER2`, insert 5 rows into `book_types` and `books`.
  6. Implement PL/SQL procedure `log_user_creation(p_username VARCHAR2)` that captures `username`, `USER` (creator) and `SYSDATE` and inserts into `user_creation_log`.

     * Optionally: create a DDL trigger that fires on CREATE USER (if allowed) to call this procedure.

* Verification:

  * Query `user_creation_log` to confirm entries.
  * Confirm `books` and `book_types` populated.

## Task 2 — Overdue Notifications Procedure

* Object:

  * Procedure `proc_send_overdue_notifications` or `proc_log_overdues`.
* Logic:

  1. Find borrowing records where:

     * `return_date` IS NULL AND `borrow_date + 7 < SYSDATE`
     * OR `return_date IS NOT NULL AND return_date > borrow_date + 7` (for late returned)
  2. Calculate overdue days: `CEIL(SYSDATE - (borrow_date + 7))` or `GREATEST(0, TRUNC(SYSDATE) - (borrow_date + 7))`.
  3. Insert rows into `notification_logs` for each overdue.
* Verification:

  * Insert sample records with older `borrow_date`, run procedure, check `notification_logs`.

## Task 3 — Dynamic Late Fee Calculation Function

* Object:

  * Function `fn_calc_and_insert_penalty(p_borrowing_id NUMBER) RETURN NUMBER`.
* Logic:

  1. Read `borrow_date`, `return_date`, `book_id` from `borrowing_records`.
  2. Compute overdue days:

     * If `return_date IS NULL`: overdue_days = `GREATEST(0, TRUNC(SYSDATE) - (borrow_date + 7))`
     * If `return_date IS NOT NULL`: overdue_days = `GREATEST(0, TRUNC(return_date) - (borrow_date + 7))`
  3. Read `book_type` via `books.type_id` and `book_types.fee_rate` (or apply rules: $1 or $2).
  4. fee = overdue_days * fee_rate
  5. Insert into `penalties` with `student_id`, `amount`, `reason` (e.g., 'Late fee for borrow id X').
  6. Return fee.
* Verification:

  * Create borrowing records with known overdue days; call function; confirm `penalties` and return value.

## Task 4 — Borrowing Validation Trigger

* Object:

  * `BEFORE INSERT` trigger on `borrowing_records` (e.g., `trg_borrowing_validation`).
* Logic:

  1. Count active borrows for `:NEW.student_id` where `status = 'Borrowed'` or `return_date IS NULL`.
  2. Check for overdue borrows for that student:

     * `borrow_date + 7 < SYSDATE` and `return_date IS NULL`, OR other logic.
  3. If overdue exists OR count >= 3 → `RAISE_APPLICATION_ERROR(-20001, 'Cannot borrow: limit reached or overdue exists')`.
  4. Otherwise, allow insert and update `books.availability` to `'Borrowed'`.
* Verification:

  * Attempt to insert a 4th active borrow for a student; expect error.
  * Attempt to insert while student has an overdue; expect error.

## Task 5 — Audit Trail for BorrowingRecords

* Objects:

  * `BEFORE UPDATE` trigger `trg_borrowing_audit_update`
  * `BEFORE DELETE` trigger `trg_borrowing_audit_delete`
* Logic:

  * On UPDATE: insert into `audit_trail` with `table_name='BORROWING_RECORDS'`, `operation='UPDATE'`, `old_data` formatted from `:OLD` row, `new_data` from `:NEW`, `created_at` SYSDATE.
  * On DELETE: insert into `audit_trail` with `operation='DELETE'`, `old_data` from `:OLD`, `new_data` NULL.
* Verification:

  * Update a borrowing record, then query `audit_trail`.
  * Delete a borrowing record, then query `audit_trail`.

## Task 6 — Borrowing History Report (Cursor)

* Object:

  * Procedure `proc_borrowing_history(p_student_id NUMBER)`.
* Logic:

  1. Cursor that selects borrowing records for `p_student_id`, joining `books` and `penalties` (LEFT JOIN).
  2. For each row, determine `status` (overdue/on time) and associated penalty sum.
  3. Output via `DBMS_OUTPUT.PUT_LINE` useful columns: title, borrow_date, return_date, status, penalty.
* Verification:

  * Call with known `student_id` and inspect DBMS_OUTPUT (enable `SET SERVEROUTPUT ON`).

## Task 7 — Safe Return Process with Transactions

* Object:

  * PL/SQL block or procedure `proc_return_books(p_student_id NUMBER, p_borrowing_ids SYS.ODCINUMBERLIST)` or similar.
* Logic:

  1. Start transaction (implicit in PL/SQL).
  2. Optionally set SAVEPOINT `before_return`.
  3. Loop over `p_borrowing_ids`:

     * Call `fn_calc_and_insert_penalty` for each if overdue.
     * Update `borrowing_records` set `status='Returned'`, `return_date=SYSDATE`.
  4. If any exception occurs: `ROLLBACK TO SAVEPOINT` or full `ROLLBACK`, return error.
  5. If all ok: `COMMIT`.
* Verification:

  * Create a scenario with 3 entries; call procedure with all; check that all updated and penalties inserted.
  * Simulate an error midway (e.g., forced exception) and confirm rollback.

## Task 8 — Books Availability Report

* Object:

  * Procedure `proc_books_availability_report`.
* Logic:

  1. Select all books and determine status:

     * If `availability='Available'` and not present in active `borrowing_records` → Available.
     * If present in `borrowing_records` with `status='Borrowed'` or `return_date IS NULL` → Borrowed (show `student_id`, name).
     * If borrowed and overdue → mark Overdue and compute overdue days.
  2. Print via `DBMS_OUTPUT`.
* Verification:

  * Populate sample data with mix of states; run report.

## Task 9 — Automated Suspension Procedure

* Object:

  * Procedure `proc_suspend_students(p_threshold NUMBER DEFAULT 50)`.
* Logic:

  1. Aggregate unpaid penalties per student (`SUM(amount)` WHERE `paid_status='unpaid'`).
  2. For students exceeding `p_threshold`, `UPDATE students SET membership_status='suspended'`.
* Verification:

  * Create penalties for a student above threshold; run procedure; check `students.membership_status`.

## Task 10 — Advanced Data Integrity & Trigger

* Part A — Function:

  * `fn_total_currently_borrowed RETURN NUMBER`
  * Logic: return `COUNT(*)` from `borrowing_records` WHERE `status='Borrowed' OR (return_date IS NULL AND status <> 'Returned')`.
* Part B — Trigger:

  * `AFTER UPDATE` trigger on `borrowing_records` that when `:NEW.status='Returned'` and `:OLD.status <> 'Returned'`, updates `books.availability='Available'`.
* Verification:

  * Update a record to `Returned`, confirm `books.availability='Available'`.
  * Call function and verify count.

## Bonus Task 11 — Blocker-Waiting Demonstration

* Steps:

  1. Session A (User1): start transaction and update a borrowing record, but do not commit.

     * `UPDATE borrowing_records SET status='Processing' WHERE id = X;` (no commit)
  2. Session B (User2): attempt to insert a penalty that references borrowing record X (or update the same borrowing record) → will block.
  3. Use Oracle views to monitor blocking:

     * `SELECT sid, serial#, blocking_session FROM v$session WHERE blocking_session IS NOT NULL OR wait_class <> 'Idle';`
* Verification:

  * Confirm blocked session exists and can be resolved by committing/rolling back the blocker.

## Bonus Task 12 — Identify Blocker & Waiting Sessions

* Steps:

  1. Query `v$session`, `v$lock` and `v$session_wait` to retrieve `SID`, `SERIAL#` for both blocker and waiter.
  2. Provide commands to resolve (e.g., `ALTER SYSTEM KILL SESSION 'sid,serial#'` or instruct to commit/rollback the blocker).
* Notes:

  * Include safety note: do not kill sessions in production without authorization.

---

# 5. Recommended Implementation Order (practical)

1. `00_create_schema.sql` — create sequences and tables (DDL).
2. `01_users_and_privileges.sql` — create MANAGER, USER1, USER2, run initial inserts for books & types as USER2.
3. `02_basic_data.sql` — insert sample students, books, borrowing records to use for testing.
4. `03_procedures_functions.sql` — implement functions and procedures:

   * `fn_calc_and_insert_penalty`
   * `proc_send_overdue_notifications`
   * `proc_borrowing_history`
   * `proc_suspend_students`
   * `fn_total_currently_borrowed`
5. `04_triggers.sql` — implement triggers:

   * borrowing validation (BEFORE INSERT)
   * audit triggers (BEFORE UPDATE/DELETE)
   * availability update trigger (AFTER UPDATE to set book available)
6. `05_transactions_examples.sql` — safe return transactional block, blocking demo and monitoring queries.
7. `06_tests_and_docs.sql` — test cases and queries to show outputs with `SET SERVEROUTPUT ON`.
8. `README.md` — instructions to run scripts, credentials for test users, and notes.

---

# 6. Test Plan / Example Queries

* Enable server output: `SET SERVEROUTPUT ON SIZE 1000000;`
* Verify sequences:

  * `SELECT seq_books.NEXTVAL FROM dual;`
* Verify tables:

  * `SELECT * FROM books;`
  * `SELECT * FROM borrowing_records WHERE student_id = <test_id>;`
* Test triggers and procedures:

  * Try inserting a borrow for a student with 3 active borrows → expect exception.
  * Insert overdue borrow and run `proc_send_overdue_notifications`; check `notification_logs`.
  * Call `fn_calc_and_insert_penalty(<borrow_id>)` and check `penalties`.

---

# 7. Error Handling & Edge Cases (must cover)

* Borrow_date in the future — treat as invalid (reject insertion or normalize).
* Negative overdue days — ensure `GREATEST(0, days)` is used.
* Race conditions when checking counts in trigger — serializable checks or SELECT FOR UPDATE where needed.
* Trigger recursion risk — avoid updating the same table inside triggers without required safeguards.
* CLOB size when storing `old_data`/`new_data` — format succinctly.

---

# 8. Deliverables Checklist

* [ ] Single consolidated SQL script `library_system_all.sql` with clear comments
* [ ] Separate smaller scripts as suggested (optional)
* [ ] `IMPLEMENTATION_PLAN.md` (this file)
* [ ] `README.md` with run order, initial credentials, and test commands
* [ ] Demonstration data for testing (sample inserts)
* [ ] Example outputs or screenshots (DBMS_OUTPUT) showing procedures/triggers working
* [ ] Blocker-wait demonstration steps and monitoring queries
