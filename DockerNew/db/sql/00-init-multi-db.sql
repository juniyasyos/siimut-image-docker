-- ================================================
--  MULTI DATABASE INITIALIZATION (SIIMUT & IAM)
--  SAFE FOR RE-RUN / MIGRATION / PRODUCTION
-- ================================================

-- =================================================
--  SIIMUT Database
-- =================================================
CREATE DATABASE IF NOT EXISTS siimut_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Create main service user (R/W FULL)
CREATE USER IF NOT EXISTS 'siimut_user'@'%'
  IDENTIFIED BY 'siimut-password';

GRANT ALL PRIVILEGES
  ON siimut_db.* TO 'siimut_user'@'%';


-- Optional: readonly user (analytics / Grafana / DWH)
CREATE USER IF NOT EXISTS 'siimut_readonly'@'%'
  IDENTIFIED BY 'Siimut@ReadOnly2025!';

GRANT SELECT ON siimut_db.* TO 'siimut_readonly'@'%';


-- =================================================
--  IAM / SSO Database
-- =================================================
CREATE DATABASE IF NOT EXISTS iam_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Create IAM user (R/W FULL)
CREATE USER IF NOT EXISTS 'iam_user'@'%'
  IDENTIFIED BY 'iam-password';

GRANT ALL PRIVILEGES
  ON iam_db.* TO 'iam_user'@'%';


-- Optional: readonly user
CREATE USER IF NOT EXISTS 'iam_readonly'@'%'
  IDENTIFIED BY 'Iam@ReadOnly2025!';

GRANT SELECT ON iam_db.* TO 'iam_readonly'@'%';


-- =================================================
--  Finalize Privileges
-- =================================================
FLUSH PRIVILEGES;
