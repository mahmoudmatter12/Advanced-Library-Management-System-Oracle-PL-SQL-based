-- ============================================================================
-- Advanced Library Management System
-- Comprehensive Test Scripts
-- ============================================================================
-- This script contains test cases to verify all functionality of the
-- library management system.
-- ============================================================================

SET SERVEROUTPUT ON SIZE 1000000;

-- ============================================================================
-- TEST 1: Verify Schema Creation
-- ============================================================================

PROMPT ========================================
PROMPT TEST 1: Schema Verification
PROMPT ========================================

SELECT 'Sequences' AS object_type, COUNT(*) AS count FROM user_sequences
UNION ALL
SELECT 'Tables', COUNT(*) FROM user_tables
UNION ALL
SELECT 'Procedures', COUNT(*) FROM user_procedures
UNION ALL
SELECT 'Functions', COUNT(*) FROM user_procedures WHERE object_type = 'FUNCTION'
UNION ALL
SELECT 'Triggers', COUNT(*) FROM user_triggers;

-- ============================================================================
-- TEST 2: Test Overdue Notifications (Task 2)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 2: Overdue Notifications
PROMPT ========================================

-- Run the procedure
BEGIN
    proc_send_overdue_notifications;
END;
/

-- Verify notifications were logged
SELECT * FROM notification_logs ORDER BY notification_date DESC;

-- ============================================================================
-- TEST 3: Test Late Fee Calculation (Task 3)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 3: Late Fee Calculation
PROMPT ========================================

DECLARE
    v_penalty NUMBER;
BEGIN
    -- Test with an overdue borrowing record (assuming ID 3 exists and is overdue)
    v_penalty := fn_calc_and_insert_penalty(3);
    DBMS_OUTPUT.PUT_LINE('Penalty calculated: $' || v_penalty);
    
    -- Verify penalty was inserted
    SELECT * FROM penalties WHERE reason LIKE '%borrow id 3%';
END;
/

-- ============================================================================
-- TEST 4: Test Borrowing Validation Trigger (Task 4)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 4: Borrowing Validation Trigger
PROMPT ========================================

-- Test 4a: Try to borrow when student has 3 active books (should fail)
PROMPT Test 4a: Attempting to borrow 4th book (should fail)...

BEGIN
    -- First, create 3 active borrowings for student 1
    -- (Assuming these don't already exist)
    INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, status)
    VALUES (seq_borrowing.NEXTVAL, 5, 1, SYSDATE, 'Borrowed');
    
    -- Try to insert 4th book (should fail)
    INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, status)
    VALUES (seq_borrowing.NEXTVAL, 1, 1, SYSDATE, 'Borrowed');
    
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have failed!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✓ Correctly prevented: ' || SQLERRM);
END;
/

-- Test 4b: Try to borrow when student has overdue books (should fail)
PROMPT Test 4b: Attempting to borrow with overdue books (should fail)...

BEGIN
    -- Try to borrow for student 3 (who has overdue book)
    INSERT INTO borrowing_records (id, book_id, student_id, borrow_date, status)
    VALUES (seq_borrowing.NEXTVAL, 2, 3, SYSDATE, 'Borrowed');
    
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have failed!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✓ Correctly prevented: ' || SQLERRM);
END;
/

-- ============================================================================
-- TEST 5: Test Audit Trail Triggers (Task 5)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 5: Audit Trail Triggers
PROMPT ========================================

-- Test 5a: Update a borrowing record
PROMPT Test 5a: Updating borrowing record...

UPDATE borrowing_records
SET status = 'Returned', return_date = SYSDATE
WHERE id = 1;

COMMIT;

-- Verify audit trail
SELECT * FROM audit_trail 
WHERE table_name = 'BORROWING_RECORDS' 
  AND operation = 'UPDATE'
ORDER BY created_at DESC
FETCH FIRST 1 ROW ONLY;

-- Test 5b: Delete a borrowing record (if allowed)
PROMPT Test 5b: Deleting borrowing record...

-- Note: In practice, you might want to prevent deletes, but for testing:
/*
DELETE FROM borrowing_records WHERE id = 999; -- Use a test ID
COMMIT;

SELECT * FROM audit_trail 
WHERE table_name = 'BORROWING_RECORDS' 
  AND operation = 'DELETE'
ORDER BY created_at DESC
FETCH FIRST 1 ROW ONLY;
*/

