-- ============================================================================
-- Advanced Library Management System
-- Complete Implementation Script (All Tasks)
-- ============================================================================
-- This is a consolidated script containing all components of the library
-- management system. Execute this script in order to set up the complete system.
--
-- Execution Order:
-- 1. Schema Creation (Sequences, Tables, Constraints, Indexes)
-- 2. User Management and Privileges
-- 3. Sample Data Insertion
-- 4. Procedures and Functions
-- 5. Triggers
-- 6. Transaction Handling
-- 7. Bonus Tasks (Blocking Demonstration)
-- 8. Test Scripts (Optional - for verification)
-- ============================================================================

SET SERVEROUTPUT ON SIZE 1000000;

-- ============================================================================
-- ============================================================================
-- SECTION 1: SCHEMA CREATION
-- ============================================================================
-- ============================================================================

-- ============================================================================
-- 1. CREATE SEQUENCES
-- ============================================================================

CREATE SEQUENCE seq_booktypes START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_books START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_students START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_borrowing START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_penalties START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_audit START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_notification START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_usercreationlog START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================================
-- 2. CREATE TABLES
-- ============================================================================

CREATE TABLE book_types (
    id NUMBER PRIMARY KEY,
    type_name VARCHAR2(50) NOT NULL,
    fee_rate NUMBER NOT NULL CHECK (fee_rate > 0)
);

CREATE TABLE books (
    id NUMBER PRIMARY KEY,
    title VARCHAR2(200) NOT NULL,
    author VARCHAR2(100),
    availability VARCHAR2(20) NOT NULL DEFAULT 'Available' 
        CHECK (availability IN ('Available', 'Borrowed')),
    type_id NUMBER NOT NULL,
    CONSTRAINT fk_books_type FOREIGN KEY (type_id) REFERENCES book_types(id)
);

CREATE TABLE students (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(200) NOT NULL,
    membership_status VARCHAR2(20) NOT NULL DEFAULT 'active'
        CHECK (membership_status IN ('active', 'suspended'))
);

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

CREATE TABLE penalties (
    id NUMBER PRIMARY KEY,
    student_id NUMBER NOT NULL,
    amount NUMBER NOT NULL CHECK (amount >= 0),
    reason VARCHAR2(200),
    paid_status VARCHAR2(10) DEFAULT 'unpaid' 
        CHECK (paid_status IN ('unpaid', 'paid')),
    CONSTRAINT fk_penalties_student FOREIGN KEY (student_id) REFERENCES students(id)
);

CREATE TABLE audit_trail (
    id NUMBER PRIMARY KEY,
    table_name VARCHAR2(100) NOT NULL,
    operation VARCHAR2(20) NOT NULL,
    old_data CLOB NULL,
    new_data CLOB NULL,
    created_at DATE DEFAULT SYSDATE NOT NULL
);

CREATE TABLE notification_logs (
    id NUMBER PRIMARY KEY,
    student_id NUMBER NOT NULL,
    book_id NUMBER NOT NULL,
    overdue_days NUMBER NOT NULL CHECK (overdue_days >= 0),
    notification_date DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_notification_student FOREIGN KEY (student_id) REFERENCES students(id),
    CONSTRAINT fk_notification_book FOREIGN KEY (book_id) REFERENCES books(id)
);

CREATE TABLE user_creation_log (
    id NUMBER PRIMARY KEY,
    username VARCHAR2(100) NOT NULL,
    created_by VARCHAR2(100) NOT NULL,
    created_at DATE DEFAULT SYSDATE NOT NULL
);

-- ============================================================================
-- 3. CREATE INDEXES
-- ============================================================================

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
-- 4. COMMENTS ON TABLES
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
-- ============================================================================
-- SECTION 2: USER MANAGEMENT AND PRIVILEGES (TASK 1)
-- ============================================================================
-- ============================================================================

-- Create MANAGER user
CREATE USER manager IDENTIFIED BY Manager123;
GRANT CONNECT, RESOURCE TO manager;
GRANT CREATE USER TO manager;
GRANT CREATE SESSION TO manager;
GRANT CREATE TABLE TO manager;
GRANT CREATE PROCEDURE TO manager;
GRANT CREATE SEQUENCE TO manager;
GRANT CREATE TRIGGER TO manager;

-- Grant access to all tables
GRANT SELECT, INSERT, UPDATE, DELETE ON system.book_types TO manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON system.books TO manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON system.students TO manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON system.borrowing_records TO manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON system.penalties TO manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON system.audit_trail TO manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON system.notification_logs TO manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON system.user_creation_log TO manager;

