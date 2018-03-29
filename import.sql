--
-- Credit for SQL import performance improvements:
-- http://derwiki.tumblr.com/post/24490758395/loading-half-a-billion-rows-into-mysql
--

CREATE DATABASE IF NOT EXISTS hibp_local;

USE hibp_local;

-- Do not enforce foreign key and uniqueness constraints
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS = 0;

-- Drop the transaction isolation guarantee to UNCOMMITTED
SET SESSION tx_isolation='READ-UNCOMMITTED';
-- Turn off the binlog
SET sql_log_bin = 0;

--
-- reason for password_hash to be CHAR(40)
-- https://stackoverflow.com/a/614483/1047730
--
CREATE TABLE IF NOT EXISTS pwned_passwords (
  password_hash CHAR(40),
  ocurrance_count INTEGER,
  INDEX password_hash_idx USING HASH (password_hash)
);

LOAD DATA INFILE '/tmp/pwned-passwords.txt' INTO TABLE pwned_passwords;

-- Reset performance optimizations for LOAD DATA
SET UNIQUE_CHECKS = 1;
SET FOREIGN_KEY_CHECKS = 1;
SET SESSION tx_isolation='READ-REPEATABLE';
SET sql_log_bin = 1;
