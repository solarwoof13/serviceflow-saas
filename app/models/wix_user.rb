# app/models/wix_user.rb
class WixUser < ApplicationRecord
  has_one :subscription
  has_many :features, through: :subscription
  
  validates :wix_id, presence: true, uniqueness: true
  validates :email, presence: true
end