-- Grant sequence privileges
GRANT SELECT ON system.seq_booktypes TO manager;
GRANT SELECT ON system.seq_books TO manager;
GRANT SELECT ON system.seq_students TO manager;
GRANT SELECT ON system.seq_borrowing TO manager;
GRANT SELECT ON system.seq_penalties TO manager;
GRANT SELECT ON system.seq_audit TO manager;
GRANT SELECT ON system.seq_notification TO manager;
GRANT SELECT ON system.seq_usercreationlog TO manager;

-- User Creation Logging Procedure
CREATE OR REPLACE PROCEDURE log_user_creation(p_username VARCHAR2) AS
    v_creator VARCHAR2(100);
BEGIN
    SELECT USER INTO v_creator FROM dual;
    INSERT INTO user_creation_log (id, username, created_by, created_at)
    VALUES (seq_usercreationlog.NEXTVAL, p_username, v_creator, SYSDATE);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('User creation logged: ' || p_username || ' created by ' || v_creator);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error logging user creation: ' || SQLERRM);
        RAISE;
END log_user_creation;
/

-- Create USER1
CREATE USER user1 IDENTIFIED BY User1Pass123;
GRANT CONNECT, RESOURCE TO user1;
GRANT CREATE SESSION TO user1;
GRANT CREATE TABLE TO user1;
GRANT CREATE SEQUENCE TO user1;
GRANT SELECT, INSERT, UPDATE, DELETE ON system.book_types TO user1;
GRANT SELECT, INSERT, UPDATE, DELETE ON system.books TO user1;
GRANT SELECT ON system.seq_booktypes TO user1;
GRANT SELECT ON system.seq_books TO user1;

BEGIN
    log_user_creation('USER1');
END;
/

-- Create USER2
CREATE USER user2 IDENTIFIED BY User2Pass123;
GRANT CONNECT, RESOURCE TO user2;
GRANT CREATE SESSION TO user2;
GRANT SELECT, INSERT ON system.book_types TO user2;
GRANT SELECT, INSERT ON system.books TO user2;
GRANT SELECT ON system.seq_booktypes TO user2;
GRANT SELECT ON system.seq_books TO user2;

BEGIN
    log_user_creation('USER2');
END;
/

-- ============================================================================
-- ============================================================================
-- SECTION 3: SAMPLE DATA INSERTION
-- ============================================================================
-- ============================================================================

INSERT INTO book_types (id, type_name, fee_rate) VALUES (seq_booktypes.NEXTVAL, 'Regular Book', 1);
INSERT INTO book_types (id, type_name, fee_rate) VALUES (seq_booktypes.NEXTVAL, 'Reference Book', 2);
COMMIT;

INSERT INTO books (id, title, author, availability, type_id) 
VALUES (seq_books.NEXTVAL, 'Introduction to Database Systems', 'John Smith', 'Available', 1);
INSERT INTO books (id, title, author, availability, type_id) 
VALUES (seq_books.NEXTVAL, 'Advanced SQL Programming', 'Jane Doe', 'Available', 1);
INSERT INTO books (id, title, author, availability, type_id) 
VALUES (seq_books.NEXTVAL, 'Oracle PL/SQL Guide', 'Robert Johnson', 'Available', 1);
INSERT INTO books (id, title, author, availability, type_id) 
VALUES (seq_books.NEXTVAL, 'Database Design Reference Manual', 'Alice Williams', 'Available', 2);
INSERT INTO books (id, title, author, availability, type_id) 
VALUES (seq_books.NEXTVAL, 'SQL Standards Encyclopedia', 'Michael Brown', 'Available', 2);
COMMIT;

INSERT INTO students (id, name, membership_status) VALUES (seq_students.NEXTVAL, 'Ahmed Hassan', 'active');
INSERT INTO students (id, name, membership_status) VALUES (seq_students.NEXTVAL, 'Fatima Ali', 'active');
INSERT INTO students (id, name, membership_status) VALUES (seq_students.NEXTVAL, 'Mohammed Ibrahim', 'active');
INSERT INTO students (id, name, membership_status) VALUES (seq_students.NEXTVAL, 'Sara Ahmed', 'active');
INSERT INTO students (id, name, membership_status) VALUES (seq_students.NEXTVAL, 'Omar Khaled', 'active');
COMMIT;

INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, return_date, status)
VALUES (seq_borrowing.NEXTVAL, 1, 1, SYSDATE - 3, NULL, 'Borrowed');
INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, return_date, status)
VALUES (seq_borrowing.NEXTVAL, 2, 2, SYSDATE - 2, NULL, 'Borrowed');
INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, return_date, status)
VALUES (seq_borrowing.NEXTVAL, 3, 3, SYSDATE - 10, NULL, 'Overdue');
INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, return_date, status)
VALUES (seq_borrowing.NEXTVAL, 4, 1, SYSDATE - 15, NULL, 'Overdue');
INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, return_date, status)
VALUES (seq_borrowing.NEXTVAL, 5, 4, SYSDATE - 20, SYSDATE - 13, 'Returned');
UPDATE books SET availability = 'Borrowed' WHERE id IN (1, 2, 3, 4);
COMMIT;

-- ============================================================================
-- ============================================================================
-- SECTION 4: PROCEDURES AND FUNCTIONS (TASKS 2, 3, 6, 8, 9, 10A)
-- ============================================================================
-- ============================================================================

-- TASK 2: Overdue Notifications Procedure
CREATE OR REPLACE PROCEDURE proc_send_overdue_notifications AS
    v_count NUMBER := 0;
BEGIN
    FOR rec IN (
        SELECT 
            br.id AS borrowing_id,
            br.student_id,
            br.book_id,
            br.borrow_date,
            CASE 
                WHEN br.return_date IS NULL THEN 
                    GREATEST(0, TRUNC(SYSDATE) - TRUNC(br.borrow_date + 7))
                ELSE 
                    GREATEST(0, TRUNC(br.return_date) - TRUNC(br.borrow_date + 7))
            END AS overdue_days
        FROM borrowing_records br
        WHERE br.status IN ('Borrowed', 'Overdue')
          AND (
              (br.return_date IS NULL AND br.borrow_date + 7 < SYSDATE)
              OR (br.return_date IS NOT NULL AND br.return_date > br.borrow_date + 7)
          )
          AND NOT EXISTS (
              SELECT 1 
              FROM notification_logs nl
              WHERE nl.student_id = br.student_id
                AND nl.book_id = br.book_id
                AND TRUNC(nl.notification_date) = TRUNC(SYSDATE)
          )
    ) LOOP
        INSERT INTO notification_logs (id, student_id, book_id, overdue_days, notification_date)
        VALUES (seq_notification.NEXTVAL, rec.student_id, rec.book_id, rec.overdue_days, SYSDATE);
        v_count := v_count + 1;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Overdue notifications sent: ' || v_count || ' notification(s) logged');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error in proc_send_overdue_notifications: ' || SQLERRM);
        RAISE;
END proc_send_overdue_notifications;
/

-- TASK 3: Dynamic Late Fee Calculation Function
CREATE OR REPLACE FUNCTION fn_calc_and_insert_penalty(p_borrowing_id NUMBER) RETURN NUMBER AS
    v_borrow_date DATE;
    v_return_date DATE;
    v_book_id NUMBER;
    v_student_id NUMBER;
    v_type_id NUMBER;
    v_fee_rate NUMBER;
    v_overdue_days NUMBER;
    v_penalty_amount NUMBER;
    v_penalty_id NUMBER;
BEGIN
    SELECT br.borrow_date, br.return_date, br.book_id, br.student_id, b.type_id
    INTO v_borrow_date, v_return_date, v_book_id, v_student_id, v_type_id
    FROM borrowing_records br
    JOIN books b ON br.book_id = b.id
    WHERE br.id = p_borrowing_id;
    
    IF v_return_date IS NULL THEN
        v_overdue_days := GREATEST(0, TRUNC(SYSDATE) - TRUNC(v_borrow_date + 7));
    ELSE
        v_overdue_days := GREATEST(0, TRUNC(v_return_date) - TRUNC(v_borrow_date + 7));
    END IF;
    
    IF v_overdue_days <= 0 THEN
        RETURN 0;
    END IF;
    
    SELECT fee_rate INTO v_fee_rate FROM book_types WHERE id = v_type_id;
    v_penalty_amount := v_overdue_days * v_fee_rate;
    
    SELECT COUNT(*) INTO v_penalty_id
    FROM penalties
    WHERE student_id = v_student_id
      AND reason LIKE '%borrow id ' || p_borrowing_id || '%';
    
    IF v_penalty_id = 0 THEN
        INSERT INTO penalties (id, student_id, amount, reason, paid_status)
        VALUES (seq_penalties.NEXTVAL, v_student_id, v_penalty_amount,
                'Late fee for borrow id ' || p_borrowing_id || ' (' || v_overdue_days || ' days overdue)', 'unpaid');
        COMMIT;
    END IF;
    
    RETURN v_penalty_amount;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Borrowing record not found: ' || p_borrowing_id);
        RETURN 0;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in fn_calc_and_insert_penalty: ' || SQLERRM);
        RETURN 0;
