-- =============================================================================
-- Script: 02_staging.sql
-- Description: Creates lossless staging table for raw CSV ingestion and provides
--              COPY commands for psql, pgAdmin, and DBeaver.
-- =============================================================================

SET search_path TO healthcare, public;

-- Drop existing staging table if needed to ensure idempotent runs
DROP TABLE IF EXISTS healthcare.staging_admissions;

-- Create staging table with permissive text datatypes to prevent ingestion truncation
CREATE TABLE healthcare.staging_admissions (
    raw_name               VARCHAR(255),
    raw_age                VARCHAR(50),
    raw_gender             VARCHAR(50),
    raw_blood_type         VARCHAR(50),
    raw_medical_condition  VARCHAR(255),
    raw_date_of_admission  VARCHAR(50),
    raw_doctor             VARCHAR(255),
    raw_hospital           VARCHAR(255),
    raw_insurance_provider VARCHAR(255),
    raw_billing_amount     VARCHAR(50),
    raw_room_number        VARCHAR(50),
    raw_admission_type     VARCHAR(50),
    raw_discharge_date     VARCHAR(50),
    raw_medication         VARCHAR(255),
    raw_test_results       VARCHAR(255)
);

COMMENT ON TABLE healthcare.staging_admissions IS 'Lossless staging table containing raw CSV data from healthcare_dataset.csv.';

-- =============================================================================
-- INGESTION INSTRUCTIONS:
-- Method A: Using psql command line (client-side copy):
--   \copy healthcare.staging_admissions FROM 'data/raw/healthcare_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
--
-- Method B: Using server-side COPY (requires absolute path and server file access):
--   COPY healthcare.staging_admissions FROM '/absolute/path/to/data/raw/healthcare_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
--
-- Method C: Using DBeaver or pgAdmin GUI:
--   Right click on `staging_admissions` -> Import Data -> Choose `healthcare_dataset.csv`.
-- =============================================================================

-- Post-Ingestion Verification Query:
SELECT COUNT(*) AS staging_row_count,
       55500    AS expected_row_count,
       CASE WHEN COUNT(*) = 55500 THEN 'PASS: Complete ingestion'
            ELSE 'FAIL: Row count mismatch'
       END AS audit_status
FROM healthcare.staging_admissions;

