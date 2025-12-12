-- ============================================================================
-- Advanced Library Management System
-- Procedures and Functions (Tasks 2, 3, 6, 8, 9, 10A)
-- ============================================================================
-- This script implements all PL/SQL procedures and functions:
-- - Task 2: Overdue Notifications Procedure
-- - Task 3: Dynamic Late Fee Calculation Function
-- - Task 6: Borrowing History Report (Cursor)
-- - Task 8: Books Availability Report
-- - Task 9: Automated Suspension Procedure
-- - Task 10A: Total Currently Borrowed Function
-- ============================================================================

SET SERVEROUTPUT ON SIZE 1000000;

-- ============================================================================
-- TASK 2: OVERDUE NOTIFICATIONS PROCEDURE
-- ============================================================================
-- Procedure that identifies students with overdue books and logs
-- notification details into the NotificationLogs table.
-- ============================================================================

CREATE OR REPLACE PROCEDURE proc_send_overdue_notifications AS
    v_overdue_days NUMBER;
    v_count NUMBER := 0;
BEGIN
    -- Find all borrowing records that are overdue (more than 7 days past borrow_date)
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
          -- Avoid duplicate notifications (check if already logged today)
          AND NOT EXISTS (
              SELECT 1 
              FROM notification_logs nl
              WHERE nl.student_id = br.student_id
                AND nl.book_id = br.book_id
                AND TRUNC(nl.notification_date) = TRUNC(SYSDATE)
          )
    ) LOOP
        -- Insert notification log
        INSERT INTO notification_logs (
            id, 
            student_id, 
            book_id, 
            overdue_days, 
            notification_date
        ) VALUES (
            seq_notification.NEXTVAL,
            rec.student_id,
            rec.book_id,
            rec.overdue_days,
            SYSDATE
        );
        
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

-- ============================================================================
-- TASK 3: DYNAMIC LATE FEE CALCULATION FUNCTION
-- ============================================================================
-- Function that calculates late fees based on overdue days and book type.
-- Inserts penalty record and returns the calculated fee amount.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_calc_and_insert_penalty(
    p_borrowing_id NUMBER
) RETURN NUMBER AS
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
    -- Get borrowing record details
    SELECT br.borrow_date, br.return_date, br.book_id, br.student_id, b.type_id
    INTO v_borrow_date, v_return_date, v_book_id, v_student_id, v_type_id
    FROM borrowing_records br
    JOIN books b ON br.book_id = b.id
    WHERE br.id = p_borrowing_id;
    
    -- Calculate overdue days
    IF v_return_date IS NULL THEN
        -- Book not yet returned, calculate from current date
        v_overdue_days := GREATEST(0, TRUNC(SYSDATE) - TRUNC(v_borrow_date + 7));
    ELSE
        -- Book returned, calculate from return date
        v_overdue_days := GREATEST(0, TRUNC(v_return_date) - TRUNC(v_borrow_date + 7));
    END IF;
    
    -- If not overdue, return 0
    IF v_overdue_days <= 0 THEN
        RETURN 0;
    END IF;
    
    -- Get fee rate from book type
    SELECT fee_rate INTO v_fee_rate
    FROM book_types
    WHERE id = v_type_id;
    
    -- Calculate penalty amount
    v_penalty_amount := v_overdue_days * v_fee_rate;
    
    -- Check if penalty already exists for this borrowing record
    SELECT COUNT(*) INTO v_penalty_id
    FROM penalties
    WHERE student_id = v_student_id
      AND reason LIKE '%borrow id ' || p_borrowing_id || '%';
    
    -- Insert penalty only if it doesn't exist
    IF v_penalty_id = 0 THEN
        INSERT INTO penalties (id, student_id, amount, reason, paid_status)
        VALUES (
            seq_penalties.NEXTVAL,
            v_student_id,
            v_penalty_amount,
            'Late fee for borrow id ' || p_borrowing_id || ' (' || v_overdue_days || ' days overdue)',
            'unpaid'
        );
        
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

-- ============================================================================
-- TASK 6: BORROWING HISTORY REPORT (CURSOR)
-- ============================================================================
-- Procedure that retrieves a student's borrowing history using a cursor,
-- including overdue books and penalties.
-- ============================================================================

CREATE OR REPLACE PROCEDURE proc_borrowing_history(p_student_id NUMBER) AS
    -- Cursor to retrieve borrowing history
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
    -- Get student name
    SELECT name INTO v_student_name
    FROM students
    WHERE id = p_student_id;
    
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('BORROWING HISTORY REPORT');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Student: ' || v_student_name || ' (ID: ' || p_student_id || ')');
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    -- Process cursor
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

-- ============================================================================
-- TASK 8: BOOKS AVAILABILITY REPORT
-- ============================================================================
-- Procedure that generates a detailed report on the availability of books
-- in the library, including borrower information and overdue status.
-- ============================================================================

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
    
    -- Report for each book
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
            -- Book is available
            DBMS_OUTPUT.PUT_LINE('  Status: Available');
            v_available_count := v_available_count + 1;
        ELSE
            -- Book is borrowed
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
    
    -- Summary
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

-- ============================================================================
-- TASK 9: AUTOMATED SUSPENSION PROCEDURE
-- ============================================================================
-- Procedure that automatically suspends students who have unpaid penalties
-- exceeding a certain threshold (default $50).
-- ============================================================================

CREATE OR REPLACE PROCEDURE proc_suspend_students(
    p_threshold NUMBER DEFAULT 50
) AS
    v_suspended_count NUMBER := 0;
    v_total_penalty NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('AUTOMATED SUSPENSION PROCESS');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Threshold: $' || p_threshold);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    -- Process each student with unpaid penalties
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
        -- Only suspend if not already suspended
        IF rec.membership_status = 'active' THEN
            UPDATE students
            SET membership_status = 'suspended'
            WHERE id = rec.student_id;
            
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

-- ============================================================================
-- TASK 10A: TOTAL CURRENTLY BORROWED FUNCTION
-- ============================================================================
-- Function that calculates and returns the total number of books currently
-- borrowed by all students.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_total_currently_borrowed RETURN NUMBER AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
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
-- VERIFICATION
-- ============================================================================

DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('Procedures and Functions Created!');
DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('Created:');
DBMS_OUTPUT.PUT_LINE('  - proc_send_overdue_notifications');
DBMS_OUTPUT.PUT_LINE('  - fn_calc_and_insert_penalty');
DBMS_OUTPUT.PUT_LINE('  - proc_borrowing_history');
DBMS_OUTPUT.PUT_LINE('  - proc_books_availability_report');
DBMS_OUTPUT.PUT_LINE('  - proc_suspend_students');
DBMS_OUTPUT.PUT_LINE('  - fn_total_currently_borrowed');
DBMS_OUTPUT.PUT_LINE('========================================');

