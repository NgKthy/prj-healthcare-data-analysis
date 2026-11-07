-- =============================================================================
-- Script: 17_high_cost.sql
-- Domain 13: High-Cost Encounters & 95th Percentile (P95) Concentration
-- Business Questions:
--   1. What is the 95th percentile (P95) billing threshold across all encounters?
--   2. What proportion of aggregate financial billing is absorbed by the top 5% cases?
--   3. What are the demographic, clinical, and payer characteristics of high-cost cases?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 13.1: 95th Percentile Threshold & Financial Concentration Analysis
-- Computes exact P95 cutoff and measures financial concentration absorbed by top 5%.
-- -----------------------------------------------------------------------------
WITH thresholds AS (
    SELECT 
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC AS p90_threshold,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC AS p95_threshold,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC AS p99_threshold,
        AVG(billing_amount)                                          AS overall_mean_billing,
        SUM(billing_amount)                                          AS grand_total_billing
    FROM healthcare.admissions
    WHERE is_negative_billing = FALSE
),
cohort_split AS (
    SELECT 
        CASE 
            WHEN a.billing_amount >= t.p95_threshold THEN 'Top 5% High-Cost Encounters (>= P95)'
            ELSE 'Standard Encounters (< P95)'
        END AS cost_tier,
        COUNT(a.admission_record_id)    AS encounter_count,
        ROUND(SUM(a.billing_amount), 2) AS tier_total_billing_usd,
        ROUND(AVG(a.billing_amount), 2) AS tier_avg_billing_usd,
        ROUND(AVG(a.length_of_stay_days), 2) AS tier_avg_los_days,
        t.p95_threshold
    FROM healthcare.admissions a
    CROSS JOIN thresholds t
    WHERE a.is_negative_billing = FALSE
    GROUP BY 1, t.p95_threshold
)
SELECT 
    cost_tier,
    encounter_count,
    ROUND(encounter_count::NUMERIC * 100.0 / 
          NULLIF((SELECT SUM(encounter_count) FROM cohort_split), 0), 2) AS pct_of_encounters,
    tier_total_billing_usd,
    ROUND(tier_total_billing_usd::NUMERIC * 100.0 / 
          NULLIF((SELECT SUM(tier_total_billing_usd) FROM cohort_split), 0), 2) AS pct_of_total_billing,
    tier_avg_billing_usd,
    tier_avg_los_days,
    ROUND(p95_threshold::NUMERIC, 2) AS p95_cutoff_usd
FROM cohort_split
ORDER BY tier_avg_billing_usd DESC;

-- -----------------------------------------------------------------------------
-- QUERY 13.2: Medical Condition Composition in Top 5% High-Cost Cases
-- Assesses which diagnoses are most prevalent among $P_{95}$ outlier admissions.
-- -----------------------------------------------------------------------------
WITH p95_ref AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC AS cutoff
    FROM healthcare.admissions
    WHERE is_negative_billing = FALSE
)
SELECT 
    a.medical_condition,
    COUNT(a.admission_record_id) AS high_cost_encounters,
    ROUND(COUNT(a.admission_record_id)::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM healthcare.admissions WHERE billing_amount >= (SELECT cutoff FROM p95_ref)), 0), 2) AS pct_of_all_p95_cases,
    ROUND(SUM(a.billing_amount), 2) AS total_high_cost_billing_usd,
    ROUND(AVG(a.billing_amount), 2) AS avg_high_cost_billing_usd,
    ROUND(AVG(a.length_of_stay_days), 2) AS avg_high_cost_los_days
FROM healthcare.admissions a
CROSS JOIN p95_ref r
WHERE a.billing_amount >= r.cutoff
GROUP BY a.medical_condition
ORDER BY high_cost_encounters DESC;

-- -----------------------------------------------------------------------------
-- QUERY 13.3: Insurance Payer Exposure to Top 5% High-Cost Encounters
-- Measures carrier distribution across P95 claims.
-- -----------------------------------------------------------------------------
WITH p95_ref AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC AS cutoff
    FROM healthcare.admissions
    WHERE is_negative_billing = FALSE
)
SELECT 
    a.insurance_provider,
    COUNT(a.admission_record_id) AS p95_encounter_count,
    ROUND(SUM(a.billing_amount), 2) AS p95_total_billed_usd,
    ROUND(AVG(a.billing_amount), 2) AS p95_avg_billed_usd,
    ROUND(COUNT(a.admission_record_id)::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM healthcare.admissions WHERE insurance_provider = a.insurance_provider), 0), 2) AS pct_of_carrier_total_claims
FROM healthcare.admissions a
CROSS JOIN p95_ref r
WHERE a.billing_amount >= r.cutoff
GROUP BY a.insurance_provider
ORDER BY p95_total_billed_usd DESC;

