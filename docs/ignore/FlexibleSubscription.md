billing_mode

dictionary

Controls how prorations and invoices for subscriptions are calculated and orchestrated.



Hide child parameters



billing_mode.type

enum

Required

Controls the calculation and orchestration of prorations and invoices for subscriptions. If no value is passed, the default is flexible.



Possible enum values

classic

Calculations for subscriptions and invoices are based on legacy defaults.



flexible

Supports more flexible calculation and orchestration options for subscriptions and invoices.





billing_mode.flexible

dictionary

Configure behavior for flexible billing mode.



Hide child parameters



billing_mode.flexible.proration_discounts

enum

Controls how invoices and invoice items display proration amounts and discount amounts.



Possible enum values

included

Amounts are net of discounts, and discount amounts are zero.



itemized

Amounts are gross of discounts, and discount amounts are accurate.



# Enable increased flexibility for subscriptions

Use flexible billing mode for enhanced functionality and to access additional features.

You can set your preferred billing mode to orchestrate your invoices and subscriptions to meet your business requirements. You can configure each subscription to use one of two billing modes:

- **Flexible** (Recommended): Provides accurate and predictable billing behavior and new capabilities. To access these improvements, which are only available in flexible billing mode, you must create new subscriptions with flexible billing mode or migrate your existing subscriptions.
- **Classic**: Uses the existing Stripe subscription behavior. This setting is maintained for backward compatibility with older integrations.

