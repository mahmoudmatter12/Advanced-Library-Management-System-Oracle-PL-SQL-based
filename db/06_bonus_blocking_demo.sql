-- ============================================================================
-- Advanced Library Management System
-- Bonus Tasks: Blocker-Waiting Situation (Tasks 11 & 12)
-- ============================================================================
-- This script demonstrates blocker-waiting situations and provides queries
-- to identify and resolve blocking sessions.
-- ============================================================================

SET SERVEROUTPUT ON SIZE 1000000;

-- ============================================================================
-- TASK 11: BLOCKER-WAITING DEMONSTRATION
-- ============================================================================
-- This section provides instructions and scripts to demonstrate a
-- blocker-waiting situation using two transactions.
-- ============================================================================

/*
INSTRUCTIONS FOR DEMONSTRATING BLOCKER-WAITING SITUATION:

STEP 1: Open Session 1 (as USER1)
-----------------------------------
Connect as USER1:
  sqlplus user1/User1Pass123@localhost:1521/XEPDB1

Start a transaction and update a borrowing record (DO NOT COMMIT):
  UPDATE borrowing_records 
  SET status = 'Processing' 
  WHERE id = 1;
  
  -- DO NOT COMMIT YET!


STEP 2: Open Session 2 (as USER2)
-----------------------------------
Connect as USER2 in a new terminal:
  sqlplus user2/User2Pass123@localhost:1521/XEPDB1

Try to insert a penalty for the same borrowing record:
  INSERT INTO penalties (id, student_id, amount, reason, paid_status)
  VALUES (seq_penalties.NEXTVAL, 1, 50, 'Test penalty for borrow id 1', 'unpaid');
  
  -- This will BLOCK waiting for Session 1 to commit or rollback


STEP 3: Monitor Blocking (in Session 3 or SYSTEM session)
-----------------------------------------------------------
Run the queries below to identify the blocker and waiting sessions.


STEP 4: Resolve the Blocking
-----------------------------
Option A: Commit in Session 1 (allows Session 2 to proceed)
Option B: Rollback in Session 1 (allows Session 2 to proceed)
Option C: Kill the blocking session (use with caution)
*/

-- ============================================================================
-- TASK 12: IDENTIFYING BLOCKER AND WAITING SESSIONS
-- ============================================================================
-- Queries to identify blocker and waiting sessions using SID and SERIAL#
-- ============================================================================

-- Query 1: Find blocking and waiting sessions
-- This query shows which sessions are blocking and which are waiting
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

-- Query 2: Detailed blocking information
CREATE OR REPLACE PROCEDURE proc_identify_blockers AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('BLOCKER-WAITING SESSION ANALYSIS');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Display blocking sessions
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
    
    -- Check if no blocking found
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No blocking sessions found.');
        DBMS_OUTPUT.PUT_LINE('All sessions are running normally.');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('========================================');
END proc_identify_blockers;
/

-- Query 3: Simple blocking session query (for quick reference)
-- Run this query to quickly see blocking situations:
/*
SELECT 
    blocking.sid || ',' || blocking.serial# AS blocker_session,
    blocking.username AS blocker_user,
    waiting.sid || ',' || waiting.serial# AS waiting_session,
    waiting.username AS waiting_user,
    waiting.seconds_in_wait AS wait_seconds,
    waiting.event AS wait_event
FROM v$session blocking
JOIN v$session waiting ON blocking.sid = waiting.blocking_session
WHERE waiting.blocking_session IS NOT NULL
  AND waiting.wait_class <> 'Idle';
*/

-- Query 4: Lock information
-- Shows detailed lock information
/*
SELECT 
    s.sid,
    s.serial#,
    s.username,
    s.program,
    l.type AS lock_type,
    l.id1,
    l.id2,
    l.lmode AS lock_mode,
    l.request AS lock_request,
    l.block AS is_blocking
FROM v$lock l
JOIN v$session s ON l.sid = s.sid
WHERE s.username IS NOT NULL
ORDER BY l.block DESC, s.sid;
*/

-- ============================================================================
-- RESOLUTION COMMANDS
-- ============================================================================

-- To resolve a blocking situation, you have several options:

-- Option 1: Commit or Rollback in the blocking session (RECOMMENDED)
-- This is the safest method. Simply commit or rollback the transaction
-- in the session that is holding the lock.

-- Option 2: Kill the blocking session (USE WITH CAUTION)
-- Format: ALTER SYSTEM KILL SESSION 'sid,serial#';
-- Example:
--   ALTER SYSTEM KILL SESSION '123,45678';

-- Option 3: Disconnect the blocking session
-- This will cause an automatic rollback of uncommitted transactions.

-- ============================================================================
-- SAFETY WARNINGS
-- ============================================================================

/*
⚠ WARNING: Killing sessions should only be done when absolutely necessary
and with proper authorization. Killing a session will:
- Rollback any uncommitted transactions in that session
- May cause application errors
- Should be avoided in production environments

Always try to resolve blocking by:
1. Identifying the blocking transaction
2. Contacting the user/session owner
3. Requesting them to commit or rollback
4. Only use KILL SESSION as a last resort
*/

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('Bonus Tasks Scripts Created!');
DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('Created:');
DBMS_OUTPUT.PUT_LINE('  - v_blocking_sessions (View)');
DBMS_OUTPUT.PUT_LINE('  - proc_identify_blockers (Procedure)');
DBMS_OUTPUT.PUT_LINE('  - Blocking demonstration instructions');
DBMS_OUTPUT.PUT_LINE('  - Session identification queries');
DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('');
DBMS_OUTPUT.PUT_LINE('To demonstrate blocking:');
DBMS_OUTPUT.PUT_LINE('1. Run blocking transaction in Session 1 (USER1)');
DBMS_OUTPUT.PUT_LINE('2. Run waiting transaction in Session 2 (USER2)');
DBMS_OUTPUT.PUT_LINE('3. Run proc_identify_blockers in Session 3 (SYSTEM)');
DBMS_OUTPUT.PUT_LINE('========================================');

