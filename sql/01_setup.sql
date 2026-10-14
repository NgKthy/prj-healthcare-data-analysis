-- =============================================================================
-- Script: 01_setup.sql
-- Description: Environment setup, database creation guidelines, schema creation,
--              and session configuration for Healthcare Data Analysis.
-- Author: Senior Data Analyst & SQL Developer
-- Target Engine: PostgreSQL 14+ (tested on PostgreSQL 16)
-- =============================================================================

-- Step 1: Optional database initialization (execute as superuser/postgres if needed)
-- CREATE DATABASE healthcare_db
--     WITH ENCODING = 'UTF8'
--     LC_COLLATE = 'English_United States.1252'
--     LC_CTYPE = 'English_United States.1252'
--     CONNECTION LIMIT = -1;

-- Step 2: Establish dedicated schema for healthcare domain modeling
CREATE SCHEMA IF NOT EXISTS healthcare;

-- Step 3: Configure search path for the current session
SET search_path TO healthcare, public;

-- Step 4: Metadata and schema documentation
COMMENT ON SCHEMA healthcare IS 'Dedicated analytical schema for healthcare inpatient admissions, operations, and billing analysis.';

-- Verify setup
SELECT current_database() AS active_database,
       current_schema() AS active_schema,
       version() AS postgres_version;

