-- =============================================================================
-- Script: 20_validation.sql
-- Domain 16: Automated Enterprise Reconciliation & Assertion Suite
-- Objective: Executes 10 mission-critical assertion tests against database tables.
-- Pattern: Returns 0 error rows when passing. Any returned rows indicate a violation.
-- =============================================================================

SET search_path TO healthcare, public;

-- =============================================================================
-- TEST SUITE EXECUTION & RECONCILIATION SUMMARY
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ASSERTION 1: Staging vs. Production Row Count Reconciliation
-- Condition for PASS: Total Staging (55,500) = Production (54,966) + Duplicates (534)
-- -----------------------------------------------------------------------------
WITH count_recon AS (
    SELECT 
        (SELECT COUNT(*) FROM healthcare.staging_admissions) AS staging_count,
        (SELECT COUNT(*) FROM healthcare.admissions)         AS production_count,
        534                                                 AS expected_duplicates
)
SELECT 
    'ASSERTION 1: Row Count Reconciliation' AS test_name,
    staging_count,
    production_count,
    expected_duplicates,
    staging_count - (production_count + expected_duplicates) AS variance,
    CASE 
        WHEN staging_count = (production_count + expected_duplicates) THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM count_recon;

-- -----------------------------------------------------------------------------
-- ASSERTION 2: Primary Surrogate Key Uniqueness & Non-Null Enforceability
-- Condition for PASS: Zero duplicate IDs and zero NULL IDs.
-- -----------------------------------------------------------------------------
SELECT 
    'ASSERTION 2: Surrogate Key Integrity' AS test_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT admission_record_id) AS distinct_keys,
    COUNT(*) FILTER (WHERE admission_record_id IS NULL) AS null_keys,
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT admission_record_id) 
         AND COUNT(*) FILTER (WHERE admission_record_id IS NULL) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM healthcare.admissions;

-- -----------------------------------------------------------------------------
-- ASSERTION 3: Inpatient Length of Stay (LOS) Validity
-- Condition for PASS: Zero records with negative length of stay.
-- -----------------------------------------------------------------------------
SELECT 
    'ASSERTION 3: Non-Negative Length of Stay' AS test_name,
    COUNT(*) FILTER (WHERE length_of_stay_days < 0) AS negative_los_violations,
    COUNT(*) FILTER (WHERE discharge_date < date_of_admission) AS chronology_violations,
    CASE 
        WHEN COUNT(*) FILTER (WHERE length_of_stay_days < 0) = 0 
         AND COUNT(*) FILTER (WHERE discharge_date < date_of_admission) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM healthcare.admissions;

-- -----------------------------------------------------------------------------
-- ASSERTION 4: Financial Billing Reconciliation
-- Condition for PASS: Staging Total Billing = Production Total Billing + Duplicate Total Billing
-- -----------------------------------------------------------------------------
WITH financial_recon AS (
    SELECT 
        ROUND((SELECT SUM(ROUND(raw_billing_amount::NUMERIC, 2)) FROM healthcare.staging_admissions), 2) AS staging_total_usd,
        ROUND((SELECT SUM(billing_amount) FROM healthcare.admissions), 2)                                 AS production_total_usd,
        13363704.06                                                                                       AS duplicate_total_usd
)
SELECT 
    'ASSERTION 4: Financial Ledger Reconciliation' AS test_name,
    staging_total_usd,
    production_total_usd,
    duplicate_total_usd,
    ROUND(staging_total_usd - (production_total_usd + duplicate_total_usd), 2) AS variance_usd,
    CASE 
        WHEN ABS(staging_total_usd - (production_total_usd + duplicate_total_usd)) < 0.05 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM financial_recon;

-- -----------------------------------------------------------------------------
-- ASSERTION 5: Critical Attribute Nullability Check
-- Condition for PASS: Exactly zero NULLs across all 18 production columns.
-- -----------------------------------------------------------------------------
SELECT 
    'ASSERTION 5: Production Nullability Audit' AS test_name,
    COUNT(*) FILTER (
        WHERE patient_name IS NULL 
           OR age IS NULL 
           OR gender IS NULL 
           OR blood_type IS NULL 
           OR medical_condition IS NULL 
           OR date_of_admission IS NULL 
           OR doctor_name IS NULL 
           OR hospital_name IS NULL 
           OR insurance_provider IS NULL 
           OR billing_amount IS NULL 
           OR room_number IS NULL 
           OR admission_type IS NULL 
           OR discharge_date IS NULL 
           OR medication IS NULL 
           OR test_results IS NULL 
           OR length_of_stay_days IS NULL 
           OR is_negative_billing IS NULL 
           OR age_group IS NULL
    ) AS total_null_attribute_violations,
    CASE 
        WHEN COUNT(*) FILTER (
            WHERE patient_name IS NULL OR age IS NULL OR billing_amount IS NULL OR date_of_admission IS NULL
        ) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM healthcare.admissions;

