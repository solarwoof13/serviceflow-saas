# app/models/feature.rb
class Feature < ApplicationRecord
  has_many :subscription_features
  has_many :subscriptions, through: :subscription_features
  
  validates :name, presence: true, uniqueness: true
  
  # Features available to all levels
  ALL_LEVELS = ['basic_emails', 'jobber_integration', 'ai_enhancements']
  
  # Level-specific features
  LEVEL_FEATURES = {
    startup: ALL_LEVELS + ['limited_cache', 'basic_reviews', 'limited_records'],
    growth: ALL_LEVELS + ['extended_cache', 'smart_reviews', 'extended_records'], 
    elite: ALL_LEVELS + ['unlimited_cache', 'advanced_reviews', 'unlimited_records']
  }
end
