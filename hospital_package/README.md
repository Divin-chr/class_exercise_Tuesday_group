# Hospital Package

Purpose
- Simple, easy-to-run PL/SQL package to manage patients and doctors in a hospital scenario.
- Demonstrates bulk insertion of patients, querying via a function (REF CURSOR), and admitting patients.

Contents
- `setup_oracle_hospital.sql` — Creates tables (`patients`, `doctors`, `email_queue`), builds the `hospital_pkg` package (spec + body), and runs a short test block.

Package highlights
- `bulk_load_patients(p_list IN t_patient_tab)` — Efficient bulk insert using `FORALL`.
- `show_all_patients` — Returns a `SYS_REFCURSOR` to read all patients.
- `count_admitted` — Returns the number of patients with admitted status.
- `admit_patient(p_id)` — Marks a specific patient as admitted.

Why this is simple
- The package keeps transaction handling straightforward (procedures commit internally) to make testing and learning easier.
- No external mail sending is implemented; `email_queue` is included for completeness.

Quick usage (interactive examples)

1) Enable DBMS output (SQL*Plus / SQLcl)

```sql
SET SERVEROUTPUT ON SIZE 1000000
```

2) Run the deployment script

```powershell
sqlplus your_user@your_db
@C:/Users/user/Desktop/exrcise/hospital_package/setup_oracle_hospital.sql
```

3) Bulk-load patients (anonymous PL/SQL block)

```sql
DECLARE
  l_list hospital_pkg.t_patient_tab := hospital_pkg.t_patient_tab();
BEGIN
  l_list.extend; l_list(1).name := 'Alice A'; l_list(1).age := 28; l_list(1).gender := 'F';
  l_list.extend; l_list(2).name := 'Mark B';  l_list(2).age := 52; l_list(2).gender := 'M';
  l_list.extend; l_list(3).name := 'Sam C';   l_list(3).age := 40; l_list(3).gender := 'M';

  hospital_pkg.bulk_load_patients(l_list);
  COMMIT; -- optional: package already commits for clarity
END;
/
```

4) Show all patients (REF CURSOR; SQL*Plus)

```sql
VARIABLE rc REFCURSOR
EXEC :rc := hospital_pkg.show_all_patients;
PRINT rc
```

5) Admit a patient and check admitted count

```sql
-- Admit patient with id = 1
EXEC hospital_pkg.admit_patient(1);

-- Get admitted count (function)
SELECT hospital_pkg.count_admitted FROM dual;
```

Notes and tips
- The `show_all_patients` returns a REF CURSOR suitable for clients and SQL*Plus `PRINT`.
- Anonymous blocks (DECLARE/BEGIN/END) are good for test data and calling the bulk loader.
- In production, remove `COMMIT` from package routines and manage transactions at the application level.

Optional next steps I can add
- A small Python worker to poll `email_queue` and send emails via SMTP.
- Input validation and uniqueness checks in the package.
- A demonstration script that populates doctors and assigns patients to doctors (if you want that extension).

Contact
- Placeholder contact used in example scripts: `security@example.com`. Replace with your operational address.

If you'd like any of the optional next steps, tell me which and I will add it.
# Hospital Package 

Purpose
- Simple, easy-to-run PL/SQL package to manage patients and doctors in a hospital scenario.
- Demonstrates bulk insertion of patients, querying via a function (ref cursor), and admitting patients.

What the script does
- Drops existing objects if present (safe re-run).
- Creates required tables.
- Creates the `hospital_pkg` package spec and body.
- Runs a small test block that:
  - Bulk loads three sample patients.
  - Prints all patients via `DBMS_OUTPUT`.
  - Admits one patient and prints the admitted count.


