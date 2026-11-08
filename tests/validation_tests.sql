-- =============================================================================
-- Test Suite: validation_tests.sql
-- Description: Automated assertion tests for production analytical table integrity.
-- Target: Returns 0 rows if all tests PASS. Any returned row indicates a test failure.
-- =============================================================================

SET search_path TO healthcare, public;

-- Violation Test 1: Check for Duplicate Primary Keys in Admissions
SELECT 'TEST_FAIL: Duplicate Surrogate Key Detected' AS failure_reason,
       admission_record_id,
       COUNT(*) AS occurrences
FROM healthcare.admissions
GROUP BY admission_record_id
HAVING COUNT(*) > 1;

-- Violation Test 2: Check for Negative Length of Stay
SELECT 'TEST_FAIL: Negative Length of Stay' AS failure_reason,
       COUNT(*) AS violation_count
FROM healthcare.admissions
WHERE length_of_stay_days < 0
HAVING COUNT(*) > 0;

-- Violation Test 3: Check for Unflagged Negative Billing Amounts
SELECT 'TEST_FAIL: Unflagged Negative Billing' AS failure_reason,
       COUNT(*) AS violation_count
FROM healthcare.admissions
WHERE billing_amount < 0 AND is_negative_billing = FALSE
HAVING COUNT(*) > 0;

-- Violation Test 4: Check for Inconsistent Age Group Classifications
SELECT 'TEST_FAIL: Invalid Age Group Logic' AS failure_reason,
       COUNT(*) AS violation_count
FROM healthcare.admissions
WHERE (age < 18 AND age_group <> '< 18')
   OR (age BETWEEN 18 AND 35 AND age_group <> '18 - 35')
   OR (age BETWEEN 36 AND 50 AND age_group <> '36 - 50')
   OR (age BETWEEN 51 AND 65 AND age_group <> '51 - 65')
   OR (age > 65 AND age_group <> '65+')
HAVING COUNT(*) > 0;

-- Violation Test 5: Check for Total Cleaned Record Count Variance
SELECT 'TEST_FAIL: Cleaned Row Count Not Equal to 54,966' AS failure_reason,
       COUNT(*) AS current_count,
       54966    AS expected_count
FROM healthcare.admissions
HAVING COUNT(*) <> 54966;