You can [learn more](https://docs.stripe.com/billing/subscriptions/billing-mode/compare.md) about the detailed differences between classic and flexible billing mode and how to choose the billing mode that works best for you.

## Why flexible billing mode

Flexible billing mode provides more accurate billing for prorations, usage-based pricing, flexible invoicing, and trial settings. It also unlocks new capabilities such as [mixed intervals on the same subscription](https://docs.stripe.com/billing/subscriptions/mixed-interval.md). These improvements are only available in flexible billing mode, which is why we recommend creating new subscriptions with flexible billing mode and [migrating](https://docs.stripe.com/billing/subscriptions/billing-mode.md#migrate-existing-subscriptions-to-flexible-billing-mode) your existing ones.

We recommend that new Billing users use flexible billing mode for subscriptions and invoices, although we don’t require it.

For existing users, your default billing mode is preserved as classic to maintain backward compatibility with your current integration. However, we recommend migrating to flexible billing mode to take advantage of the latest billing features and improvements. Learn more about the [differences between classic and flexible billing mode](https://docs.stripe.com/billing/subscriptions/billing-mode/compare.md).

## Get started with flexible billing mode

You can set or update the billing mode through the API or Dashboard when you create or migrate subscriptions. We apply a default billing mode if you don’t specify one.

- If you create or update a subscription through the API, the default value for billing mode depends on your [API integration version](https://docs.stripe.com/upgrades.md#how-can-i-upgrade-my-api).
- If you create or update subscriptions through the Dashboard (including [Payment Links](https://docs.stripe.com/payment-links.md) and [Pricing Tables](https://docs.stripe.com/payments/checkout/pricing-table.md)), the default value depends on the [billing mode default setting](https://dashboard.stripe.com/settings/billing/subscriptions) you configure in **Settings** > **Billing** > **Subscriptions and emails**.

To use flexible billing mode, your integration must be on Stripe API version [2025-06-30.basil](https://docs.stripe.com/changelog/basil.md#2025-06-30.basil) or later. Learn how to [upgrade your API version](https://docs.stripe.com/upgrades.md#how-can-i-upgrade-my-api).

### Create a new subscription with flexible billing mode

#### Dashboard

You can create a flexible billing mode subscription or update a classic billing mode subscription to be flexible through the Dashboard, regardless of your integration’s API version. To fully modify these subscriptions in the Stripe API, your integration must be on [2025-06-30.basil](https://docs.stripe.com/changelog/basil.md#2025-06-30.basil)  or later. To see what version you’re on, go to the [Workbench overview](https://dashboard.stripe.com/workbench/overview) and look at the API versions section. From there, click **Upgrade** to upgrade to a newer version.

Follow the steps below to create a flexible billing mode subscription through the subscription editor:

1. Go to the [Subscriptions page](https://dashboard.stripe.com/subscriptions?status=active) in the Dashboard.
1. Select **+Create Subscription**.
1. Scroll down to the **Advanced settings** section.
1. Set **Billing mode** to **Flexible**.

The default billing mode value depends on your account settings. You can customize the displayed billing mode options and the default selection in **Advanced settings** by configuring the [billing mode default setting](https://dashboard.stripe.com/settings/billing/subscriptions) under **Settings** > **Billing** > **Subscriptions and emails**. In the subscription editor, you can choose to display billing mode options from the following:

- **Classic:** Both flexible and classic billing modes are displayed, with classic selected by default. This option is recommended if your integration depends on classic billing mode and you cannot migrate to flexible billing yet.
- **Flexible:** Both flexible and classic billing modes are displayed, with flexible selected by default. This option is recommended if you are actively migrating to flexible billing mode.
- **Flexible and hide classic:** Only flexible billing mode is displayed in the subscription editor. This option is recommended for new Stripe Billing users and for existing users who exclusively use flexible billing mode.

The billing mode default setting also determines the billing mode for subscriptions created through Dashboard-generated Payment Links and Pricing Tables. For example, if you set the billing mode default to flexible and then create a Payment Link in the Dashboard, any subscription generated from that Payment Link uses flexible billing mode.

The billing mode default setting only applies to new subscriptions created in the Dashboard. It doesn’t affect subscriptions created using the API or subscriptions migrated to flexible mode.

#### API

You can provide the [billing_mode](https://docs.stripe.com/api/subscriptions/create.md#create_subscription-billing_mode) parameter as `flexible` on API requests that create a subscription or preview an invoice for a subscription.

If you don’t provide this parameter, its default value depends on the API version you’re using:

- For API version `2025-08-27.preview` and any later preview version, and for `2025-09-30.clover` (GA) and any later GA version, the default is flexible.
- For all other API versions, the default is `classic`.

This API version logic also determines the billing mode for subscriptions generated by Payment Links and Pricing Tables.

Here’s an example when using the Subscriptions API:

```curl
curl https://api.stripe.com/v1/subscriptions \
  -u "<<YOUR_SECRET_KEY>>:" \
  -H "Stripe-Version: 2025-06-30.basil" \
  -d "items[0][price]"="{{PRICE_ID}}" \
  -d customer="{{CUSTOMER_ID}}" \
  -d "billing_mode[type]"=flexible \
  -d payment_behavior=default_incomplete \
  -d "payment_settings[save_default_payment_method]"=on_subscription
```

```cli
stripe subscriptions create  \
  -d "items[0][price]"="{{PRICE_ID}}" \
  --customer="{{CUSTOMER_ID}}" \
  -d "billing_mode[type]"=flexible \
  --payment-behavior=default_incomplete \
  -d "payment_settings[save_default_payment_method]"=on_subscription
```

```ruby
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
client = Stripe::StripeClient.new("<<YOUR_SECRET_KEY>>")

subscription = client.v1.subscriptions.create({
  items: [{price: '{{PRICE_ID}}'}],
  customer: '{{CUSTOMER_ID}}',
  billing_mode: {type: 'flexible'},
  payment_behavior: 'default_incomplete',
  payment_settings: {save_default_payment_method: 'on_subscription'},
})
```

```python
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
client = StripeClient("<<YOUR_SECRET_KEY>>")

# For SDK versions 12.4.0 or lower, remove '.v1' from the following line.
subscription = client.v1.subscriptions.create({
  "items": [{"price": "{{PRICE_ID}}"}],
  "customer": "{{CUSTOMER_ID}}",
  "billing_mode": {"type": "flexible"},
  "payment_behavior": "default_incomplete",
  "payment_settings": {"save_default_payment_method": "on_subscription"},
})
```

```php
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
$stripe = new \Stripe\StripeClient('<<YOUR_SECRET_KEY>>');

$subscription = $stripe->subscriptions->create([
  'items' => [['price' => '{{PRICE_ID}}']],
  'customer' => '{{CUSTOMER_ID}}',
  'billing_mode' => ['type' => 'flexible'],
  'payment_behavior' => 'default_incomplete',
  'payment_settings' => ['save_default_payment_method' => 'on_subscription'],
]);
```

```java
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
StripeClient client = new StripeClient("<<YOUR_SECRET_KEY>>");

SubscriptionCreateParams params =
  SubscriptionCreateParams.builder()
    .addItem(
      SubscriptionCreateParams.Item.builder().setPrice("{{PRICE_ID}}").build()
    )
    .setCustomer("{{CUSTOMER_ID}}")
    .setBillingMode(
      SubscriptionCreateParams.BillingMode.builder()
        .setType(SubscriptionCreateParams.BillingMode.Type.FLEXIBLE)
        .build()
    )
    .setPaymentBehavior(SubscriptionCreateParams.PaymentBehavior.DEFAULT_INCOMPLETE)
    .setPaymentSettings(
      SubscriptionCreateParams.PaymentSettings.builder()
        .setSaveDefaultPaymentMethod(
          SubscriptionCreateParams.PaymentSettings.SaveDefaultPaymentMethod.ON_SUBSCRIPTION
        )
        .build()
    )
    .build();

// For SDK versions 29.4.0 or lower, remove '.v1()' from the following line.
Subscription subscription = client.v1().subscriptions().create(params);
```

```node
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
const stripe = require('stripe')('<<YOUR_SECRET_KEY>>');

const subscription = await stripe.subscriptions.create({
  items: [
    {
      price: '{{PRICE_ID}}',
    },
  ],
  customer: '{{CUSTOMER_ID}}',
  billing_mode: {
    type: 'flexible',
  },
  payment_behavior: 'default_incomplete',
  payment_settings: {
    save_default_payment_method: 'on_subscription',
  },
});
```

```go
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
sc := stripe.NewClient("<<YOUR_SECRET_KEY>>")
params := &stripe.SubscriptionCreateParams{
  Items: []*stripe.SubscriptionCreateItemParams{
    &stripe.SubscriptionCreateItemParams{Price: stripe.String("{{PRICE_ID}}")},
  },
  Customer: stripe.String("{{CUSTOMER_ID}}"),
  BillingMode: &stripe.SubscriptionCreateBillingModeParams{
    Type: stripe.String(stripe.SubscriptionBillingModeTypeFlexible),
  },
  PaymentBehavior: stripe.String("default_incomplete"),
  PaymentSettings: &stripe.SubscriptionCreatePaymentSettingsParams{
    SaveDefaultPaymentMethod: stripe.String(stripe.SubscriptionPaymentSettingsSaveDefaultPaymentMethodOnSubscription),
  },
}
result, err := sc.V1Subscriptions.Create(context.TODO(), params)
```

```dotnet
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
var options = new SubscriptionCreateOptions
{
    Items = new List<SubscriptionItemOptions>
    {
        new SubscriptionItemOptions { Price = "{{PRICE_ID}}" },
    },
    Customer = "{{CUSTOMER_ID}}",
    BillingMode = new SubscriptionBillingModeOptions { Type = "flexible" },
    PaymentBehavior = "default_incomplete",
    PaymentSettings = new SubscriptionPaymentSettingsOptions
    {
        SaveDefaultPaymentMethod = "on_subscription",
    },
};
var client = new StripeClient("<<YOUR_SECRET_KEY>>");
var service = client.V1.Subscriptions;
Subscription subscription = service.Create(options);
```

Here’s the response:

```json
{"id": "sub_JgRjFjhKbtD2qz",
  "object": "subscription",
  "billing_mode": {
    "flexible": {
      "proration_discounts": "included"
    },
    "type": "flexible",
    "updated_at": 1751071020
  },
  "application_fee_percent": null,
  "automatic_tax": {
    "disabled_reason": null,
    "enabled": false,
    "liability": "null"
  },
  "billing_cycle_anchor": 1623873347,
  "billing_cycle_anchor_config": null,
  "cancel_at": null,
  "cancel_at_period_end": false,
  "canceled_at": null,
  "cancellation_details": {
    comment: null,
    feedback: null,
    reason: null
  },
  "collection_method": "charge_automatically",
  "created": 1623873347,
  "currency": "usd","customer": "cus_CMqDWO2xODTZqt",
  "days_until_due": null,
  "default_payment_method": null,
  "default_source": null,
  "default_tax_rates": [

  ],
  "discounts": [],
  "ended_at": null,
  "invoice_customer_balance_settings": {
    "account_tax_ids": null,
    issuer: {
      type: "self"
    }
  },
  "items": {
    "object": "list",
    "data": [
      {
        "id": "si_JgRjmS4Ur1khEx",
        "object": "subscription_item",
        "created": 1623873347,"current_period_end": 1626465347,
        "current_period_start": 1623873347,
        discounts: [],
        "metadata": {
        },
        "plan": {
          "id": "price_1J32RfGPZ1iASj5zHHp57z7C",
          "object": "plan",
          "active": true,
          "amount": 2000,
          "amount_decimal": "2000",
          "billing_scheme": "per_unit",
          "created": 1623864151,
          "currency": "usd",
          "interval": "month",
          "interval_count": 1,
          "livemode": false,
          "metadata": {
          },
          "nickname": null,
          "product": "prod_JgPF5xnq7qBun3",
          "tiers": null,
          "tiers_mode": null,
          "transform_usage": null,
          "trial_period_days": null,
          "usage_type": "licensed"
        },
        "price": {
          "id": "price_1J32RfGPZ1iASj5zHHp57z7C",
          "object": "price",
          "active": true,
          "billing_scheme": "per_unit",
          "created": 1623864151,
          "currency": "usd",
          "livemode": false,
          "lookup_key": null,
          "metadata": {
          },
          "nickname": null,
          "product": "prod_JgPF5xnq7qBun3",
          "recurring": {
            "interval": "month",
            "interval_count": 1,
            "trial_period_days": null,
            "usage_type": "licensed"
          },
          "tiers_mode": null,
          "transform_quantity": null,
          "type": "recurring",
          "unit_amount": 2000,
          "unit_amount_decimal": "2000"
        },
        "quantity": 1,
        "subscription": "sub_JgRjFjhKbtD2qz",
        "tax_rates": [

        ]
      }
    ],
    "has_more": false,
    "total_count": 1,
    "url": "/v1/subscription_items?subscription=sub_JgRjFjhKbtD2qz"
  },
  "latest_invoice": {
    "id": "in_1J34pzGPZ1iASj5zB87qdBNZ",
    "object": "invoice",
    "account_country": "US",
    "account_name": "Angelina's Store",
    "account_tax_ids": null,
    "amount_due": 2000,
    "amount_overpaid": 0,
    "amount_paid": 0,
    "amount_remaining": 2000,
    "amount_shipping": 0,
    "attempt_count": 0,
    "attempted": false,
    "auto_advance": false,
    "automatic_tax": {
      "disabled_reason": null,
      "enabled": false,
      liability: null,
      "status": null
    },
    "automatically_finalizes_at": null,
    "billing_reason": "subscription_update",
    "collection_method": "charge_automatically",
    "created": 1623873347,
    "currency": "usd",
    "custom_fields": null,
    "customer": "cus_CMqDWO2xODTZqt",
    "customer_address": null,
    "customer_email": "angelina@stripe.com",
    "customer_name": null,
    "customer_phone": null,
    "customer_shipping": {
      "address": {
        "city": "",
        "country": "US",
        "line1": "Berry",
        "line2": "",
        "postal_code": "",
        "state": ""
      },
      "name": "",
      "phone": null
    },
    "customer_tax_exempt": "none",
    "customer_tax_ids": [

    ],
    "default_payment_method": null,
    "default_source": null,
    "default_tax_rates": [

    ],
    "description": null,
    "discounts": [],
    "due_date": null,
    "effective_at": "1623873347",
    "ending_balance": 0,
    "footer": null,
    "from_invoice": null,
    "hosted_invoice_url": "https://invoice.stripe.com/i/acct_1By64KGPZ1iASj5z/invst_JgRjzIOILGeq2MKC9T0KtyXnD5udsLp",
    "invoice_pdf": "https://pay.stripe.com/invoice/acct_1By64KGPZ1iASj5z/invst_JgRjzIOILGeq2MKC9T0KtyXnD5udsLp/pdf",
    "last_finalization_error": null,
    "latest_revision": null,
    "lines": {
      "object": "list",
      "data": [
        {
          "id": "il_1N2CjMBwKQ696a5NeOawRQP2",
          "object": "line_item",
          "amount": 2000,
          "currency": "usd",
          "description": "1 × Gold Special (at $20.00 / month)",
          "discount_amounts": [

          ],
          "discountable": true,
          "discounts": [

          ],
          "invoice": "in_1J34pzGPZ1iASj5zB87qdBNZ",
          "livemode": false,
          "metadata": {
          },
          "parent": {
            "invoice_item_details": null,
            "subscription_item_details":
            {
              "invoice_item": null
            "proration": false
            "proration_details":
            {
              "credited_items": null
            }
            subscription:
            "sub_JgRjFjhKbtD2qz"
            subscription_item:
              "si_JgRjmS4Ur1khEx"
            }
            type: "subscription_item_details"
          },
          "period": {
            "end": 1626465347,
            "start": 1623873347
          },
          "plan": {
            "id": "price_1J32RfGPZ1iASj5zHHp57z7C",
            "object": "plan",
            "active": true,
            "amount": 2000,
            "amount_decimal": "2000",
            "billing_scheme": "per_unit",
            "created": 1623864151,
            "currency": "usd",
            "interval": "month",
            "interval_count": 1,
            "livemode": false,
            "metadata": {
            },
            "nickname": null,
            "product": "prod_JgPF5xnq7qBun3",
            "tiers": null,
            "tiers_mode": null,
            "transform_usage": null,
            "trial_period_days": null,
            "usage_type": "licensed"
          },
          "price": {
            "id": "price_1J32RfGPZ1iASj5zHHp57z7C",
            "object": "price",
            "active": true,
            "billing_scheme": "per_unit",
            "created": 1623864151,
            "currency": "usd",
            "livemode": false,
            "lookup_key": null,
            "metadata": {
            },
            "nickname": null,
            "product": "prod_JgPF5xnq7qBun3",
            "recurring": {
              "interval": "month",
              "interval_count": 1,
              "trial_period_days": null,
              "usage_type": "licensed"
            },
            "tiers_mode": null,
            "transform_quantity": null,
            "type": "recurring",
            "unit_amount": 2000,
            "unit_amount_decimal": "2000"
          },
          "quantity": 1,
          "taxes": [],
        }
      ],
      "has_more": false,
      "total_count": 1,
      "url": "/v1/invoices/in_1J34pzGPZ1iASj5zB87qdBNZ/lines"
    },
    "livemode": false,
    "metadata": {
    },
    "next_payment_attempt": null,
    "number": "C008FC2-0354",
    "on_behalf_of": null,
    "parent": {
      "quote_details": null,
      "subscription_details": {
        "metadata": {},
        "pause_collection": null,
        "subscription": "sub_JgRjFjhKbtD2qz",
      }
    }
    "payment_intent": {
      "id": "pi_1J34pzGPZ1iASj5zI2nOAaE6",
      "object": "payment_intent",
      "allowed_source_types": [
        "card"
      ],
      "amount": 2000,
      "amount_capturable": 0,
      "amount_received": 0,
      "application": null,
      "application_fee_amount": null,
      "canceled_at": null,
      "cancellation_reason": null,
      "capture_method": "automatic",
      "charges": {
        "object": "list",
        "data": [

        ],
        "has_more": false,
        "total_count": 0,
        "url": "/v1/charges?payment_intent=pi_1J34pzGPZ1iASj5zI2nOAaE6"
      },
      "client_secret": "pi_1J34pzGPZ1iASj5zI2nOAaE6_secret_l7FN6ldFfXiFmJEumenJ2y2wu",
      "confirmation_method": "automatic",
      "created": 1623873347,
      "currency": "usd",
      "customer": "cus_CMqDWO2xODTZqt",
      "description": "Subscription creation",
      "invoice": "in_1J34pzGPZ1iASj5zB87qdBNZ",
      "last_payment_error": null,
      "livemode": false,
      "metadata": {
      },
      "next_action": null,
      "next_source_action": null,
      "on_behalf_of": null,
      "payment_method": null,
      "payment_method_options": {
        "card": {
          "installments": null,
          "network": null,
          "request_three_d_secure": "automatic"
        }
      },
      "payment_method_types": [
        "card"
      ],
      "receipt_email": null,
      "review": null,
      "setup_future_usage": "off_session",
      "shipping": null,
      "source": "card_1By6iQGPZ1iASj5z7ijKBnXJ",
      "statement_descriptor": null,
      "statement_descriptor_suffix": null,
      "status": "requires_confirmation",
      "transfer_data": null,
      "transfer_group": null
    },
    "payment_settings": {
      "payment_method_options": null,
      "payment_method_types": null,
      "save_default_payment_method": "on_subscription"
    },
    "period_end": 1623873347,
    "period_start": 1623873347,
    "post_payment_credit_notes_amount": 0,
    "pre_payment_credit_notes_amount": 0,
    "receipt_number": null,
    "starting_balance": 0,
    "statement_descriptor": null,
    "status": "open",
    "status_transitions": {
      "finalized_at": 1623873347,
      "marked_uncollectible_at": null,
      "paid_at": null,
      "voided_at": null
    },
    "subscription": "sub_JgRjFjhKbtD2qz",
    "subtotal": 2000,
    "tax": null,
    "tax_percent": null,
    "total": 2000,
    "total_discount_amounts": [],
    "total_tax_amounts": [],
    "transfer_data": null,
    "webhooks_delivered_at": 1623873347
  },
  "livemode": false,
  "metadata": {
  },
  "next_pending_invoice_item_invoice": null,
  "pause_collection": null,
  "pending_invoice_item_interval": null,
  "pending_setup_intent": null,
  "pending_update": null,
  "plan": {
    "id": "price_1J32RfGPZ1iASj5zHHp57z7C",
    "object": "plan",
    "active": true,
    "amount": 2000,
    "amount_decimal": "2000",
    "billing_scheme": "per_unit",
    "created": 1623864151,
    "currency": "usd",
    "interval": "month",
    "interval_count": 1,
    "livemode": false,
    "metadata": {
    },
    "nickname": null,
    "product": "prod_JgPF5xnq7qBun3",
    "tiers": null,
    "tiers_mode": null,
    "transform_usage": null,
    "trial_period_days": null,
    "usage_type": "licensed"
  },
  "quantity": 1,
  "schedule": null,
  "start": 1623873347,
  "start_date": 1623873347,
  "status": "incomplete",
  "tax_percent": null,
  "transfer_data": null,
  "trial_end": null,
  "trial_start": null
}
```

Similarly, you can set `billing_mode` to `flexible` when creating a subscription from the following sources:

- A [Checkout Session](https://docs.stripe.com/api/checkout/sessions/create.md?&rds=1#create_checkout_session-billing_mode)
- A [Subscription Schedule](https://docs.stripe.com/api/subscription_schedules/create.md?&rds=1#create_subscription_schedule-billing_mode)
- A [Quote](https://docs.stripe.com/api/quotes/create.md?&rds=1#create_quote-billing_mode)

### Migrate existing subscriptions to flexible billing mode

You can migrate your existing subscriptions to flexible billing mode. The flexible behaviors take effect for all new activity on the subscription after migration. However, Stripe doesn’t recalculate any resources created before migration, including pending proration Invoice Items.

#### Dashboard

To use flexible billing mode, your integration must be on Stripe API version [2025-06-30.basil](https://docs.stripe.com/changelog/basil.md#2025-06-30.basil) or later. To see what version you’re on, go to the Workbench overview and look at the **API versions** section. From there, click **Upgrade** to upgrade to a newer version.

1. On the [Subscriptions page](https://dashboard.stripe.com/subscriptions?status=active) in the Dashboard, select the subscription that you’d like to migrate.
1. Select **Actions** and then **Update subscription**.
1. Scroll down to the **Advanced settings** section.
1. Set **Billing mode** to **Flexible** and select **Update subscription**.

#### API

To use flexible billing mode, you must [upgrade your API version](https://docs.stripe.com/upgrades.md#how-can-i-upgrade-my-api) to [2025-06-30.basil](https://docs.stripe.com/changelog/basil.md#2025-06-30.basil) or later.

Use the [migrate API](https://docs.stripe.com/api/subscriptions/migrate.md) to set `billing_mode` to `flexible` for an existing subscription. After the subscription is migrated to flexible billing mode, the `billing_mode.updated_at` timestamp reflects when the migration occurred. Here are an example request and response:

```curl
curl https://api.stripe.com/v1/subscriptions/sub_123/migrate \
  -u "<<YOUR_SECRET_KEY>>:" \
  -d "billing_mode[type]"=flexible
```

```cli
stripe subscriptions migrate sub_123 \
  -d "billing_mode[type]"=flexible
```

```ruby
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
client = Stripe::StripeClient.new("<<YOUR_SECRET_KEY>>")

subscription = client.v1.subscriptions.migrate(
  'sub_123',
  {billing_mode: {type: 'flexible'}},
)
```

```python
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
client = StripeClient("<<YOUR_SECRET_KEY>>")

# For SDK versions 12.4.0 or lower, remove '.v1' from the following line.
subscription = client.v1.subscriptions.migrate(
  "sub_123",
  {"billing_mode": {"type": "flexible"}},
)
```

```php
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
$stripe = new \Stripe\StripeClient('<<YOUR_SECRET_KEY>>');

$subscription = $stripe->subscriptions->migrate(
  'sub_123',
  ['billing_mode' => ['type' => 'flexible']]
);
```

```java
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
StripeClient client = new StripeClient("<<YOUR_SECRET_KEY>>");

SubscriptionMigrateParams params =
  SubscriptionMigrateParams.builder()
    .setBillingMode(
      SubscriptionMigrateParams.BillingMode.builder()
        .setType(SubscriptionMigrateParams.BillingMode.Type.FLEXIBLE)
        .build()
    )
    .build();

// For SDK versions 29.4.0 or lower, remove '.v1()' from the following line.
Subscription subscription = client.v1().subscriptions().migrate("sub_123", params);
```

```node
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
const stripe = require('stripe')('<<YOUR_SECRET_KEY>>');

const subscription = await stripe.subscriptions.migrate(
  'sub_123',
  {
    billing_mode: {
      type: 'flexible',
    },
  }
);
```

```go
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
sc := stripe.NewClient("<<YOUR_SECRET_KEY>>")
params := &stripe.SubscriptionMigrateParams{
  BillingMode: &stripe.SubscriptionMigrateBillingModeParams{
    Type: stripe.String("flexible"),
  },
  Subscription: stripe.String("sub_123"),
}
result, err := sc.V1Subscriptions.Migrate(context.TODO(), params)
```

```dotnet
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
var options = new SubscriptionMigrateOptions
{
    BillingMode = new SubscriptionBillingModeOptions { Type = "flexible" },
};
var client = new StripeClient("<<YOUR_SECRET_KEY>>");
var service = client.V1.Subscriptions;
Subscription subscription = service.Migrate("sub_123", options);
```

Here’s the response:

```json
{
  "id": "sub_123",
  "billing_mode": "flexible",
  "billing_mode_details": {
    "updated_at": 1716883200 // Example timestamp
  },
  // ... other subscription details
}
```

### Billing mode and subscription schedules

When you create a subscription schedule from an existing subscription, don’t set `billing_mode` if the subscription already has one. The schedule automatically inherits the `billing_mode` from the original subscription. If you set `billing_mode` when using `from_subscription`, Stripe returns an error. If you need a different `billing_mode`, create a new subscription.

### Itemize proration discounts

If you use flexible subscriptions, you can set your preferred behavior for [proration discounts](https://docs.stripe.com/api/subscriptions/create.md#create_subscription-billing_mode-flexible-proration_discounts) on invoices and invoice items:

- **Itemized** (Recommended): Enables invoices and invoice items to show prorations with gross amounts and accurate discount amounts, consistent with non-prorations.
- **Included**: Uses the existing Stripe proration display behavior, with net amount and zero monetary discount amounts. This setting is maintained for backward compatibility with older integrations.

Learn more about the [differences between itemized and included](https://docs.stripe.com/billing/subscriptions/billing-mode/compare.md).

To enable itemized proration discounts, you must [upgrade your API version](https://docs.stripe.com/upgrades.md#how-can-i-upgrade-my-api) to [2025-06-30.basil](https://docs.stripe.com/changelog/basil.md#2025-06-30.basil) or later.

[Create](https://docs.stripe.com/api/subscriptions/create.md) or [migrate](https://docs.stripe.com/api/subscriptions/migrate.md) a subscription in order to set `proration_discounts` to `itemized`.

```curl
curl https://api.stripe.com/v1/subscriptions \
  -u "<<YOUR_SECRET_KEY>>:" \
  -H "Stripe-Version: 2025-06-30.basil" \
  -d "items[0][price]"="{{PRICE_ID}}" \
  -d customer="{{CUSTOMER_ID}}" \
  -d "billing_mode[type]"=flexible \
  -d "billing_mode[flexible][proration_discounts]"=itemized \
  -d payment_behavior=default_incomplete \
  -d "payment_settings[save_default_payment_method]"=on_subscription
```

```cli
stripe subscriptions create  \
  -d "items[0][price]"="{{PRICE_ID}}" \
  --customer="{{CUSTOMER_ID}}" \
  -d "billing_mode[type]"=flexible \
  -d "billing_mode[flexible][proration_discounts]"=itemized \
  --payment-behavior=default_incomplete \
  -d "payment_settings[save_default_payment_method]"=on_subscription
```

```ruby
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
client = Stripe::StripeClient.new("<<YOUR_SECRET_KEY>>")

subscription = client.v1.subscriptions.create({
  items: [{price: '{{PRICE_ID}}'}],
  customer: '{{CUSTOMER_ID}}',
  billing_mode: {
    type: 'flexible',
    flexible: {proration_discounts: 'itemized'},
  },
  payment_behavior: 'default_incomplete',
  payment_settings: {save_default_payment_method: 'on_subscription'},
})
```

```python
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
client = StripeClient("<<YOUR_SECRET_KEY>>")

# For SDK versions 12.4.0 or lower, remove '.v1' from the following line.
subscription = client.v1.subscriptions.create({
  "items": [{"price": "{{PRICE_ID}}"}],
  "customer": "{{CUSTOMER_ID}}",
  "billing_mode": {"type": "flexible", "flexible": {"proration_discounts": "itemized"}},
  "payment_behavior": "default_incomplete",
  "payment_settings": {"save_default_payment_method": "on_subscription"},
})
```

```php
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
$stripe = new \Stripe\StripeClient('<<YOUR_SECRET_KEY>>');

$subscription = $stripe->subscriptions->create([
  'items' => [['price' => '{{PRICE_ID}}']],
  'customer' => '{{CUSTOMER_ID}}',
  'billing_mode' => [
    'type' => 'flexible',
    'flexible' => ['proration_discounts' => 'itemized'],
  ],
  'payment_behavior' => 'default_incomplete',
  'payment_settings' => ['save_default_payment_method' => 'on_subscription'],
]);
```

```java
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
StripeClient client = new StripeClient("<<YOUR_SECRET_KEY>>");

SubscriptionCreateParams params =
  SubscriptionCreateParams.builder()
    .addItem(
      SubscriptionCreateParams.Item.builder().setPrice("{{PRICE_ID}}").build()
    )
    .setCustomer("{{CUSTOMER_ID}}")
    .setBillingMode(
      SubscriptionCreateParams.BillingMode.builder()
        .setType(SubscriptionCreateParams.BillingMode.Type.FLEXIBLE)
        .setFlexible(
          SubscriptionCreateParams.BillingMode.Flexible.builder()
            .setProrationDiscounts(
              SubscriptionCreateParams.BillingMode.Flexible.ProrationDiscounts.ITEMIZED
            )
            .build()
        )
        .build()
    )
    .setPaymentBehavior(SubscriptionCreateParams.PaymentBehavior.DEFAULT_INCOMPLETE)
    .setPaymentSettings(
      SubscriptionCreateParams.PaymentSettings.builder()
        .setSaveDefaultPaymentMethod(
          SubscriptionCreateParams.PaymentSettings.SaveDefaultPaymentMethod.ON_SUBSCRIPTION
        )
        .build()
    )
    .build();

// For SDK versions 29.4.0 or lower, remove '.v1()' from the following line.
Subscription subscription = client.v1().subscriptions().create(params);
```

```node
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
const stripe = require('stripe')('<<YOUR_SECRET_KEY>>');

const subscription = await stripe.subscriptions.create({
  items: [
    {
      price: '{{PRICE_ID}}',
    },
  ],
  customer: '{{CUSTOMER_ID}}',
  billing_mode: {
    type: 'flexible',
    flexible: {
      proration_discounts: 'itemized',
    },
  },
  payment_behavior: 'default_incomplete',
  payment_settings: {
    save_default_payment_method: 'on_subscription',
  },
});
```

```go
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
sc := stripe.NewClient("<<YOUR_SECRET_KEY>>")
params := &stripe.SubscriptionCreateParams{
  Items: []*stripe.SubscriptionCreateItemParams{
    &stripe.SubscriptionCreateItemParams{Price: stripe.String("{{PRICE_ID}}")},
  },
  Customer: stripe.String("{{CUSTOMER_ID}}"),
  BillingMode: &stripe.SubscriptionCreateBillingModeParams{
    Type: stripe.String(stripe.SubscriptionBillingModeTypeFlexible),
    Flexible: &stripe.SubscriptionCreateBillingModeFlexibleParams{
      ProrationDiscounts: stripe.String(stripe.SubscriptionBillingModeFlexibleProrationDiscountsItemized),
    },
  },
  PaymentBehavior: stripe.String("default_incomplete"),
  PaymentSettings: &stripe.SubscriptionCreatePaymentSettingsParams{
    SaveDefaultPaymentMethod: stripe.String(stripe.SubscriptionPaymentSettingsSaveDefaultPaymentMethodOnSubscription),
  },
}
result, err := sc.V1Subscriptions.Create(context.TODO(), params)
```

```dotnet
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
var options = new SubscriptionCreateOptions
{
    Items = new List<SubscriptionItemOptions>
    {
        new SubscriptionItemOptions { Price = "{{PRICE_ID}}" },
    },
    Customer = "{{CUSTOMER_ID}}",
    BillingMode = new SubscriptionBillingModeOptions
    {
        Type = "flexible",
        Flexible = new SubscriptionBillingModeFlexibleOptions
        {
            ProrationDiscounts = "itemized",
        },
    },
    PaymentBehavior = "default_incomplete",
    PaymentSettings = new SubscriptionPaymentSettingsOptions
    {
        SaveDefaultPaymentMethod = "on_subscription",
    },
};
var client = new StripeClient("<<YOUR_SECRET_KEY>>");
var service = client.V1.Subscriptions;
Subscription subscription = service.Create(options);
```

The code example above returns the following response:

```json
{"id": "sub_JgRjFjhKbtD2qz",
  "object": "subscription",
  "billing_mode": {
    "flexible": {
      "proration_discounts": "itemized"
    },
    "type": "flexible",
    "updated_at": 1751071020
  },
  "application_fee_percent": null,
  "automatic_tax": {
    "disabled_reason": null,
    "enabled": false,
    "liability": "null"
  },
  "billing_cycle_anchor": 1623873347,
  "billing_cycle_anchor_config": null,
  "cancel_at": null,
  "cancel_at_period_end": false,
  "canceled_at": null,
  "cancellation_details": {
    comment: null,
    feedback: null,
    reason: null
  },
  "collection_method": "charge_automatically",
  "created": 1623873347,
  "currency": "usd","customer": "cus_CMqDWO2xODTZqt",
  "days_until_due": null,
  "default_payment_method": null,
  "default_source": null,
  "default_tax_rates": [

  ],
  "discounts": [],
  "ended_at": null,
  "invoice_customer_balance_settings": {
    "account_tax_ids": null,
    issuer: {
      type: "self"
    }
  },
  "items": {
    "object": "list",
    "data": [
      {
        "id": "si_JgRjmS4Ur1khEx",
        "object": "subscription_item",
        "created": 1623873347,"current_period_end": 1626465347,
        "current_period_start": 1623873347,
        discounts: [],
        "metadata": {
        },
        "plan": {
          "id": "price_1J32RfGPZ1iASj5zHHp57z7C",
          "object": "plan",
          "active": true,
          "amount": 2000,
          "amount_decimal": "2000",
          "billing_scheme": "per_unit",
          "created": 1623864151,
          "currency": "usd",
          "interval": "month",
          "interval_count": 1,
          "livemode": false,
          "metadata": {
          },
          "nickname": null,
          "product": "prod_JgPF5xnq7qBun3",
          "tiers": null,
          "tiers_mode": null,
          "transform_usage": null,
          "trial_period_days": null,
          "usage_type": "licensed"
        },
        "price": {
          "id": "price_1J32RfGPZ1iASj5zHHp57z7C",
          "object": "price",
          "active": true,
          "billing_scheme": "per_unit",
          "created": 1623864151,
          "currency": "usd",
          "livemode": false,
          "lookup_key": null,
          "metadata": {
          },
          "nickname": null,
          "product": "prod_JgPF5xnq7qBun3",
          "recurring": {
            "interval": "month",
            "interval_count": 1,
            "trial_period_days": null,
            "usage_type": "licensed"
          },
          "tiers_mode": null,
          "transform_quantity": null,
          "type": "recurring",
          "unit_amount": 2000,
          "unit_amount_decimal": "2000"
        },
        "quantity": 1,
        "subscription": "sub_JgRjFjhKbtD2qz",
        "tax_rates": [

        ]
      }
    ],
    "has_more": false,
    "total_count": 1,
    "url": "/v1/subscription_items?subscription=sub_JgRjFjhKbtD2qz"
  },
  "latest_invoice": {
    "id": "in_1J34pzGPZ1iASj5zB87qdBNZ",
    "object": "invoice",
    "account_country": "US",
    "account_name": "Angelina's Store",
    "account_tax_ids": null,
    "amount_due": 2000,
    "amount_overpaid": 0,
    "amount_paid": 0,
    "amount_remaining": 2000,
    "amount_shipping": 0,
    "attempt_count": 0,
    "attempted": false,
    "auto_advance": false,
    "automatic_tax": {
      "disabled_reason": null,
      "enabled": false,
      liability: null,
      "status": null
    },
    "automatically_finalizes_at": null,
    "billing_reason": "subscription_update",
    "collection_method": "charge_automatically",
    "created": 1623873347,
    "currency": "usd",
    "custom_fields": null,
    "customer": "cus_CMqDWO2xODTZqt",
    "customer_address": null,
    "customer_email": "angelina@stripe.com",
    "customer_name": null,
    "customer_phone": null,
    "customer_shipping": {
      "address": {
        "city": "",
        "country": "US",
        "line1": "Berry",
        "line2": "",
        "postal_code": "",
        "state": ""
      },
      "name": "",
      "phone": null
    },
    "customer_tax_exempt": "none",
    "customer_tax_ids": [

    ],
    "default_payment_method": null,
    "default_source": null,
    "default_tax_rates": [

    ],
    "description": null,
    "discounts": [],
    "due_date": null,
    "effective_at": "1623873347",
    "ending_balance": 0,
    "footer": null,
    "from_invoice": null,
    "hosted_invoice_url": "https://invoice.stripe.com/i/acct_1By64KGPZ1iASj5z/invst_JgRjzIOILGeq2MKC9T0KtyXnD5udsLp",
    "invoice_pdf": "https://pay.stripe.com/invoice/acct_1By64KGPZ1iASj5z/invst_JgRjzIOILGeq2MKC9T0KtyXnD5udsLp/pdf",
    "last_finalization_error": null,
    "latest_revision": null,
    "lines": {
      "object": "list",
      "data": [
        {
          "id": "il_1N2CjMBwKQ696a5NeOawRQP2",
          "object": "line_item",
          "amount": 2000,
          "currency": "usd",
          "description": "1 × Gold Special (at $20.00 / month)",
          "discount_amounts": [

          ],
          "discountable": true,
          "discounts": [

          ],
          "invoice": "in_1J34pzGPZ1iASj5zB87qdBNZ",
          "livemode": false,
          "metadata": {
          },
          "parent": {
            "invoice_item_details": null,
            "subscription_item_details":
            {
              "invoice_item": null
            "proration": false
            "proration_details":
            {
              "credited_items": null
            }
            subscription:
            "sub_JgRjFjhKbtD2qz"
            subscription_item:
              "si_JgRjmS4Ur1khEx"
            }
            type: "subscription_item_details"
          },
          "period": {
            "end": 1626465347,
            "start": 1623873347
          },
          "plan": {
            "id": "price_1J32RfGPZ1iASj5zHHp57z7C",
            "object": "plan",
            "active": true,
            "amount": 2000,
            "amount_decimal": "2000",
            "billing_scheme": "per_unit",
            "created": 1623864151,
            "currency": "usd",
            "interval": "month",
            "interval_count": 1,
            "livemode": false,
            "metadata": {
            },
            "nickname": null,
            "product": "prod_JgPF5xnq7qBun3",
            "tiers": null,
            "tiers_mode": null,
            "transform_usage": null,
            "trial_period_days": null,
            "usage_type": "licensed"
          },
          "price": {
            "id": "price_1J32RfGPZ1iASj5zHHp57z7C",
            "object": "price",
            "active": true,
            "billing_scheme": "per_unit",
            "created": 1623864151,
            "currency": "usd",
            "livemode": false,
            "lookup_key": null,
            "metadata": {
            },
            "nickname": null,
            "product": "prod_JgPF5xnq7qBun3",
            "recurring": {
              "interval": "month",
              "interval_count": 1,
              "trial_period_days": null,
              "usage_type": "licensed"
            },
            "tiers_mode": null,
            "transform_quantity": null,
            "type": "recurring",
            "unit_amount": 2000,
            "unit_amount_decimal": "2000"
          },
          "quantity": 1,
          "taxes": [],
        }
      ],
      "has_more": false,
      "total_count": 1,
      "url": "/v1/invoices/in_1J34pzGPZ1iASj5zB87qdBNZ/lines"
    },
    "livemode": false,
    "metadata": {
    },
    "next_payment_attempt": null,
    "number": "C008FC2-0354",
    "on_behalf_of": null,
    "parent": {
      "quote_details": null,
      "subscription_details": {
        "metadata": {},
        "pause_collection": null,
        "subscription": "sub_JgRjFjhKbtD2qz",
      }
    }
    "payment_intent": {
      "id": "pi_1J34pzGPZ1iASj5zI2nOAaE6",
      "object": "payment_intent",
      "allowed_source_types": [
        "card"
      ],
      "amount": 2000,
      "amount_capturable": 0,
      "amount_received": 0,
      "application": null,
      "application_fee_amount": null,
      "canceled_at": null,
      "cancellation_reason": null,
      "capture_method": "automatic",
      "charges": {
        "object": "list",
        "data": [

        ],
        "has_more": false,
        "total_count": 0,
        "url": "/v1/charges?payment_intent=pi_1J34pzGPZ1iASj5zI2nOAaE6"
      },
      "client_secret": "pi_1J34pzGPZ1iASj5zI2nOAaE6_secret_l7FN6ldFfXiFmJEumenJ2y2wu",
      "confirmation_method": "automatic",
      "created": 1623873347,
      "currency": "usd",
      "customer": "cus_CMqDWO2xODTZqt",
      "description": "Subscription creation",
      "invoice": "in_1J34pzGPZ1iASj5zB87qdBNZ",
      "last_payment_error": null,
      "livemode": false,
      "metadata": {
      },
      "next_action": null,
      "next_source_action": null,
      "on_behalf_of": null,
      "payment_method": null,
      "payment_method_options": {
        "card": {
          "installments": null,
          "network": null,
          "request_three_d_secure": "automatic"
        }
      },
      "payment_method_types": [
        "card"
      ],
      "receipt_email": null,
      "review": null,
      "setup_future_usage": "off_session",
      "shipping": null,
      "source": "card_1By6iQGPZ1iASj5z7ijKBnXJ",
      "statement_descriptor": null,
      "statement_descriptor_suffix": null,
      "status": "requires_confirmation",
      "transfer_data": null,
      "transfer_group": null
    },
    "payment_settings": {
      "payment_method_options": null,
      "payment_method_types": null,
      "save_default_payment_method": "on_subscription"
    },
    "period_end": 1623873347,
    "period_start": 1623873347,
    "post_payment_credit_notes_amount": 0,
    "pre_payment_credit_notes_amount": 0,
    "receipt_number": null,
    "starting_balance": 0,
    "statement_descriptor": null,
    "status": "open",
    "status_transitions": {
      "finalized_at": 1623873347,
      "marked_uncollectible_at": null,
      "paid_at": null,
      "voided_at": null
    },
    "subscription": "sub_JgRjFjhKbtD2qz",
    "subtotal": 2000,
    "tax": null,
    "tax_percent": null,
    "total": 2000,
    "total_discount_amounts": [],
    "total_tax_amounts": [],
    "transfer_data": null,
    "webhooks_delivered_at": 1623873347
  },
  "livemode": false,
  "metadata": {
  },
  "next_pending_invoice_item_invoice": null,
  "pause_collection": null,
  "pending_invoice_item_interval": null,
  "pending_setup_intent": null,
  "pending_update": null,
  "plan": {
    "id": "price_1J32RfGPZ1iASj5zHHp57z7C",
    "object": "plan",
    "active": true,
    "amount": 2000,
    "amount_decimal": "2000",
    "billing_scheme": "per_unit",
    "created": 1623864151,
    "currency": "usd",
    "interval": "month",
    "interval_count": 1,
    "livemode": false,
    "metadata": {
    },
    "nickname": null,
    "product": "prod_JgPF5xnq7qBun3",
    "tiers": null,
    "tiers_mode": null,
    "transform_usage": null,
    "trial_period_days": null,
    "usage_type": "licensed"
  },
  "quantity": 1,
  "schedule": null,
  "start": 1623873347,
  "start_date": 1623873347,
  "status": "incomplete",
  "tax_percent": null,
  "transfer_data": null,
  "trial_end": null,
  "trial_start": null
}
```

### Compare classic and flexible billing mode

We recommend using [flexible billing mode](https://docs.stripe.com/billing/subscriptions/billing-mode.md) because it provides improved billing behavior and access to new features. However, moving to flexible billing mode can change your integration’s behavior. Review the following differences to understand the impact on your integration and make an informed decision.

#### Credit proration calculations

Credit prorations are issued when customers downgrade their subscriptions or cancel subscription items before the end of their billing period. Flexible billing mode calculates credit prorations based on the original amount previously debited to a customer.

For a full overview of credit proration calculations, see [Credit prorations](https://docs.stripe.com/billing/subscriptions/prorations.md#credit-prorations).

| **Classic** | **Flexible** |
| --- | --- |
| When an update to a subscription generates a credit proration, the credit proration amounts are calculated based on the value of the subscription item’s current price, tax, quantity, and the last discounts used. | When an update to a subscription generates a credit proration, these prorations use the original debited amount instead of current subscription values. |

##### Proportional discount application for prorations

We apply discounts proportionally to each subscription item during [proration calculations](https://docs.stripe.com/billing/subscriptions/prorations.md#prorations-and-discounts) instead of distributing them evenly. This results in more prorations, especially when invoicing on a per-item basis or canceling items with unevenly distributed discounts.

| **Classic** | **Flexible** |
| --- | --- |
| We distribute discounts evenly across all subscription items. | We apply discounts proportionally to each subscription item during proration calculations. |

#### Usage-based pricing

##### Suppress zero-amount line items when adding usage-based items

Flexible billing mode doesn’t create zero-amount line items when you add usage-based items to a subscription. If the invoice is empty as a result, we don’t generate one.

For example, when adding a monthly usage-based item during subscription creation or update:

| **Classic** | **Flexible** |
| --- | --- |
| A 0 USD line item is generated on the invoice for the usage-based item. This also applies when updating a subscription without cycling to add a usage-based item while using `proration_behavior=always_invoice`. | A 0 USD line item isn’t added to the invoice for the usage-based item. If the resulting invoice wouldn’t contain any items, we don’t generate one. |

##### Bill usage-based items based on price at time of reporting

Flexible billing mode charges for usage based on the price that was in effect when the usage was reported, rather than the most recent price.

For example:

1. Initially, the price is 0.1 USD per 100 API calls (Price A)
1. Usage on January 5: 1000 API calls
1. On January 15, the price changes to 0.15 USD per 100 calls (Price B)
1. Usage on January 20: 500 API calls

| **Classic** | **Flexible** |
| --- | --- |
| Stripe only bills for the usage that was reported since changing to the current price.  
- 500 API calls at Price B (0.15 USD per 100 calls) = 0.75 USD  
Total invoice amount = 0.75 USD. | Stripe bills for all usage in the current period at the price effective at the time it’s reported.  
- 1000 API calls at Price A (0.1 USD per 100 calls) = 1 USD  
- 500 API calls at Price B (0.15 USD per 100 calls) = 0.75 USD  
Total invoice amount = 1.75 USD. |

##### Bill for unbilled usage when removing usage-based items

Depending on the value of `proration_behavior`, flexible billing mode might generate an invoice item for unbilled usage when removing a usage-based subscription item. This applies to removals using the API or during schedule phase transitions that occur mid-period. For phase transitions that coincide with any subscription item `current_period_end`, an invoice gets created with an invoice line item for the removed usage-based subscription item.

| **Scenario** | **Classic** | **Flexible** |
| --- | --- | --- |
| Update subscription or schedule using the API | No invoice item or invoice is generated for unbilled usage when removing a usage-based subscription item. | An invoice item is generated for unbilled usage when removing a usage-based subscription item. |
| Schedule phase transition | An invoice (but no invoice item) is generated for unbilled usage when removing a usage-based subscription item. | Depending on the incoming phase’s `proration_behavior`:  
- `create_prorations`: an invoice item is created for unbilled usage when removing a usage-based subscription item.  
- `always_invoice`: an invoice item for unbilled usage is created and immediately invoiced.  
- `none`: no invoice item is created. |

##### Reset the billing cycle anchor

Flexible billing mode only resets your [billing cycle anchor](https://docs.stripe.com/billing/subscriptions/billing-cycle.md) on subscription updates when you explicitly set `billing_cycle_anchor` to a value other than `unchanged`.

| Classic | Flexible |
| --- | --- |
| The `billing_cycle_anchor` is automatically reset to the current date when switching a subscription to a different price with a different recurring interval, changing from zero-amount prices to non-zero prices, or moving [cancel_at](https://docs.stripe.com/api/subscriptions/object.md#subscription_object-cancel_at) to a date before the next time the subscription renews. | The `billing_cycle_anchor` is never automatically reset. |

##### Consolidated invoicing for subscription schedule phase transitions with usage-based items

Flexible billing mode consistently generates a single invoice when a subscription renews. This change eliminates separate invoices for removed usage-based items and improves billing consistency.

When your subscription with usage-based items transitions between phases:

| **Classic** | **Flexible** |
| --- | --- |
| Two invoices are generated. | A single consolidated invoice is generated. This invoice includes both usage-based and licensed items, applies discounts from the previous phase to usage-based billing, and uses tax rates from the next phase. |

#### Scheduled subscription cancellation

Flexible billing mode lets you disable prorations for a truncated first billing period (when setting `cancel_at` on creation) using the `proration_behavior` parameter.

| **Classic** | **Flexible** |
| --- | --- |
| Prorations are applied to the first billing period. | Prorations aren’t applied to the first billing period. |

#### Backdate subscriptions

When [backdating](https://docs.stripe.com/billing/subscriptions/backdating.md) is consistent with regular billing, flexible billing mode creates separate invoice line items for each billing period within the backdated range. It also automatically aligns the billing cycle anchor to the `backdate_start_date` when not explicitly set. Backdating isn’t supported if the resulting invoice has more than 250 line items.

For example, a subscription needs to be backdated due to a missed invoice for the past two billing periods. The customer was invoiced for 2 different backdated periods:

- Billing Period 1 (March 1 - March 31):  
  - Usage reported: 100 GB of storage used.  
  - Price: 10 USD per 10 GB.
- Billing Period 2 (April 1 - April 30):  
  - Usage reported: 150 GB of storage used.  
  - Price: 10 USD per 10 GB.

The service provider decides to backdate the invoice to cover both billing periods: March 1 to April 30.

| Classic | Flexible |
| --- | --- |
| Charges for the entire backdated period are calculated collectively as a single line item. Total charges:  
- 250 GB = 25 x 10 USD = 250 USD  
- This amount appears as a single line item on the invoice. | Backdated time ranges are split into multiple invoice line items according to billing period boundaries. Total charges:  
- Billing Period 1 (March):  
  - 100 GB = 10 x 10 USD = 100 USD (as a separate line item).  
- Billing Period 2 (April):  
  - 150 GB = 15 x 10 USD = 150 USD (as a separate line item). |

#### Trials

##### Update trial start date for subsequent trials

Flexible billing mode uses the most recent trial start date for subscriptions with subsequent trials.

| **Classic** | **Flexible** |
| --- | --- |
| The `subscription.trial_start` always refers to the first trial a subscription started. | The `subscription.trial_start` refers to the start of the most recent trial of a subscription. |

##### Preserve original trial end date when subscription cancels

Flexible billing mode preserves the `trial_end` if you modify the `cancel_at` date.

| Classic | Flexible |
| --- | --- |
| Setting `cancel_at` to a date earlier than the `trial_end` date automatically changes `trial_end` to match `cancel_at`. However, removing `cancel_at` or changing it to a date later than the `trial_end` date doesn’t automatically change `trial_end`, even if `trial_end` was originally a later date. | Scheduling a subscription cancellation using `cancel_at` no longer alters the `trial_end` date. This ensures that trials run for their intended duration regardless of cancellation date updates. |

##### Standardize trial period line item description

Flexible billing mode uses a consistent description format for both usage-based and licensed items during trial periods.

| **Classic** | **Flexible** |
| --- | --- |
| Licensed items use the template `Trial period for {product name}`, while usage-based items use `{quantity} x {product name} (Free trial)`. | The same format, `Free trial for {quantity} x {product name}`, applies to all item types, which provides a more uniform presentation of trial information. These descriptions are also localized. |

##### Re-bill for trial line items

Flexible billing mode only generates line items for changes made during a trial. Existing items without changes aren’t rebilled.

| Classic | Flexible |
| --- | --- |
| Changes during a trial result either in no invoice or in an invoice that restates the entire state of the subscription. | Changes during a trial consistently result in line items comparable to changes outside of a trial. For example, if a new price is added to a subscription a line item representing that price is also added. |

#### Pending invoice items

##### Consistently include pending invoice items

Flexible billing mode includes all available pending invoice items in invoices generated by a billing cycle anchor reset where `proration_behavior = always_invoice`.

| **Classic** | **Flexible** |
| --- | --- |
| Billing cycle anchor reset invoices include pending items only when `proration behavior` isn’t `always_invoice`. | Pending invoice items are always included on all invoices a subscription generates. |

### Mixed intervals on the same subscription

Flexible billing mode lets you create [mixed interval subscriptions](https://docs.stripe.com/billing/subscriptions/mixed-interval.md), which can bill for multiple recurring prices with different intervals. That allows you to combine different pricing structures within a single subscription.

| **Classic** | **Flexible** |
| --- | --- |
| Not supported. All items in a subscription must have prices with the same interval and interval count. | Items on a [mixed interval subscription](https://docs.stripe.com/billing/subscriptions/mixed-interval.md) can have recurring prices with different intervals or interval counts. For example, a monthly price and an annual price can exist on the same subscription. |

# Prorations

Manage prorations for modified subscriptions.

The most complex aspect of changing existing subscriptions are prorations, where the customer is charged a percentage of a subscription’s cost to reflect partial use. This page explains how prorations work with subscriptions and how to manage prorations for your customers.

## How prorations work

For example, [upgrading or downgrading](https://docs.stripe.com/billing/subscriptions/change-price.md) a subscription can result in a proration. If a customer upgrades from a 10 USD monthly plan to a 20 USD option, they’re charged prorated amounts for the time spent on each option. Assuming the change occurred halfway through the billing period, the customer is billed an additional 5 USD: -5 USD for unused time on the initial price, and 10 USD for the remaining time on the new price.

Proration ensures that customers are billed accurately, but a proration can result in different payment amounts than you might expect. Negative prorations aren’t automatically refunded and positive prorations aren’t immediately billed, although you can do both manually.

You can [preview a proration](https://docs.stripe.com/billing/subscriptions/prorations.md#preview-proration) to view the amount before applying the changes. To learn more about [how credit prorations work](https://docs.stripe.com/billing/subscriptions/prorations.md#credit-prorations), read our guide.

### Prorations and discounts

All [invoice items](https://docs.stripe.com/api/invoiceitems/object.md#invoiceitem_object) that are prorations (`prorations=true`) are set to `discountable=false`. Discounts applied to an invoice containing prorations are only applied to [invoice items](https://docs.stripe.com/api/invoiceitems/object.md#invoiceitem_object-discounts) and [invoice line items](https://docs.stripe.com/api/invoice-line-item/object.md#invoice_line_item_object-discounts) that aren’t prorations. Any discounts previously applied to the subscription and affecting the amount of the proration are reflected in the proration invoice item’s amount.

Non-prorations show discount adjustments in [discount_amounts](https://docs.stripe.com/api/invoice-line-item/object.md#invoice_line_item_object-discount_amounts).

### What triggers prorations

By default, the following scenarios result in a proration:

| Update | Description |
| --- | --- |
| Changing [items](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-items) | Adding a new item or removing an existing item |
| Changing [price](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-items-price) | Changing to a price with a different base cost or billing period |
| Changing [quantity](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-items-quantity) | Increasing or decreasing the quantity on a subscription item |
| Adding [trial_end](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-trial_end) or [trial_from_plan](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-trial_from_plan) | Adding a trial period to an active subscription |
| Changing [billing_cycle_anchor](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-billing_cycle_anchor) | Resetting the billing period to a new date |
| Setting [cancel_at](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-cancel_at) | Canceling a subscription mid-period (not at period end) |

### What doesn’t trigger prorations 

Many subscription updates don’t affect billing or generate prorations. Make these updates at any time without creating *proration* invoice items:

| Parameter | Description |
| --- | --- |
| **Configuration and settings updates** | |
| [automatic_tax](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-automatic_tax) | Enable or disable automatic tax calculation |
| [default_payment_method](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-default_payment_method) | Change the default payment method |
| [default_source](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-default_source) | Change the default payment source |
| [payment_behavior](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-payment_behavior) | Control payment attempt behavior |
| [collection_method](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-collection_method) | Change between charge automatically and send invoice |
| [days_until_due](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-days_until_due) | Update payment due date for send invoice subscriptions |
| [tax_filing_currency](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-tax_filing_currency) | Change the tax filing currency |
| [retry_settings](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-retry_settings) | Modify retry behavior for failed payments |
| [trial_settings](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-trial_settings) | Update trial end behavior settings |
| [pay_immediately](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-pay_immediately) | Control immediate payment behavior |
| [pending_invoice_item_interval](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-pending_invoice_item_interval) | Change how often pending items are invoiced |
| [pause_collection](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-pause_collection) | Pause or resume payment collection |
| [proration_date](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-proration_date) | Set a specific proration date (doesn’t create prorations by itself) |
| **Metadata and descriptive fields** | |
| [metadata](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-metadata) and [items.metadata](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-items-metadata) | Update metadata on the subscription/subscription items |
| [cancellation_details](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-cancellation_details) | Add cancellation feedback and comments |
| **Updates that act as settings for future non-proration billing changes** | |
| [discounts](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-discounts) and [items.discounts](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-items-discounts) | Add or update discounts (applies to future invoices) |
| [billing_thresholds](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-billing_thresholds) and [items.billing_thresholds](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-items-billing_thresholds) | Update billing thresholds on subscription/subscription items |
| [cancel_at_period_end](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-cancel_at_period_end) | Cancel at the current period end without proration |
| [add_invoice_items](https://docs.stripe.com/api/subscriptions/update.md#update_subscription-add_invoice_items) | Add one-time charges to the next invoice |

> These updates don’t generate proration invoice items with `proration_behavior=create_prorations` or generate invoices with proration invoice items with `proration_behavior=always_invoice` because they don’t change the billing amount for the current period.

### Manually creating your own prorations

To calculate your own prorations outside of Stripe and add them to the subscription, pass [add_invoice_items](https://docs.stripe.com/api/subscription_schedules/create.md#create_subscription_schedule-add_invoice_items) with a negative `unit_amount` (equal to the calculated proration amount) to these endpoints:

- [CreateSubscription](https://docs.stripe.com/api/subscriptions/create.md)
- [UpdateSubscription](https://docs.stripe.com/api/subscriptions/update.md)
- [CreateSubscriptionSchedule](https://docs.stripe.com/api/subscription_schedules/create.md)
- [UpdateSubscriptionSchedule](https://docs.stripe.com/api/subscription_schedules/update.md)

### When prorations are applied

Prorations only apply to charges that occur ahead of the billing period. [Usage-based billing](https://docs.stripe.com/billing/subscriptions/usage-based.md) isn’t subject to proration.

The prorated amount is calculated as soon as the API updates the subscription. The current billing period’s start and end times are used to calculate the cost of the subscription before and after the change.

### Prorations and unpaid invoices

Stripe calculates prorations based on the subscription’s status at the time of an update, assuming that any previous invoices for the subscription will eventually be paid. If a customer changes their subscription while having an unpaid invoice for the current period, they might receive a credit for unused time on the higher-priced plan, even if they haven’t paid for that time yet.

To avoid crediting for unpaid time, you can disable prorations when the subscription’s latest invoice is unpaid. When updating the subscription, set [proration_behavior](https://docs.stripe.com/api/subscriptions/update.md?update_subscription-proration_behavior=#update_subscription-proration_behavior) to `none`. Select one of the following approaches:

1. **To keep the original billing period:** Manually [create a one-off invoice](https://docs.stripe.com/api/invoices/create.md) for any new charges.
1. **To charge immediately for the new plan and reset the billing period:** Set `billing_cycle_anchor` to `now`. For more details, see [Reset the billing period to the current time](https://docs.stripe.com/billing/subscriptions/billing-cycle.md#reset-the-billing-period-to-the-current-time).

Either of these approaches can lead to double payment если the customer eventually pays the old invoice. To avoid this, [void the unpaid invoice](https://docs.stripe.com/api/invoices/void.md).

### Taxes and prorations

For information about how taxes work with prorations, see [Collect taxes for recurring payments](https://docs.stripe.com/billing/taxes/collect-taxes.md).

## Credit prorations 

Credit prorations are issued when customers downgrade their subscriptions or cancel subscription items before the end of their billing period. Stripe offers two approaches for calculating credit prorations, depending on whether you set your subscription’s [billing_mode](https://docs.stripe.com/billing/subscriptions/billing-mode.md#differences-between-classic-and-flexible-billing-mode) to `classic` or `flexible`.

### Calculation logic with no prorations

In the following scenario, you upgrade a 10 USD monthly subscription to 20 USD with the `proration_behavior` set to `none` for 10 days. There’s no previous debit to base it on. Later, you downgrade the subscription to 10 USD per month with the `proration_behavior` set to `always_invoice`.

To set up this scenario, first you [create a subscription](https://docs.stripe.com/api/subscriptions/create.md) for 10 USD per month on April 1:

```curl
curl https://api.stripe.com/v1/subscriptions \
  -u "<<YOUR_SECRET_KEY>>:" \
  -d "items[0][price]"=price_10_monthly
```

```cli
stripe subscriptions create  \
  -d "items[0][price]"=price_10_monthly
```

```ruby
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
client = Stripe::StripeClient.new("<<YOUR_SECRET_KEY>>")
subscription = client.v1.subscriptions.create({items: [{price: 'price_10_monthly'}]})
```

```python
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
# This example uses the beta SDK. See https://github.com/stripe/stripe-python#public-preview-sdks
client = StripeClient("<<YOUR_SECRET_KEY>>")
# For SDK versions 12.4.0 or lower, remove '.v1' from the following line.
subscription = client.v1.subscriptions.create({"items": [{"price": "price_10_monthly"}]})
```

```php
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
// This example uses the beta SDK. See https://github.com/stripe/stripe-php#public-preview-sdks
$stripe = new \Stripe\StripeClient('<<YOUR_SECRET_KEY>>');
$subscription = $stripe->subscriptions->create([
  'items' => [['price' => 'price_10_monthly']],
]);
```

```java
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
// This example uses the beta SDK. See https://github.com/stripe/stripe-java#public-preview-sdks
StripeClient client = new StripeClient("<<YOUR_SECRET_KEY>>");
SubscriptionCreateParams params =
  SubscriptionCreateParams.builder()
    .addItem(SubscriptionCreateParams.Item.builder().setPrice("price_10_monthly").build())
    .build();
// For SDK versions 29.4.0 or lower, remove '.v1()' from the following line.
Subscription subscription = client.v1().subscriptions().create(params);
```

```node
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
// This example uses the beta SDK. See https://github.com/stripe/stripe-node#public-preview-sdks
const stripe = require('stripe')('<<YOUR_SECRET_KEY>>');
const subscription = await stripe.subscriptions.create({
  items: [
    {
      price: 'price_10_monthly',
    },
  ],
});
```

```go
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
// This example uses the beta SDK. See https://github.com/stripe/stripe-go#public-preview-sdks
sc := stripe.NewClient("<<YOUR_SECRET_KEY>>")
params := &stripe.SubscriptionCreateParams{
  Items: []*stripe.SubscriptionCreateItemParams{
    &stripe.SubscriptionCreateItemParams{Price: stripe.String("price_10_monthly")},
  },
}
result, err := sc.V1Subscriptions.Create(context.TODO(), params)
```

```dotnet
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
var options = new SubscriptionCreateOptions
{
    Items = new List<SubscriptionItemOptions>
    {
        new SubscriptionItemOptions { Price = "price_10_monthly" },
    },
};
var client = new StripeClient("<<YOUR_SECRET_KEY>>");
var service = client.V1.Subscriptions;
Subscription subscription = service.Create(options);
```

The response includes the invoice that’s created for this subscription:

```json
{
  id: "sub_123",
  latest_invoice: {
    id: "in_123",
    total: 10_00,
    currency: "usd"
    }
}
```

Then, on April 11, you [upgrade the subscription](https://docs.stripe.com/billing/subscriptions/change-price.md#changing) to 20 USD per month without creating prorations:

```curl
curl https://api.stripe.com/v1/subscriptions/sub_123 \
  -u "<<YOUR_SECRET_KEY>>:" \
  -d "items[0][id]"=sub_item_1 \
  -d "items[0][price]"=price_20_monthly \
  -d proration_behavior=none
```

```cli
stripe subscriptions update sub_123 \
  -d "items[0][id]"=sub_item_1 \
  -d "items[0][price]"=price_20_monthly \
  --proration-behavior=none
```

```ruby
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
client = Stripe::StripeClient.new("<<YOUR_SECRET_KEY>>")
subscription = client.v1.subscriptions.update(
  'sub_123',
  {
    items: [
      {
        id: 'sub_item_1',
        price: 'price_20_monthly',
      },
    ],
    proration_behavior: 'none',
  },
)
```

```python
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
client = StripeClient("<<YOUR_SECRET_KEY>>")
# For SDK versions 12.4.0 or lower, remove '.v1' from the following line.
subscription = client.v1.subscriptions.update(
  "sub_123",
  {
    "items": [{"id": "sub_item_1", "price": "price_20_monthly"}],
    "proration_behavior": "none",
  },
)
```

```php
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
$stripe = new \Stripe\StripeClient('<<YOUR_SECRET_KEY>>');
$subscription = $stripe->subscriptions->update(
  'sub_123',
  [
    'items' => [
      [
        'id' => 'sub_item_1',
        'price' => 'price_20_monthly',
      ],
    ],
    'proration_behavior' => 'none',
  ]
);
```

```java
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
StripeClient client = new StripeClient("<<YOUR_SECRET_KEY>>");
SubscriptionUpdateParams params =
  SubscriptionUpdateParams.builder()
    .addItem(
      SubscriptionUpdateParams.Item.builder()
        .setId("sub_item_1")
        .setPrice("price_20_monthly")
        .build()
    )
    .setProrationBehavior(SubscriptionUpdateParams.ProrationBehavior.NONE)
    .build();
// For SDK versions 29.4.0 or lower, remove '.v1()' from the following line.
Subscription subscription = client.v1().subscriptions().update("sub_123", params);
```

```node
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
const stripe = require('stripe')('<<YOUR_SECRET_KEY>>');
const subscription = await stripe.subscriptions.update(
  'sub_123',
  {
    items: [
      {
        id: 'sub_item_1',
        price: 'price_20_monthly',
      },
    ],
    proration_behavior: 'none',
  }
);
```

```go
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
sc := stripe.NewClient("<<YOUR_SECRET_KEY>>")
params := &stripe.SubscriptionUpdateParams{
  Items: []*stripe.SubscriptionUpdateItemParams{
    &stripe.SubscriptionUpdateItemParams{
      ID: stripe.String("sub_item_1"),
      Price: stripe.String("price_20_monthly"),
    },
  },
  ProrationBehavior: stripe.String("none"),
  SubscriptionExposedID: stripe.String("sub_123"),
}
result, err := sc.V1Subscriptions.Update(context.TODO(), params)
```

```dotnet
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
var options = new SubscriptionUpdateOptions
{
    Items = new List<SubscriptionItemOptions>
    {
        new SubscriptionItemOptions { Id = "sub_item_1", Price = "price_20_monthly" },
    },
    ProrationBehavior = "none",
};
var client = new StripeClient("<<YOUR_SECRET_KEY>>");
var service = client.V1.Subscriptions;
Subscription subscription = service.Update("sub_123", options);
```

The latest invoice remains unchanged because `proration_behavior` is `none`:

```json
{
  id: "sub_123",
  latest_invoice: {
    id: "in_123"
  }
}
```

Finally, on April 21, you [downgrade the subscription](https://docs.stripe.com/billing/subscriptions/change-price.md#changing) to 10 USD per month and create prorations:

```curl
curl https://api.stripe.com/v1/subscriptions/sub_123 \
  -u "<<YOUR_SECRET_KEY>>:" \
  -d "items[0][id]"=sub_item_1 \
  -d "items[0][price]"=price_10_monthly \
  -d proration_behavior=always_invoice
```

```cli
stripe subscriptions update sub_123 \
  -d "items[0][id]"=sub_item_1 \
  -d "items[0][price]"=price_10_monthly \
  --proration-behavior=always_invoice
```

```ruby
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
client = Stripe::StripeClient.new("<<YOUR_SECRET_KEY>>")
subscription = client.v1.subscriptions.update(
  'sub_123',
  {
    items: [
      {
        id: 'sub_item_1',
        price: 'price_10_monthly',
      },
    ],
    proration_behavior: 'always_invoice',
  },
)
```

```python
# Set your secret key. Remember to switch to your live secret key in production.
# See your keys here: https://dashboard.stripe.com/apikeys
client = StripeClient("<<YOUR_SECRET_KEY>>")
# For SDK versions 12.4.0 or lower, remove '.v1' from the following line.
subscription = client.v1.subscriptions.update(
  "sub_123",
  {
    "items": [{"id": "sub_item_1", "price": "price_10_monthly"}],
    "proration_behavior": "always_invoice",
  },
)
```

```php
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
$stripe = new \Stripe\StripeClient('<<YOUR_SECRET_KEY>>');
$subscription = $stripe->subscriptions->update(
  'sub_123',
  [
    'items' => [
      [
        'id' => 'sub_item_1',
        'price' => 'price_10_monthly',
      ],
    ],
    'proration_behavior' => 'always_invoice',
  ]
);
```

```java
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
StripeClient client = new StripeClient("<<YOUR_SECRET_KEY>>");
SubscriptionUpdateParams params =
  SubscriptionUpdateParams.builder()
    .addItem(
      SubscriptionUpdateParams.Item.builder()
        .setId("sub_item_1")
        .setPrice("price_10_monthly")
        .build()
    )
    .setProrationBehavior(SubscriptionUpdateParams.ProrationBehavior.ALWAYS_INVOICE)
    .build();
// For SDK versions 29.4.0 or lower, remove '.v1()' from the following line.
Subscription subscription = client.v1().subscriptions().update("sub_123", params);
```

```node
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
const stripe = require('stripe')('<<YOUR_SECRET_KEY>>');
const subscription = await stripe.subscriptions.update(
  'sub_123',
  {
    items: [
      {
        id: 'sub_item_1',
        price: 'price_10_monthly',
      },
    ],
    proration_behavior: 'always_invoice',
  }
);
```

```go
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
sc := stripe.NewClient("<<YOUR_SECRET_KEY>>")
params := &stripe.SubscriptionUpdateParams{
  Items: []*stripe.SubscriptionUpdateItemParams{
    &stripe.SubscriptionUpdateItemParams{
      ID: stripe.String("sub_item_1"),
      Price: stripe.String("price_10_monthly"),
    },
  },
  ProrationBehavior: stripe.String("always_invoice"),
  SubscriptionExposedID: stripe.String("sub_123"),
}
result, err := sc.V1Subscriptions.Update(context.TODO(), params)
```

```dotnet
// Set your secret key. Remember to switch to your live secret key in production.
// See your keys here: https://dashboard.stripe.com/apikeys
var options = new SubscriptionUpdateOptions
{
    Items = new List<SubscriptionItemOptions>
    {
        new SubscriptionItemOptions { Id = "sub_item_1", Price = "price_10_monthly" },
    },
    ProrationBehavior = "always_invoice",
};
var client = new StripeClient("<<YOUR_SECRET_KEY>>");
var service = client.V1.Subscriptions;
Subscription subscription = service.Update("sub_123", options);
```

The response shows the updated subscription with billing_mode set to flexible and the billing_mode_details.updated_at timestamp:

```json
{
  "id": "sub_123",
  "billing_mode": "flexible",
  "billing_mode_details": {
    "updated_at": 1716883200 // Example timestamp
  },
  // ... other subscription details
}
```