END fn_calc_and_insert_penalty;
/

-- TASK 6: Borrowing History Report (Cursor)
CREATE OR REPLACE PROCEDURE proc_borrowing_history(p_student_id NUMBER) AS
    CURSOR c_borrowing_history IS
        SELECT 
            b.title AS book_title,
            br.borrow_date,
            br.return_date,
            br.status,
            br.id AS borrowing_id,
            CASE 
                WHEN br.return_date IS NULL AND br.borrow_date + 7 < SYSDATE THEN 'Overdue'
                WHEN br.return_date IS NOT NULL AND br.return_date > br.borrow_date + 7 THEN 'Returned Late'
                WHEN br.return_date IS NOT NULL AND br.return_date <= br.borrow_date + 7 THEN 'Returned On Time'
                ELSE 'On Time'
            END AS return_status,
            NVL(SUM(p.amount), 0) AS total_penalty
        FROM borrowing_records br
        JOIN books b ON br.book_id = b.id
        LEFT JOIN penalties p ON br.student_id = p.student_id 
            AND p.reason LIKE '%borrow id ' || br.id || '%'
        WHERE br.student_id = p_student_id
        GROUP BY b.title, br.borrow_date, br.return_date, br.status, br.id
        ORDER BY br.borrow_date DESC;
    
    v_student_name VARCHAR2(200);
    v_record_count NUMBER := 0;
BEGIN
    SELECT name INTO v_student_name FROM students WHERE id = p_student_id;
    
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('BORROWING HISTORY REPORT');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Student: ' || v_student_name || ' (ID: ' || p_student_id || ')');
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    FOR rec IN c_borrowing_history LOOP
        v_record_count := v_record_count + 1;
        DBMS_OUTPUT.PUT_LINE('Book: ' || rec.book_title);
        DBMS_OUTPUT.PUT_LINE('  Borrow Date: ' || TO_CHAR(rec.borrow_date, 'DD-MON-YYYY'));
        IF rec.return_date IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('  Return Date: ' || TO_CHAR(rec.return_date, 'DD-MON-YYYY'));
        ELSE
            DBMS_OUTPUT.PUT_LINE('  Return Date: Not Returned');
        END IF;
        DBMS_OUTPUT.PUT_LINE('  Status: ' || rec.status);
        DBMS_OUTPUT.PUT_LINE('  Return Status: ' || rec.return_status);
        DBMS_OUTPUT.PUT_LINE('  Penalty: $' || TO_CHAR(rec.total_penalty, '999.99'));
        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    END LOOP;
    
    IF v_record_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No borrowing records found for this student.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Total Records: ' || v_record_count);
    END IF;
    DBMS_OUTPUT.PUT_LINE('========================================');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Student not found: ' || p_student_id);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in proc_borrowing_history: ' || SQLERRM);
        RAISE;
END proc_borrowing_history;
/

