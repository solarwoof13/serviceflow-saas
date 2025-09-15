class Subscription < ApplicationRecord
  belongs_to :wix_user  # Keep current association
  belongs_to :jobber_account, optional: true  # Add if needed
  has_many :subscription_features
  has_many :features, through: :subscription_features
  
  enum level: [:startup, :growth, :elite]
  validates :level, presence: true
  
  # Add new features conditionally
  PLAN_TYPES = %w[basic pro enterprise].freeze
  validates :plan_type, inclusion: { in: PLAN_TYPES }, if: -> { has_attribute?(:plan_type) }
  RETENTION_DAYS = { basic: 60, pro: 90, enterprise: 180 }.freeze
  
  scope :active, -> { where(active: true) }, if: -> { has_attribute?(:active) }
  
  def at_email_limit?
    return false unless has_attribute?(:emails_sent_this_period) && has_attribute?(:email_limit)
    emails_sent_this_period >= email_limit
  end
end