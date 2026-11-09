"""
Automated Test Runner & Validation Harness
Healthcare Data Analysis Project
Executes all data quality, transformation, and validation assertions.
"""

import os
import json
import sqlite3
import pandas as pd
import numpy as np

def run_tests():
    raw_path = 'data/raw/healthcare_dataset.csv'
    cleaned_path = 'data/processed/admissions_cleaned.csv'
    outputs_dir = 'outputs'
    os.makedirs(outputs_dir, exist_ok=True)
    
    print("=" * 70)
    print("HEALTHCARE SQL DATA ANALYSIS — AUTOMATED VERIFICATION SUITE")
    print("=" * 70)

    # 1. Load data
    df_raw = pd.read_csv(raw_path)
    df_clean = pd.read_csv(cleaned_path)
    
    results = {
        "summary": {
            "total_raw_rows": len(df_raw),
            "total_cleaned_rows": len(df_clean),
            "duplicates_removed": len(df_raw) - len(df_clean),
            "status": "PASS"
        },
        "tests": []
    }
    
    def log_test(test_id, name, condition, details=""):
        status = "PASS" if condition else "FAIL"
        if status == "FAIL":
            results["summary"]["status"] = "FAIL"
        entry = {
            "test_id": test_id,
            "name": name,
            "status": status,
            "details": details
        }
        results["tests"].append(entry)
        symbol = "✓" if status == "PASS" else "✗"
        print(f"[{symbol}] {test_id}: {name} -> {status} {details}")

    # TEST 1: Raw row count
    log_test(
        "T01_RAW_ROW_COUNT",
        "Raw staging count matches benchmark (55,500)",
        len(df_raw) == 55500,
        f"(Count: {len(df_raw)})"
    )

    # TEST 2: Null values in raw
    null_count = df_raw.isnull().sum().sum()
    log_test(
        "T02_RAW_NULL_CHECK",
        "Zero null or missing values across raw dataset",
        null_count == 0,
        f"(Nulls found: {null_count})"
    )

    # TEST 3: Duplicate records in raw
    dup_count = df_raw.duplicated().sum()
    log_test(
        "T03_RAW_DUPLICATE_AUDIT",
        "Exact duplicates accurately identified (534 expected)",
        dup_count == 534,
        f"(Duplicates found: {dup_count})"
    )

    # TEST 4: Cleaned row count
    expected_clean = 55500 - 534
    log_test(
        "T04_CLEANED_ROW_COUNT",
        "Cleaned admissions table matches expected (54,966)",
        len(df_clean) == expected_clean,
        f"(Cleaned count: {len(df_clean)})"
    )

    # TEST 5: Primary Key uniqueness
    pk_unique = df_clean['admission_record_id'].nunique() == len(df_clean)
    log_test(
        "T05_PRIMARY_KEY_UNIQUE",
        "Surrogate key admission_record_id is 100% unique",
        pk_unique,
        f"(Distinct keys: {df_clean['admission_record_id'].nunique()})"
    )

    # TEST 6: Chronological date validity
    df_clean['date_of_admission'] = pd.to_datetime(df_clean['date_of_admission'])
    df_clean['discharge_date'] = pd.to_datetime(df_clean['discharge_date'])
    date_inversions = (df_clean['discharge_date'] < df_clean['date_of_admission']).sum()
    log_test(
        "T06_DATE_CHRONOLOGY",
        "Discharge date occurs on or after admission date",
        date_inversions == 0,
        f"(Inversions found: {date_inversions})"
    )

    # TEST 7: Length of stay bounds
    min_los = df_clean['length_of_stay_days'].min()
    max_los = df_clean['length_of_stay_days'].max()
    log_test(
        "T07_LOS_BOUNDARIES",
        "Inpatient stay between 1 and 30 days without negative values",
        min_los >= 0 and max_los <= 30,
        f"(Range: {min_los} to {max_los} days)"
    )

    # TEST 8: Age range validation
    min_age = df_clean['age'].min()
    max_age = df_clean['age'].max()
    log_test(
        "T08_AGE_RANGE",
        "Patient age strictly between 0 and 125 years",
        min_age >= 0 and max_age <= 125,
        f"(Range: {min_age} to {max_age} years)"
    )

    # TEST 9: Negative billing flag consistency
    negative_charges = (df_clean['billing_amount'] < 0).sum()
    flagged_negatives = df_clean['is_negative_billing'].sum()
    log_test(
        "T09_NEGATIVE_BILLING_FLAG",
        "Negative billing correctly identified & flagged (106 records)",
        negative_charges == 106 and flagged_negatives == 106,
        f"(Negative charges: {negative_charges}, Flagged: {flagged_negatives})"
    )

    # TEST 10: Financial ledger reconciliation
    raw_rounded_sum = round(df_raw['Billing Amount'].round(2).sum(), 2)
    clean_billing_sum = round(df_clean['billing_amount'].sum(), 2)
    duplicate_billing_sum = round(df_raw[df_raw.duplicated()]['Billing Amount'].round(2).sum(), 2)
    reconciled = abs(raw_rounded_sum - (clean_billing_sum + duplicate_billing_sum)) < 0.05
    log_test(
        "T10_FINANCIAL_RECONCILIATION",
        "Raw rounded billing = Cleaned billing + Duplicate billing",
        reconciled,
        f"(Raw: ${raw_rounded_sum:,.2f} | Cleaned+Dup: ${clean_billing_sum + duplicate_billing_sum:,.2f})"
    )

    # TEST 11: Categorical domain integrity
    valid_conditions = {'Arthritis', 'Asthma', 'Cancer', 'Diabetes', 'Hypertension', 'Obesity'}
    cond_diff = set(df_clean['medical_condition'].unique()) - valid_conditions
    log_test(
        "T11_CONDITION_DOMAIN",
        "Medical condition domain strictly matches 6 allowed values",
        len(cond_diff) == 0,
        f"(Distinct: {len(df_clean['medical_condition'].unique())})"
    )

    # TEST 12: Insurance domain integrity
    valid_insurance = {'Aetna', 'Blue Cross', 'Cigna', 'Medicare', 'UnitedHealthcare'}
    ins_diff = set(df_clean['insurance_provider'].unique()) - valid_insurance
    log_test(
        "T12_INSURANCE_DOMAIN",
        "Insurance carrier domain strictly matches 5 allowed values",
        len(ins_diff) == 0,
        f"(Distinct: {len(df_clean['insurance_provider'].unique())})"
    )

    # TEST 13: Admission type integrity
    valid_admission_types = {'Elective', 'Emergency', 'Urgent'}
    adm_diff = set(df_clean['admission_type'].unique()) - valid_admission_types
    log_test(
        "T13_ADMISSION_TYPE_DOMAIN",
        "Admission type domain strictly matches 3 allowed values",
        len(adm_diff) == 0,
        f"(Distinct: {len(df_clean['admission_type'].unique())})"
    )

    # TEST 14: Title casing verification
    casing_issues = sum(1 for name in df_clean['patient_name'] if name != name.title())
    log_test(
        "T14_TITLE_CASING",
        "Patient names standardized to proper Title Case",
        casing_issues == 0,
        f"(Anomalies found: {casing_issues})"
    )

    # Save test results
    test_results_path = os.path.join(outputs_dir, 'test_results.json')
    with open(test_results_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2)
    print("-" * 70)
    print(f"Test suite finished with overall status: {results['summary']['status']}")
    print(f"Results written to: {test_results_path}")
    print("=" * 70)

if __name__ == '__main__':
    run_tests()