-- TASK 8: Books Availability Report
CREATE OR REPLACE PROCEDURE proc_books_availability_report AS
    v_total_books NUMBER := 0;
    v_available_count NUMBER := 0;
    v_borrowed_count NUMBER := 0;
    v_overdue_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('BOOKS AVAILABILITY REPORT');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    FOR rec IN (
        SELECT 
            b.id AS book_id,
            b.title,
            b.author,
            b.availability,
            br.student_id,
            s.name AS student_name,
            br.borrow_date,
            br.return_date,
            br.status,
            CASE 
                WHEN br.return_date IS NULL AND br.borrow_date + 7 < SYSDATE THEN 
                    GREATEST(0, TRUNC(SYSDATE) - TRUNC(br.borrow_date + 7))
                WHEN br.return_date IS NOT NULL AND br.return_date > br.borrow_date + 7 THEN 
                    GREATEST(0, TRUNC(br.return_date) - TRUNC(br.borrow_date + 7))
                ELSE 0
            END AS overdue_days
        FROM books b
        LEFT JOIN borrowing_records br ON b.id = br.book_id 
            AND br.status IN ('Borrowed', 'Overdue')
        LEFT JOIN students s ON br.student_id = s.id
        ORDER BY b.id
    ) LOOP
        v_total_books := v_total_books + 1;
        DBMS_OUTPUT.PUT_LINE('Book ID: ' || rec.book_id);
        DBMS_OUTPUT.PUT_LINE('  Title: ' || rec.title);
        DBMS_OUTPUT.PUT_LINE('  Author: ' || NVL(rec.author, 'Unknown'));
        
        IF rec.student_id IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('  Status: Available');
            v_available_count := v_available_count + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('  Status: Borrowed');
            DBMS_OUTPUT.PUT_LINE('  Borrower: ' || rec.student_name || ' (ID: ' || rec.student_id || ')');
            DBMS_OUTPUT.PUT_LINE('  Borrow Date: ' || TO_CHAR(rec.borrow_date, 'DD-MON-YYYY'));
            IF rec.overdue_days > 0 THEN
                DBMS_OUTPUT.PUT_LINE('  Overdue Days: ' || rec.overdue_days);
                DBMS_OUTPUT.PUT_LINE('  ⚠ OVERDUE');
                v_overdue_count := v_overdue_count + 1;
            ELSE
                v_borrowed_count := v_borrowed_count + 1;
            END IF;
        END IF;
        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('SUMMARY');
    DBMS_OUTPUT.PUT_LINE('  Total Books: ' || v_total_books);
    DBMS_OUTPUT.PUT_LINE('  Available: ' || v_available_count);
    DBMS_OUTPUT.PUT_LINE('  Borrowed (On Time): ' || v_borrowed_count);
    DBMS_OUTPUT.PUT_LINE('  Overdue: ' || v_overdue_count);
    DBMS_OUTPUT.PUT_LINE('========================================');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in proc_books_availability_report: ' || SQLERRM);
        RAISE;
END proc_books_availability_report;
/

-- TASK 9: Automated Suspension Procedure
CREATE OR REPLACE PROCEDURE proc_suspend_students(p_threshold NUMBER DEFAULT 50) AS
    v_suspended_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('AUTOMATED SUSPENSION PROCESS');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Threshold: $' || p_threshold);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    FOR rec IN (
        SELECT 
            s.id AS student_id,
            s.name AS student_name,
            s.membership_status,
            NVL(SUM(p.amount), 0) AS total_unpaid_penalties
        FROM students s
        LEFT JOIN penalties p ON s.id = p.student_id 
            AND p.paid_status = 'unpaid'
        GROUP BY s.id, s.name, s.membership_status
        HAVING NVL(SUM(p.amount), 0) > p_threshold
    ) LOOP
        IF rec.membership_status = 'active' THEN
            UPDATE students SET membership_status = 'suspended' WHERE id = rec.student_id;
            v_suspended_count := v_suspended_count + 1;
            DBMS_OUTPUT.PUT_LINE('Suspended: ' || rec.student_name || 
                               ' (ID: ' || rec.student_id || 
                               ', Unpaid Penalties: $' || rec.total_unpaid_penalties || ')');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Already Suspended: ' || rec.student_name || 
                               ' (ID: ' || rec.student_id || 
                               ', Unpaid Penalties: $' || rec.total_unpaid_penalties || ')');
        END IF;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Total Students Suspended: ' || v_suspended_count);
    DBMS_OUTPUT.PUT_LINE('========================================');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error in proc_suspend_students: ' || SQLERRM);
        RAISE;
END proc_suspend_students;
/

-- TASK 10A: Total Currently Borrowed Function
CREATE OR REPLACE FUNCTION fn_total_currently_borrowed RETURN NUMBER AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM borrowing_records
    WHERE status = 'Borrowed' 
       OR (return_date IS NULL AND status <> 'Returned');
    RETURN v_count;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in fn_total_currently_borrowed: ' || SQLERRM);
        RETURN 0;
END fn_total_currently_borrowed;
/

-- ============================================================================
-- ============================================================================
-- SECTION 5: TRIGGERS (TASKS 4, 5, 10B)
-- ============================================================================
-- ============================================================================

-- TASK 4: Borrowing Validation Trigger
CREATE OR REPLACE TRIGGER trg_borrowing_validation
BEFORE INSERT ON borrowing_records
FOR EACH ROW
DECLARE
    v_active_count NUMBER;
    v_overdue_count NUMBER;
    v_student_status VARCHAR2(20);
    v_book_availability VARCHAR2(20);
