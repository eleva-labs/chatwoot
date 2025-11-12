# frozen_string_literal: true

# == Schema Information
#
# Table name: webhook_deliveries
#
#  id                :bigint           not null, primary key
#  job_id            :string           not null
#  url               :string           not null
#  conversation_id   :integer
#  message_id        :integer
#  webhook_type      :string           not null
#  attempt_count     :integer          default(0), not null
#  status            :string           default("pending"), not null
#  last_error        :text
#  last_attempt_at   :datetime
#  delivered_at      :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

class WebhookDelivery < ApplicationRecord
  # Status values: pending, delivering, delivered, failed, dead_letter
  enum status: {
    pending: 'pending',
    delivering: 'delivering',
    delivered: 'delivered',
    failed: 'failed',
    dead_letter: 'dead_letter'
  }, _suffix: true

  validates :job_id, presence: true, uniqueness: true
  validates :url, presence: true
  validates :webhook_type, presence: true
  validates :status, presence: true

  scope :failed_deliveries, -> { where(status: %w[failed dead_letter]) }
  scope :recent, ->(window = 24.hours) { where('created_at > ?', window.ago) }
  scope :by_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }
  scope :by_message, ->(message_id) { where(message_id: message_id) }

  # Calculate failure rate for monitoring
  def self.failure_rate(window: 1.hour)
    recent_deliveries = recent(window)
    total = recent_deliveries.count
    return 0 if total.zero?

    failed = recent_deliveries.failed_deliveries.count
    (failed.to_f / total * 100).round(2)
  end

  # Average attempts for successful deliveries
  def self.avg_attempts(window: 1.hour)
    recent(window)
      .where(status: 'delivered')
      .average(:attempt_count)
      .to_f
      .round(2)
  end

  # Count deliveries by status
  def self.status_counts(window: 1.hour)
    recent(window).group(:status).count
  end

  # Find deliveries that may need manual intervention
  def self.needs_attention
    where(status: 'dead_letter')
      .or(where('attempt_count >= ? AND status = ?', 5, 'failed'))
      .order(created_at: :desc)
  end

  # Mark as requiring manual intervention
  def move_to_dead_letter!(error_message)
    update!(
      status: 'dead_letter',
      last_error: error_message,
      last_attempt_at: Time.current
    )
  end
end
