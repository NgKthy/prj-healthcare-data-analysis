# Junior Data Analyst Portfolio — Interview Defense & Presentation Guide

## 1. 2-Minute Elevator Pitch

> "This project is an end-to-end Healthcare Data Analysis project built on PostgreSQL, modeling over 55,000 inpatient admission encounters across five calendar years. 
> 
> Rather than just running basic ad-hoc queries on a CSV, I architected a production-ready ELT pipeline. I established a lossless staging layer, performed comprehensive data quality audits that caught 534 duplicate records and 106 negative billing adjustments, and engineered a clean analytical schema with surrogate keys and calculated features like inpatient length of stay.
> 
> On the analysis side, I wrote 20 modular PostgreSQL scripts covering patient demographics, clinical cost drivers, time-series admission momentum with `LAG`, facility comparisons using `DENSE_RANK`, and high-cost patient segmentation via `NTILE` and 95th-percentile cutoffs. 
> 
> Critically, as a data analyst, I didn't take the numbers at face value: I identified the synthetic signatures of the dataset, documented why patient readmissions cannot be reliably calculated without an Enterprise Master Patient Index, and reconciled every single dollar and record back to the staging ledger."

---

## 2. Technical Architecture Talking Points

### Q: Why did you create both a staging table and an analytics table instead of cleaning the CSV directly?
**Answer**:
"In enterprise data engineering, you never mutate raw data or perform destructive cleaning on ingest. By loading the raw CSV into `healthcare.staging_admissions` using permissive text types, we guarantee zero ingestion failures from malformed formats. 
The downstream transformation script (`04_cleaning.sql`) is completely deterministic and idempotent—meaning it can be rerun at any time without creating side effects. This guarantees a complete audit trail where every record in production can be traced and reconciled back to its raw source."

### Q: Why did you use an auto-incrementing surrogate key (`admission_record_id`)?
**Answer**:
"The raw dataset lacked an immutable natural primary key. Relying on patient names or composite columns as primary keys is dangerous because patient names collide and composite keys degrade join performance. Generating `admission_record_id BIGSERIAL PRIMARY KEY` gives us a compact 8-byte integer key that accelerates B-Tree indexing, partition queries, and downstream dimensional joins."

### Q: How did you handle negative billing amounts? Why not just delete them?
**Answer**:
"I detected 106 records with negative billing amounts between -\$0.37 and -\$2,008.49. In hospital revenue cycle management, negative charges are standard accounting adjustments—such as insurance re-adjudication, billing correction credits, or refund reversals.
If I had deleted them, the financial ledger would not reconcile with the source data (\$13,674,561 in duplicates + \$1,404,068,337 in production + negative adjustments). Instead, I engineered a boolean flag `is_negative_billing`. When calculating encounter cost benchmarks, we filter for positive charges; when reconciling aggregate cash flows, all records are preserved."

### Q: Why did you decide NOT to calculate 30-day readmission rates?
**Answer**:
"That was a deliberate data governance decision. A junior analyst might see the `Name` column and run a self-join or `LAG` window function to calculate readmissions. 
However, profiling showed that the dataset does not include a unique Patient ID or Social Security Number. The dataset has 40,235 unique names across 54,966 records; records with identical names often had different birth years, genders, or blood types. Computing readmission rates on names would produce false-positive pairings and corrupt the metric. Demonstrating restraint and explaining why a metric shouldn't be computed is just as important as knowing how to write the query."

---

## 3. SQL Techniques Demonstrated & Defended

| SQL Technique | Where Used | Technical Justification |
| :--- | :--- | :--- |
| **Common Table Expressions (CTEs)** | `12_cte_analysis.sql`, `13_time_trends.sql` | Improves query readability, encapsulates intermediate aggregations, and allows modular pipeline execution. |
| **Window Functions (`LAG`, `LEAD`)** | `13_time_trends.sql` | Computes Month-over-Month and Year-over-Year volume change without expensive self-joins. |
| **Ranking (`RANK`, `DENSE_RANK`, `ROW_NUMBER`)** | `09_providers.sql`, `15_ranking.sql` | Correctly handles ties when identifying top 3 physicians per hospital or top facilities by volume. |
| **Percentile & Median (`PERCENTILE_CONT`)** | `06_conditions.sql`, `17_high_cost.sql` | Provides true medians and $P_{95}$ cutoffs, which are more robust to extreme financial outliers than standard arithmetic means. |
| **Quantile Segmentation (`NTILE(4)`)** | `16_cost_segments.sql` | Splits admissions into 4 balanced financial quartiles for cohort comparison. |
| **Defensive Math (`NULLIF`)** | Across all percentage queries | Enforces `NULLIF(total, 0)` in denominators to prevent runtime division-by-zero exceptions. |

---

## 4. Key Questions an Interviewer Might Ask You

### 1. "Your analysis shows that cancer, diabetes, and asthma all have almost identical average billing (~$25,500) and average LOS (~15.5 days). Does that make clinical sense?"
**Model Answer**:
"Clinically, no. In real life, oncology inpatients usually incur higher pharmacy costs and longer stays than routine asthma encounters. 
However, during my initial data profiling phase, I ran distribution tests and recognized that this dataset exhibits the classic statistical signature of synthetic uniform generation. I documented this explicitly in my `data_quality_report.md` and `limitations.md`. While the data generator assigned values uniformly, the SQL queries I built are fully production-grade and ready to run on real EHR data where those clinical variations would immediately be reflected."

### 2. "If an executive asked you to rank the best hospitals based on this dataset, what would you say?"
**Model Answer**:
"I would caution the executive that billing volume and patient counts cannot measure clinical quality of care. A hospital with higher billing might simply treat a higher-acuity case mix, or charge higher chargemaster markups, while lower-cost hospitals might be more efficient or treat simpler elective cases. 
Furthermore, because the dataset lacks clinical outcomes (such as mortality, complication rates, or risk-adjusted readmissions), we can only report operational throughput and financial volume, not clinical excellence."

### 3. "How did you ensure that your queries could be reproduced by anyone on GitHub?"
**Model Answer**:
"I structured the repository with numbered SQL files (`01_setup.sql` through `20_validation.sql`) that execute in chronological order. I created a staging-to-production pipeline with explicit schema definitions, automated assertion tests in `tests/validation_tests.sql`, and provided a cross-platform Python runner that executes the entire pipeline and validates every mathematical metric against expected outputs."