BEGIN
    SELECT membership_status INTO v_student_status FROM students WHERE id = :NEW.student_id;
    IF v_student_status = 'suspended' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Cannot borrow: Student ID ' || :NEW.student_id || ' is suspended.');
    END IF;
    
    SELECT availability INTO v_book_availability FROM books WHERE id = :NEW.book_id;
    IF v_book_availability = 'Borrowed' THEN
        RAISE_APPLICATION_ERROR(-20002, 'Cannot borrow: Book ID ' || :NEW.book_id || ' is already borrowed.');
    END IF;
    
    SELECT COUNT(*) INTO v_active_count
    FROM borrowing_records
    WHERE student_id = :NEW.student_id AND (status = 'Borrowed' OR return_date IS NULL);
    
    IF v_active_count >= 3 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Cannot borrow: Student ID ' || :NEW.student_id || 
            ' has reached the maximum borrowing limit of 3 books.');
    END IF;
    
    SELECT COUNT(*) INTO v_overdue_count
    FROM borrowing_records
    WHERE student_id = :NEW.student_id
      AND status IN ('Borrowed', 'Overdue')
      AND return_date IS NULL
      AND borrow_date + 7 < SYSDATE;
    
    IF v_overdue_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Cannot borrow: Student ID ' || :NEW.student_id || 
            ' has ' || v_overdue_count || ' overdue book(s). Please return overdue books first.');
    END IF;
    
    IF :NEW.borrow_date IS NULL THEN :NEW.borrow_date := SYSDATE; END IF;
    IF :NEW.status IS NULL THEN :NEW.status := 'Borrowed'; END IF;
    
    UPDATE books SET availability = 'Borrowed' WHERE id = :NEW.book_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20005, 'Invalid student ID or book ID.');
    WHEN OTHERS THEN
        RAISE;
END trg_borrowing_validation;
/

-- TASK 5: Audit Trail Helper Function
CREATE OR REPLACE FUNCTION format_record_data(
    p_id NUMBER, p_book_id NUMBER, p_student_id NUMBER,
    p_borrow_date DATE, p_return_date DATE, p_status VARCHAR2
) RETURN CLOB AS
    v_data CLOB;
BEGIN
    v_data := 'ID: ' || p_id || ', Book ID: ' || p_book_id || 
              ', Student ID: ' || p_student_id || 
              ', Borrow Date: ' || TO_CHAR(p_borrow_date, 'DD-MON-YYYY HH24:MI:SS') || 
              ', Return Date: ' || NVL(TO_CHAR(p_return_date, 'DD-MON-YYYY HH24:MI:SS'), 'NULL') || 
              ', Status: ' || p_status;
    RETURN v_data;
END format_record_data;
/

-- TASK 5: Audit Trail UPDATE Trigger
CREATE OR REPLACE TRIGGER trg_borrowing_audit_update
BEFORE UPDATE ON borrowing_records
FOR EACH ROW
DECLARE
    v_old_data CLOB;
    v_new_data CLOB;
BEGIN
    v_old_data := format_record_data(:OLD.id, :OLD.book_id, :OLD.student_id, 
                                     :OLD.borrow_date, :OLD.return_date, :OLD.status);
    v_new_data := format_record_data(:NEW.id, :NEW.book_id, :NEW.student_id, 
                                     :NEW.borrow_date, :NEW.return_date, :NEW.status);
    INSERT INTO audit_trail (id, table_name, operation, old_data, new_data, created_at)
    VALUES (seq_audit.NEXTVAL, 'BORROWING_RECORDS', 'UPDATE', v_old_data, v_new_data, SYSDATE);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in audit trigger: ' || SQLERRM);
END trg_borrowing_audit_update;
/

-- TASK 5: Audit Trail DELETE Trigger
CREATE OR REPLACE TRIGGER trg_borrowing_audit_delete
BEFORE DELETE ON borrowing_records
FOR EACH ROW
DECLARE
    v_old_data CLOB;
BEGIN
    v_old_data := format_record_data(:OLD.id, :OLD.book_id, :OLD.student_id, 
                                     :OLD.borrow_date, :OLD.return_date, :OLD.status);
    INSERT INTO audit_trail (id, table_name, operation, old_data, new_data, created_at)
    VALUES (seq_audit.NEXTVAL, 'BORROWING_RECORDS', 'DELETE', v_old_data, NULL, SYSDATE);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in audit trigger: ' || SQLERRM);
END trg_borrowing_audit_delete;
/

-- TASK 10B: Availability Update Trigger
CREATE OR REPLACE TRIGGER trg_update_book_availability
AFTER UPDATE ON borrowing_records
FOR EACH ROW
WHEN (NEW.status = 'Returned' AND (OLD.status <> 'Returned' OR OLD.status IS NULL))
BEGIN
    UPDATE books SET availability = 'Available' WHERE id = :NEW.book_id;
    DBMS_OUTPUT.PUT_LINE('Book ID ' || :NEW.book_id || ' availability updated to Available.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error updating book availability: ' || SQLERRM);
