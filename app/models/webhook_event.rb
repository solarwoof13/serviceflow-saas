# Create app/models/webhook_event.rb
class WebhookEvent < ApplicationRecord
  belongs_to :jobber_account, optional: true
  
  scope :pending, -> { where(processing_status: 'pending') }
  scope :failed, -> { where(processing_status: 'failed') }
  scope :recent, -> { where('created_at > ?', 24.hours.ago) }
end