"""
Verification and Analytical Metrics Calculator
Healthcare Data Analysis Project
Senior Data Analyst & Data Quality Verification Engine
"""

import os
import json
import pandas as pd
import numpy as np

def run_pipeline():
    raw_path = 'data/raw/healthcare_dataset.csv'
    processed_dir = 'data/processed'
    outputs_dir = 'outputs'
    os.makedirs(processed_dir, exist_ok=True)
    os.makedirs(outputs_dir, exist_ok=True)

    print(f"Loading raw dataset from {raw_path}...")
    df_raw = pd.read_csv(raw_path)
    total_raw_rows = len(df_raw)
    raw_columns = list(df_raw.columns)
    
    # 1. Audit duplicates
    duplicates_mask = df_raw.duplicated()
    duplicate_count = int(duplicates_mask.sum())
    
    # Deduplicate while preserving original order
    df_clean = df_raw.drop_duplicates().copy()
    dedup_count = len(df_clean)
    
    # Rename columns to standardized snake_case
    rename_map = {
        'Name': 'patient_name',
        'Age': 'age',
        'Gender': 'gender',
        'Blood Type': 'blood_type',
        'Medical Condition': 'medical_condition',
        'Date of Admission': 'date_of_admission',
        'Doctor': 'doctor_name',
        'Hospital': 'hospital_name',
        'Insurance Provider': 'insurance_provider',
        'Billing Amount': 'billing_amount',
        'Room Number': 'room_number',
        'Admission Type': 'admission_type',
        'Discharge Date': 'discharge_date',
        'Medication': 'medication',
        'Test Results': 'test_results'
    }
    df_clean.rename(columns=rename_map, inplace=True)
    
    # Standardize text casing and trimming
    df_clean['patient_name'] = df_clean['patient_name'].astype(str).str.strip().str.title()
    df_clean['doctor_name'] = df_clean['doctor_name'].astype(str).str.strip()
    df_clean['hospital_name'] = df_clean['hospital_name'].astype(str).str.strip()
    df_clean['medical_condition'] = df_clean['medical_condition'].astype(str).str.strip()
    df_clean['admission_type'] = df_clean['admission_type'].astype(str).str.strip()
    df_clean['insurance_provider'] = df_clean['insurance_provider'].astype(str).str.strip()
    df_clean['medication'] = df_clean['medication'].astype(str).str.strip()
    df_clean['test_results'] = df_clean['test_results'].astype(str).str.strip()
    df_clean['blood_type'] = df_clean['blood_type'].astype(str).str.strip()
    
    # Convert dates and compute LOS
    df_clean['date_of_admission'] = pd.to_datetime(df_clean['date_of_admission'])
    df_clean['discharge_date'] = pd.to_datetime(df_clean['discharge_date'])
    df_clean['length_of_stay_days'] = (df_clean['discharge_date'] - df_clean['date_of_admission']).dt.days
    
    # Round billing amount
    df_clean['billing_amount'] = df_clean['billing_amount'].round(2)
    
    # Flags and derived features
    df_clean['is_negative_billing'] = df_clean['billing_amount'] < 0
    negative_billing_count = int(df_clean['is_negative_billing'].sum())
    
    def get_age_group(age):
        if age < 18:
            return '< 18'
        elif age <= 35:
            return '18 - 35'
        elif age <= 50:
            return '36 - 50'
        elif age <= 65:
            return '51 - 65'
        else:
            return '65+'

    df_clean['age_group'] = df_clean['age'].apply(get_age_group)
    
    # Assign technical surrogate key
    df_clean.reset_index(drop=True, inplace=True)
    df_clean['admission_record_id'] = df_clean.index + 1
    
    # Reorder columns with admission_record_id first
    cols = ['admission_record_id'] + [c for c in df_clean.columns if c != 'admission_record_id']
    df_clean = df_clean[cols]
    
    # Save cleaned csv
    processed_path = os.path.join(processed_dir, 'admissions_cleaned.csv')
    df_clean.to_csv(processed_path, index=False)
    print(f"Cleaned dataset saved to {processed_path} with {len(df_clean)} records.")

    # 2. Detailed Metrics Computation
    # Filter for positive billing when calculating patient encounter costs
    df_pos = df_clean[~df_clean['is_negative_billing']]
    
    metrics = {
        "dataset_summary": {
            "total_raw_records": total_raw_rows,
            "raw_columns_count": len(raw_columns),
            "exact_duplicate_records": duplicate_count,
            "cleaned_records": dedup_count,
            "negative_billing_records": negative_billing_count,
            "valid_positive_billing_records": len(df_pos),
            "admission_date_start": str(df_clean['date_of_admission'].min().date()),
            "admission_date_end": str(df_clean['date_of_admission'].max().date()),
            "discharge_date_start": str(df_clean['discharge_date'].min().date()),
            "discharge_date_end": str(df_clean['discharge_date'].max().date()),
            "unique_hospitals": int(df_clean['hospital_name'].nunique()),
            "unique_doctors": int(df_clean['doctor_name'].nunique()),
            "unique_patient_names": int(df_clean['patient_name'].nunique())
        },
        "billing_kpis": {
            "total_billing_all": float(df_clean['billing_amount'].sum()),
            "total_billing_positive": float(df_pos['billing_amount'].sum()),
            "avg_billing_all": float(df_clean['billing_amount'].mean()),
            "median_billing_all": float(df_clean['billing_amount'].median()),
            "avg_billing_positive": float(df_pos['billing_amount'].mean()),
            "median_billing_positive": float(df_pos['billing_amount'].median()),
            "min_billing": float(df_clean['billing_amount'].min()),
            "max_billing": float(df_clean['billing_amount'].max())
        },
        "length_of_stay_kpis": {
            "avg_los_days": float(df_clean['length_of_stay_days'].mean()),
            "median_los_days": float(df_clean['length_of_stay_days'].median()),
            "min_los_days": int(df_clean['length_of_stay_days'].min()),
            "max_los_days": int(df_clean['length_of_stay_days'].max()),
            "invalid_los_count": int((df_clean['length_of_stay_days'] < 0).sum())
        }
    }
    
    # Demographics: Gender Breakdown
    gender_agg = df_clean.groupby('gender').agg(
        records=('admission_record_id', 'count'),
        avg_age=('age', 'mean'),
        total_billing=('billing_amount', 'sum'),
        avg_billing=('billing_amount', 'mean')
    ).reset_index()
    gender_agg['pct_records'] = (gender_agg['records'] / dedup_count * 100).round(2)
    metrics['gender_distribution'] = gender_agg.to_dict(orient='records')
    
    # Demographics: Age Group
    age_order = ['< 18', '18 - 35', '36 - 50', '51 - 65', '65+']
    age_agg = df_clean.groupby('age_group').agg(
        records=('admission_record_id', 'count'),
        avg_billing=('billing_amount', 'mean'),
        median_billing=('billing_amount', 'median'),
        avg_los=('length_of_stay_days', 'mean')
    ).reindex(age_order).reset_index()
    age_agg['pct_records'] = (age_agg['records'] / dedup_count * 100).round(2)
    metrics['age_group_distribution'] = age_agg.to_dict(orient='records')
    
    # Demographics: Blood Type
    blood_agg = df_clean.groupby('blood_type').agg(
        records=('admission_record_id', 'count'),
        pct_records=('admission_record_id', lambda x: round(len(x) / dedup_count * 100, 2))
    ).reset_index().sort_values('records', ascending=False)
    metrics['blood_type_distribution'] = blood_agg.to_dict(orient='records')
    
    # Medical Condition Analysis
    cond_agg = df_clean.groupby('medical_condition').agg(
        records=('admission_record_id', 'count'),
        total_billing=('billing_amount', 'sum'),
        avg_billing=('billing_amount', 'mean'),
        median_billing=('billing_amount', 'median'),
        avg_los=('length_of_stay_days', 'mean')
    ).reset_index()
    cond_agg['pct_records'] = (cond_agg['records'] / dedup_count * 100).round(2)
    cond_agg['pct_billing'] = (cond_agg['total_billing'] / df_clean['billing_amount'].sum() * 100).round(2)
    cond_agg.sort_values('records', ascending=False, inplace=True)
    metrics['medical_condition_analysis'] = cond_agg.to_dict(orient='records')
    
    # Admission Type Analysis
    adm_agg = df_clean.groupby('admission_type').agg(
        records=('admission_record_id', 'count'),
        total_billing=('billing_amount', 'sum'),
        avg_billing=('billing_amount', 'mean'),
        avg_los=('length_of_stay_days', 'mean')
    ).reset_index()
    adm_agg['pct_records'] = (adm_agg['records'] / dedup_count * 100).round(2)
    adm_agg['pct_billing'] = (adm_agg['total_billing'] / df_clean['billing_amount'].sum() * 100).round(2)
    adm_agg.sort_values('records', ascending=False, inplace=True)
    metrics['admission_type_analysis'] = adm_agg.to_dict(orient='records')
    
    # Insurance Provider Analysis
    ins_agg = df_clean.groupby('insurance_provider').agg(
        records=('admission_record_id', 'count'),
        total_billing=('billing_amount', 'sum'),
        avg_billing=('billing_amount', 'mean'),
        median_billing=('billing_amount', 'median'),
        avg_los=('length_of_stay_days', 'mean')
    ).reset_index()
    ins_agg['pct_records'] = (ins_agg['records'] / dedup_count * 100).round(2)
    ins_agg['pct_billing'] = (ins_agg['total_billing'] / df_clean['billing_amount'].sum() * 100).round(2)
    ins_agg.sort_values('total_billing', ascending=False, inplace=True)
    metrics['insurance_analysis'] = ins_agg.to_dict(orient='records')
    
    # Test Results & Medication Distribution
    test_agg = df_clean.groupby('test_results').agg(
        records=('admission_record_id', 'count'),
        avg_billing=('billing_amount', 'mean')
    ).reset_index()
    test_agg['pct_records'] = (test_agg['records'] / dedup_count * 100).round(2)
    metrics['test_results_distribution'] = test_agg.to_dict(orient='records')

    med_agg = df_clean.groupby('medication').agg(
        records=('admission_record_id', 'count'),
        avg_billing=('billing_amount', 'mean')
    ).reset_index()
    med_agg['pct_records'] = (med_agg['records'] / dedup_count * 100).round(2)
    metrics['medication_distribution'] = med_agg.to_dict(orient='records')

    # Cost Segmentation (NTILE 4 / Quartiles)
    df_clean['billing_quartile'] = pd.qcut(df_clean['billing_amount'], q=4, labels=['Q1 (Lowest)', 'Q2', 'Q3', 'Q4 (Highest)'])
    quart_agg = df_clean.groupby('billing_quartile', observed=False).agg(
        records=('admission_record_id', 'count'),
        min_billing=('billing_amount', 'min'),
        max_billing=('billing_amount', 'max'),
        avg_billing=('billing_amount', 'mean'),
        total_billing=('billing_amount', 'sum'),
        avg_los=('length_of_stay_days', 'mean')
    ).reset_index()
    metrics['cost_quartiles'] = quart_agg.to_dict(orient='records')

    # 95th Percentile High Cost Threshold
    p95_val = float(df_clean['billing_amount'].quantile(0.95))
    high_cost_df = df_clean[df_clean['billing_amount'] >= p95_val]
    metrics['high_cost_analysis'] = {
        "p95_threshold": p95_val,
        "high_cost_records_count": len(high_cost_df),
        "pct_of_total_records": round(len(high_cost_df) / dedup_count * 100, 2),
        "total_high_cost_billing": float(high_cost_df['billing_amount'].sum()),
        "pct_of_total_billing": round(high_cost_df['billing_amount'].sum() / df_clean['billing_amount'].sum() * 100, 2),
        "avg_high_cost_billing": float(high_cost_df['billing_amount'].mean()),
        "avg_los_high_cost": float(high_cost_df['length_of_stay_days'].mean())
    }

    # Annual Trends
    df_clean['admission_year'] = df_clean['date_of_admission'].dt.year
    year_agg = df_clean.groupby('admission_year').agg(
        records=('admission_record_id', 'count'),
        total_billing=('billing_amount', 'sum'),
        avg_billing=('billing_amount', 'mean')
    ).reset_index()
    year_agg['pct_records'] = (year_agg['records'] / dedup_count * 100).round(2)
    metrics['annual_trends'] = year_agg.to_dict(orient='records')

    # Save metrics JSON
    metrics_path = os.path.join(outputs_dir, 'verified_metrics.json')
    with open(metrics_path, 'w', encoding='utf-8') as f:
        json.dump(metrics, f, indent=2)
    print(f"Verified metrics saved to {metrics_path}.")

    return metrics

if __name__ == '__main__':
    metrics = run_pipeline()
    print("\n=== PIPELINE EXECUTION SUMMARY ===")
    print("Raw records:", metrics['dataset_summary']['total_raw_records'])
    print("Exact duplicates:", metrics['dataset_summary']['exact_duplicate_records'])
    print("Cleaned records:", metrics['dataset_summary']['cleaned_records'])
    print("Total Billing:", f"${metrics['billing_kpis']['total_billing_all']:,.2f}")
    print("Average Billing:", f"${metrics['billing_kpis']['avg_billing_all']:,.2f}")
    print("Average LOS:", f"{metrics['length_of_stay_kpis']['avg_los_days']:.2f} days")

