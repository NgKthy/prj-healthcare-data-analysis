-- =============================================================================
-- Script: 15_ranking.sql
-- Domain 11: Advanced Ranking Frameworks (RANK, DENSE_RANK, ROW_NUMBER)
-- Business Questions:
--   1. What are the practical differences between ROW_NUMBER, RANK, and DENSE_RANK?
--   2. Which hospitals rank highest across volume, revenue, and length of stay?
--   3. What are the top 5 most expensive inpatient encounters within each condition?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 11.1: Technical Demonstration of Ranking Mechanics on Hospital Volume
-- Demonstrates how ROW_NUMBER (arbitrary tie-break), RANK (gaps on ties),
-- and DENSE_RANK (no gaps on ties) behave on shared encounter volumes.
-- -----------------------------------------------------------------------------
WITH facility_volume AS (
    SELECT 
        hospital_name,
        COUNT(admission_record_id)    AS encounter_count,
        ROUND(SUM(billing_amount), 2) AS total_billing_usd
    FROM healthcare.admissions
    GROUP BY hospital_name
    HAVING COUNT(admission_record_id) >= 5
)
SELECT 
    hospital_name,
    encounter_count,
    total_billing_usd,
    ROW_NUMBER() OVER (ORDER BY encounter_count DESC, total_billing_usd DESC) AS row_num,
    RANK()       OVER (ORDER BY encounter_count DESC)                          AS standard_rank,
    DENSE_RANK() OVER (ORDER BY encounter_count DESC)                          AS dense_rank
FROM facility_volume
ORDER BY encounter_count DESC, total_billing_usd DESC
LIMIT 20;

-- -----------------------------------------------------------------------------
-- QUERY 11.2: Multi-Dimensional Hospital Ranking Scorecard
-- Ranks facilities simultaneously across Volume Rank, Billing Rank, and Stay Rank.
-- -----------------------------------------------------------------------------
WITH facility_stats AS (
    SELECT 
        hospital_name,
        COUNT(admission_record_id)           AS total_admissions,
        ROUND(SUM(billing_amount), 2)        AS total_billing_usd,
        ROUND(AVG(billing_amount), 2)        AS avg_billing_usd,
        ROUND(AVG(length_of_stay_days), 2)   AS avg_los_days
    FROM healthcare.admissions
    GROUP BY hospital_name
    HAVING COUNT(admission_record_id) >= 5
)
SELECT 
    hospital_name,
    total_admissions,
    DENSE_RANK() OVER (ORDER BY total_admissions DESC) AS rank_by_volume,
    total_billing_usd,
    DENSE_RANK() OVER (ORDER BY total_billing_usd DESC) AS rank_by_total_billing,
    avg_billing_usd,
    DENSE_RANK() OVER (ORDER BY avg_billing_usd DESC) AS rank_by_avg_cost,
    avg_los_days,
    DENSE_RANK() OVER (ORDER BY avg_los_days ASC) AS rank_by_los_efficiency
FROM facility_stats
ORDER BY rank_by_volume ASC
LIMIT 15;

-- -----------------------------------------------------------------------------
-- QUERY 11.3: Top 5 Highest-Billed Encounters per Medical Condition
-- Uses ROW_NUMBER() PARTITION BY medical_condition to extract outlier cases per condition.
-- -----------------------------------------------------------------------------
WITH ranked_cases AS (
    SELECT 
        admission_record_id,
        patient_name,
        medical_condition,
        admission_type,
        insurance_provider,
        length_of_stay_days,
        billing_amount,
        ROW_NUMBER() OVER (
            PARTITION BY medical_condition 
            ORDER BY billing_amount DESC
        ) AS cost_rank_within_condition
    FROM healthcare.admissions
    WHERE is_negative_billing = FALSE
)
SELECT 
    medical_condition,
    cost_rank_within_condition,
    admission_record_id,
    patient_name,
    admission_type,
    insurance_provider,
    length_of_stay_days,
    billing_amount
FROM ranked_cases
WHERE cost_rank_within_condition <= 5
ORDER BY medical_condition, cost_rank_within_condition;

