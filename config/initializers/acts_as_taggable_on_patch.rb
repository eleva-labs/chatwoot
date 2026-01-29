# frozen_string_literal: true

# Backwards compatibility patch for acts-as-taggable-on gem
#
# The upstream Chatwoot migration 20231211010807_add_cached_labels_list.rb
# references ActsAsTaggableOn::Taggable::Cache, but in gem version 12.0.0+
# this was renamed to ActsAsTaggableOn::Taggable::Caching.
#
# This patch provides the old constant name to allow the migration to run.
# We cannot modify the upstream migration file per our dual migration system rules.

if defined?(ActsAsTaggableOn::Taggable::Caching) && !defined?(ActsAsTaggableOn::Taggable::Cache)
  ActsAsTaggableOn::Taggable::Cache = ActsAsTaggableOn::Taggable::Caching
end
