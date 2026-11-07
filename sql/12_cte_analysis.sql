-- =============================================================================
-- Script: 12_cte_analysis.sql
-- Domain 8: Advanced SQL — Modular Common Table Expressions (CTEs)
-- Business Questions:
--   1. How do individual condition billing benchmarks compare against enterprise averages?
--   2. Which age cohorts generate above-average billing intensity across admission types?
--   3. What is the comprehensive demographic-clinical-payer cohort scorecard?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 8.1: Condition Financial Benchmark vs. Enterprise Baseline (Multi-Step CTE)
-- Computes the overall enterprise billing baseline in CTE 1, evaluates condition
-- metrics in CTE 2, and calculates variance deltas against enterprise averages.
-- -----------------------------------------------------------------------------
WITH enterprise_baseline AS (
    SELECT 
        COUNT(*)                             AS grand_total_encounters,
        ROUND(AVG(billing_amount), 2)        AS enterprise_avg_billing,
        ROUND(AVG(length_of_stay_days), 2)   AS enterprise_avg_los
    FROM healthcare.admissions
    WHERE is_negative_billing = FALSE
),
condition_performance AS (
    SELECT 
        medical_condition,
        COUNT(admission_record_id)           AS condition_encounters,
        ROUND(SUM(billing_amount), 2)        AS condition_total_billing,
        ROUND(AVG(billing_amount), 2)        AS condition_avg_billing,
        ROUND(AVG(length_of_stay_days), 2)   AS condition_avg_los
    FROM healthcare.admissions
    WHERE is_negative_billing = FALSE
    GROUP BY medical_condition
)
SELECT 
    cp.medical_condition,
    cp.condition_encounters,
    cp.condition_total_billing,
    cp.condition_avg_billing,
    eb.enterprise_avg_billing,
    ROUND(cp.condition_avg_billing - eb.enterprise_avg_billing, 2) AS billing_diff_from_enterprise,
    ROUND(((cp.condition_avg_billing - eb.enterprise_avg_billing) * 100.0 / 
           NULLIF(eb.enterprise_avg_billing, 0)), 2) AS billing_variance_pct,
    cp.condition_avg_los,
    eb.enterprise_avg_los,
    ROUND(cp.condition_avg_los - eb.enterprise_avg_los, 2) AS los_diff_from_enterprise
FROM condition_performance cp
CROSS JOIN enterprise_baseline eb
ORDER BY cp.condition_avg_billing DESC;

-- -----------------------------------------------------------------------------
-- QUERY 8.2: Cohort Severity Matrix via Chained CTEs
-- Analyzes interaction between Age Group and Admission Urgency.
-- -----------------------------------------------------------------------------
WITH cohort_aggregates AS (
    SELECT 
        age_group,
        admission_type,
        COUNT(admission_record_id)    AS encounter_count,
        ROUND(SUM(billing_amount), 2) AS total_billing_usd,
        ROUND(AVG(billing_amount), 2) AS avg_billing_usd,
        ROUND(AVG(length_of_stay_days), 2) AS avg_los_days
    FROM healthcare.admissions
    GROUP BY age_group, admission_type
),
bracket_totals AS (
    SELECT 
        age_group,
        SUM(encounter_count)   AS bracket_total_encounters,
        SUM(total_billing_usd) AS bracket_total_billing
    FROM cohort_aggregates
    GROUP BY age_group
)
SELECT 
    ca.age_group,
    ca.admission_type,
    ca.encounter_count,
    ROUND(ca.encounter_count::NUMERIC * 100.0 / NULLIF(bt.bracket_total_encounters, 0), 2) AS pct_of_age_bracket_volume,
    ca.avg_billing_usd,
    ca.avg_los_days
FROM cohort_aggregates ca
JOIN bracket_totals bt ON ca.age_group = bt.age_group
ORDER BY 
    CASE ca.age_group
        WHEN '< 18'    THEN 1
        WHEN '18 - 35' THEN 2
        WHEN '36 - 50' THEN 3
        WHEN '51 - 65' THEN 4
        WHEN '65+'     THEN 5
    END,
    ca.encounter_count DESC;

