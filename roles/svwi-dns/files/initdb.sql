
-- Create the powerdns database
CREATE DATABASE IF NOT EXISTS powerdns;

-- Grant privileges to the root user for localhost and all hosts (% wildcard)
-- Note: Using CREATE USER first, then GRANT for MariaDB 10.6+ compatibility
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- It's generally recommended to avoid using the root user for application connections.
-- A more secure approach would be to create a dedicated user for PowerDNS with
-- only the necessary privileges on the 'powerdns' database.
-- For now, we'll configure root access to fix the immediate issue, but a follow-up
-- task should be created to implement a dedicated user with limited privileges.

-- Optional: Create a replicator user if needed for multi-master replication
-- create user 'replicator'@'%' identified by 'repl1234or';
-- grant replication slave on *.* to 'replicator'@'%';
-- FLUSH PRIVILEGES;

FLUSH PRIVILEGES;
