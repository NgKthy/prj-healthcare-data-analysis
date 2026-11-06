-- =============================================================================
-- Script: 19_insurance_condition.sql
-- Domain 15: Insurance Payer x Medical Condition Cross-Tabulation Matrix
-- Business Questions:
--   1. What is the full two-way matrix of encounter volume between Insurers and Conditions?
--   2. Which Payer-Condition combination drives the highest aggregate gross billed charges?
--   3. Are there significant average billing divergences across payer-condition pairs?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 15.1: Two-Way Cross-Tabulation Matrix: Payer x Medical Condition
-- Displays encounter volume matrix across all 5 insurance carriers and 6 conditions.
-- -----------------------------------------------------------------------------
SELECT 
    insurance_provider,
    COUNT(*) FILTER (WHERE medical_condition = 'Arthritis')    AS arthritis_cases,
    COUNT(*) FILTER (WHERE medical_condition = 'Asthma')       AS asthma_cases,
    COUNT(*) FILTER (WHERE medical_condition = 'Cancer')       AS cancer_cases,
    COUNT(*) FILTER (WHERE medical_condition = 'Diabetes')     AS diabetes_cases,
    COUNT(*) FILTER (WHERE medical_condition = 'Hypertension') AS hypertension_cases,
    COUNT(*) FILTER (WHERE medical_condition = 'Obesity')      AS obesity_cases,
    COUNT(*)                                                   AS total_payer_encounters
FROM healthcare.admissions
GROUP BY insurance_provider
ORDER BY total_payer_encounters DESC;

-- -----------------------------------------------------------------------------
-- QUERY 15.2: Payer-Condition Financial Charge & Volume League Table
-- Details encounter count, total billing, and average billing for all 30 pairs.
-- -----------------------------------------------------------------------------
WITH payer_condition_pairs AS (
    SELECT 
        insurance_provider,
        medical_condition,
        COUNT(admission_record_id)           AS encounter_count,
        ROUND(SUM(billing_amount), 2)        AS total_billing_usd,
        ROUND(AVG(billing_amount), 2)        AS avg_billing_usd,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC, 2) AS median_billing_usd,
        ROUND(AVG(length_of_stay_days), 2)   AS avg_los_days
    FROM healthcare.admissions
    GROUP BY insurance_provider, medical_condition
)
SELECT 
    insurance_provider,
    medical_condition,
    encounter_count,
    ROUND(encounter_count::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM healthcare.admissions), 0), 2) AS pct_of_all_admissions,
    total_billing_usd,
    avg_billing_usd,
    median_billing_usd,
    avg_los_days,
    DENSE_RANK() OVER (ORDER BY total_billing_usd DESC) AS financial_rank
FROM payer_condition_pairs
ORDER BY total_billing_usd DESC;

