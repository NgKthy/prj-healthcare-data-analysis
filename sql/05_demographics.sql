-- =============================================================================
-- Script: 05_demographics.sql
-- Domain 1: Patient Demographics & Cohort Profile
-- Business Questions:
--   1. What is the overall distribution of patients by age, gender, and blood type?
--   2. How do patient volumes and billing averages vary across age groups?
--   3. Are there gender-based disparities in admissions, costs, or inpatient stays?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 1.1: Overall Patient Demographic Baseline
-- Calculates aggregate volume, age statistics, and unique patient names.
-- -----------------------------------------------------------------------------
SELECT 
    COUNT(admission_record_id)               AS total_encounters,
    COUNT(DISTINCT patient_name)             AS distinct_patient_names,
    MIN(age)                                 AS youngest_patient_age,
    MAX(age)                                 AS oldest_patient_age,
    ROUND(AVG(age), 2)                       AS mean_patient_age,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY age::DOUBLE PRECISION)::NUMERIC AS median_patient_age
FROM healthcare.admissions;

-- -----------------------------------------------------------------------------
-- QUERY 1.2: Age Group Distribution & Inpatient Economics
-- Categorizes patients into clinical age brackets and evaluates encounter
-- volume, billing charges, and length of stay.
-- -----------------------------------------------------------------------------
SELECT 
    age_group,
    COUNT(admission_record_id) AS admission_count,
    ROUND(COUNT(admission_record_id)::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM healthcare.admissions), 0), 2) AS pct_of_total_admissions,
    ROUND(AVG(billing_amount), 2) AS avg_billing_usd,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC, 2) AS median_billing_usd,
    ROUND(AVG(length_of_stay_days), 2) AS avg_los_days
FROM healthcare.admissions
GROUP BY age_group
ORDER BY 
    CASE age_group
        WHEN '< 18'    THEN 1
        WHEN '18 - 35' THEN 2
        WHEN '36 - 50' THEN 3
        WHEN '51 - 65' THEN 4
        WHEN '65+'     THEN 5
    END;

-- -----------------------------------------------------------------------------
-- QUERY 1.3: Gender Breakdown & Billing Comparison
-- Compares encounter volume, average age, and gross charges between biological sexes.
-- -----------------------------------------------------------------------------
SELECT 
    gender,
    COUNT(admission_record_id) AS encounter_count,
    ROUND(COUNT(admission_record_id)::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM healthcare.admissions), 0), 2) AS pct_gender_share,
    ROUND(AVG(age), 2) AS avg_patient_age,
    ROUND(SUM(billing_amount), 2) AS total_billing_usd,
    ROUND(AVG(billing_amount), 2) AS avg_billing_usd,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC, 2) AS median_billing_usd,
    ROUND(AVG(length_of_stay_days), 2) AS avg_los_days
FROM healthcare.admissions
GROUP BY gender
ORDER BY encounter_count DESC;

-- -----------------------------------------------------------------------------
-- QUERY 1.4: Blood Type Distribution Across Patient Cohort
-- Measures frequency and population percentage of ABO / Rh serotypes.
-- -----------------------------------------------------------------------------
SELECT 
    blood_type,
    COUNT(admission_record_id) AS encounter_count,
    ROUND(COUNT(admission_record_id)::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM healthcare.admissions), 0), 2) AS pct_share,
    ROUND(AVG(billing_amount), 2) AS avg_billing_usd
FROM healthcare.admissions
GROUP BY blood_type
ORDER BY encounter_count DESC, blood_type;

-- -----------------------------------------------------------------------------
-- QUERY 1.5: Demographic Cross-Tabulation (Age Group x Gender Matrix)
-- Provides multi-dimensional visibility into demographic composition.
-- -----------------------------------------------------------------------------
SELECT 
    age_group,
    COUNT(*) FILTER (WHERE gender = 'Female') AS female_encounters,
    COUNT(*) FILTER (WHERE gender = 'Male')   AS male_encounters,
    ROUND(COUNT(*) FILTER (WHERE gender = 'Female')::NUMERIC * 100.0 / 
          NULLIF(COUNT(*), 0), 2) AS female_ratio_pct,
    COUNT(*) AS total_bracket_encounters,
    ROUND(AVG(billing_amount), 2) AS bracket_avg_billing_usd
FROM healthcare.admissions
GROUP BY age_group
ORDER BY 
    CASE age_group
        WHEN '< 18'    THEN 1
        WHEN '18 - 35' THEN 2
        WHEN '36 - 50' THEN 3
        WHEN '51 - 65' THEN 4
        WHEN '65+'     THEN 5
    END;

