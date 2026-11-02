-- =============================================================================
-- Script: 11_tests_medication.sql
-- Domain 7: Diagnostic Test Results & Pharmacological Regimens
-- Business Questions:
--   1. What is the overall distribution of diagnostic test results across admissions?
--   2. Which medications are most frequently administered across medical conditions?
--   3. Does the prevalence of abnormal test results vary by admission urgency?
-- Caveat: Medication frequency and diagnostic test outcomes in this observational
--         dataset reflect mock assignment. They must NEVER be used to evaluate
--         pharmacological efficacy, drug safety, or clinical care guidelines.
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 7.1: Diagnostic Test Result Distribution & Financial Exposure
-- Analyzes frequency, percentage share, and average billing by test result outcome.
-- -----------------------------------------------------------------------------
SELECT 
    test_results,
    COUNT(admission_record_id) AS encounter_count,
    ROUND(COUNT(admission_record_id)::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM healthcare.admissions), 0), 2) AS pct_share,
    ROUND(SUM(billing_amount), 2) AS total_billing_usd,
    ROUND(AVG(billing_amount), 2) AS avg_billing_usd,
    ROUND(AVG(length_of_stay_days), 2) AS avg_los_days
FROM healthcare.admissions
GROUP BY test_results
ORDER BY encounter_count DESC;

-- -----------------------------------------------------------------------------
-- QUERY 7.2: Pharmacological Regimen Distribution
-- Measures prescription frequency and average patient stay duration by medication.
-- -----------------------------------------------------------------------------
SELECT 
    medication,
    COUNT(admission_record_id) AS prescription_count,
    ROUND(COUNT(admission_record_id)::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM healthcare.admissions), 0), 2) AS pct_of_prescriptions,
    ROUND(AVG(billing_amount), 2) AS avg_encounter_billing_usd,
    ROUND(AVG(length_of_stay_days), 2) AS avg_los_days
FROM healthcare.admissions
GROUP BY medication
ORDER BY prescription_count DESC;

-- -----------------------------------------------------------------------------
-- QUERY 7.3: Clinical Cross-Tabulation: Medical Condition x Medication Matrix
-- Evaluates the cross-distribution of prescribed medications across admitting diagnoses.
-- -----------------------------------------------------------------------------
SELECT 
    medical_condition,
    COUNT(*) FILTER (WHERE medication = 'Aspirin')     AS aspirin_count,
    COUNT(*) FILTER (WHERE medication = 'Ibuprofen')   AS ibuprofen_count,
    COUNT(*) FILTER (WHERE medication = 'Lipitor')     AS lipitor_count,
    COUNT(*) FILTER (WHERE medication = 'Paracetamol') AS paracetamol_count,
    COUNT(*) FILTER (WHERE medication = 'Penicillin')  AS penicillin_count,
    COUNT(*)                                           AS total_condition_cases
FROM healthcare.admissions
GROUP BY medical_condition
ORDER BY total_condition_cases DESC;

-- -----------------------------------------------------------------------------
-- QUERY 7.4: Test Result Severity by Admission Urgency
-- Assesses whether acute Emergency admissions exhibit higher rates of Abnormal findings.
-- -----------------------------------------------------------------------------
SELECT 
    admission_type,
    COUNT(*) FILTER (WHERE test_results = 'Abnormal')     AS abnormal_tests,
    COUNT(*) FILTER (WHERE test_results = 'Inconclusive') AS inconclusive_tests,
    COUNT(*) FILTER (WHERE test_results = 'Normal')       AS normal_tests,
    COUNT(*)                                              AS total_type_admissions,
    ROUND(COUNT(*) FILTER (WHERE test_results = 'Abnormal')::NUMERIC * 100.0 / 
          NULLIF(COUNT(*), 0), 2) AS abnormal_test_rate_pct
FROM healthcare.admissions
GROUP BY admission_type
ORDER BY abnormal_test_rate_pct DESC;

