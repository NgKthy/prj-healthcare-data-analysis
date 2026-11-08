-- =============================================================================
-- Test Suite: data_quality_tests.sql
-- Description: Automated assertion tests for staging data quality.
-- Target: Returns 0 rows if all tests PASS. Any returned row indicates a test failure.
-- =============================================================================

SET search_path TO healthcare, public;

-- Violation Test 1: Check for NULL or Empty Mandatory Attributes in Staging
SELECT 'TEST_FAIL: NULL or Empty Values in Staging' AS failure_reason,
       COUNT(*) AS violation_count
FROM healthcare.staging_admissions
WHERE raw_name IS NULL OR TRIM(raw_name) = ''
   OR raw_age IS NULL OR TRIM(raw_age) = ''
   OR raw_gender IS NULL OR TRIM(raw_gender) = ''
   OR raw_medical_condition IS NULL OR TRIM(raw_medical_condition) = ''
   OR raw_date_of_admission IS NULL OR TRIM(raw_date_of_admission) = ''
   OR raw_billing_amount IS NULL OR TRIM(raw_billing_amount) = ''
HAVING COUNT(*) > 0;

-- Violation Test 2: Check for Unparseable Integer Ages
SELECT 'TEST_FAIL: Unparseable Age in Staging' AS failure_reason,
       COUNT(*) AS violation_count
FROM healthcare.staging_admissions
WHERE raw_age !~ '^[0-9]+$'
HAVING COUNT(*) > 0;

-- Violation Test 3: Check for Chronological Inversion in Staging Dates
SELECT 'TEST_FAIL: Discharge Precedes Admission' AS failure_reason,
       COUNT(*) AS violation_count
FROM healthcare.staging_admissions
WHERE raw_discharge_date::DATE < raw_date_of_admission::DATE
HAVING COUNT(*) > 0;

-- Violation Test 4: Check for Unexpected Gender Categories in Staging
SELECT 'TEST_FAIL: Invalid Gender Categorical Domain' AS failure_reason,
       COUNT(*) AS violation_count
FROM healthcare.staging_admissions
WHERE TRIM(raw_gender) NOT IN ('Male', 'Female')
HAVING COUNT(*) > 0;

-- Violation Test 5: Check for Unexpected Medical Conditions in Staging
SELECT 'TEST_FAIL: Invalid Medical Condition Domain' AS failure_reason,
       COUNT(*) AS violation_count
FROM healthcare.staging_admissions
WHERE TRIM(raw_medical_condition) NOT IN (
    'Arthritis', 'Asthma', 'Cancer', 'Diabetes', 'Hypertension', 'Obesity'
)
HAVING COUNT(*) > 0;

