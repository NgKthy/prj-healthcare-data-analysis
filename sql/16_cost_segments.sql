-- =============================================================================
-- Script: 16_cost_segments.sql
-- Domain 12: Patient Billing Quartile Segmentation (NTILE)
-- Business Questions:
--   1. How is inpatient volume and financial burden segmented across cost quartiles (NTILE 4)?
--   2. What are the minimum, maximum, and average billing boundaries for each quartile?
--   3. Does clinical condition or admission type composition skew into higher quartiles?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 12.1: Inpatient Cost Quartile Profiling via NTILE(4)
-- Splits all admissions into 4 equal volume tiers based on billed charges.
-- -----------------------------------------------------------------------------
WITH cost_quartiles AS (
    SELECT 
        admission_record_id,
        patient_name,
        medical_condition,
        admission_type,
        insurance_provider,
        length_of_stay_days,
        billing_amount,
        NTILE(4) OVER (ORDER BY billing_amount ASC) AS billing_quartile
    FROM healthcare.admissions
)
SELECT 
    CASE billing_quartile
        WHEN 1 THEN 'Quartile 1 (Lowest Charges)'
        WHEN 2 THEN 'Quartile 2 (Mid-Low Charges)'
        WHEN 3 THEN 'Quartile 3 (Mid-High Charges)'
        WHEN 4 THEN 'Quartile 4 (Highest Charges)'
    END AS quartile_label,
    COUNT(admission_record_id)           AS encounter_count,
    ROUND(MIN(billing_amount), 2)        AS min_tier_billing_usd,
    ROUND(MAX(billing_amount), 2)        AS max_tier_billing_usd,
    ROUND(AVG(billing_amount), 2)        AS avg_tier_billing_usd,
    ROUND(SUM(billing_amount), 2)        AS total_tier_billing_usd,
    ROUND(SUM(billing_amount)::NUMERIC * 100.0 / 
          NULLIF((SELECT SUM(billing_amount) FROM healthcare.admissions), 0), 2) AS pct_of_total_billing,
    ROUND(AVG(length_of_stay_days), 2)   AS avg_los_days
FROM cost_quartiles
GROUP BY billing_quartile
ORDER BY billing_quartile;

-- -----------------------------------------------------------------------------
-- QUERY 12.2: Clinical Condition Distribution Across Billing Quartiles
-- Evaluates whether any medical condition is disproportionately represented
-- in the top quartile (Q4) versus bottom quartile (Q1).
-- -----------------------------------------------------------------------------
WITH segmented_admissions AS (
    SELECT 
        medical_condition,
        NTILE(4) OVER (ORDER BY billing_amount ASC) AS billing_quartile
    FROM healthcare.admissions
)
SELECT 
    medical_condition,
    COUNT(*) FILTER (WHERE billing_quartile = 1) AS q1_lowest_encounters,
    COUNT(*) FILTER (WHERE billing_quartile = 2) AS q2_midlow_encounters,
    COUNT(*) FILTER (WHERE billing_quartile = 3) AS q3_midhigh_encounters,
    COUNT(*) FILTER (WHERE billing_quartile = 4) AS q4_highest_encounters,
    COUNT(*) AS total_encounters,
    ROUND(COUNT(*) FILTER (WHERE billing_quartile = 4)::NUMERIC * 100.0 / 
          NULLIF(COUNT(*), 0), 2) AS pct_in_highest_quartile
FROM segmented_admissions
GROUP BY medical_condition
ORDER BY pct_in_highest_quartile DESC;

