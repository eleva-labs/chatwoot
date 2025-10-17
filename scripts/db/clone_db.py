#!/usr/bin/env python3
"""
Clone remote Chatwoot database to local Docker container.

This script:
1. Fetches remote DB credentials from AWS Parameter Store
2. Uses pg_dump to dump remote database
3. Restores dump to local Docker PostgreSQL container
4. Includes safety checks to prevent accidental remote DB modifications
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

# Add scripts directory to path to import get_db_credentials
sys.path.insert(0, str(Path(__file__).parent))

from get_db_credentials import get_db_credentials


# Default tables to exclude (large tables that can bloat dumps)
DEFAULT_EXCLUDES = [
    "conversations",
    "messages",
    "reporting_events",
    "notifications",
]


def run_command(cmd: list, description: str, check=True, capture_output=False):
    """
    Run a shell command with error handling.

    Args:
        cmd: Command as list of strings
        description: Human-readable description for logging
        check: Whether to raise exception on non-zero exit
        capture_output: Whether to capture stdout/stderr

    Returns:
        subprocess.CompletedProcess result
    """
    print(f"[INFO] {description}...")
    try:
        if capture_output:
            result = subprocess.run(cmd, check=check, capture_output=True, text=True)
        else:
            result = subprocess.run(cmd, check=check)
        return result
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] {description} failed!")
        if capture_output and e.stderr:
            print(f"[ERROR] {e.stderr}")
        sys.exit(1)


def check_docker_running():
    """Check if Docker is running."""
    print("[INFO] Checking Docker status...")
    try:
        result = subprocess.run(
            ["docker", "ps"],
            check=True,
            capture_output=True,
            text=True,
        )
        print("[SUCCESS] Docker is running")
        return True
    except subprocess.CalledProcessError:
        print("[ERROR] Docker is not running. Please start Docker first.")
        return False
    except FileNotFoundError:
        print("[ERROR] Docker command not found. Is Docker installed?")
        return False


def check_postgres_container():
    """Check if PostgreSQL container is running."""
    print("[INFO] Checking PostgreSQL container...")
    try:
        result = subprocess.run(
            ["docker", "compose", "ps", "-q", "postgres"],
            check=True,
            capture_output=True,
            text=True,
        )
        container_id = result.stdout.strip()
        if not container_id:
            print("[ERROR] PostgreSQL container is not running.")
            print("[INFO] Start it with: docker compose up -d postgres")
            return False

        print(f"[SUCCESS] PostgreSQL container is running (ID: {container_id[:12]})")
        return True
    except subprocess.CalledProcessError:
        print("[ERROR] Failed to check PostgreSQL container status.")
        return False


def validate_localhost_target():
    """
    Safety check: Ensure we're always writing to localhost.

    This prevents accidental writes to remote databases.
    """
    print("[INFO] Validating target database is localhost...")

    # Check .env file for POSTGRES_HOST
    env_file = Path(".env")
    if env_file.exists():
        with open(env_file, "r") as f:
            for line in f:
                if line.startswith("POSTGRES_HOST="):
                    host = line.split("=", 1)[1].strip()
                    if host not in ["localhost", "postgres", "127.0.0.1"]:
                        print(f"[ERROR] POSTGRES_HOST is set to '{host}'")
                        print(
                            "[ERROR] For safety, local database must be localhost/postgres"
                        )
                        return False

    # Check docker-compose.yaml for postgres service
    compose_file = Path("docker-compose.yaml")
    if not compose_file.exists():
        print("[ERROR] docker-compose.yaml not found")
        return False

    print("[SUCCESS] Target database validated as local Docker container")
    return True


def confirm_operation(env: str, excludes: list, auto_confirm: bool = False):
    """Ask user to confirm the database clone operation."""
    print("\n" + "=" * 70)
    print("⚠️  DATABASE CLONE CONFIRMATION")
    print("=" * 70)
    print(f"Source:      {env.upper()} database (chatwoot)")
    print(f"Target:      LOCAL database (chatwoot_dev)")
    print(f"Action:      DROP and RECREATE local database")
    print(f"Excluded:    {', '.join(excludes) if excludes else 'None'}")
    print("=" * 70)
    print("\n⚠️  WARNING: This will DELETE ALL DATA in your local chatwoot_dev database!")
    print()

    if auto_confirm:
        print("[INFO] Auto-confirmed (--yes flag)")
        print()
        return True

    response = input("Type 'yes' to continue: ").strip().lower()
    if response != "yes":
        print("[INFO] Operation cancelled by user.")
        return False

    print()
    return True


def dump_remote_database(remote_creds: dict, dump_file: str, excludes: list):
    """
    Dump remote database using pg_dump from Docker container.

    Args:
        remote_creds: Dictionary with host, port, database, username, password
        dump_file: Path to output dump file
        excludes: List of table names to exclude
    """
    print("[INFO] Dumping remote database...")

    # Build pg_dump command (runs inside Docker container)
    pg_dump_args = [
        "pg_dump",
        f"--host={remote_creds['host']}",
        f"--port={remote_creds['port']}",
        f"--username={remote_creds['username']}",
        f"--dbname={remote_creds['database']}",
        "--format=custom",  # Custom format for pg_restore
        "--no-owner",  # Don't dump ownership
        "--no-acl",  # Don't dump access privileges
        f"--file=/tmp/remote_dump.dump",  # Dump to container's /tmp
    ]

    # Add table data exclusions (keep schema, exclude data)
    for table in excludes:
        pg_dump_args.append(f"--exclude-table-data={table}")

    # Build docker exec command
    cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "-e",
        f"PGPASSWORD={remote_creds['password']}",
        "postgres",
        "sh",
        "-c",
        " ".join(pg_dump_args),
    ]

    print(f"[INFO] Connecting to {remote_creds['host']}:{remote_creds['port']}")
    print(f"[INFO] Database: {remote_creds['database']}")
    if excludes:
        print(f"[INFO] Excluding table data (keeping schema): {', '.join(excludes)}")

    try:
        subprocess.run(cmd, check=True)
        print(f"[SUCCESS] Database dumped to container /tmp/remote_dump.dump")

        # Copy dump file from container to host
        print(f"[INFO] Copying dump file to host...")
        copy_cmd = [
            "docker",
            "compose",
            "cp",
            "postgres:/tmp/remote_dump.dump",
            dump_file,
        ]
        subprocess.run(copy_cmd, check=True)

        # Clean up container dump file
        cleanup_cmd = [
            "docker",
            "compose",
            "exec",
            "-T",
            "postgres",
            "rm",
            "/tmp/remote_dump.dump",
        ]
        subprocess.run(cleanup_cmd, check=False)  # Don't fail if cleanup fails

        print(f"[SUCCESS] Database dumped to {dump_file}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] pg_dump failed: {e}")
        return False


def restore_local_database(dump_file: str, local_db: str = "chatwoot_dev"):
    """
    Restore dump to local Docker PostgreSQL container.

    Args:
        dump_file: Path to dump file
        local_db: Local database name (default: chatwoot_dev)
    """
    print(f"[INFO] Restoring to local database '{local_db}'...")

    # Step 1: Drop database if exists
    print(f"[INFO] Dropping database '{local_db}' if exists...")
    drop_cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "postgres",
        "psql",
        "-U",
        "postgres",
        "-c",
        f"DROP DATABASE IF EXISTS {local_db};",
    ]
    run_command(drop_cmd, f"Drop database '{local_db}'", check=False)

    # Step 2: Create fresh database
    print(f"[INFO] Creating fresh database '{local_db}'...")
    create_cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "postgres",
        "psql",
        "-U",
        "postgres",
        "-c",
        f"CREATE DATABASE {local_db};",
    ]
    run_command(create_cmd, f"Create database '{local_db}'")

    # Step 3: Restore dump
    print(f"[INFO] Restoring dump to '{local_db}'...")
    restore_cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "postgres",
        "pg_restore",
        "--username=postgres",
        f"--dbname={local_db}",
        "--no-owner",
        "--no-acl",
        "--clean",  # Clean before restore
        "--if-exists",  # Don't error if objects don't exist
    ]

    # Copy dump file into container and restore
    # First, copy dump file to a location accessible by container
    print("[INFO] Copying dump file to Docker container...")
    copy_cmd = ["docker", "compose", "cp", dump_file, f"postgres:/tmp/dump.sql"]
    run_command(copy_cmd, "Copy dump to container")

    # Restore from inside container
    restore_cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "postgres",
        "pg_restore",
        "--username=postgres",
        f"--dbname={local_db}",
        "--no-owner",
        "--no-acl",
        "--clean",
        "--if-exists",
        "/tmp/dump.sql",
    ]

    # Note: pg_restore may show warnings for missing objects during --clean
    # This is expected and not an error
    print("[INFO] Running pg_restore (warnings about missing objects are normal)...")
    result = run_command(restore_cmd, f"Restore to '{local_db}'", check=False)

    # Clean up dump file from container
    cleanup_cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "postgres",
        "rm",
        "/tmp/dump.sql",
    ]
    run_command(cleanup_cmd, "Clean up container dump file", check=False)

    if result.returncode in [0, 1]:  # 0 = success, 1 = warnings (acceptable)
        print(f"[SUCCESS] Database restored to '{local_db}'")
        return True
    else:
        print(f"[ERROR] Database restore failed")
        return False


def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description="Clone remote Chatwoot database to local Docker container",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Clone from dev (with default exclusions)
  python clone_db.py dev

  # Clone from prod (with default exclusions)
  python clone_db.py prod

  # Clone with all tables (no exclusions)
  python clone_db.py dev --no-exclude

  # Clone with custom exclusions
  python clone_db.py dev --exclude reporting_events --exclude notifications

  # Clone with both default and custom exclusions
  python clone_db.py dev --exclude audit_logs

Default excluded table data (schemas are kept): {tables}
        """.format(
            tables=", ".join(DEFAULT_EXCLUDES)
        ),
    )

    parser.add_argument(
        "environment",
        choices=["dev", "prod"],
        help="Source environment (dev or prod)",
    )

    parser.add_argument(
        "--exclude",
        action="append",
        dest="custom_excludes",
        help="Exclude additional table(s). Can be used multiple times.",
    )

    parser.add_argument(
        "--no-exclude",
        action="store_true",
        help="Disable default exclusions (clone ALL tables)",
    )

    parser.add_argument(
        "--keep-dump",
        action="store_true",
        help="Keep dump file after restore (useful for debugging)",
    )

    parser.add_argument(
        "--yes",
        "-y",
        action="store_true",
        help="Skip confirmation prompt (auto-confirm)",
    )

    args = parser.parse_args()

    # Determine exclusions
    if args.no_exclude:
        excludes = args.custom_excludes or []
    else:
        excludes = DEFAULT_EXCLUDES.copy()
        if args.custom_excludes:
            excludes.extend(args.custom_excludes)

    # Remove duplicates
    excludes = list(set(excludes))

    print("=" * 70)
    print("Chatwoot Database Clone Tool")
    print("=" * 70)
    print(f"Source:      {args.environment.upper()}")
    print(f"Target:      LOCAL (chatwoot_dev)")
    print("=" * 70)
    print()

    # Pre-flight checks
    if not check_docker_running():
        sys.exit(1)

    if not check_postgres_container():
        sys.exit(1)

    if not validate_localhost_target():
        sys.exit(1)

    # Get confirmation
    if not confirm_operation(args.environment, excludes, args.yes):
        sys.exit(0)

    # Fetch remote credentials
    print("[INFO] Fetching remote database credentials from AWS Parameter Store...")
    remote_creds = get_db_credentials("chatscomm", args.environment)
    if not remote_creds:
        print("[ERROR] Failed to fetch remote database credentials")
        sys.exit(1)

    # Create temporary dump file
    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".dump",
        prefix=f"chatwoot_{args.environment}_",
        delete=False,
    ) as tmp_file:
        dump_file = tmp_file.name

    try:
        # Dump remote database
        print()
        print("=" * 70)
        print("STEP 1: Dump Remote Database")
        print("=" * 70)
        if not dump_remote_database(remote_creds, dump_file, excludes):
            print("[ERROR] Database dump failed")
            sys.exit(1)

        # Check dump file size
        dump_size = os.path.getsize(dump_file)
        print(f"[INFO] Dump file size: {dump_size / 1024 / 1024:.2f} MB")

        # Restore to local
        print()
        print("=" * 70)
        print("STEP 2: Restore to Local Database")
        print("=" * 70)
        if not restore_local_database(dump_file):
            print("[ERROR] Database restore failed")
            sys.exit(1)

        # Success!
        print()
        print("=" * 70)
        print("✅ DATABASE CLONE COMPLETE!")
        print("=" * 70)
        print(f"Source:      {args.environment.upper()} → chatwoot")
        print(f"Target:      LOCAL → chatwoot_dev")
        print(f"Size:        {dump_size / 1024 / 1024:.2f} MB")
        print(f"Excluded:    {', '.join(excludes) if excludes else 'None'}")
        print("=" * 70)
        print()
        print("You can now use your local database with:")
        print("  task dev-dbconsole")
        print("  docker compose up -d")
        print()

    finally:
        # Clean up dump file
        if not args.keep_dump:
            if os.path.exists(dump_file):
                os.remove(dump_file)
                print(f"[INFO] Cleaned up dump file: {dump_file}")
        else:
            print(f"[INFO] Dump file kept: {dump_file}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[INFO] Operation cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n[ERROR] Unexpected error: {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)
