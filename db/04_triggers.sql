-- ============================================================================
-- Advanced Library Management System
-- Triggers Implementation (Tasks 4, 5, 10B)
-- ============================================================================
-- This script implements all triggers:
-- - Task 4: Borrowing Validation Trigger
-- - Task 5: Audit Trail Triggers (UPDATE/DELETE)
-- - Task 10B: Availability Update Trigger
-- ============================================================================

SET SERVEROUTPUT ON SIZE 1000000;

-- ============================================================================
-- TASK 4: BORROWING VALIDATION TRIGGER
-- ============================================================================
-- BEFORE INSERT trigger that prevents a student from borrowing a book
-- if they have overdue books or have reached the borrowing limit (3 books).
-- ============================================================================

CREATE OR REPLACE TRIGGER trg_borrowing_validation
BEFORE INSERT ON borrowing_records
FOR EACH ROW
DECLARE
    v_active_count NUMBER;
    v_overdue_count NUMBER;
    v_student_status VARCHAR2(20);
    v_book_availability VARCHAR2(20);
BEGIN
    -- Check student membership status
    SELECT membership_status INTO v_student_status
    FROM students
    WHERE id = :NEW.student_id;
    
    IF v_student_status = 'suspended' THEN
        RAISE_APPLICATION_ERROR(-20001, 
            'Cannot borrow: Student ID ' || :NEW.student_id || ' is suspended.');
    END IF;
    
    -- Check book availability
    SELECT availability INTO v_book_availability
    FROM books
    WHERE id = :NEW.book_id;
    
    IF v_book_availability = 'Borrowed' THEN
        RAISE_APPLICATION_ERROR(-20002, 
            'Cannot borrow: Book ID ' || :NEW.book_id || ' is already borrowed.');
    END IF;
    
    -- Count active borrowings for this student
    SELECT COUNT(*)
    INTO v_active_count
    FROM borrowing_records
    WHERE student_id = :NEW.student_id
      AND (status = 'Borrowed' OR return_date IS NULL);
    
    -- Check if student has reached borrowing limit (3 books)
    IF v_active_count >= 3 THEN
        RAISE_APPLICATION_ERROR(-20003, 
            'Cannot borrow: Student ID ' || :NEW.student_id || 
            ' has reached the maximum borrowing limit of 3 books.');
    END IF;
    
    -- Check for overdue books
    SELECT COUNT(*)
    INTO v_overdue_count
    FROM borrowing_records
    WHERE student_id = :NEW.student_id
      AND status IN ('Borrowed', 'Overdue')
      AND return_date IS NULL
      AND borrow_date + 7 < SYSDATE;
    
    IF v_overdue_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 
            'Cannot borrow: Student ID ' || :NEW.student_id || 
            ' has ' || v_overdue_count || ' overdue book(s). Please return overdue books first.');
    END IF;
    
    -- Set default values if not provided
    IF :NEW.borrow_date IS NULL THEN
        :NEW.borrow_date := SYSDATE;
    END IF;
    
    IF :NEW.status IS NULL THEN
        :NEW.status := 'Borrowed';
    END IF;
    
    -- Update book availability to 'Borrowed'
    UPDATE books
    SET availability = 'Borrowed'
    WHERE id = :NEW.book_id;
    
    DBMS_OUTPUT.PUT_LINE('Borrowing record validated and inserted successfully.');
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20005, 
            'Invalid student ID or book ID.');
    WHEN OTHERS THEN
        RAISE;
END trg_borrowing_validation;
/

-- ============================================================================
-- TASK 5: AUDIT TRAIL TRIGGERS
-- ============================================================================
-- BEFORE UPDATE and BEFORE DELETE triggers that log modifications or
-- deletions to borrowing records into the AuditTrail table.
-- ============================================================================

-- Helper function to format record data as CLOB
CREATE OR REPLACE FUNCTION format_record_data(
    p_id NUMBER,
    p_book_id NUMBER,
    p_student_id NUMBER,
    p_borrow_date DATE,
    p_return_date DATE,
    p_status VARCHAR2
) RETURN CLOB AS
    v_data CLOB;
