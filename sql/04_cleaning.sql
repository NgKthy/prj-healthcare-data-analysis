-- =============================================================================
-- Script: 04_cleaning.sql
-- Description: Production ETL transformation pipeline.
--              Transforms raw staging records into the production analytical
--              table `healthcare.admissions`. Applies deduplication, text
--              normalization, type casting, feature engineering, and indexing.
-- =============================================================================

SET search_path TO healthcare, public;

-- Drop production analytical table to ensure clean, repeatable runs
DROP TABLE IF EXISTS healthcare.admissions CASCADE;

-- Create production analytical table
CREATE TABLE healthcare.admissions (
    admission_record_id    BIGSERIAL PRIMARY KEY,
    patient_name           VARCHAR(150)   NOT NULL,
    age                    SMALLINT       NOT NULL,
    gender                 VARCHAR(10)    NOT NULL,
    blood_type             VARCHAR(5)     NOT NULL,
    medical_condition      VARCHAR(50)    NOT NULL,
    date_of_admission      DATE           NOT NULL,
    doctor_name            VARCHAR(150)   NOT NULL,
    hospital_name          VARCHAR(150)   NOT NULL,
    insurance_provider     VARCHAR(50)    NOT NULL,
    billing_amount         NUMERIC(12, 2) NOT NULL,
    room_number            INTEGER        NOT NULL,
    admission_type         VARCHAR(20)    NOT NULL,
    discharge_date         DATE           NOT NULL,
    medication             VARCHAR(50)    NOT NULL,
    test_results           VARCHAR(20)    NOT NULL,
    -- Engineered analytical features
    length_of_stay_days    INTEGER        NOT NULL,
    is_negative_billing    BOOLEAN        NOT NULL,
    age_group              VARCHAR(20)    NOT NULL,
    
    -- Table constraints
    CONSTRAINT chk_admissions_age CHECK (age >= 0 AND age <= 125),
    CONSTRAINT chk_admissions_dates CHECK (discharge_date >= date_of_admission),
    CONSTRAINT chk_admissions_los CHECK (length_of_stay_days >= 0)
);

COMMENT ON TABLE healthcare.admissions IS 'Standardized, deduplicated production analytics table for healthcare encounters.';

-- =============================================================================
-- INGESTION & TRANSFORMATION PIPELINE
-- Extracts distinct 15-attribute records from staging, normalizing casing and
-- deriving analytical dimensions.
-- =============================================================================
INSERT INTO healthcare.admissions (
    patient_name,
    age,
    gender,
    blood_type,
    medical_condition,
    date_of_admission,
    doctor_name,
    hospital_name,
    insurance_provider,
    billing_amount,
    room_number,
    admission_type,
    discharge_date,
    medication,
    test_results,
    length_of_stay_days,
    is_negative_billing,
    age_group
)
SELECT 
    INITCAP(TRIM(raw_name))                          AS patient_name,
    raw_age::SMALLINT                                AS age,
    TRIM(raw_gender)                                 AS gender,
    TRIM(raw_blood_type)                             AS blood_type,
    TRIM(raw_medical_condition)                      AS medical_condition,
    raw_date_of_admission::DATE                      AS date_of_admission,
    TRIM(raw_doctor)                                 AS doctor_name,
    TRIM(raw_hospital)                               AS hospital_name,
    TRIM(raw_insurance_provider)                     AS insurance_provider,
    ROUND(raw_billing_amount::NUMERIC, 2)            AS billing_amount,
    raw_room_number::INTEGER                         AS room_number,
    TRIM(raw_admission_type)                         AS admission_type,
    raw_discharge_date::DATE                         AS discharge_date,
    TRIM(raw_medication)                             AS medication,
    TRIM(raw_test_results)                           AS test_results,
    -- Derived Length of Stay (LOS) in calendar days
    (raw_discharge_date::DATE - raw_date_of_admission::DATE)::INTEGER AS length_of_stay_days,
    -- Derived Negative Billing Flag
    CASE WHEN raw_billing_amount::NUMERIC < 0 THEN TRUE ELSE FALSE END AS is_negative_billing,
    -- Standardized Demographic Age Bracket
    CASE 
        WHEN raw_age::INTEGER < 18 THEN '< 18'
        WHEN raw_age::INTEGER BETWEEN 18 AND 35 THEN '18 - 35'
        WHEN raw_age::INTEGER BETWEEN 36 AND 50 THEN '36 - 50'
        WHEN raw_age::INTEGER BETWEEN 51 AND 65 THEN '51 - 65'
        ELSE '65+'
    END AS age_group
FROM (
    -- Deduplication Gate: Select distinct across all 15 raw source attributes
    SELECT DISTINCT 
        raw_name, raw_age, raw_gender, raw_blood_type, raw_medical_condition,
        raw_date_of_admission, raw_doctor, raw_hospital, raw_insurance_provider,
        raw_billing_amount, raw_room_number, raw_admission_type, raw_discharge_date,
        raw_medication, raw_test_results
    FROM healthcare.staging_admissions
) deduplicated_source
ORDER BY raw_date_of_admission::DATE, raw_name;

-- =============================================================================
-- PERFORMANCE INDEXING
-- Indexing high-frequency filter and join predicates for analytical queries.
-- =============================================================================
CREATE INDEX idx_admissions_med_condition   ON healthcare.admissions (medical_condition);
CREATE INDEX idx_admissions_admission_type  ON healthcare.admissions (admission_type);
CREATE INDEX idx_admissions_insurance       ON healthcare.admissions (insurance_provider);
CREATE INDEX idx_admissions_adm_date        ON healthcare.admissions (date_of_admission);
CREATE INDEX idx_admissions_hospital        ON healthcare.admissions (hospital_name);
CREATE INDEX idx_admissions_age_group       ON healthcare.admissions (age_group);
CREATE INDEX idx_admissions_neg_billing     ON healthcare.admissions (is_negative_billing);

-- =============================================================================
-- POST-TRANSFORMATION RECONCILIATION AUDIT
-- =============================================================================
SELECT 
    (SELECT COUNT(*) FROM healthcare.staging_admissions) AS staging_raw_count,
    COUNT(*) AS cleaned_production_count,
    (SELECT COUNT(*) FROM healthcare.staging_admissions) - COUNT(*) AS duplicates_eliminated,
    COUNT(*) FILTER (WHERE is_negative_billing = TRUE) AS negative_billing_records,
    ROUND(SUM(billing_amount), 2) AS total_gross_billed_usd,
    ROUND(AVG(length_of_stay_days), 2) AS overall_avg_los_days
FROM healthcare.admissions;

