-- =============================================================================
-- Script: 18_hospital_comparison.sql
-- Domain 14: Multi-Dimensional Hospital Facility Comparison Scorecard
-- Business Questions:
--   1. How do leading hospital facilities compare across patient volume, billing, and LOS?
--   2. What is the Emergency encounter intake ratio across active medical centers?
--   3. What are the dominant medical condition specialties treated per hospital?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 14.1: Comprehensive Hospital Facility Comparative Scorecard
-- Evaluates throughput, total gross billing, average charge, median charge,
-- average length of stay, and emergency admission proportion for active facilities.
-- -----------------------------------------------------------------------------
WITH facility_aggregates AS (
    SELECT 
        hospital_name,
        COUNT(admission_record_id)           AS total_admissions,
        ROUND(SUM(billing_amount), 2)        AS total_billing_usd,
        ROUND(AVG(billing_amount), 2)        AS avg_billing_usd,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC, 2) AS median_billing_usd,
        ROUND(AVG(length_of_stay_days), 2)   AS avg_los_days,
        COUNT(*) FILTER (WHERE admission_type = 'Emergency') AS emergency_cases,
        ROUND(COUNT(*) FILTER (WHERE admission_type = 'Emergency')::NUMERIC * 100.0 / 
              NULLIF(COUNT(*), 0), 2) AS emergency_ratio_pct
    FROM healthcare.admissions
    GROUP BY hospital_name
    HAVING COUNT(admission_record_id) >= 5
)
SELECT 
    hospital_name,
    total_admissions,
    total_billing_usd,
    avg_billing_usd,
    median_billing_usd,
    avg_los_days,
    emergency_cases,
    emergency_ratio_pct,
    DENSE_RANK() OVER (ORDER BY total_admissions DESC, total_billing_usd DESC) AS composite_volume_rank
FROM facility_aggregates
ORDER BY total_admissions DESC, total_billing_usd DESC
LIMIT 15;

-- -----------------------------------------------------------------------------
-- QUERY 14.2: Facility Clinical Case Mix Analysis (Specialty Concentration)
-- Analyzes condition breakdown across leading hospitals.
-- -----------------------------------------------------------------------------
WITH top_facilities AS (
    SELECT hospital_name
    FROM healthcare.admissions
    GROUP BY hospital_name
    HAVING COUNT(admission_record_id) >= 5
    ORDER BY COUNT(admission_record_id) DESC
    LIMIT 10
)
SELECT 
    a.hospital_name,
    COUNT(*) FILTER (WHERE a.medical_condition = 'Arthritis')    AS arthritis_cases,
    COUNT(*) FILTER (WHERE a.medical_condition = 'Asthma')       AS asthma_cases,
    COUNT(*) FILTER (WHERE a.medical_condition = 'Cancer')       AS cancer_cases,
    COUNT(*) FILTER (WHERE a.medical_condition = 'Diabetes')     AS diabetes_cases,
    COUNT(*) FILTER (WHERE a.medical_condition = 'Hypertension') AS hypertension_cases,
    COUNT(*) FILTER (WHERE a.medical_condition = 'Obesity')      AS obesity_cases,
    COUNT(*)                                                     AS total_cases
FROM healthcare.admissions a
INNER JOIN top_facilities tf ON a.hospital_name = tf.hospital_name
GROUP BY a.hospital_name
ORDER BY total_cases DESC;

