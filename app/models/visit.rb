class Visit < ApplicationRecord
  belongs_to :wix_user
  belongs_to :jobber_account
  
  validates :jobber_visit_id, presence: true, uniqueness: true
  
  scope :recent, -> { where('completed_at > ?', 30.days.ago) }
  scope :expiring_soon, -> { where('data_expires_at < ?', 7.days.from_now) }
  
  # Set retention date based on user's plan
  before_create :set_expiration_date
  
  private
  
  def set_expiration_date
    self.data_expires_at = wix_user.retention_days.days.from_now
  end
end