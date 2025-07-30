# Certificate Management Guide for BYOD MDM Deployment

## Overview

Certificate management is a critical component of any Mobile Device Management (MDM) solution. This guide provides comprehensive instructions for generating, managing, and deploying certificates for both Headwind MDM (Android) and MicroMDM/NanoMDM (iOS) solutions.

## Certificate Types and Requirements

### For Headwind MDM (Android)

1. **SSL/TLS Certificates**
   - Server certificate for HTTPS communication
   - Can use Let's Encrypt or commercial certificates
   - Required for secure device-server communication

2. **APK Signing Certificates**
   - Used to sign Android applications
   - Required for app integrity verification
   - Should be kept secure and backed up

### For MicroMDM/NanoMDM (iOS)

1. **APNs (Apple Push Notification service) Certificate**
   - Required for sending push notifications to iOS devices
   - Must be obtained from Apple Developer Portal
   - Expires annually and must be renewed

2. **MDM Push Certificate**
   - Used for MDM-specific push notifications
   - Obtained through Apple Push Certificates Portal
   - Different from regular APNs certificates

3. **Identity Certificates**
   - Used for device authentication
   - Can be issued via SCEP (Simple Certificate Enrollment Protocol)
   - Unique per device

4. **Server SSL/TLS Certificates**
   - Required for HTTPS communication
   - Can use Let's Encrypt or commercial certificates

5. **CA (Certificate Authority) Certificates**
   - Root and intermediate certificates
   - Used for SCEP certificate issuance
   - Required for device trust establishment

## Certificate Generation Instructions

### SSL/TLS Certificates (Both Platforms)

#### Using Let's Encrypt (Recommended for Production)

```bash
# Install Certbot
sudo apt update
sudo apt install certbot

# Generate certificate for your domain
sudo certbot certonly --standalone -d your-mdm-domain.com

# Certificates will be stored in:
# /etc/letsencrypt/live/your-mdm-domain.com/
```

#### Using OpenSSL (For Testing/Development)

```bash
# Generate private key
openssl genrsa -out server-key.pem 2048

# Generate certificate signing request
openssl req -new -key server-key.pem -out server.csr \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=your-mdm-domain.com"

# Generate self-signed certificate
openssl x509 -req -in server.csr -signkey server-key.pem \
  -out server.pem -days 365
```

### APNs Certificates for iOS MDM

#### Step 1: Create Certificate Signing Request (CSR)

```bash
# Generate private key for APNs
openssl genrsa -out apns-key.pem 2048

# Generate CSR for APNs certificate
openssl req -new -key apns-key.pem -out apns.csr \
  -subj "/C=US/ST=State/L=City/O=YourCompany/CN=MDM_Certificate"
```

#### Step 2: Obtain APNs Certificate from Apple

1. Log in to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to Certificates, Identifiers & Profiles
3. Select Certificates and click the "+" button
4. Choose "Apple Push Notification service SSL (Sandbox & Production)"
5. Upload the CSR file created in Step 1
6. Download the certificate file (usually named `aps.cer`)

#### Step 3: Convert Certificate to PEM Format

```bash
# Convert the downloaded certificate to PEM format
openssl x509 -inform DER -in aps.cer -out apns.pem
```

### MDM Push Certificate for iOS

#### Step 1: Access Apple Push Certificates Portal

