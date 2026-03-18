# Database Clone Tool

Clone remote Chatwoot databases (dev/prod) to your local Docker environment.

## Quick Start

```bash
# Clone from dev (with default exclusions)
task setup-db -- dev

# Clone from prod (with default exclusions)
task setup-db -- prod
```

## Requirements

1. **Docker** running with PostgreSQL container up
2. **AWS Credentials** configured (profile `chatscommerce-admin` or environment variables)
3. **Python 3** with `boto3` installed: `pip3 install boto3`

## Usage

### Basic Usage

```bash
# Clone from dev environment
task setup-db -- dev

# Clone from prod environment
task setup-db -- prod
```

### Advanced Options

```bash
# Clone ALL tables (disable default exclusions)
task setup-db -- dev --no-exclude

# Exclude additional custom tables
task setup-db -- dev --exclude audit_logs --exclude custom_table

# Keep dump file after restore (for debugging)
task setup-db -- dev --keep-dump
```

## Default Exclusions

By default, **data** from these large tables is **excluded** (but the table schemas are kept):

- `conversations` - Can be millions of rows
- `messages` - Can be millions of rows
- `reporting_events` - Analytics data
- `notifications` - User notifications

**Important:** The tables still exist with their full schema, they just start empty. This ensures your local Chatwoot instance works correctly.

You can override this with `--no-exclude` to clone ALL data.

## How It Works

1. **Fetch Credentials**: Retrieves remote DB credentials from AWS Parameter Store (`/chatscomm/[env]/DB_*`)
2. **Safety Checks**: Validates that local target is Docker container (prevents accidental remote writes)
3. **Confirmation**: Auto-confirms when using `task setup-db` (or asks if using script directly)
4. **Dump Remote**: Uses `pg_dump --exclude-table-data` to dump:
   - ALL table schemas (CREATE TABLE statements)
   - Data for all tables EXCEPT large ones (conversations, messages, etc.)
5. **Restore Local**: Drops and recreates `chatwoot_dev`, then restores dump
6. **Result**: Local database has all tables but excluded tables start empty

## AWS Parameter Store

The tool expects these parameters in AWS SSM:

```
/chatscomm/dev/POSTGRES_HOST
/chatscomm/dev/POSTGRES_PORT
/chatscomm/dev/POSTGRES_DATABASE
/chatscomm/dev/POSTGRES_USERNAME
/chatscomm/dev/POSTGRES_PASSWORD
```

Replace `dev` with `prod` for production.

## Safety Features

- ✅ Always validates target is `localhost` Docker container
- ✅ Requires explicit user confirmation before dropping database
- ✅ Never modifies remote databases (read-only operations)
- ✅ Uses temporary files that are automatically cleaned up

## Troubleshooting

### "Docker is not running"

Start Docker and ensure PostgreSQL container is running:

```bash
docker compose up -d postgres
```

### "boto3 is not installed"

Install boto3:

```bash
pip3 install boto3
```

### "AWS credentials not found"

Configure AWS profile or set environment variables:

```bash
# Option 1: AWS Profile (recommended for local dev)
aws configure --profile chatscommerce-admin

# Option 2: Environment variables (for CI/CD)
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
```

### "pg_dump: command not found"

Install PostgreSQL client tools:

```bash
# macOS
brew install postgresql

# Ubuntu/Debian
sudo apt-get install postgresql-client

# The Docker container has pg_dump, this is for your host machine
```

### Large database taking too long?

Use default exclusions (enabled by default) or add more:

```bash
task setup-db -- dev --exclude conversations --exclude messages
```

## Files

- `clone_db.py` - Main orchestration script
- `get_db_credentials.py` - AWS Parameter Store credential fetcher
- `README.md` - This file

## Development

Run scripts directly for testing:

```bash
# Test credential fetching
python3 scripts/db/get_db_credentials.py dev

# Run clone with verbose output
python3 scripts/db/clone_db.py dev --help
```

## Examples

### Scenario 1: Quick Dev Clone

I want to quickly sync my local database with dev, excluding data from large tables:

```bash
task setup-db -- dev
# Uses defaults: excludes data from conversations, messages, reporting_events, notifications
# Tables still exist with schema, just start empty
```

### Scenario 2: Full Production Clone

I need ALL data from production for debugging:

```bash
task setup-db -- prod --no-exclude
# Clones everything, may take 10-30 minutes depending on data size
```

### Scenario 3: Selective Clone

I want most data but need to exclude a specific large table:

```bash
task setup-db -- dev --exclude custom_reports
# Uses default exclusions + custom_reports
```

### Scenario 4: Debug Failed Restore

The restore failed and I want to inspect the dump file:

```bash
task setup-db -- dev --keep-dump
# Dump file location will be printed, usually /tmp/chatwoot_dev_XXXXX.dump
```

## Notes

- **Local Database**: Always targets `chatwoot_dev` (defined in `.env` as `POSTGRES_DATABASE`)
- **Remote Database**: Always named `chatwoot` (both dev and prod)
- **Dump Format**: Uses PostgreSQL custom format (`.dump`) for efficient compression
- **Restore Strategy**: Uses `--clean --if-exists` to handle existing objects gracefully
- **Ownership**: Uses `--no-owner --no-acl` to avoid permission issues

## Related Commands

After cloning, you might want to:

```bash
# Open database console
task dev-dbconsole

# Start Rails server
task docker-up

# Check what's in the database
docker compose exec postgres psql -U postgres -d chatwoot_dev -c "\dt"
```
