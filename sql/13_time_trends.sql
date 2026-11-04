-- =============================================================================
-- Script: 13_time_trends.sql
-- Domain 9: Longitudinal Time Trends & Growth Velocity
-- Business Questions:
--   1. What is the Year-over-Year (YoY) trajectory of inpatient encounters and billing?
--   2. What is the Month-over-Month (MoM) volume momentum using window functions (LAG)?
--   3. Which specific calendar months experienced peak intake and financial velocity?
-- =============================================================================

SET search_path TO healthcare, public;

-- -----------------------------------------------------------------------------
-- QUERY 9.1: Year-over-Year (YoY) Volume and Billing Growth Analysis
-- Employs LAG() window function to compute YoY percentage change across years.
-- Normalizes partial years (2019: 8 months, 2024: 5 months) via monthly run-rate.
-- -----------------------------------------------------------------------------
WITH annual_data AS (
    SELECT 
        EXTRACT(YEAR FROM date_of_admission)::INTEGER AS calendar_year,
        COUNT(admission_record_id)                    AS annual_admissions,
        COUNT(DISTINCT DATE_TRUNC('month', date_of_admission)) AS active_months_observed,
        ROUND(COUNT(admission_record_id)::NUMERIC / 
              NULLIF(COUNT(DISTINCT DATE_TRUNC('month', date_of_admission)), 0), 1) AS monthly_run_rate_admissions,
        ROUND(SUM(billing_amount), 2)                 AS annual_billing_usd,
        ROUND(AVG(billing_amount), 2)                 AS avg_billing_usd,
        ROUND(AVG(length_of_stay_days), 2)            AS avg_los_days
    FROM healthcare.admissions
    GROUP BY EXTRACT(YEAR FROM date_of_admission)
)
SELECT 
    calendar_year,
    active_months_observed,
    annual_admissions,
    monthly_run_rate_admissions,
    LAG(monthly_run_rate_admissions, 1) OVER (ORDER BY calendar_year) AS prev_year_monthly_run_rate,
    ROUND(((monthly_run_rate_admissions - LAG(monthly_run_rate_admissions, 1) OVER (ORDER BY calendar_year)) * 100.0 / 
           NULLIF(LAG(monthly_run_rate_admissions, 1) OVER (ORDER BY calendar_year), 0)), 2) AS yoy_normalized_volume_growth_pct,
    annual_billing_usd,
    LAG(annual_billing_usd, 1) OVER (ORDER BY calendar_year) AS prev_year_billing_usd,
    ROUND(((annual_billing_usd - LAG(annual_billing_usd, 1) OVER (ORDER BY calendar_year)) * 100.0 / 
           NULLIF(LAG(annual_billing_usd, 1) OVER (ORDER BY calendar_year), 0)), 2) AS yoy_unadjusted_billing_growth_pct,
    avg_billing_usd,
    avg_los_days
FROM annual_data
ORDER BY calendar_year;

-- -----------------------------------------------------------------------------
-- QUERY 9.2: Month-over-Month (MoM) Admissions Velocity (Dense Calendar Grid)
-- Uses GENERATE_SERIES to construct an unbroken monthly timeline, preventing
-- LAG() from skipping inactive months in filtered subsets.
-- -----------------------------------------------------------------------------
WITH calendar_grid AS (
    SELECT DATE_TRUNC('month', series_date)::DATE AS calendar_month
    FROM GENERATE_SERIES(
        '2019-05-01'::DATE,
        '2024-05-01'::DATE,
        '1 month'::INTERVAL
    ) AS series_date
),
monthly_metrics AS (
    SELECT 
        DATE_TRUNC('month', date_of_admission)::DATE AS admission_month,
        COUNT(admission_record_id)                   AS monthly_admissions,
        ROUND(SUM(billing_amount), 2)                AS monthly_billing_usd
    FROM healthcare.admissions
    GROUP BY DATE_TRUNC('month', date_of_admission)
),
dense_monthly AS (
    SELECT 
        cg.calendar_month,
        COALESCE(mm.monthly_admissions, 0)   AS monthly_admissions,
        COALESCE(mm.monthly_billing_usd, 0.0) AS monthly_billing_usd
    FROM calendar_grid cg
    LEFT JOIN monthly_metrics mm ON cg.calendar_month = mm.admission_month
)
SELECT 
    calendar_month,
    monthly_admissions,
    LAG(monthly_admissions, 1) OVER (ORDER BY calendar_month) AS prev_month_admissions,
    ROUND(((monthly_admissions - LAG(monthly_admissions, 1) OVER (ORDER BY calendar_month))::NUMERIC * 100.0 / 
           NULLIF(LAG(monthly_admissions, 1) OVER (ORDER BY calendar_month), 0)), 2) AS mom_admission_change_pct,
    monthly_billing_usd,
    LAG(monthly_billing_usd, 1) OVER (ORDER BY calendar_month) AS prev_month_billing_usd,
    ROUND(((monthly_billing_usd - LAG(monthly_billing_usd, 1) OVER (ORDER BY calendar_month)) * 100.0 / 
           NULLIF(LAG(monthly_billing_usd, 1) OVER (ORDER BY calendar_month), 0)), 2) AS mom_billing_change_pct
FROM dense_monthly
ORDER BY calendar_month;

-- -----------------------------------------------------------------------------
-- QUERY 9.3: Peak and Trough Admission Months (Ranked Monthly Velocity)
-- Highlights the 5 highest and 5 lowest volume admission months on record.
-- -----------------------------------------------------------------------------
WITH monthly_ranked AS (
    SELECT 
        DATE_TRUNC('month', date_of_admission)::DATE AS admission_month,
        COUNT(admission_record_id)                   AS monthly_admissions,
        ROUND(SUM(billing_amount), 2)                AS monthly_billing_usd,
        ROW_NUMBER() OVER (ORDER BY COUNT(admission_record_id) DESC) AS rank_highest,
        ROW_NUMBER() OVER (ORDER BY COUNT(admission_record_id) ASC)  AS rank_lowest
    FROM healthcare.admissions
    GROUP BY DATE_TRUNC('month', date_of_admission)
)
SELECT 
    admission_month,
    monthly_admissions,
    monthly_billing_usd,
    CASE 
        WHEN rank_highest <= 5 THEN 'Top 5 Peak Month'
        WHEN rank_lowest <= 5 THEN 'Bottom 5 Trough Month'
    END AS volume_status
FROM monthly_ranked
WHERE rank_highest <= 5 OR rank_lowest <= 5
ORDER BY monthly_admissions DESC;

