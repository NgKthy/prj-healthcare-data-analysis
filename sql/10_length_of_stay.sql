-- =============================================================================
-- Script: 10_length_of_stay.sql
-- Domain 6: Inpatient Length of Stay (LOS) & Bed Utilization
-- Business Questions:
--   1. What is the central tendency and dispersion of inpatient length of stay?
--   2. How does length of stay vary across medical conditions, age cohorts, and admission types?
--   3. Is there an empirical relationship between bed days occupied and billed charges?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 6.1: Length of Stay Central Tendency & Statistical Dispersion
-- Evaluates mean, median, interquartile range (IQR), minimum, and maximum stay.
-- -----------------------------------------------------------------------------
SELECT 
    COUNT(admission_record_id)                                           AS total_admissions,
    MIN(length_of_stay_days)                                             AS min_los_days,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY length_of_stay_days::DOUBLE PRECISION)::NUMERIC, 1) AS p25_los_days,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY length_of_stay_days::DOUBLE PRECISION)::NUMERIC, 1) AS median_los_days,
    ROUND(AVG(length_of_stay_days), 2)                                   AS mean_los_days,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY length_of_stay_days::DOUBLE PRECISION)::NUMERIC, 1) AS p75_los_days,
    MAX(length_of_stay_days)                                             AS max_los_days,
    ROUND(STDDEV(length_of_stay_days), 2)                                AS stddev_los_days
FROM healthcare.admissions;

-- -----------------------------------------------------------------------------
-- QUERY 6.2: Inpatient Stay Duration Bins (LOS Histogram)
-- Classifies bed-days into 5-day duration cohorts to evaluate bed occupancy blocks.
-- -----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN length_of_stay_days BETWEEN 1 AND 5   THEN '01 - 05 Days (Short Stay)'
        WHEN length_of_stay_days BETWEEN 6 AND 10  THEN '06 - 10 Days'
        WHEN length_of_stay_days BETWEEN 11 AND 15 THEN '11 - 15 Days (Median Range)'
        WHEN length_of_stay_days BETWEEN 16 AND 20 THEN '16 - 20 Days'
        WHEN length_of_stay_days BETWEEN 21 AND 25 THEN '21 - 25 Days'
        ELSE '26 - 30 Days (Extended Stay)'
    END AS stay_duration_tier,
    COUNT(admission_record_id) AS encounter_count,
    ROUND(COUNT(admission_record_id)::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM healthcare.admissions), 0), 2) AS pct_of_admissions,
    ROUND(SUM(billing_amount), 2) AS total_tier_billing_usd,
    ROUND(AVG(billing_amount), 2) AS avg_tier_billing_usd
FROM healthcare.admissions
GROUP BY 1
ORDER BY 1;

-- -----------------------------------------------------------------------------
-- QUERY 6.3: Multi-Dimensional Length of Stay Matrix
-- Compares average stay across Medical Condition, Admission Type, and Age Bracket.
-- -----------------------------------------------------------------------------
SELECT 
    medical_condition,
    admission_type,
    COUNT(*) AS encounter_count,
    ROUND(AVG(length_of_stay_days), 2) AS avg_los_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY length_of_stay_days::DOUBLE PRECISION)::NUMERIC AS median_los_days,
    ROUND(AVG(billing_amount), 2) AS avg_billing_usd
FROM healthcare.admissions
GROUP BY medical_condition, admission_type
ORDER BY medical_condition, admission_type;

-- -----------------------------------------------------------------------------
-- QUERY 6.4: Descriptive Correlation Between Stay Duration and Billed Charges
-- Calculates correlation coefficient and average billing per bed-day occupied.
-- Note: Synthetic dataset exhibits zero correlation (r ~= 0.00), demonstrating
--       that billing was generated independently of duration.
-- -----------------------------------------------------------------------------
SELECT 
    ROUND(CORR(length_of_stay_days::DOUBLE PRECISION, billing_amount::DOUBLE PRECISION)::NUMERIC, 4) AS pearson_correlation_los_billing,
    ROUND(AVG(billing_amount / NULLIF(length_of_stay_days, 0)), 2) AS avg_billed_charges_per_day,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY (billing_amount / NULLIF(length_of_stay_days, 0))::DOUBLE PRECISION)::NUMERIC, 2) AS median_charge_per_day
FROM healthcare.admissions
WHERE is_negative_billing = FALSE;

