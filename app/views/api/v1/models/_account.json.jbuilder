json.settings resource.settings
json.created_at resource.created_at
if resource.custom_attributes.present?
  json.custom_attributes do
    json.plan_name resource.custom_attributes['plan_name']
    json.subscription_status resource.custom_attributes['subscription_status']
    json.subscription_ends_on resource.custom_attributes['subscription_ends_on']
    json.trial_expires_in_days resource.custom_attributes['trial_expires_in_days'] if resource.custom_attributes['trial_expires_in_days'].present?
    json.store_id resource.custom_attributes['store_id'] if resource.custom_attributes['store_id'].present?
    json.industry resource.custom_attributes['industry'] if resource.custom_attributes['industry'].present?
    json.company_size resource.custom_attributes['company_size'] if resource.custom_attributes['company_size'].present?
    json.timezone resource.custom_attributes['timezone'] if resource.custom_attributes['timezone'].present?
    json.logo resource.custom_attributes['logo'] if resource.custom_attributes['logo'].present?
    json.onboarding_step resource.custom_attributes['onboarding_step'] if resource.custom_attributes['onboarding_step'].present?
    json.onboarding_completed resource.custom_attributes['onboarding_completed'] if resource.custom_attributes['onboarding_completed'].present?
    json.marked_for_deletion_at resource.custom_attributes['marked_for_deletion_at'] if resource.custom_attributes['marked_for_deletion_at'].present?
    if resource.custom_attributes['marked_for_deletion_reason'].present?
      json.marked_for_deletion_reason resource.custom_attributes['marked_for_deletion_reason']
    end
    json.ai_token_balance_status resource.custom_attributes['ai_token_balance_status'] if resource.custom_attributes['ai_token_balance_status'].present?
    json.ai_token_balance_status_updated_at resource.custom_attributes['ai_token_balance_status_updated_at'] if resource.custom_attributes['ai_token_balance_status_updated_at'].present?
    if resource.custom_attributes['ai_token_impacted_conversations_count'].present?
      json.ai_token_impacted_conversations_count resource.custom_attributes['ai_token_impacted_conversations_count'].to_i
    end
  end
end
json.domain @account.domain
json.features @account.enabled_features
json.custom_features @account.custom_features
json.custom_features_metadata CustomFeaturesManagerService.instance.features_with_metadata
json.id @account.id
json.locale @account.locale
json.name @account.name
json.support_email @account.support_email
json.status @account.status
json.cache_keys @account.cache_keys
