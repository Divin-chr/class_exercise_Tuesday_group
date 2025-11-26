
BEGIN
  EXECUTE IMMEDIATE 'DROP PACKAGE hospital_pkg';
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
  EXECUTE IMMEDIATE 'DROP TABLE patients PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE doctors PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Create tables
CREATE TABLE patients (
  id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR2(200 CHAR) NOT NULL,
  age NUMBER,
  gender VARCHAR2(10 CHAR),
  admitted_status VARCHAR2(1 CHAR) DEFAULT 'N' NOT NULL
);

CREATE TABLE doctors (
  id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR2(200 CHAR) NOT NULL,
  specialty VARCHAR2(200 CHAR)
);

-- Simple email queue (optional for notifications)
CREATE TABLE email_queue (
  id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  recipient VARCHAR2(255 CHAR),
  subject VARCHAR2(255 CHAR),
  body CLOB,
  queued_time TIMESTAMP DEFAULT SYSTIMESTAMP,
  sent NUMBER(1) DEFAULT 0
);

-- Package specification
CREATE OR REPLACE PACKAGE hospital_pkg IS
  -- Simple record and collection for bulk operations
  TYPE t_patient_rec IS RECORD (
    name     VARCHAR2(200 CHAR),
    age      NUMBER,
    gender   VARCHAR2(10 CHAR),
    admitted VARCHAR2(1 CHAR)
  );

  TYPE t_patient_tab IS TABLE OF t_patient_rec;

  -- Bulk load multiple patients
  PROCEDURE bulk_load_patients(p_list IN t_patient_tab);

  -- Return a ref cursor with all patients
  FUNCTION show_all_patients RETURN SYS_REFCURSOR;

  -- Count admitted patients
  FUNCTION count_admitted RETURN NUMBER;

  -- Admit a patient by id
  PROCEDURE admit_patient(p_id IN NUMBER);
END hospital_pkg;
/

-- Package body: implementations
CREATE OR REPLACE PACKAGE BODY hospital_pkg IS

  PROCEDURE bulk_load_patients(p_list IN t_patient_tab) IS
  BEGIN
    IF p_list IS NULL OR p_list.COUNT = 0 THEN
      RETURN;
    END IF;

    FORALL i IN 1 .. p_list.COUNT
      INSERT INTO patients (name, age, gender, admitted_status)
      VALUES (p_list(i).name, p_list(i).age, p_list(i).gender, NVL(p_list(i).admitted,'N'));

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END bulk_load_patients;

  FUNCTION show_all_patients RETURN SYS_REFCURSOR IS
    rc SYS_REFCURSOR;
  BEGIN
    OPEN rc FOR SELECT id, name, age, gender, admitted_status FROM patients ORDER BY id;
    RETURN rc;
  END show_all_patients;

  FUNCTION count_admitted RETURN NUMBER IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_cnt FROM patients WHERE admitted_status = 'Y';
    RETURN v_cnt;
  END count_admitted;

  PROCEDURE admit_patient(p_id IN NUMBER) IS
  BEGIN
    UPDATE patients SET admitted_status = 'Y' WHERE id = p_id;
    COMMIT;
  END admit_patient;

END hospital_pkg;
/

SET SERVEROUTPUT ON SIZE 1000000;

DECLARE
  l_list hospital_pkg.t_patient_tab := hospital_pkg.t_patient_tab();
  rc SYS_REFCURSOR;
  v_id patients.id%TYPE;
  v_name patients.name%TYPE;
  v_age patients.age%TYPE;
  v_gender patients.gender%TYPE;
  v_adm patients.admitted_status%TYPE;
  v_total NUMBER;
  v_admitted NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- Hospital package test start ---');

  -- Clean existing test data for deterministic runs
  DELETE FROM patients;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Existing patients cleared.');

  -- Prepare sample patients for bulk load
  l_list.extend; l_list(1).name := 'John Doe'; l_list(1).age := 45; l_list(1).gender := 'M'; l_list(1).admitted := 'N';
  l_list.extend; l_list(2).name := 'Jane Roe'; l_list(2).age := 30; l_list(2).gender := 'F'; l_list(2).admitted := 'N';
  l_list.extend; l_list(3).name := 'Bob Smith'; l_list(3).age := 60; l_list(3).gender := 'M'; l_list(3).admitted := 'N';
  l_list.extend; l_list(4).name := 'Emily X'; l_list(4).age := 50; l_list(4).gender := 'F'; l_list(4).admitted := 'N';

  hospital_pkg.bulk_load_patients(l_list);
  DBMS_OUTPUT.PUT_LINE('Bulk load completed.');

  -- Verify total rows
  SELECT COUNT(*) INTO v_total FROM patients;
  DBMS_OUTPUT.PUT_LINE('Total patients after bulk load: ' || v_total);

  -- Display all patients via package
  rc := hospital_pkg.show_all_patients;
  DBMS_OUTPUT.PUT_LINE('Listing patients:');
  LOOP
    FETCH rc INTO v_id, v_name, v_age, v_gender, v_adm;
    EXIT WHEN rc%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('ID:'||v_id||' Name:'||v_name||' Age:'||NVL(TO_CHAR(v_age),'NULL')||' Gender:'||NVL(v_gender,'-')||' Admitted:'||v_adm);
  END LOOP;
  CLOSE rc;

  -- Admit two patients
  hospital_pkg.admit_patient(2);
  hospital_pkg.admit_patient(3);
  DBMS_OUTPUT.PUT_LINE('Admitted patients with id 2 and 3.');

  -- Check admitted count via package and direct query
  v_admitted := hospital_pkg.count_admitted;
  DBMS_OUTPUT.PUT_LINE('Admitted count (package): ' || v_admitted);

  SELECT COUNT(*) INTO v_admitted FROM patients WHERE admitted_status = 'Y';
  DBMS_OUTPUT.PUT_LINE('Admitted count (direct query): ' || v_admitted);

  DBMS_OUTPUT.PUT_LINE('--- Hospital package test end ---');
END;
/
