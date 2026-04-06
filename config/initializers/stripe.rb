require 'stripe'

# The initializer:
# Loads the Stripe Ruby SDK - The require 'stripe' statement loads the Stripe gem
# Sets the Global API Key - Configures Stripe's global API key from the STRIPE_SECRET_KEY environment variable
# Sets explicit API version - Prevents breaking changes from gem updates (Stripe best practice)
# Runs at Application Boot - This configuration happens when Rails starts up, making Stripe available throughout the application

Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', nil)

# API version 2025-06-30.basil or later is REQUIRED for flexible billing mode support
# Flexible billing mode provides:
# - More accurate proration calculations based on actual debited amounts
# - Improved trial handling with preserved trial end dates
# - Better usage-based billing timing
# - Access to new features like mixed-interval subscriptions
# See: docs/ignore/ClassicToFlexible.md and docs/ignore/BreakingChanges_Acacia_to_Basil.md
Stripe.api_version = '2025-06-30.basil'

# Log the version being used
Rails.logger.info "Stripe API version: #{Stripe.api_version}" if Stripe.api_key.present?