-- ============================================================================
-- TEST 6: Test Borrowing History Report (Task 6)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 6: Borrowing History Report
PROMPT ========================================

BEGIN
    proc_borrowing_history(1);
END;
/

-- ============================================================================
-- TEST 7: Test Safe Return Process (Task 7)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 7: Safe Return Process
PROMPT ========================================

DECLARE
    v_borrowing_ids SYS.ODCINUMBERLIST;
BEGIN
    -- Create list of borrowing IDs to return
    -- Use IDs that exist in your test data
    v_borrowing_ids := SYS.ODCINUMBERLIST(1, 2);
    
    -- Call the procedure
    proc_return_books(p_student_id => 1, p_borrowing_ids => v_borrowing_ids);
END;
/

-- Verify books were returned
SELECT * FROM borrowing_records WHERE id IN (1, 2);

-- ============================================================================
-- TEST 8: Test Books Availability Report (Task 8)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 8: Books Availability Report
PROMPT ========================================

BEGIN
    proc_books_availability_report;
END;
/

-- ============================================================================
-- TEST 9: Test Automated Suspension (Task 9)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 9: Automated Suspension
PROMPT ========================================

-- First, create some penalties for a student
INSERT INTO penalties (id, student_id, amount, reason, paid_status)
VALUES (seq_penalties.NEXTVAL, 1, 60, 'Test penalty exceeding threshold', 'unpaid');

COMMIT;

-- Run suspension procedure
BEGIN
    proc_suspend_students(p_threshold => 50);
END;
/

-- Verify student was suspended
SELECT id, name, membership_status FROM students WHERE id = 1;

-- ============================================================================
-- TEST 10: Test Total Currently Borrowed Function (Task 10A)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 10: Total Currently Borrowed
PROMPT ========================================

DECLARE
    v_total NUMBER;
BEGIN
    v_total := fn_total_currently_borrowed;
    DBMS_OUTPUT.PUT_LINE('Total books currently borrowed: ' || v_total);
END;
/

-- ============================================================================
-- TEST 11: Test Availability Update Trigger (Task 10B)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 11: Availability Update Trigger
PROMPT ========================================

-- Update a borrowing record to 'Returned'
UPDATE borrowing_records
SET status = 'Returned', return_date = SYSDATE
WHERE id = 3;

COMMIT;

-- Verify book availability was updated
SELECT id, title, availability FROM books WHERE id = 3;

-- ============================================================================
-- TEST 12: Test User Creation Logging (Task 1)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 12: User Creation Logging
PROMPT ========================================

SELECT * FROM user_creation_log ORDER BY created_at DESC;

-- ============================================================================
-- TEST 13: Test Blocking Session Identification (Task 12)
-- ============================================================================

PROMPT ========================================
PROMPT TEST 13: Blocking Session Identification
PROMPT ========================================

BEGIN
    proc_identify_blockers;
END;
/

-- ============================================================================
-- COMPREHENSIVE DATA VERIFICATION
-- ============================================================================

PROMPT ========================================
PROMPT COMPREHENSIVE DATA VERIFICATION
PROMPT ========================================

-- Count records in each table
SELECT 'book_types' AS table_name, COUNT(*) AS record_count FROM book_types
UNION ALL
SELECT 'books', COUNT(*) FROM books
UNION ALL
SELECT 'students', COUNT(*) FROM students
UNION ALL
SELECT 'borrowing_records', COUNT(*) FROM borrowing_records
UNION ALL
SELECT 'penalties', COUNT(*) FROM penalties
UNION ALL
SELECT 'notification_logs', COUNT(*) FROM notification_logs
UNION ALL
SELECT 'audit_trail', COUNT(*) FROM audit_trail
UNION ALL
SELECT 'user_creation_log', COUNT(*) FROM user_creation_log
ORDER BY table_name;

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

PROMPT ========================================
PROMPT ALL TESTS COMPLETED
PROMPT ========================================
PROMPT Review the output above to verify all functionality.
PROMPT ========================================

