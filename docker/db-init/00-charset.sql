-- © Frank-Christian Struve 2026 · Version 26 rev 0.1
-- Wird von MariaDB beim ersten Start einmalig ausgeführt (leeres Datenverzeichnis).
-- Stellt sicher, dass die Anwendungs-DB wirklich utf8mb4_unicode_ci ist.

ALTER DATABASE spielplaner CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
