-- =============================================================================
-- Script: 14_window_functions.sql
-- Domain 10: Window Functions — Cumulative Totals, Moving Averages & Distributions
-- Business Questions:
--   1. What is the cumulative running total of admissions and gross billing over time?
--   2. What is the 3-month moving average of admissions to smooth seasonal variance?
--   3. How does each encounter's billing compare to its condition-specific cohort average?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 10.1: Cumulative Running Totals Across 5-Year Admission Timeline
-- Tracks progressive accumulation of admissions and billed charges.
-- -----------------------------------------------------------------------------
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', date_of_admission)::DATE AS admission_month,
        COUNT(admission_record_id)                   AS monthly_admissions,
        SUM(billing_amount)                          AS monthly_billing
    FROM healthcare.admissions
    GROUP BY DATE_TRUNC('month', date_of_admission)
)
SELECT 
    admission_month,
    monthly_admissions,
    SUM(monthly_admissions) OVER (ORDER BY admission_month) AS cumulative_admissions,
    ROUND(monthly_billing, 2) AS monthly_billing_usd,
    ROUND(SUM(monthly_billing) OVER (ORDER BY admission_month), 2) AS cumulative_billing_usd
FROM monthly_data
ORDER BY admission_month;

-- -----------------------------------------------------------------------------
-- QUERY 10.2: 3-Month Moving Average of Inpatient Encounters
-- Smoothes month-to-month noise using window framing (ROWS BETWEEN 2 PRECEDING AND CURRENT ROW).
-- -----------------------------------------------------------------------------
WITH monthly_volume AS (
    SELECT 
        DATE_TRUNC('month', date_of_admission)::DATE AS admission_month,
        COUNT(admission_record_id)                   AS monthly_admissions
    FROM healthcare.admissions
    GROUP BY DATE_TRUNC('month', date_of_admission)
)
SELECT 
    admission_month,
    monthly_admissions,
    ROUND(AVG(monthly_admissions) OVER (
        ORDER BY admission_month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 1) AS moving_avg_3_month_admissions
FROM monthly_volume
ORDER BY admission_month;

-- -----------------------------------------------------------------------------
-- QUERY 10.3: Encounter Variance from Condition-Specific Baseline
-- Uses PARTITION BY medical_condition to evaluate individual encounter charge deviation.
-- -----------------------------------------------------------------------------
SELECT 
    admission_record_id,
    patient_name,
    medical_condition,
    admission_type,
    billing_amount,
    ROUND(AVG(billing_amount) OVER (PARTITION BY medical_condition), 2) AS condition_avg_billing,
    ROUND(billing_amount - AVG(billing_amount) OVER (PARTITION BY medical_condition), 2) AS variance_from_condition_mean,
    ROUND(((billing_amount - AVG(billing_amount) OVER (PARTITION BY medical_condition)) * 100.0 / 
           NULLIF(AVG(billing_amount) OVER (PARTITION BY medical_condition), 0)), 2) AS variance_pct
FROM healthcare.admissions
WHERE is_negative_billing = FALSE
ORDER BY variance_from_condition_mean DESC
LIMIT 20;

-- -----------------------------------------------------------------------------
-- QUERY 10.4: Cumulative Distribution & Percent Rank of Inpatient Stays
-- Evaluates the percentile standing of lengths of stay via CUME_DIST().
-- -----------------------------------------------------------------------------
SELECT DISTINCT 
    length_of_stay_days,
    COUNT(*) OVER (PARTITION BY length_of_stay_days) AS encounters_at_this_los,
    ROUND(CUME_DIST() OVER (ORDER BY length_of_stay_days)::NUMERIC, 4) AS cumulative_distribution,
    ROUND(PERCENT_RANK() OVER (ORDER BY length_of_stay_days)::NUMERIC, 4) AS percentile_rank
FROM healthcare.admissions
ORDER BY length_of_stay_days;

