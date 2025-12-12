-- ============================================================================
-- Advanced Library Management System
-- Safe Return Process with Transactions (Task 7)
-- ============================================================================
-- This script implements a PL/SQL block that handles returning multiple books
-- at once using transactions to ensure data integrity.
-- ============================================================================

SET SERVEROUTPUT ON SIZE 1000000;

-- ============================================================================
-- TASK 7: SAFE RETURN PROCESS WITH TRANSACTIONS
-- ============================================================================
-- Procedure that handles returning multiple books in a single transaction.
-- Checks for overdue penalties, calculates fees, and updates records.
-- Uses ROLLBACK on errors to ensure data integrity.
-- ============================================================================

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
    
    -- Check if student has overdue penalties (informational)
    SELECT NVL(SUM(amount), 0)
    INTO v_total_penalty
    FROM penalties
    WHERE student_id = p_student_id
      AND paid_status = 'unpaid';
    
    IF v_total_penalty > 0 THEN
        DBMS_OUTPUT.PUT_LINE('⚠ WARNING: Student has unpaid penalties totaling $' || v_total_penalty);
        DBMS_OUTPUT.PUT_LINE('  Penalties will be calculated for overdue books.');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    -- Start transaction (implicit in PL/SQL)
    -- Set savepoint for potential rollback
    SAVEPOINT before_return;
    
    -- Process each borrowing record
    FOR i IN 1..p_borrowing_ids.COUNT LOOP
        v_borrowing_id := p_borrowing_ids(i);
        
        BEGIN
            -- Verify the borrowing record belongs to the student
            DECLARE
                v_verify_student_id NUMBER;
                v_verify_status VARCHAR2(20);
            BEGIN
                SELECT student_id, status
                INTO v_verify_student_id, v_verify_status
                FROM borrowing_records
                WHERE id = v_borrowing_id;
                
                IF v_verify_student_id != p_student_id THEN
                    RAISE_APPLICATION_ERROR(-20010, 
                        'Borrowing record ' || v_borrowing_id || 
                        ' does not belong to student ' || p_student_id);
                END IF;
                
                IF v_verify_status = 'Returned' THEN
                    DBMS_OUTPUT.PUT_LINE('Book ' || v_borrowing_id || ' already returned. Skipping.');
                    CONTINUE;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20011, 
                        'Borrowing record ' || v_borrowing_id || ' not found.');
            END;
            
            -- Calculate and insert penalty if overdue
            v_penalty_amount := fn_calc_and_insert_penalty(v_borrowing_id);
            
            IF v_penalty_amount > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Book ' || v_borrowing_id || 
                                   ': Penalty calculated = $' || v_penalty_amount);
            END IF;
            
            -- Update borrowing record to 'Returned'
            UPDATE borrowing_records
            SET status = 'Returned',
                return_date = SYSDATE
            WHERE id = v_borrowing_id;
            
            v_returned_count := v_returned_count + 1;
            DBMS_OUTPUT.PUT_LINE('✓ Book ' || v_borrowing_id || ' returned successfully.');
            
        EXCEPTION
            WHEN OTHERS THEN
                v_error_occurred := TRUE;
                v_error_message := SQLERRM;
                DBMS_OUTPUT.PUT_LINE('✗ Error processing book ' || v_borrowing_id || ': ' || v_error_message);
                -- Continue to next book, but mark error for rollback
        END;
    END LOOP;
    
    -- Check if any errors occurred
    IF v_error_occurred THEN
        -- Rollback all changes
        ROLLBACK TO SAVEPOINT before_return;
        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
        DBMS_OUTPUT.PUT_LINE('✗ TRANSACTION ROLLED BACK');
        DBMS_OUTPUT.PUT_LINE('Reason: Errors occurred during processing');
        DBMS_OUTPUT.PUT_LINE('No books were returned.');
        DBMS_OUTPUT.PUT_LINE('========================================');
        RAISE_APPLICATION_ERROR(-20012, 'Return process failed. All changes rolled back.');
    ELSE
        -- Commit all changes
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
        DBMS_OUTPUT.PUT_LINE('✓ TRANSACTION COMMITTED');
        DBMS_OUTPUT.PUT_LINE('Successfully returned: ' || v_returned_count || ' book(s)');
        DBMS_OUTPUT.PUT_LINE('========================================');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Final safety rollback
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
        DBMS_OUTPUT.PUT_LINE('✗ FATAL ERROR - ALL CHANGES ROLLED BACK');
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('========================================');
        RAISE;
END proc_return_books;
/

-- ============================================================================
-- EXAMPLE USAGE
-- ============================================================================
-- Example: Return multiple books for a student
/*
DECLARE
    v_borrowing_ids SYS.ODCINUMBERLIST;
BEGIN
    -- Create list of borrowing IDs to return
    v_borrowing_ids := SYS.ODCINUMBERLIST(1, 2, 3);
    
    -- Call the procedure
    proc_return_books(p_student_id => 1, p_borrowing_ids => v_borrowing_ids);
END;
/
*/

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('Transaction Procedure Created!');
DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('Created:');
DBMS_OUTPUT.PUT_LINE('  - proc_return_books (with transaction handling)');
DBMS_OUTPUT.PUT_LINE('========================================');

