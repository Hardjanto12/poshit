-- Create database and user (adjust credentials as needed)
CREATE DATABASE IF NOT EXISTS poshit CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- CREATE USER 'posuser'@'%' IDENTIFIED BY 'pospass';
-- GRANT ALL PRIVILEGES ON poshit.* TO 'posuser'@'%';
-- FLUSH PRIVILEGES;

-- When using GORM AutoMigrate, tables will be created automatically.
-- You can still pre-create if desired, but AutoMigrate is recommended.

-- Optional: seed raw rows (if you are not using the Go seeder)
-- INSERT INTO users (name, username, password, date_created, date_updated) VALUES
--   ('Admin', 'admin', 'admin123', NOW(), NOW());


