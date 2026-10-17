-- =============================================================================
-- Script: 03_data_quality.sql
-- Description: Comprehensive 10-point Data Quality Audit on staging data.
--              Identifies NULLs, duplicates, outliers, formatting anomalies,
--              and synthetic generation artifacts before production cleaning.
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- CHECK 1: Total Ingested Row Count Verification
-- Objective: Confirm full load of raw file against expected baseline (55,500).
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS total_staging_records,
       55500    AS benchmark_records,
       COUNT(*) - 55500 AS delta
FROM healthcare.staging_admissions;

-- -----------------------------------------------------------------------------
-- CHECK 2: NULL and Whitespace Audit Across All 15 Fields
-- Objective: Check for missing data, unpopulated strings, or blank values.
-- Expected: 0 NULLs across all fields (100% completeness).
-- -----------------------------------------------------------------------------
SELECT 
    COUNT(*) FILTER (WHERE raw_name IS NULL OR TRIM(raw_name) = '') AS null_name_count,
    COUNT(*) FILTER (WHERE raw_age IS NULL OR TRIM(raw_age) = '') AS null_age_count,
    COUNT(*) FILTER (WHERE raw_gender IS NULL OR TRIM(raw_gender) = '') AS null_gender_count,
    COUNT(*) FILTER (WHERE raw_blood_type IS NULL OR TRIM(raw_blood_type) = '') AS null_blood_type_count,
    COUNT(*) FILTER (WHERE raw_medical_condition IS NULL OR TRIM(raw_medical_condition) = '') AS null_condition_count,
    COUNT(*) FILTER (WHERE raw_date_of_admission IS NULL OR TRIM(raw_date_of_admission) = '') AS null_adm_date_count,
    COUNT(*) FILTER (WHERE raw_doctor IS NULL OR TRIM(raw_doctor) = '') AS null_doctor_count,
    COUNT(*) FILTER (WHERE raw_hospital IS NULL OR TRIM(raw_hospital) = '') AS null_hospital_count,
    COUNT(*) FILTER (WHERE raw_insurance_provider IS NULL OR TRIM(raw_insurance_provider) = '') AS null_insurance_count,
    COUNT(*) FILTER (WHERE raw_billing_amount IS NULL OR TRIM(raw_billing_amount) = '') AS null_billing_count,
    COUNT(*) FILTER (WHERE raw_room_number IS NULL OR TRIM(raw_room_number) = '') AS null_room_count,
    COUNT(*) FILTER (WHERE raw_admission_type IS NULL OR TRIM(raw_admission_type) = '') AS null_adm_type_count,
    COUNT(*) FILTER (WHERE raw_discharge_date IS NULL OR TRIM(raw_discharge_date) = '') AS null_discharge_date_count,
    COUNT(*) FILTER (WHERE raw_medication IS NULL OR TRIM(raw_medication) = '') AS null_medication_count,
    COUNT(*) FILTER (WHERE raw_test_results IS NULL OR TRIM(raw_test_results) = '') AS null_test_results_count
FROM healthcare.staging_admissions;

-- -----------------------------------------------------------------------------
-- CHECK 3: Exact 15-Column Record Duplication Audit
-- Objective: Identify identical records duplicated across all attributes.
-- Finding: 534 duplicate records exist in the benchmark dataset.
-- -----------------------------------------------------------------------------
WITH duplicate_audit AS (
    SELECT raw_name, raw_age, raw_gender, raw_blood_type, raw_medical_condition,
           raw_date_of_admission, raw_doctor, raw_hospital, raw_insurance_provider,
           raw_billing_amount, raw_room_number, raw_admission_type, raw_discharge_date,
           raw_medication, raw_test_results,
           COUNT(*) AS occurrence_count
    FROM healthcare.staging_admissions
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
    HAVING COUNT(*) > 1
)
SELECT COUNT(*)                     AS distinct_duplicated_patterns,
       SUM(occurrence_count)        AS total_rows_in_duplicate_groups,
       SUM(occurrence_count - 1)    AS surplus_duplicate_rows_to_remove
FROM duplicate_audit;

-- -----------------------------------------------------------------------------
-- CHECK 4: Name Casing & Formatting Inconsistencies
-- Objective: Detect erratic capitalization in patient names (e.g., 'Bobby JacksOn').
-- -----------------------------------------------------------------------------
SELECT raw_name AS sample_raw_name,
       INITCAP(TRIM(raw_name)) AS standardized_name
FROM healthcare.staging_admissions
WHERE raw_name <> INITCAP(TRIM(raw_name))
LIMIT 10;

