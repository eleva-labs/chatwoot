#!/bin/sh
set -e

# Color output for better visibility
info() { echo "ℹ️  [ENTRYPOINT] $*"; }
success() { echo "✅ [ENTRYPOINT] $*"; }
error() { echo "❌ [ENTRYPOINT] $*" >&2; }

# Detect container type from command arguments
CONTAINER_TYPE="unknown"
if echo "$*" | grep -q "rails.*server\|rails.*s"; then
  CONTAINER_TYPE="web"
elif echo "$*" | grep -q "sidekiq"; then
  CONTAINER_TYPE="worker"
fi

info "Container type: $CONTAINER_TYPE"
info "Command: $*"

# Run migrations ONLY for web containers
if [ "$CONTAINER_TYPE" = "web" ]; then
  info "Running database migrations..."

  # Use chatwoot_prepare which handles both fresh DB and migrations
  # POSTGRES_STATEMENT_TIMEOUT prevents hanging on slow migrations
  if POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare; then
    success "Database migrations completed successfully"
  else
    error "Database migrations failed! Container will not start."
    exit 1
  fi
else
  info "Skipping migrations for non-web container"
fi

# Execute the actual container command
info "Starting: $*"
exec "$@"
