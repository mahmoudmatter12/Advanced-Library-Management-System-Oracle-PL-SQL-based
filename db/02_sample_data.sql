-- ============================================================================
-- Advanced Library Management System
-- Sample Data Insertion
-- ============================================================================
-- This script inserts sample data for testing all functionality
-- ============================================================================

SET SERVEROUTPUT ON SIZE 1000000;

-- ============================================================================
-- 1. INSERT BOOK TYPES
-- ============================================================================

INSERT INTO book_types (id, type_name, fee_rate) VALUES (seq_booktypes.NEXTVAL, 'Regular Book', 1);
INSERT INTO book_types (id, type_name, fee_rate) VALUES (seq_booktypes.NEXTVAL, 'Reference Book', 2);

COMMIT;

DBMS_OUTPUT.PUT_LINE('Inserted ' || SQL%ROWCOUNT || ' book types');

-- ============================================================================
-- 2. INSERT BOOKS (5 books as required)
-- ============================================================================

-- Regular Books
INSERT INTO books (id, title, author, availability, type_id) 
VALUES (seq_books.NEXTVAL, 'Introduction to Database Systems', 'John Smith', 'Available', 1);

INSERT INTO books (id, title, author, availability, type_id) 
VALUES (seq_books.NEXTVAL, 'Advanced SQL Programming', 'Jane Doe', 'Available', 1);

INSERT INTO books (id, title, author, availability, type_id) 
VALUES (seq_books.NEXTVAL, 'Oracle PL/SQL Guide', 'Robert Johnson', 'Available', 1);

-- Reference Books
INSERT INTO books (id, title, author, availability, type_id) 
VALUES (seq_books.NEXTVAL, 'Database Design Reference Manual', 'Alice Williams', 'Available', 2);

INSERT INTO books (id, title, author, availability, type_id) 
VALUES (seq_books.NEXTVAL, 'SQL Standards Encyclopedia', 'Michael Brown', 'Available', 2);

COMMIT;

DBMS_OUTPUT.PUT_LINE('Inserted ' || SQL%ROWCOUNT || ' books');

-- ============================================================================
-- 3. INSERT STUDENTS
-- ============================================================================

INSERT INTO students (id, name, membership_status) 
VALUES (seq_students.NEXTVAL, 'Ahmed Hassan', 'active');

INSERT INTO students (id, name, membership_status) 
VALUES (seq_students.NEXTVAL, 'Fatima Ali', 'active');

INSERT INTO students (id, name, membership_status) 
VALUES (seq_students.NEXTVAL, 'Mohammed Ibrahim', 'active');

INSERT INTO students (id, name, membership_status) 
VALUES (seq_students.NEXTVAL, 'Sara Ahmed', 'active');

INSERT INTO students (id, name, membership_status) 
VALUES (seq_students.NEXTVAL, 'Omar Khaled', 'active');

COMMIT;

DBMS_OUTPUT.PUT_LINE('Inserted ' || SQL%ROWCOUNT || ' students');

-- ============================================================================
-- 4. INSERT BORROWING RECORDS (Various States)
-- ============================================================================

-- Current borrowings (not overdue)
INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, return_date, status)
VALUES (seq_borrowing.NEXTVAL, 1, 1, SYSDATE - 3, NULL, 'Borrowed');

INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, return_date, status)
VALUES (seq_borrowing.NEXTVAL, 2, 2, SYSDATE - 2, NULL, 'Borrowed');

-- Overdue borrowings (more than 7 days)
INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, return_date, status)
VALUES (seq_borrowing.NEXTVAL, 3, 3, SYSDATE - 10, NULL, 'Overdue');

INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, return_date, status)
VALUES (seq_borrowing.NEXTVAL, 4, 1, SYSDATE - 15, NULL, 'Overdue');

-- Returned books (on time)
INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, return_date, status)
VALUES (seq_borrowing.NEXTVAL, 5, 4, SYSDATE - 20, SYSDATE - 13, 'Returned');

-- Update book availability for borrowed books
UPDATE books SET availability = 'Borrowed' WHERE id IN (1, 2, 3, 4);

COMMIT;

DBMS_OUTPUT.PUT_LINE('Inserted ' || SQL%ROWCOUNT || ' borrowing records');

-- ============================================================================
-- 5. DISPLAY SUMMARY
-- ============================================================================

DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('Sample Data Insertion Complete!');
DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('Summary:');
DBMS_OUTPUT.PUT_LINE('  - Book Types: 2');
DBMS_OUTPUT.PUT_LINE('  - Books: 5');
DBMS_OUTPUT.PUT_LINE('  - Students: 5');
DBMS_OUTPUT.PUT_LINE('  - Borrowing Records: 5');
DBMS_OUTPUT.PUT_LINE('========================================');