-- -----------------------------------------------------------------------------
-- CHECK 5: Categorical Domain Conformance & Distinct Value Inspection
-- Objective: Verify that categorical fields only contain sanctioned values.
-- -----------------------------------------------------------------------------
SELECT 'gender' AS attribute_name, raw_gender AS distinct_val, COUNT(*) AS freq FROM healthcare.staging_admissions GROUP BY 2
UNION ALL
SELECT 'admission_type', raw_admission_type, COUNT(*) FROM healthcare.staging_admissions GROUP BY 2
UNION ALL
SELECT 'insurance_provider', raw_insurance_provider, COUNT(*) FROM healthcare.staging_admissions GROUP BY 2
UNION ALL
SELECT 'test_results', raw_test_results, COUNT(*) FROM healthcare.staging_admissions GROUP BY 2
ORDER BY 1, 2;

-- -----------------------------------------------------------------------------
-- CHECK 6: Age Range & Type Casting Verification
-- Objective: Identify patients outside plausible biological human age ranges.
-- -----------------------------------------------------------------------------
SELECT MIN(raw_age::INTEGER) AS min_age,
       MAX(raw_age::INTEGER) AS max_age,
       AVG(raw_age::INTEGER)::NUMERIC(5,2) AS mean_age,
       COUNT(*) FILTER (WHERE raw_age::INTEGER < 0 OR raw_age::INTEGER > 120) AS invalid_age_count
FROM healthcare.staging_admissions;

-- -----------------------------------------------------------------------------
-- CHECK 7: Chronological Date Validity & Inpatient Length of Stay (LOS)
-- Objective: Confirm that discharge occurs on or after admission date.
-- -----------------------------------------------------------------------------
SELECT 
    MIN(raw_date_of_admission::DATE) AS earliest_admission,
    MAX(raw_date_of_admission::DATE) AS latest_admission,
    MIN(raw_discharge_date::DATE)    AS earliest_discharge,
    MAX(raw_discharge_date::DATE)    AS latest_discharge,
    COUNT(*) FILTER (WHERE raw_discharge_date::DATE < raw_date_of_admission::DATE) AS invalid_chronology_count,
    COUNT(*) FILTER (WHERE raw_discharge_date::DATE = raw_date_of_admission::DATE) AS same_day_admissions_count,
    MIN(raw_discharge_date::DATE - raw_date_of_admission::DATE) AS min_los_days,
    MAX(raw_discharge_date::DATE - raw_date_of_admission::DATE) AS max_los_days
FROM healthcare.staging_admissions;

-- -----------------------------------------------------------------------------
-- CHECK 8: Financial Billing Anomalies & Negative Charges
-- Objective: Detect negative, zero, or extreme outlier billing amounts.
-- Finding: 108 records in raw staging have negative charges (adjustments).
-- -----------------------------------------------------------------------------
SELECT 
    COUNT(*) FILTER (WHERE raw_billing_amount::NUMERIC < 0) AS negative_billing_count,
    COUNT(*) FILTER (WHERE raw_billing_amount::NUMERIC = 0) AS zero_billing_count,
    MIN(raw_billing_amount::NUMERIC) AS min_billing_amount,
    MAX(raw_billing_amount::NUMERIC) AS max_billing_amount,
    ROUND(AVG(raw_billing_amount::NUMERIC), 2) AS mean_billing_amount,
    ROUND(SUM(raw_billing_amount::NUMERIC) FILTER (WHERE raw_billing_amount::NUMERIC < 0), 2) AS total_negative_adjustment_dollars
FROM healthcare.staging_admissions;

-- -----------------------------------------------------------------------------
-- CHECK 9: Inpatient Room Number Boundaries
-- Objective: Ensure assigned room numbers conform to physical facility bounds.
-- -----------------------------------------------------------------------------
SELECT MIN(raw_room_number::INTEGER) AS min_room,
       MAX(raw_room_number::INTEGER) AS max_room,
       COUNT(DISTINCT raw_room_number::INTEGER) AS distinct_rooms_assigned
FROM healthcare.staging_admissions;

-- -----------------------------------------------------------------------------
-- CHECK 10: Entity Cardinality & Synthetic Generation Profiling
-- Objective: Profile distinct count of hospitals, doctors, and patient names.
-- Finding: High cardinality reveals synthetic generation characteristics.
-- -----------------------------------------------------------------------------
SELECT 
    COUNT(DISTINCT raw_hospital) AS unique_hospitals,
    COUNT(DISTINCT raw_doctor)   AS unique_doctors,
    COUNT(DISTINCT raw_name)     AS unique_patient_names,
    COUNT(*)                     AS total_encounters
FROM healthcare.staging_admissions;

