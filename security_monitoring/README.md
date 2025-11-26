# Security Monitoring - Login Audit and Alerts

**Overview**
- **Purpose:** Record login attempts and generate a security alert when a user fails to authenticate more than twice in the same day (on the 3rd failed attempt).
- **Approach:** Database-level audit table + alert table. Triggers detect suspicious behavior and record alerts. An `email_queue` table is provided so an external worker can send notifications.

**Files**
- `setup_oracle.sql`: Oracle DDL and triggers (uses a compound trigger on `login_audit` to avoid mutating-table errors).

**Requirements**
- MySQL/MariaDB or Oracle DB and a client (`mysql`, `sqlplus` or `sqlcl`).
- Privileges to create tables and triggers in the chosen schema.

**Design notes**
- **Audit:** All login attempts are recorded in `login_audit` with `username`, `attempt_time`, `status` (SUCCESS/FAILED) and optional `ip_address`.
- **Alerting:** When failed attempts for the same username in the same day reach 3, a single alert row is inserted into `security_alerts`.
- **Emailing:** The DB does not send mail directly. Instead, alerts insert a row into `email_queue` that a separate worker should process and deliver.

The script uses a compound trigger to collect FAILED rows during the statement and perform counting after the statement to avoid mutating-table errors.

**Quick test (applies to both MySQL and Oracle)**
- Insert three failed attempts for the same username (same day):

```sql
INSERT INTO login_audit (username, status, ip_address) VALUES ('alice','FAILED','10.0.0.1');
INSERT INTO login_audit (username, status, ip_address) VALUES ('alice','FAILED','10.0.0.1');
INSERT INTO login_audit (username, status, ip_address) VALUES ('alice','FAILED','10.0.0.1');

-- Then verify:
SELECT * FROM security_alerts WHERE username = 'alice';
SELECT * FROM email_queue WHERE recipient = 'security@example.com';
```

You should see one `security_alerts` record and one `email_queue` entry after the third failed insert.

**Email worker (recommended)**
- Implementation idea: a small service (Python/Node/PowerShell) that polls `email_queue` for `sent = 0`, sends the message via SMTP or provider API, and marks `sent = 1` with a `sent_time` (add column if desired).

**Security considerations**
- Limit who can run the scripts (DDL privileges grant power).
- Mask or encrypt sensitive fields if storing device identifiers.
- Consider rate-limiting and account lockout policies at the application layer in addition to DB auditing.

**Customization**
- Threshold, period, and contact address are simple to change in the scripts. For per-session detection (instead of per-day), alter the timestamp-window logic in the trigger.

**Contact & notes**
- Placeholder contact used in scripts: `security@example.com`. Replace with your security team's address.
- If you want, I can add a small worker script to send queued emails, or adapt the scripts to a different RDBMS (Postgres/SQL Server).
