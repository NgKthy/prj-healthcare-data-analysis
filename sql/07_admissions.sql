-- =============================================================================
-- Script: 07_admissions.sql
-- Domain 3: Admission Patterns & Operational Flow
-- Business Questions:
--   1. What is the breakdown of encounters by admission type (Elective, Emergency, Urgent)?
--   2. How do billing amounts and inpatient stays differ by clinical urgency?
--   3. What are the monthly and annual admission intake trends across the 5-year timeline?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 3.1: Admission Type Distribution & Operational Profile
-- Measures volume, share of encounters, aggregate billing, and average stay duration.
-- -----------------------------------------------------------------------------
SELECT 
    admission_type,
    COUNT(admission_record_id) AS encounter_count,
    ROUND(COUNT(admission_record_id)::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM healthcare.admissions), 0), 2) AS pct_of_total_encounters,
    ROUND(SUM(billing_amount), 2) AS total_billing_usd,
    ROUND(SUM(billing_amount)::NUMERIC * 100.0 / 
          NULLIF((SELECT SUM(billing_amount) FROM healthcare.admissions), 0), 2) AS pct_of_total_billing,
    ROUND(AVG(billing_amount), 2) AS avg_billing_usd,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY billing_amount::DOUBLE PRECISION)::NUMERIC, 2) AS median_billing_usd,
    ROUND(AVG(length_of_stay_days), 2) AS avg_los_days
FROM healthcare.admissions
GROUP BY admission_type
ORDER BY encounter_count DESC;

-- -----------------------------------------------------------------------------
-- QUERY 3.2: Annual Admission Trends & Intake Trajectory
-- Aggregates admissions, total billing, and average charge by calendar year.
-- Note: 2019 starts in May; 2024 concludes in May.
-- -----------------------------------------------------------------------------
SELECT 
    EXTRACT(YEAR FROM date_of_admission)::INTEGER AS admission_year,
    COUNT(admission_record_id)                    AS total_annual_admissions,
    ROUND(COUNT(admission_record_id)::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM healthcare.admissions), 0), 2) AS pct_five_year_total,
    ROUND(SUM(billing_amount), 2)                 AS total_annual_billing_usd,
    ROUND(AVG(billing_amount), 2)                 AS avg_billing_usd,
    ROUND(AVG(length_of_stay_days), 2)            AS avg_los_days
FROM healthcare.admissions
GROUP BY EXTRACT(YEAR FROM date_of_admission)
ORDER BY admission_year;

-- -----------------------------------------------------------------------------
-- QUERY 3.3: Monthly Admission Trends (Monthly Inpatient Intake)
-- Uses DATE_TRUNC to aggregate monthly admission velocity, monthly billing,
-- and the percentage of admissions categorized as Emergency.
-- -----------------------------------------------------------------------------
SELECT 
    DATE_TRUNC('month', date_of_admission)::DATE AS admission_month,
    COUNT(admission_record_id)                   AS monthly_admissions,
    ROUND(SUM(billing_amount), 2)                AS monthly_billing_usd,
    ROUND(AVG(billing_amount), 2)                AS avg_monthly_billing_usd,
    COUNT(*) FILTER (WHERE admission_type = 'Emergency') AS emergency_admissions,
    ROUND(COUNT(*) FILTER (WHERE admission_type = 'Emergency')::NUMERIC * 100.0 / 
          NULLIF(COUNT(*), 0), 2) AS emergency_ratio_pct
FROM healthcare.admissions
GROUP BY DATE_TRUNC('month', date_of_admission)
ORDER BY admission_month;

-- -----------------------------------------------------------------------------
-- QUERY 3.4: Cross-Tabulation: Admission Type by Medical Condition
-- Identifies whether specific conditions have a higher propensity for emergency intake.
-- -----------------------------------------------------------------------------
SELECT 
    medical_condition,
    COUNT(*) FILTER (WHERE admission_type = 'Elective')  AS elective_count,
    COUNT(*) FILTER (WHERE admission_type = 'Urgent')    AS urgent_count,
    COUNT(*) FILTER (WHERE admission_type = 'Emergency') AS emergency_count,
    COUNT(*) AS total_condition_encounters,
    ROUND(COUNT(*) FILTER (WHERE admission_type = 'Emergency')::NUMERIC * 100.0 / 
          NULLIF(COUNT(*), 0), 2) AS emergency_percentage
FROM healthcare.admissions
GROUP BY medical_condition
ORDER BY emergency_percentage DESC;