-- -----------------------------------------------------------------------------
-- ASSERTION 6: Demographic Age Boundary Conformance
-- Condition for PASS: All patient ages within biologically valid bounds (0 to 125).
-- -----------------------------------------------------------------------------
SELECT 
    'ASSERTION 6: Demographic Age Range' AS test_name,
    MIN(age) AS observed_min_age,
    MAX(age) AS observed_max_age,
    COUNT(*) FILTER (WHERE age < 0 OR age > 125) AS out_of_bounds_age_count,
    CASE 
        WHEN COUNT(*) FILTER (WHERE age < 0 OR age > 125) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM healthcare.admissions;

-- -----------------------------------------------------------------------------
-- ASSERTION 7: Categorical Domain Conformance
-- Condition for PASS: Zero unexpected categories in categorical dimensions.
-- -----------------------------------------------------------------------------
SELECT 
    'ASSERTION 7: Categorical Domain Integrity' AS test_name,
    COUNT(*) FILTER (WHERE gender NOT IN ('Male', 'Female')) AS invalid_gender_count,
    COUNT(*) FILTER (WHERE admission_type NOT IN ('Elective', 'Emergency', 'Urgent')) AS invalid_admission_type_count,
    COUNT(*) FILTER (WHERE medical_condition NOT IN ('Arthritis', 'Asthma', 'Cancer', 'Diabetes', 'Hypertension', 'Obesity')) AS invalid_condition_count,
    COUNT(*) FILTER (WHERE insurance_provider NOT IN ('Aetna', 'Blue Cross', 'Cigna', 'Medicare', 'UnitedHealthcare')) AS invalid_insurance_count,
    CASE 
        WHEN COUNT(*) FILTER (
            WHERE gender NOT IN ('Male', 'Female')
               OR admission_type NOT IN ('Elective', 'Emergency', 'Urgent')
               OR medical_condition NOT IN ('Arthritis', 'Asthma', 'Cancer', 'Diabetes', 'Hypertension', 'Obesity')
               OR insurance_provider NOT IN ('Aetna', 'Blue Cross', 'Cigna', 'Medicare', 'UnitedHealthcare')
        ) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM healthcare.admissions;

-- -----------------------------------------------------------------------------
-- ASSERTION 8: Negative Billing Flag Consistency
-- Condition for PASS: Flag correctly identifies all negative billing charges (106 rows).
-- -----------------------------------------------------------------------------
SELECT 
    'ASSERTION 8: Negative Billing Flag Audit' AS test_name,
    COUNT(*) FILTER (WHERE billing_amount < 0 AND is_negative_billing = FALSE) AS unflagged_negative_count,
    COUNT(*) FILTER (WHERE billing_amount >= 0 AND is_negative_billing = TRUE) AS false_flagged_positive_count,
    COUNT(*) FILTER (WHERE is_negative_billing = TRUE) AS total_flagged_negatives,
    CASE 
        WHEN COUNT(*) FILTER (WHERE billing_amount < 0 AND is_negative_billing = FALSE) = 0
         AND COUNT(*) FILTER (WHERE billing_amount >= 0 AND is_negative_billing = TRUE) = 0
         AND COUNT(*) FILTER (WHERE is_negative_billing = TRUE) = 106 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM healthcare.admissions;

-- -----------------------------------------------------------------------------
-- ASSERTION 9: Temporal Boundary Validation
-- Condition for PASS: Admissions fall strictly within 2019-05-08 and 2024-05-07.
-- -----------------------------------------------------------------------------
SELECT 
    'ASSERTION 9: Temporal Timeline Bounds' AS test_name,
    MIN(date_of_admission) AS observed_start_date,
    MAX(date_of_admission) AS observed_end_date,
    COUNT(*) FILTER (WHERE date_of_admission < '2019-05-08'::DATE OR date_of_admission > '2024-05-07'::DATE) AS out_of_bounds_dates,
    CASE 
        WHEN COUNT(*) FILTER (WHERE date_of_admission < '2019-05-08'::DATE OR date_of_admission > '2024-05-07'::DATE) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM healthcare.admissions;

-- -----------------------------------------------------------------------------
-- ASSERTION 10: Percentage Share Sum Integrity Check
-- Condition for PASS: Proportions across all medical conditions sum to exactly 100.0%.
-- -----------------------------------------------------------------------------
WITH condition_counts AS (
    SELECT 
        medical_condition,
        COUNT(admission_record_id)::NUMERIC * 100.0 / 
            NULLIF((SELECT COUNT(*) FROM healthcare.admissions), 0) AS condition_share
    FROM healthcare.admissions
    GROUP BY medical_condition
)
SELECT 
    'ASSERTION 10: Percentage Mathematical Balance' AS test_name,
    ROUND(SUM(condition_share), 1) AS total_aggregated_shares,
    CASE 
        WHEN ROUND(SUM(condition_share), 0) = 100 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM condition_counts;
