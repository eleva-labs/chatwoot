#!/usr/bin/env python3
"""
Fetch database credentials from AWS SSM Parameter Store.

Supports both profile-based authentication (local development) and
environment variable authentication (CI/CD pipelines).
"""

import sys
from typing import Dict, Optional

import boto3
from botocore.exceptions import (
    BotoCoreError,
    NoCredentialsError,
    PartialCredentialsError,
    ProfileNotFound,
)


def get_db_credentials(
    project_name: str, env: str, profile_name: str = "chatscomm"
) -> Optional[Dict[str, str]]:
    """
    Get database credentials from AWS SSM Parameter Store.

    Authentication strategy:
    1. Try to use AWS profile if provided (local development)
    2. Fall back to environment variables if profile fails (CI/CD)

    Args:
        project_name: Project name for parameter path (e.g., "chatscomm")
        env: Environment (dev/prod)
        profile_name: AWS profile name (default: "chatscomm")

    Returns:
        Dictionary with keys: host, port, database, username, password
        Returns None if credentials cannot be retrieved
    """
    ssm = None

    # Attempt 1: Try profile-based authentication
    if profile_name and profile_name.lower() not in ["none", ""]:
        try:
            print(f"[INFO] Attempting profile-based authentication: {profile_name}")
            session = boto3.Session(profile_name=profile_name, region_name="us-east-1")
            ssm = session.client("ssm")

            # Verify credentials work by making a simple API call
            ssm.describe_parameters(MaxResults=1)
            print(f"[SUCCESS] Authenticated with AWS profile '{profile_name}'")

        except ProfileNotFound:
            print(
                f"[WARN] AWS profile '{profile_name}' not found in ~/.aws/credentials"
            )
            print("[INFO] Falling back to environment variable authentication")
        except (NoCredentialsError, PartialCredentialsError) as e:
            print(f"[WARN] Profile credentials invalid: {e}")
            print("[INFO] Falling back to environment variable authentication")
        except BotoCoreError as e:
            print(f"[WARN] Profile authentication failed: {e}")
            print("[INFO] Falling back to environment variable authentication")

    # Attempt 2: Fall back to environment variables
    if ssm is None:
        try:
            print("[INFO] Using environment variable authentication")
            print("[INFO] Looking for: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY")
            ssm = boto3.client("ssm", region_name="us-east-1")

            # Verify credentials work
            ssm.describe_parameters(MaxResults=1)
            print("[SUCCESS] Authenticated with environment credentials")

        except (NoCredentialsError, PartialCredentialsError) as e:
            print(f"[ERROR] No valid AWS credentials found: {e}")
            print("[ERROR] Please configure:")
            print("  - Local: AWS profile in ~/.aws/credentials")
            print(
                "  - CI/CD: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
            )
            return None
        except BotoCoreError as e:
            print(f"[ERROR] AWS authentication failed: {e}")
            return None

    # Fetch database parameters
    try:
        print(f"[INFO] Fetching database credentials for /{project_name}/{env}/*")

        # Parameter names we expect (using actual AWS parameter names)
        param_names = [
            f"/{project_name}/{env}/DB_HOST",
            f"/{project_name}/{env}/DB_PORT",
            f"/{project_name}/{env}/CHATWOOT_DB_NAME",
            f"/{project_name}/{env}/DB_USER",
            f"/{project_name}/{env}/DB_PASSWORD",
        ]

        credentials = {}

        for param_name in param_names:
            try:
                response = ssm.get_parameter(Name=param_name, WithDecryption=True)
                # Extract the key name (e.g., DB_HOST from /chatscomm/dev/DB_HOST)
                key = param_name.split("/")[-1]
                credentials[key] = response["Parameter"]["Value"]
            except ssm.exceptions.ParameterNotFound:
                print(f"[WARN] Parameter not found: {param_name}")
                continue

        # Map to simpler keys
        db_creds = {
            "host": credentials.get("DB_HOST"),
            "port": credentials.get("DB_PORT", "5432"),
            "database": credentials.get("CHATWOOT_DB_NAME", "chatwoot"),
            "username": credentials.get("DB_USER"),
            "password": credentials.get("DB_PASSWORD"),
        }

        # Validate all required fields are present
        missing = [k for k, v in db_creds.items() if not v]
        if missing:
            print(f"[ERROR] Missing required database credentials: {', '.join(missing)}")
            return None

        print(f"[SUCCESS] Retrieved database credentials")
        print(f"  Host: {db_creds['host']}")
        print(f"  Port: {db_creds['port']}")
        print(f"  Database: {db_creds['database']}")
        print(f"  Username: {db_creds['username']}")

        return db_creds

    except Exception as e:  # pylint: disable=broad-exception-caught
        print(f"[ERROR] Failed to fetch database credentials: {e}")
        return None


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("[ERROR] Invalid arguments")
        print("Usage: python get_db_credentials.py <environment>")
        print("\nExamples:")
        print("  python get_db_credentials.py dev")
        print("  python get_db_credentials.py prod")
        sys.exit(1)

    environment = sys.argv[1]

    print("=" * 70)
    print("AWS SSM Database Credential Fetcher")
    print("=" * 70)
    print(f"Project:     chatscomm")
    print(f"Environment: {environment}")
    print("=" * 70)
    print()

    creds = get_db_credentials("chatscomm", environment)

    if creds:
        print()
        print("[SUCCESS] Database credentials retrieved!")
        sys.exit(0)
    else:
        print()
        print("[ERROR] Failed to retrieve database credentials.")
        sys.exit(1)
