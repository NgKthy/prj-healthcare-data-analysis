-- =============================================================================
-- Script: 06_conditions.sql
-- Domain 2: Medical Conditions & Clinical Economics
-- Business Questions:
--   1. What is the encounter volume and total gross billing across medical conditions?
--   2. Which condition generates the highest average and median billing per stay?
--   3. Does any condition exhibit a disproportionate share of costs relative to volume?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 2.1: Clinical Condition Portfolio Overview
-- Evaluates admissions, gross billing, average charges, median charges,
-- and percentage shares of overall volume and gross billed charges.
-- -----------------------------------------------------------------------------
WITH condition_metrics AS (
    SELECT 
        medical_condition,
        COUNT(admission_record_id)           AS encounter_count,
        SUM(billing_amount)                  AS total_billing_usd,
        AVG(billing_amount)                  AS avg_billing_usd,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC AS median_billing_usd,
        AVG(length_of_stay_days)             AS avg_los_days
    FROM healthcare.admissions
    GROUP BY medical_condition
),
totals AS (
    SELECT 
        SUM(encounter_count)   AS grand_total_encounters,
        SUM(total_billing_usd) AS grand_total_billing_usd
    FROM condition_metrics
)
SELECT 
    cm.medical_condition,
    cm.encounter_count,
    ROUND(cm.encounter_count::NUMERIC * 100.0 / NULLIF(t.grand_total_encounters, 0), 2) AS pct_of_total_encounters,
    ROUND(cm.total_billing_usd, 2) AS total_billing_usd,
    ROUND(cm.total_billing_usd::NUMERIC * 100.0 / NULLIF(t.grand_total_billing_usd, 0), 2) AS pct_of_total_billing,
    ROUND(cm.avg_billing_usd, 2) AS avg_billing_usd,
    ROUND(cm.median_billing_usd::NUMERIC, 2) AS median_billing_usd,
    ROUND(cm.avg_los_days, 2) AS avg_los_days,
    -- Cost-to-Volume Ratio: > 1.0 indicates condition absorbs higher cost share than volume share
    ROUND((cm.total_billing_usd / NULLIF(t.grand_total_billing_usd, 0)) / 
          (cm.encounter_count::NUMERIC / NULLIF(t.grand_total_encounters, 0)), 3) AS cost_to_volume_ratio
FROM condition_metrics cm
CROSS JOIN totals t
ORDER BY cm.total_billing_usd DESC;

-- -----------------------------------------------------------------------------
-- QUERY 2.2: Condition Encounter Economics (Positive Billing Charges Only)
-- Isolates standard patient encounter costs by filtering out accounting adjustments.
-- -----------------------------------------------------------------------------
SELECT 
    medical_condition,
    COUNT(*) AS encounter_count,
    ROUND(SUM(billing_amount), 2) AS total_positive_billing_usd,
    ROUND(AVG(billing_amount), 2) AS avg_positive_billing_usd,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC, 2) AS median_positive_billing_usd,
    ROUND(MIN(billing_amount), 2) AS min_charge,
    ROUND(MAX(billing_amount), 2) AS max_charge,
    ROUND(STDDEV(billing_amount), 2) AS stddev_billing_usd
FROM healthcare.admissions
WHERE is_negative_billing = FALSE
GROUP BY medical_condition
ORDER BY avg_positive_billing_usd DESC;

-- -----------------------------------------------------------------------------
-- QUERY 2.3: Medical Condition by Age Group Interaction
-- Evaluates which age demographics drive encounter volume for each clinical diagnosis.
-- -----------------------------------------------------------------------------
SELECT 
    medical_condition,
    COUNT(*) FILTER (WHERE age_group = '< 18')    AS pediatric_count,
    COUNT(*) FILTER (WHERE age_group = '18 - 35') AS young_adult_count,
    COUNT(*) FILTER (WHERE age_group = '36 - 50') AS adult_count,
    COUNT(*) FILTER (WHERE age_group = '51 - 65') AS middle_aged_count,
    COUNT(*) FILTER (WHERE age_group = '65+')     AS senior_count,
    COUNT(*)                                      AS total_condition_encounters
FROM healthcare.admissions
GROUP BY medical_condition
ORDER BY total_condition_encounters DESC;