END trg_update_book_availability;
/

-- ============================================================================
-- ============================================================================
-- SECTION 6: TRANSACTION HANDLING (TASK 7)
-- ============================================================================
-- ============================================================================

-- TASK 7: Safe Return Process with Transactions
CREATE OR REPLACE PROCEDURE proc_return_books(
    p_student_id NUMBER,
    p_borrowing_ids SYS.ODCINUMBERLIST
) AS
    v_borrowing_id NUMBER;
    v_penalty_amount NUMBER;
    v_total_penalty NUMBER := 0;
    v_returned_count NUMBER := 0;
    v_error_occurred BOOLEAN := FALSE;
    v_error_message VARCHAR2(4000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('SAFE RETURN PROCESS');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Student ID: ' || p_student_id);
    DBMS_OUTPUT.PUT_LINE('Books to Return: ' || p_borrowing_ids.COUNT);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    SELECT NVL(SUM(amount), 0) INTO v_total_penalty
    FROM penalties WHERE student_id = p_student_id AND paid_status = 'unpaid';
    
    IF v_total_penalty > 0 THEN
        DBMS_OUTPUT.PUT_LINE('⚠ WARNING: Student has unpaid penalties totaling $' || v_total_penalty);
    END IF;
    
    SAVEPOINT before_return;
    
    FOR i IN 1..p_borrowing_ids.COUNT LOOP
        v_borrowing_id := p_borrowing_ids(i);
        BEGIN
            DECLARE
                v_verify_student_id NUMBER;
                v_verify_status VARCHAR2(20);
            BEGIN
                SELECT student_id, status INTO v_verify_student_id, v_verify_status
                FROM borrowing_records WHERE id = v_borrowing_id;
                
                IF v_verify_student_id != p_student_id THEN
                    RAISE_APPLICATION_ERROR(-20010, 'Borrowing record ' || v_borrowing_id || 
                        ' does not belong to student ' || p_student_id);
                END IF;
                
                IF v_verify_status = 'Returned' THEN
                    DBMS_OUTPUT.PUT_LINE('Book ' || v_borrowing_id || ' already returned. Skipping.');
                    CONTINUE;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20011, 'Borrowing record ' || v_borrowing_id || ' not found.');
            END;
            
            v_penalty_amount := fn_calc_and_insert_penalty(v_borrowing_id);
            IF v_penalty_amount > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Book ' || v_borrowing_id || ': Penalty calculated = $' || v_penalty_amount);
            END IF;
            
            UPDATE borrowing_records SET status = 'Returned', return_date = SYSDATE WHERE id = v_borrowing_id;
            v_returned_count := v_returned_count + 1;
            DBMS_OUTPUT.PUT_LINE('✓ Book ' || v_borrowing_id || ' returned successfully.');
        EXCEPTION
            WHEN OTHERS THEN
                v_error_occurred := TRUE;
                v_error_message := SQLERRM;
                DBMS_OUTPUT.PUT_LINE('✗ Error processing book ' || v_borrowing_id || ': ' || v_error_message);
        END;
    END LOOP;
    
    IF v_error_occurred THEN
        ROLLBACK TO SAVEPOINT before_return;
        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
        DBMS_OUTPUT.PUT_LINE('✗ TRANSACTION ROLLED BACK');
        DBMS_OUTPUT.PUT_LINE('No books were returned.');
        DBMS_OUTPUT.PUT_LINE('========================================');
        RAISE_APPLICATION_ERROR(-20012, 'Return process failed. All changes rolled back.');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
        DBMS_OUTPUT.PUT_LINE('✓ TRANSACTION COMMITTED');
        DBMS_OUTPUT.PUT_LINE('Successfully returned: ' || v_returned_count || ' book(s)');
        DBMS_OUTPUT.PUT_LINE('========================================');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('✗ FATAL ERROR - ALL CHANGES ROLLED BACK');
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END proc_return_books;
/

-- ============================================================================
-- ============================================================================
-- SECTION 7: BONUS TASKS (TASKS 11 & 12)
-- ============================================================================
-- ============================================================================

-- TASK 12: Blocking Sessions View
CREATE OR REPLACE VIEW v_blocking_sessions AS
SELECT 
    blocking.sid AS blocking_sid,
    blocking.serial# AS blocking_serial,
    blocking.username AS blocking_user,
    blocking.program AS blocking_program,
    blocking.status AS blocking_status,
    waiting.sid AS waiting_sid,
    waiting.serial# AS waiting_serial,
    waiting.username AS waiting_user,
    waiting.program AS waiting_program,
    waiting.status AS waiting_status,
    waiting.seconds_in_wait AS wait_seconds,
    waiting.event AS wait_event
