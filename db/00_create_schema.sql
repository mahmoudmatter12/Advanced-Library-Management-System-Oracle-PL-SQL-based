-- ============================================================================
-- Advanced Library Management System
-- Schema Creation Script
-- ============================================================================
-- This script creates all sequences, tables, constraints, and indexes
-- for the library management system.
-- ============================================================================

-- Enable output for debugging
SET SERVEROUTPUT ON SIZE 1000000;

-- ============================================================================
-- 1. CREATE SEQUENCES
-- ============================================================================

-- Sequence for book_types table
CREATE SEQUENCE seq_booktypes
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- Sequence for books table
CREATE SEQUENCE seq_books
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- Sequence for students table
CREATE SEQUENCE seq_students
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- Sequence for borrowing_records table
CREATE SEQUENCE seq_borrowing
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- Sequence for penalties table
CREATE SEQUENCE seq_penalties
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- Sequence for audit_trail table
CREATE SEQUENCE seq_audit
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- Sequence for notification_logs table
CREATE SEQUENCE seq_notification
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- Sequence for user_creation_log table
CREATE SEQUENCE seq_usercreationlog
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- ============================================================================
-- 2. CREATE TABLES
-- ============================================================================

-- Book Types Table
CREATE TABLE book_types (
    id NUMBER PRIMARY KEY,
    type_name VARCHAR2(50) NOT NULL,
    fee_rate NUMBER NOT NULL CHECK (fee_rate > 0)
);

-- Books Table
CREATE TABLE books (
    id NUMBER PRIMARY KEY,
    title VARCHAR2(200) NOT NULL,
    author VARCHAR2(100),
    availability VARCHAR2(20) NOT NULL DEFAULT 'Available' 
        CHECK (availability IN ('Available', 'Borrowed')),
    type_id NUMBER NOT NULL,
    CONSTRAINT fk_books_type FOREIGN KEY (type_id) REFERENCES book_types(id)
);

-- Students Table
CREATE TABLE students (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(200) NOT NULL,
    membership_status VARCHAR2(20) NOT NULL DEFAULT 'active'
        CHECK (membership_status IN ('active', 'suspended'))
);

-- Borrowing Records Table
CREATE TABLE borrowing_records (
    id NUMBER PRIMARY KEY,
    book_id NUMBER NOT NULL,
    student_id NUMBER NOT NULL,
    borrow_date DATE DEFAULT SYSDATE NOT NULL,
    return_date DATE NULL,
    status VARCHAR2(20) DEFAULT 'Borrowed' NOT NULL
        CHECK (status IN ('Borrowed', 'Returned', 'Overdue')),
    CONSTRAINT fk_borrowing_book FOREIGN KEY (book_id) REFERENCES books(id),
    CONSTRAINT fk_borrowing_student FOREIGN KEY (student_id) REFERENCES students(id)
);

-- Penalties Table
CREATE TABLE penalties (
    id NUMBER PRIMARY KEY,
    student_id NUMBER NOT NULL,
    amount NUMBER NOT NULL CHECK (amount >= 0),
    reason VARCHAR2(200),
    paid_status VARCHAR2(10) DEFAULT 'unpaid' 
        CHECK (paid_status IN ('unpaid', 'paid')),
    CONSTRAINT fk_penalties_student FOREIGN KEY (student_id) REFERENCES students(id)
);

-- Audit Trail Table
CREATE TABLE audit_trail (
    id NUMBER PRIMARY KEY,
    table_name VARCHAR2(100) NOT NULL,
    operation VARCHAR2(20) NOT NULL,
    old_data CLOB NULL,
    new_data CLOB NULL,
    created_at DATE DEFAULT SYSDATE NOT NULL
);

-- Notification Logs Table
CREATE TABLE notification_logs (
    id NUMBER PRIMARY KEY,
    student_id NUMBER NOT NULL,
    book_id NUMBER NOT NULL,
    overdue_days NUMBER NOT NULL CHECK (overdue_days >= 0),
    notification_date DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_notification_student FOREIGN KEY (student_id) REFERENCES students(id),
    CONSTRAINT fk_notification_book FOREIGN KEY (book_id) REFERENCES books(id)
);

-- User Creation Log Table
CREATE TABLE user_creation_log (
    id NUMBER PRIMARY KEY,
    username VARCHAR2(100) NOT NULL,
    created_by VARCHAR2(100) NOT NULL,
    created_at DATE DEFAULT SYSDATE NOT NULL
);

-- ============================================================================
-- 3. CREATE INDEXES
-- ============================================================================

-- Indexes for foreign keys and frequently queried columns
CREATE INDEX idx_books_type_id ON books(type_id);
CREATE INDEX idx_borrowing_book_id ON borrowing_records(book_id);
CREATE INDEX idx_borrowing_student_id ON borrowing_records(student_id);
CREATE INDEX idx_borrowing_status ON borrowing_records(status);
CREATE INDEX idx_borrowing_dates ON borrowing_records(borrow_date, return_date);
CREATE INDEX idx_penalties_student_id ON penalties(student_id);
CREATE INDEX idx_penalties_paid_status ON penalties(paid_status);
CREATE INDEX idx_notification_student_id ON notification_logs(student_id);
CREATE INDEX idx_notification_book_id ON notification_logs(book_id);
CREATE INDEX idx_audit_table_name ON audit_trail(table_name);
CREATE INDEX idx_audit_created_at ON audit_trail(created_at);

-- ============================================================================
-- 4. COMMENTS ON TABLES AND COLUMNS
-- ============================================================================

COMMENT ON TABLE book_types IS 'Stores different types of books and their fee rates';
COMMENT ON TABLE books IS 'Stores book information and availability status';
COMMENT ON TABLE students IS 'Stores student information and membership status';
COMMENT ON TABLE borrowing_records IS 'Logs all borrowing and return transactions';
COMMENT ON TABLE penalties IS 'Records late fees and other penalties for students';
COMMENT ON TABLE audit_trail IS 'Logs updates or deletions to track changes';
COMMENT ON TABLE notification_logs IS 'Logs overdue notifications sent to students';
COMMENT ON TABLE user_creation_log IS 'Logs creation of new database users';

-- ============================================================================
-- Schema creation completed successfully!
-- All sequences, tables, constraints, and indexes have been created.
-- ============================================================================