BEGIN
    v_data := 'ID: ' || p_id || 
              ', Book ID: ' || p_book_id || 
              ', Student ID: ' || p_student_id || 
              ', Borrow Date: ' || TO_CHAR(p_borrow_date, 'DD-MON-YYYY HH24:MI:SS') || 
              ', Return Date: ' || NVL(TO_CHAR(p_return_date, 'DD-MON-YYYY HH24:MI:SS'), 'NULL') || 
              ', Status: ' || p_status;
    RETURN v_data;
END format_record_data;
/

-- BEFORE UPDATE Trigger
CREATE OR REPLACE TRIGGER trg_borrowing_audit_update
BEFORE UPDATE ON borrowing_records
FOR EACH ROW
DECLARE
    v_old_data CLOB;
    v_new_data CLOB;
BEGIN
    -- Format old data
    v_old_data := format_record_data(
        :OLD.id,
        :OLD.book_id,
        :OLD.student_id,
        :OLD.borrow_date,
        :OLD.return_date,
        :OLD.status
    );
    
    -- Format new data
    v_new_data := format_record_data(
        :NEW.id,
        :NEW.book_id,
        :NEW.student_id,
        :NEW.borrow_date,
        :NEW.return_date,
        :NEW.status
    );
    
    -- Insert into audit trail
    INSERT INTO audit_trail (
        id,
        table_name,
        operation,
        old_data,
        new_data,
        created_at
    ) VALUES (
        seq_audit.NEXTVAL,
        'BORROWING_RECORDS',
        'UPDATE',
        v_old_data,
        v_new_data,
        SYSDATE
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't prevent the update
        DBMS_OUTPUT.PUT_LINE('Error in audit trigger: ' || SQLERRM);
END trg_borrowing_audit_update;
/

-- BEFORE DELETE Trigger
CREATE OR REPLACE TRIGGER trg_borrowing_audit_delete
BEFORE DELETE ON borrowing_records
FOR EACH ROW
DECLARE
    v_old_data CLOB;
BEGIN
    -- Format old data
    v_old_data := format_record_data(
        :OLD.id,
        :OLD.book_id,
        :OLD.student_id,
        :OLD.borrow_date,
        :OLD.return_date,
        :OLD.status
    );
    
    -- Insert into audit trail
    INSERT INTO audit_trail (
        id,
        table_name,
        operation,
        old_data,
        new_data,
        created_at
    ) VALUES (
        seq_audit.NEXTVAL,
        'BORROWING_RECORDS',
        'DELETE',
        v_old_data,
        NULL,
        SYSDATE
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't prevent the delete
        DBMS_OUTPUT.PUT_LINE('Error in audit trigger: ' || SQLERRM);
END trg_borrowing_audit_delete;
/

-- ============================================================================
-- TASK 10B: AVAILABILITY UPDATE TRIGGER
-- ============================================================================
-- AFTER UPDATE trigger that automatically updates the availability status
-- of the corresponding book to 'Available' when a borrowing record's status
-- is updated to 'Returned'.
-- ============================================================================

CREATE OR REPLACE TRIGGER trg_update_book_availability
AFTER UPDATE ON borrowing_records
FOR EACH ROW
WHEN (NEW.status = 'Returned' AND (OLD.status <> 'Returned' OR OLD.status IS NULL))
BEGIN
    -- Update book availability to 'Available'
    UPDATE books
    SET availability = 'Available'
    WHERE id = :NEW.book_id;
    
    DBMS_OUTPUT.PUT_LINE('Book ID ' || :NEW.book_id || ' availability updated to Available.');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error updating book availability: ' || SQLERRM);
        -- Don't raise to prevent blocking the return operation
END trg_update_book_availability;
/

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('Triggers Created!');
DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('Created:');
DBMS_OUTPUT.PUT_LINE('  - trg_borrowing_validation (BEFORE INSERT)');
DBMS_OUTPUT.PUT_LINE('  - trg_borrowing_audit_update (BEFORE UPDATE)');
DBMS_OUTPUT.PUT_LINE('  - trg_borrowing_audit_delete (BEFORE DELETE)');
DBMS_OUTPUT.PUT_LINE('  - trg_update_book_availability (AFTER UPDATE)');
DBMS_OUTPUT.PUT_LINE('  - format_record_data (Helper Function)');
DBMS_OUTPUT.PUT_LINE('========================================');

