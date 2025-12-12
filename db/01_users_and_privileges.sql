-- ============================================================================
-- Advanced Library Management System
-- User Management and Privileges (Task 1)
-- ============================================================================
-- This script creates users (MANAGER, USER1, USER2) and implements
-- user creation logging functionality.
-- ============================================================================

SET SERVEROUTPUT ON SIZE 1000000;

-- ============================================================================
-- 1. CREATE MANAGER USER
-- ============================================================================
-- Note: This must be run as a user with DBA privileges (SYSTEM or SYS)

-- Create MANAGER user
CREATE USER manager IDENTIFIED BY Manager123;

-- Grant necessary privileges to MANAGER
GRANT CONNECT, RESOURCE TO manager;
GRANT CREATE USER TO manager;
GRANT CREATE SESSION TO manager;
GRANT CREATE TABLE TO manager;
GRANT CREATE PROCEDURE TO manager;
GRANT CREATE SEQUENCE TO manager;
GRANT CREATE TRIGGER TO manager;

-- Grant access to all tables (will be created later)
-- These grants will be done after schema creation
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

-- ============================================================================
-- 2. CREATE USER CREATION LOGGING PROCEDURE
-- ============================================================================

CREATE OR REPLACE PROCEDURE log_user_creation(p_username VARCHAR2) AS
    v_creator VARCHAR2(100);
BEGIN
    -- Get the current user who is creating the new user
    SELECT USER INTO v_creator FROM dual;
    
    -- Insert into user_creation_log
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

-- ============================================================================
-- 3. CREATE USER1 (by MANAGER)
-- ============================================================================
-- Note: This section should be run as MANAGER user
-- For demonstration, we'll create it here but in practice, MANAGER would run this

-- Create USER1
CREATE USER user1 IDENTIFIED BY User1Pass123;

-- Grant privileges to USER1
GRANT CONNECT, RESOURCE TO user1;
GRANT CREATE SESSION TO user1;
GRANT CREATE TABLE TO user1;
GRANT CREATE SEQUENCE TO user1;

-- Grant access to create books and book_types tables
-- USER1 will create these tables in their own schema
-- For this task, we'll grant access to SYSTEM schema tables
GRANT SELECT, INSERT, UPDATE, DELETE ON system.book_types TO user1;
GRANT SELECT, INSERT, UPDATE, DELETE ON system.books TO user1;
GRANT SELECT ON system.seq_booktypes TO user1;
GRANT SELECT ON system.seq_books TO user1;

-- Log user creation
BEGIN
    log_user_creation('USER1');
END;
/

-- ============================================================================
-- 4. CREATE USER2 (by MANAGER)
-- ============================================================================

-- Create USER2
CREATE USER user2 IDENTIFIED BY User2Pass123;

-- Grant privileges to USER2
GRANT CONNECT, RESOURCE TO user2;
GRANT CREATE SESSION TO user2;

-- Grant INSERT privileges on books and book_types to USER2
GRANT SELECT, INSERT ON system.book_types TO user2;
GRANT SELECT, INSERT ON system.books TO user2;
GRANT SELECT ON system.seq_booktypes TO user2;
GRANT SELECT ON system.seq_books TO user2;

-- Log user creation
BEGIN
    log_user_creation('USER2');
END;
/

-- ============================================================================
-- 5. VERIFICATION QUERIES
-- ============================================================================

-- Display user creation log
SELECT * FROM user_creation_log ORDER BY created_at DESC;

DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('User Management Setup Complete!');
DBMS_OUTPUT.PUT_LINE('========================================');
DBMS_OUTPUT.PUT_LINE('Created users:');
DBMS_OUTPUT.PUT_LINE('  - MANAGER (with CREATE USER privilege)');
DBMS_OUTPUT.PUT_LINE('  - USER1 (can create books and book_types tables)');
DBMS_OUTPUT.PUT_LINE('  - USER2 (can insert into books and book_types)');
DBMS_OUTPUT.PUT_LINE('========================================');

