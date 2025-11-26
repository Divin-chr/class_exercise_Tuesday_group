
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_after_security_alert_insert';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_login_audit_compound';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE email_queue PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE security_alerts PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE login_audit PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Create tables
CREATE TABLE login_audit (
  id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username VARCHAR2(255 CHAR) NOT NULL,
  attempt_time TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  status VARCHAR2(10) DEFAULT 'FAILED' NOT NULL,
  ip_address VARCHAR2(100 CHAR)
);

-- Ensure only allowed status values
ALTER TABLE login_audit ADD CONSTRAINT chk_login_status CHECK (status IN ('SUCCESS','FAILED'));

CREATE TABLE security_alerts (
  id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username VARCHAR2(255 CHAR) NOT NULL,
  failed_attempts NUMBER NOT NULL,
  alert_time TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  alert_message CLOB,
  contact VARCHAR2(255 CHAR)
);

CREATE TABLE email_queue (
  id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  alert_id NUMBER,
  recipient VARCHAR2(255 CHAR),
  subject VARCHAR2(255 CHAR),
  body CLOB,
  queued_time TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  sent NUMBER(1) DEFAULT 0 NOT NULL
);

-- Compound trigger on login_audit to avoid mutating-table errors
-- It collects usernames of FAILED rows during the statement and then
-- in the AFTER STATEMENT section performs SELECTs against the table.
CREATE OR REPLACE TRIGGER trg_login_audit_compound
  FOR INSERT ON login_audit
  COMPOUND TRIGGER

  -- associative array to track unique usernames inserted with FAILED status
  TYPE username_map_t IS TABLE OF BOOLEAN INDEX BY VARCHAR2(255);
  g_usernames username_map_t;

  BEFORE STATEMENT IS
  BEGIN
    NULL; -- nothing needed here
  END BEFORE STATEMENT;

  AFTER EACH ROW IS
  BEGIN
    IF :NEW.status = 'FAILED' THEN
      g_usernames(:NEW.username) := TRUE;
    END IF;
  END AFTER EACH ROW;

  AFTER STATEMENT IS
    v_username VARCHAR2(255);
    failed_count NUMBER;
    existing_alerts NUMBER;
  BEGIN
    v_username := g_usernames.FIRST;
    WHILE v_username IS NOT NULL LOOP
      -- Count failed attempts for this user for today
      SELECT COUNT(*) INTO failed_count
      FROM login_audit
      WHERE username = v_username
        AND status = 'FAILED'
        AND TRUNC(attempt_time) = TRUNC(SYSDATE);

      -- Only insert a new alert if none exists yet for this user today
      IF failed_count >= 3 THEN
        SELECT COUNT(*) INTO existing_alerts
        FROM security_alerts
        WHERE username = v_username
          AND TRUNC(alert_time) = TRUNC(SYSDATE);

        IF existing_alerts = 0 THEN
          INSERT INTO security_alerts (username, failed_attempts, alert_message, contact)
          VALUES (v_username, failed_count,
                  'User ' || v_username || ' failed to login ' || failed_count || ' times today.',
                  'security@example.com');
        END IF;
      END IF;

      v_username := g_usernames.NEXT(v_username);
    END LOOP;
  END AFTER STATEMENT;

END trg_login_audit_compound;
/

-- Trigger on security_alerts to queue an email (simple DB-side queue insert)
CREATE OR REPLACE TRIGGER trg_after_security_alert_insert
AFTER INSERT ON security_alerts
FOR EACH ROW
BEGIN
  INSERT INTO email_queue (alert_id, recipient, subject, body)
  VALUES (:NEW.id, :NEW.contact, 'Security alert for ' || :NEW.username, :NEW.alert_message);
END;
/

-- Example test (run these after running the script):
INSERT INTO login_audit (username, status, ip_address) VALUES ('alice','FAILED','10.0.0.1');
INSERT INTO login_audit (username, status, ip_address) VALUES ('alice','FAILED','10.0.0.1');
INSERT INTO login_audit (username, status, ip_address) VALUES ('alice','FAILED','10.0.0.1');

-- Then check:
SELECT * FROM security_alerts WHERE username = 'alice';
SELECT * FROM email_queue WHERE recipient = 'security@example.com';