1. Visit [Apple Push Certificates Portal](https://identity.apple.com/pushcert/)
2. Sign in with your Apple ID
3. Click "Create a Certificate"

#### Step 2: Generate CSR for MDM Push Certificate

```bash
# Generate private key for MDM push certificate
openssl genrsa -out push-key.pem 2048

# Generate CSR for MDM push certificate
openssl req -new -key push-key.pem -out push.csr \
  -subj "/C=US/ST=State/L=City/O=YourCompany/CN=MDM_Push_Certificate"
```

#### Step 3: Upload CSR and Download Certificate

1. Upload the CSR file to the Apple Push Certificates Portal
2. Download the certificate file
3. Convert to PEM format if necessary

### CA Certificates for SCEP

#### Generate Root CA

```bash
# Generate root CA private key
openssl genrsa -out ca-key.pem 4096

# Generate root CA certificate
openssl req -new -x509 -key ca-key.pem -out ca.pem -days 3650 \
  -subj "/C=US/ST=State/L=City/O=YourCompany/CN=YourCompany Root CA"
```

#### Generate Intermediate CA (Optional but Recommended)

```bash
# Generate intermediate CA private key
openssl genrsa -out intermediate-key.pem 2048

# Generate intermediate CA CSR
openssl req -new -key intermediate-key.pem -out intermediate.csr \
  -subj "/C=US/ST=State/L=City/O=YourCompany/CN=YourCompany Intermediate CA"

# Sign intermediate CA with root CA
openssl x509 -req -in intermediate.csr -CA ca.pem -CAkey ca-key.pem \
  -out intermediate.pem -days 1825 -CAcreateserial
```

## Certificate Deployment

### Headwind MDM Certificate Deployment

1. **SSL Certificate Deployment**
   ```bash
   # Copy certificates to Docker volume
   cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ./volumes/letsencrypt/live/your-domain.com/
   cp /etc/letsencrypt/live/your-domain.com/privkey.pem ./volumes/letsencrypt/live/your-domain.com/
   ```

2. **Update Docker Compose Configuration**
   ```yaml
   volumes:
     - letsencrypt_data:/etc/letsencrypt
   ```

### MicroMDM/NanoMDM Certificate Deployment

1. **Create Certificates Directory**
   ```bash
   mkdir -p ./certs
   chmod 700 ./certs
   ```

2. **Copy Certificates**
   ```bash
   # Copy all certificates to the certs directory
   cp apns.pem ./certs/
   cp apns-key.pem ./certs/
   cp push.pem ./certs/
   cp push-key.pem ./certs/
   cp server.pem ./certs/
   cp server-key.pem ./certs/
   cp ca.pem ./certs/
   cp ca-key.pem ./certs/
   ```

3. **Set Proper Permissions**
   ```bash
   chmod 600 ./certs/*.pem
   ```

## Certificate Renewal and Maintenance

### Automated SSL Certificate Renewal

#### Let's Encrypt Renewal

```bash
# Add to crontab for automatic renewal
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

#### Docker Compose with Certbot

The provided Docker Compose configurations include Certbot containers that automatically handle certificate renewal.

### APNs Certificate Renewal

APNs certificates expire annually and must be renewed manually:

1. **Monitor Expiration Dates**
   ```bash
   # Check certificate expiration
   openssl x509 -in apns.pem -noout -dates
   ```

2. **Set Up Renewal Reminders**
   - Create calendar reminders 30 days before expiration
   - Monitor certificate expiration through MDM logs
   - Implement automated monitoring scripts

3. **Renewal Process**
   - Generate new CSR using existing private key
   - Submit to Apple Developer Portal
   - Download and deploy new certificate
   - Restart MDM services

### Certificate Backup and Recovery

#### Backup Strategy

```bash
# Create secure backup of all certificates
tar -czf mdm-certificates-backup-$(date +%Y%m%d).tar.gz \
  --exclude='*.csr' \
  ./certs/

# Encrypt the backup
gpg --symmetric --cipher-algo AES256 \
  mdm-certificates-backup-$(date +%Y%m%d).tar.gz
```

#### Recovery Procedures

1. **Restore from Backup**
   ```bash
   # Decrypt and extract backup
   gpg --decrypt mdm-certificates-backup-YYYYMMDD.tar.gz.gpg | \
     tar -xzf -
   ```

2. **Verify Certificate Integrity**
   ```bash
   # Verify certificate and key match
   openssl x509 -noout -modulus -in server.pem | openssl md5
   openssl rsa -noout -modulus -in server-key.pem | openssl md5
   ```

3. **Restart Services**
   ```bash
   # Restart Docker containers
   docker-compose restart
   ```

## Security Best Practices

### Certificate Storage

1. **File Permissions**
   - Private keys: 600 (owner read/write only)
   - Certificates: 644 (owner read/write, group/others read)
   - Directories: 700 (owner access only)

2. **Encryption at Rest**
   - Use encrypted file systems for certificate storage
   - Consider hardware security modules (HSMs) for production
   - Implement proper key management procedures

### Access Control

1. **Limit Access**
   - Restrict certificate access to necessary personnel only
   - Use role-based access control (RBAC)
   - Implement audit logging for certificate access

2. **Secure Transfer**
   - Use secure channels (SFTP, SCP) for certificate transfer
   - Verify certificate integrity after transfer
   - Use encrypted communication for all certificate operations

### Monitoring and Alerting

1. **Certificate Expiration Monitoring**
   ```bash
   #!/bin/bash
   # Certificate expiration check script
   
   CERT_FILE="./certs/apns.pem"
   DAYS_WARNING=30
   
   EXPIRY_DATE=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
   EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
   CURRENT_EPOCH=$(date +%s)
   DAYS_UNTIL_EXPIRY=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))
   
   if [ $DAYS_UNTIL_EXPIRY -le $DAYS_WARNING ]; then
       echo "WARNING: Certificate expires in $DAYS_UNTIL_EXPIRY days"
       # Send alert email or notification
   fi
   ```

2. **Certificate Validation**
   ```bash
   # Validate certificate chain
   openssl verify -CAfile ca.pem intermediate.pem
   
   # Check certificate details
   openssl x509 -in server.pem -text -noout
   ```

## Troubleshooting Common Certificate Issues

### SSL/TLS Certificate Issues

1. **Certificate Chain Problems**
   ```bash
   # Test certificate chain
   openssl s_client -connect your-mdm-domain.com:443 -showcerts
   ```

2. **Certificate Mismatch**
   - Verify certificate Common Name (CN) matches domain
   - Check Subject Alternative Names (SAN) for multiple domains
   - Ensure certificate is not expired

### APNs Certificate Issues

1. **Invalid APNs Certificate**
   - Verify certificate is for the correct environment (production/sandbox)
   - Check certificate expiration date
   - Ensure private key matches certificate

2. **Push Notification Failures**
   - Verify APNs connectivity
   - Check certificate permissions and file paths
   - Monitor APNs logs for error messages

### SCEP Certificate Issues

1. **CA Certificate Problems**
   - Verify CA certificate is properly installed on devices
   - Check certificate chain validity
   - Ensure SCEP server is accessible

2. **Device Certificate Enrollment Failures**
   - Verify SCEP challenge password
   - Check device connectivity to SCEP server
   - Monitor SCEP server logs for errors

## Certificate Management Tools

### Recommended Tools

1. **OpenSSL**
   - Command-line toolkit for certificate operations
   - Available on all Unix-like systems
   - Comprehensive certificate management capabilities

2. **Certbot**
   - Automated Let's Encrypt certificate management
   - Supports automatic renewal
   - Integration with web servers

3. **cfssl**
   - CloudFlare's PKI toolkit
   - Good for CA operations
   - JSON-based configuration

### Custom Scripts

Create custom scripts for routine certificate operations:

```bash
#!/bin/bash
# Certificate management script

case "$1" in
    "check")
        # Check all certificate expiration dates
        ;;
    "renew")
        # Renew certificates
        ;;
    "backup")
        # Create certificate backup
        ;;
    "deploy")
        # Deploy certificates to containers
        ;;
    *)
        echo "Usage: $0 {check|renew|backup|deploy}"
        ;;
esac
```

## Conclusion

Proper certificate management is essential for the security and reliability of your MDM deployment. Regular monitoring, timely renewal, and secure storage practices will ensure your MDM infrastructure remains secure and operational. Always test certificate changes in a development environment before applying them to production systems.

