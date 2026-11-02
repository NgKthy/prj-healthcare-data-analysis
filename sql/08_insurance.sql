-- =============================================================================
-- Script: 08_insurance.sql
-- Domain 4: Insurance & Payer Portfolio Analysis
-- Business Questions:
--   1. What is the market share and total billed charges for each insurance carrier?
--   2. Which insurance provider exhibits the highest average and median billing?
--   3. What are the leading medical conditions covered within each insurance pool?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 4.1: Insurance Payer Market Share & Financial Distribution
-- Compares encounter volume, total gross billing, average charges, median charges,
-- and average length of stay across all five insurance providers.
-- -----------------------------------------------------------------------------
WITH payer_summary AS (
    SELECT 
        insurance_provider,
        COUNT(admission_record_id)           AS encounter_count,
        SUM(billing_amount)                  AS total_billing_usd,
        AVG(billing_amount)                  AS avg_billing_usd,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC AS median_billing_usd,
        AVG(length_of_stay_days)             AS avg_los_days
    FROM healthcare.admissions
    GROUP BY insurance_provider
),
grand_totals AS (
    SELECT 
        SUM(encounter_count)   AS total_all_encounters,
        SUM(total_billing_usd) AS total_all_billing_usd
    FROM payer_summary
)
SELECT 
    ps.insurance_provider,
    ps.encounter_count,
    ROUND(ps.encounter_count::NUMERIC * 100.0 / NULLIF(gt.total_all_encounters, 0), 2) AS market_share_pct,
    ROUND(ps.total_billing_usd, 2) AS total_billing_usd,
    ROUND(ps.total_billing_usd::NUMERIC * 100.0 / NULLIF(gt.total_all_billing_usd, 0), 2) AS pct_of_total_billing,
    ROUND(ps.avg_billing_usd, 2) AS avg_billing_usd,
    ROUND(ps.median_billing_usd::NUMERIC, 2) AS median_billing_usd,
    ROUND(ps.avg_los_days, 2) AS avg_los_days
FROM payer_summary ps
CROSS JOIN grand_totals gt
ORDER BY ps.total_billing_usd DESC;

-- -----------------------------------------------------------------------------
-- QUERY 4.2: Payer Encounter Charges (Excluding Negative Adjustments)
-- Analyzes standard encounter charges for commercial and government carriers.
-- -----------------------------------------------------------------------------
SELECT 
    insurance_provider,
    COUNT(*) AS encounter_count,
    ROUND(AVG(billing_amount), 2) AS avg_positive_billing_usd,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC, 2) AS median_positive_billing_usd,
    ROUND(MIN(billing_amount), 2) AS min_charge,
    ROUND(MAX(billing_amount), 2) AS max_charge
FROM healthcare.admissions
WHERE is_negative_billing = FALSE
GROUP BY insurance_provider
ORDER BY avg_positive_billing_usd DESC;

-- -----------------------------------------------------------------------------
-- QUERY 4.3: Top Clinical Condition within Each Insurance Carrier
-- Employs ROW_NUMBER() OVER (PARTITION BY insurance_provider) to identify
-- the single most prevalent admitting diagnosis for each payer.
-- -----------------------------------------------------------------------------
WITH condition_by_payer AS (
    SELECT 
        insurance_provider,
        medical_condition,
        COUNT(admission_record_id) AS condition_encounters,
        ROUND(SUM(billing_amount), 2) AS condition_billing_usd,
        ROUND(AVG(billing_amount), 2) AS condition_avg_billing_usd,
        ROW_NUMBER() OVER (
            PARTITION BY insurance_provider 
            ORDER BY COUNT(admission_record_id) DESC, SUM(billing_amount) DESC
        ) AS rank_within_payer
    FROM healthcare.admissions
    GROUP BY insurance_provider, medical_condition
)
SELECT 
    insurance_provider,
    medical_condition AS dominant_condition,
    condition_encounters,
    condition_billing_usd,
    condition_avg_billing_usd
FROM condition_by_payer
WHERE rank_within_payer = 1
ORDER BY condition_billing_usd DESC;

