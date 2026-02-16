# Helper Scripts

Utility scripts for NetBird infrastructure maintenance and operations.

## Available Scripts

### Database Management
- **`migrate-database.sh`**: Database migration helper
- **`validate-db-connection.sh`**: Test database connectivity

### Validation & Testing
- **`validate.sh`**: Infrastructure validation checks
- **`dr-test.sh`**: Disaster recovery testing script

### Identity Provider Setup
- **`zitadel-setup.sh`**: Configure Zitadel IdP (alternative to Keycloak)

## Usage

All scripts should be run from the project root directory:

```bash
# Example: Validate database connection
./scripts/validate-db-connection.sh

# Example: Run DR test
./scripts/dr-test.sh
```

## Notes

- Scripts assume Terraform has been applied and infrastructure exists
- Database scripts require appropriate credentials in environment variables
- See individual script help text for detailed usage: `./scripts/<script>.sh --help`
