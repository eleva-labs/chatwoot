require 'stripe'

# The initializer:
# Loads the Stripe Ruby SDK - The require 'stripe' statement loads the Stripe gem
# Sets the Global API Key - Configures Stripe's global API key from the STRIPE_SECRET_KEY environment variable
# Sets explicit API version - Prevents breaking changes from gem updates (Stripe best practice)
# Runs at Application Boot - This configuration happens when Rails starts up, making Stripe available throughout the application

Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', nil)
Stripe.api_version = '2024-12-18.acacia'

# Log the version being used
Rails.logger.info "Stripe API version: #{Stripe.api_version}" if Stripe.api_key.present?
