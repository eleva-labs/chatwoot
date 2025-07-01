# frozen_string_literal: true

module Shopify
  module Concerns
    module AccountResolver
      extend ActiveSupport::Concern

      private

      def resolve_account(shop_domain)
        return nil if shop_domain.blank?

        Rails.logger.debug "Starting account resolution", {
          shop_domain: shop_domain,
          job_class: self.class.name
        }

        # Find the integration hook for this shop
        integration_hook = find_integration_hook(shop_domain)
        return nil unless integration_hook

        # Get the associated account
        account = integration_hook.account
        return nil unless account&.active?

        Rails.logger.debug "Resolved account for shop", {
          shop_domain: shop_domain,
          account_id: account.id,
          account_name: account.name,
          hook_id: integration_hook.id
        }

        account
      rescue StandardError => e
        Rails.logger.error "Error resolving account", {
          shop_domain: shop_domain,
          error: e.message,
          backtrace: e.backtrace.first(3),
          job_class: self.class.name
        }
        nil
      end

      def find_integration_hook(shop_domain)
        # Primary: exact match on reference_id (shop domain)
        hook = Integrations::Hook.active
                                 .where(app_id: 'shopify')
                                 .where(reference_id: shop_domain)
                                 .first

        return hook if hook

        # Fallback: try with normalized domain (add .myshopify.com if missing)
        normalized_domain = normalize_shop_domain(shop_domain)
        if normalized_domain != shop_domain
          Rails.logger.debug "Trying normalized domain fallback", {
            original_domain: shop_domain,
            normalized_domain: normalized_domain,
            job_class: self.class.name
          }

          hook = Integrations::Hook.active
                                   .where(app_id: 'shopify')
                                   .where(reference_id: normalized_domain)
                                   .first

          if hook
            Rails.logger.info "Account resolved using normalized domain", {
              original_domain: shop_domain,
              normalized_domain: normalized_domain,
              hook_id: hook.id
            }
          end

          return hook
        end

        # Log available hooks for debugging if no match found
        log_available_hooks_for_debugging(shop_domain)
        nil
      end

      def normalize_shop_domain(domain)
        return domain if domain.include?('.myshopify.com')
        "#{domain}.myshopify.com"
      end

      def log_available_hooks_for_debugging(shop_domain)
        available_hooks = Integrations::Hook.where(app_id: 'shopify')
                                            .active
                                            .limit(5)
                                            .pluck(:reference_id, :id)

        Rails.logger.warn "No integration hook found for shop domain", {
          requested_domain: shop_domain,
          available_shopify_hooks: available_hooks.map { |ref_id, id| { reference_id: ref_id, hook_id: id } },
          total_shopify_hooks: Integrations::Hook.where(app_id: 'shopify').active.count,
          job_class: self.class.name
        }
      rescue StandardError => e
        Rails.logger.debug "Could not fetch debug information", {
          error: e.message,
          shop_domain: shop_domain
        }
      end

      def log_account_not_found
        Rails.logger.warn "Account not found for shop_domain", job_context.merge({
          resolution_attempted: true,
          fallback_attempted: true
        })
      end
    end
  end
end 