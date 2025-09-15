class Visit < ApplicationRecord
  belongs_to :wix_user  # Links to Wix user
  belongs_to :jobber_account, optional: true  # Links to Jobber account
  
  # Add validations only if columns exist
  validates :jobber_visit_id, presence: true, uniqueness: true, if: -> { has_attribute?(:jobber_visit_id) }
  
  scope :recent, -> { where('completed_at > ?', 30.days.ago) }, if: -> { has_attribute?(:completed_at) }
  scope :expiring_soon, -> { where('data_expires_at < ?', 7.days.from_now) }, if: -> { has_attribute?(:data_expires_at) }
end

class WixUser < ApplicationRecord
  has_many :visits
  belongs_to :jobber_account, optional: true  # Direct link to Jobber
  
  # Store Wix user ID
  validates :wix_user_id, presence: true, uniqueness: true
end

class JobberAccount < ApplicationRecord
  has_many :wix_users
  has_many :visits, through: :wix_users  # Through association
end
