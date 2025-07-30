-- Database initialization script for MicroMDM/NanoMDM
-- This script creates the necessary database structure

-- Create database if it doesn't exist (handled by Docker environment variables)
-- CREATE DATABASE IF NOT EXISTS micromdm;

-- Create user if it doesn't exist (handled by Docker environment variables)
-- CREATE USER IF NOT EXISTS micromdm WITH PASSWORD 'topsecret';

-- Grant privileges (handled by Docker environment variables)
-- GRANT ALL PRIVILEGES ON DATABASE micromdm TO micromdm;

-- Switch to the micromdm database
\c micromdm;

-- Create extensions that might be needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create basic tables for NanoMDM (these will be created automatically by NanoMDM)
-- But we can prepare some basic structure

-- Devices table
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    udid VARCHAR(255) UNIQUE NOT NULL,
    serial_number VARCHAR(255),
    device_name VARCHAR(255),
    model VARCHAR(255),
    product_name VARCHAR(255),
    os_version VARCHAR(255),
    build_version VARCHAR(255),
    enrollment_id VARCHAR(255),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Commands table
CREATE TABLE IF NOT EXISTS commands (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_udid VARCHAR(255) NOT NULL,
    command_uuid VARCHAR(255) UNIQUE NOT NULL,
    command_type VARCHAR(255) NOT NULL,
    command_data JSONB,
    status VARCHAR(50) DEFAULT 'Pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_udid) REFERENCES devices(udid) ON DELETE CASCADE
);

-- Profiles table
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    identifier VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    description TEXT,
    profile_data BYTEA,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Device profiles relationship table
CREATE TABLE IF NOT EXISTS device_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_udid VARCHAR(255) NOT NULL,
    profile_identifier VARCHAR(255) NOT NULL,
    installed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_udid) REFERENCES devices(udid) ON DELETE CASCADE,
    FOREIGN KEY (profile_identifier) REFERENCES profiles(identifier) ON DELETE CASCADE,
    UNIQUE(device_udid, profile_identifier)
);

-- Applications table
CREATE TABLE IF NOT EXISTS applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bundle_id VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255),
    version VARCHAR(255),
    short_version VARCHAR(255),
    app_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Device applications relationship table
CREATE TABLE IF NOT EXISTS device_applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_udid VARCHAR(255) NOT NULL,
    bundle_id VARCHAR(255) NOT NULL,
    installed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_udid) REFERENCES devices(udid) ON DELETE CASCADE,
    FOREIGN KEY (bundle_id) REFERENCES applications(bundle_id) ON DELETE CASCADE,
    UNIQUE(device_udid, bundle_id)
);

-- Certificates table
CREATE TABLE IF NOT EXISTS certificates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    common_name VARCHAR(255),
    serial_number VARCHAR(255) UNIQUE NOT NULL,
    certificate_data BYTEA,
    issued_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Device certificates relationship table
CREATE TABLE IF NOT EXISTS device_certificates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_udid VARCHAR(255) NOT NULL,
    certificate_serial VARCHAR(255) NOT NULL,
    installed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_udid) REFERENCES devices(udid) ON DELETE CASCADE,
    FOREIGN KEY (certificate_serial) REFERENCES certificates(serial_number) ON DELETE CASCADE,
    UNIQUE(device_udid, certificate_serial)
);

-- Enrollment profiles table
CREATE TABLE IF NOT EXISTS enrollment_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    enrollment_id VARCHAR(255) UNIQUE NOT NULL,
    profile_data BYTEA,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Push notifications table
CREATE TABLE IF NOT EXISTS push_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_udid VARCHAR(255) NOT NULL,
    push_magic VARCHAR(255),
    token VARCHAR(255),
    topic VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_udid) REFERENCES devices(udid) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_devices_udid ON devices(udid);
CREATE INDEX IF NOT EXISTS idx_devices_serial ON devices(serial_number);
CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices(last_seen);
CREATE INDEX IF NOT EXISTS idx_commands_device_udid ON commands(device_udid);
CREATE INDEX IF NOT EXISTS idx_commands_status ON commands(status);
CREATE INDEX IF NOT EXISTS idx_commands_created_at ON commands(created_at);
CREATE INDEX IF NOT EXISTS idx_device_profiles_device_udid ON device_profiles(device_udid);
CREATE INDEX IF NOT EXISTS idx_device_applications_device_udid ON device_applications(device_udid);
CREATE INDEX IF NOT EXISTS idx_certificates_serial ON certificates(serial_number);
CREATE INDEX IF NOT EXISTS idx_certificates_expires_at ON certificates(expires_at);
CREATE INDEX IF NOT EXISTS idx_push_notifications_device_udid ON push_notifications(device_udid);

-- Create a function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update the updated_at column
CREATE TRIGGER update_devices_updated_at BEFORE UPDATE ON devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_commands_updated_at BEFORE UPDATE ON commands
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_applications_updated_at BEFORE UPDATE ON applications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_enrollment_profiles_updated_at BEFORE UPDATE ON enrollment_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_push_notifications_updated_at BEFORE UPDATE ON push_notifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert some default data if needed
-- This could include default configuration profiles, applications, etc.

-- Example: Insert a default Wi-Fi configuration profile
-- INSERT INTO profiles (identifier, display_name, description, profile_data)
-- VALUES (
--     'com.company.wifi.corporate',
--     'Corporate Wi-Fi',
--     'Corporate Wi-Fi configuration profile',
--     decode('...', 'base64')  -- Base64 encoded profile data
-- ) ON CONFLICT (identifier) DO NOTHING;

-- Grant necessary permissions to the micromdm user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO micromdm;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO micromdm;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO micromdm;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO micromdm;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO micromdm;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO micromdm;