FROM v$session blocking
JOIN v$session waiting ON blocking.sid = waiting.blocking_session
WHERE blocking.blocking_session IS NULL
  AND waiting.blocking_session IS NOT NULL
  AND waiting.wait_class <> 'Idle';

-- TASK 12: Identify Blockers Procedure
CREATE OR REPLACE PROCEDURE proc_identify_blockers AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('BLOCKER-WAITING SESSION ANALYSIS');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    FOR rec IN (
        SELECT 
            blocking.sid AS blocking_sid,
            blocking.serial# AS blocking_serial,
            blocking.username AS blocking_user,
            blocking.program AS blocking_program,
            blocking.machine AS blocking_machine,
            blocking.sql_id AS blocking_sql_id,
            waiting.sid AS waiting_sid,
            waiting.serial# AS waiting_serial,
            waiting.username AS waiting_user,
            waiting.program AS waiting_program,
            waiting.seconds_in_wait AS wait_seconds,
            waiting.event AS wait_event,
            waiting.sql_id AS waiting_sql_id
        FROM v$session blocking
        JOIN v$session waiting ON blocking.sid = waiting.blocking_session
        WHERE blocking.blocking_session IS NULL
          AND waiting.blocking_session IS NOT NULL
          AND waiting.wait_class <> 'Idle'
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('BLOCKER SESSION:');
        DBMS_OUTPUT.PUT_LINE('  SID: ' || rec.blocking_sid);
        DBMS_OUTPUT.PUT_LINE('  SERIAL#: ' || rec.blocking_serial);
        DBMS_OUTPUT.PUT_LINE('  User: ' || NVL(rec.blocking_user, 'UNKNOWN'));
        DBMS_OUTPUT.PUT_LINE('  Program: ' || NVL(rec.blocking_program, 'UNKNOWN'));
        DBMS_OUTPUT.PUT_LINE('  Machine: ' || NVL(rec.blocking_machine, 'UNKNOWN'));
        DBMS_OUTPUT.PUT_LINE('  SQL ID: ' || NVL(rec.blocking_sql_id, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('WAITING SESSION:');
        DBMS_OUTPUT.PUT_LINE('  SID: ' || rec.waiting_sid);
        DBMS_OUTPUT.PUT_LINE('  SERIAL#: ' || rec.waiting_serial);
        DBMS_OUTPUT.PUT_LINE('  User: ' || NVL(rec.waiting_user, 'UNKNOWN'));
        DBMS_OUTPUT.PUT_LINE('  Program: ' || NVL(rec.waiting_program, 'UNKNOWN'));
        DBMS_OUTPUT.PUT_LINE('  Wait Event: ' || rec.wait_event);
        DBMS_OUTPUT.PUT_LINE('  Wait Time: ' || rec.wait_seconds || ' seconds');
        DBMS_OUTPUT.PUT_LINE('  SQL ID: ' || NVL(rec.waiting_sql_id, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('RESOLUTION COMMAND:');
        DBMS_OUTPUT.PUT_LINE('  ALTER SYSTEM KILL SESSION ''' || rec.blocking_sid || ',' || rec.blocking_serial || ''';');
        DBMS_OUTPUT.PUT_LINE('  (Or commit/rollback in the blocking session)');
        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    END LOOP;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No blocking sessions found.');
        DBMS_OUTPUT.PUT_LINE('All sessions are running normally.');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('========================================');
END proc_identify_blockers;
/

-- ============================================================================
-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================
-- ============================================================================

BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('LIBRARY MANAGEMENT SYSTEM SETUP COMPLETE!');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('All components have been successfully created:');
    DBMS_OUTPUT.PUT_LINE('  ✓ Schema (Sequences, Tables, Indexes)');
    DBMS_OUTPUT.PUT_LINE('  ✓ Users (MANAGER, USER1, USER2)');
    DBMS_OUTPUT.PUT_LINE('  ✓ Sample Data');
    DBMS_OUTPUT.PUT_LINE('  ✓ Procedures and Functions');
    DBMS_OUTPUT.PUT_LINE('  ✓ Triggers');
    DBMS_OUTPUT.PUT_LINE('  ✓ Transaction Handling');
    DBMS_OUTPUT.PUT_LINE('  ✓ Bonus Tasks (Blocking Detection)');
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

