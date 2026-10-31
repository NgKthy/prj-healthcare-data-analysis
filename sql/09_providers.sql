-- =============================================================================
-- Script: 09_providers.sql
-- Domain 5: Hospital & Physician Operational Analysis
-- Business Questions:
--   1. What is the distribution of encounter volume and gross billing across hospitals?
--   2. Which facilities handle the highest patient volumes and average stays?
--   3. Who are the top 3 admitting physicians by volume within active facilities?
-- Caveat: Results reflect synthetic operational workload and should NEVER be
--         used to infer clinical quality, doctor skill, or therapeutic efficacy.
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 5.1: Hospital Facility Volume & Financial Concentration
-- Calculates operational metrics for hospitals with the highest encounter intake.
-- Note: Dataset contains 39,876 distinct hospital names; a volume threshold
--       is applied to isolate active facilities.
-- -----------------------------------------------------------------------------
SELECT 
    hospital_name,
    COUNT(admission_record_id)           AS total_admissions,
    ROUND(SUM(billing_amount), 2)        AS total_facility_billing_usd,
    ROUND(AVG(billing_amount), 2)        AS avg_billing_per_stay_usd,
    ROUND(AVG(length_of_stay_days), 2)   AS avg_los_days,
    COUNT(DISTINCT doctor_name)          AS distinct_physicians_active,
    DENSE_RANK() OVER (ORDER BY COUNT(admission_record_id) DESC) AS volume_rank
FROM healthcare.admissions
GROUP BY hospital_name
HAVING COUNT(admission_record_id) >= 5
ORDER BY total_admissions DESC, total_facility_billing_usd DESC
LIMIT 15;

-- -----------------------------------------------------------------------------
-- QUERY 5.2: Top 3 Physicians by Inpatient Volume within Leading Facilities
-- Uses DENSE_RANK() / ROW_NUMBER() window functions partitioned by facility
-- to identify primary admitting doctors per hospital.
-- -----------------------------------------------------------------------------
WITH top_hospitals AS (
    SELECT hospital_name
    FROM healthcare.admissions
    GROUP BY hospital_name
    HAVING COUNT(admission_record_id) >= 5
    ORDER BY COUNT(admission_record_id) DESC
    LIMIT 5
),
physician_workload AS (
    SELECT 
        a.hospital_name,
        a.doctor_name,
        COUNT(a.admission_record_id)    AS encounters_handled,
        ROUND(SUM(a.billing_amount), 2) AS doctor_total_billing_usd,
        ROUND(AVG(a.billing_amount), 2) AS doctor_avg_billing_usd,
        ROUND(AVG(a.length_of_stay_days), 2) AS doctor_avg_los_days,
        ROW_NUMBER() OVER (
            PARTITION BY a.hospital_name 
            ORDER BY COUNT(a.admission_record_id) DESC, SUM(a.billing_amount) DESC
        ) AS physician_rank_in_facility
    FROM healthcare.admissions a
    INNER JOIN top_hospitals th ON a.hospital_name = th.hospital_name
    GROUP BY a.hospital_name, a.doctor_name
)
SELECT 
    hospital_name,
    physician_rank_in_facility,
    doctor_name,
    encounters_handled,
    doctor_total_billing_usd,
    doctor_avg_billing_usd,
    doctor_avg_los_days
FROM physician_workload
WHERE physician_rank_in_facility <= 3
ORDER BY hospital_name, physician_rank_in_facility;

-- -----------------------------------------------------------------------------
-- QUERY 5.3: Overall Physician Inpatient Workload Distribution
-- Evaluates physician caseload across the entire enterprise.
-- -----------------------------------------------------------------------------
WITH doctor_summary AS (
    SELECT 
        doctor_name,
        COUNT(admission_record_id)    AS total_patients_treated,
        ROUND(SUM(billing_amount), 2) AS total_billed_charges_usd,
        ROUND(AVG(length_of_stay_days), 2) AS avg_patient_los
    FROM healthcare.admissions
    GROUP BY doctor_name
)
SELECT 
    total_patients_treated AS caseload_size_encounters,
    COUNT(doctor_name)     AS number_of_doctors_at_this_caseload,
    ROUND(COUNT(doctor_name)::NUMERIC * 100.0 / 
          NULLIF((SELECT COUNT(DISTINCT doctor_name) FROM healthcare.admissions), 0), 2) AS pct_of_doctor_workforce
FROM doctor_summary
GROUP BY total_patients_treated
ORDER BY total_patients_treated DESC;

