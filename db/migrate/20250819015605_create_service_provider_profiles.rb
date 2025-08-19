class CreateServiceProviderProfiles < ActiveRecord::Migration[7.0]
  def change
    create_table :service_provider_profiles do |t|
      # Link to Jobber account
      t.references :jobber_account, null: false, foreign_key: true
      
      # Company Information (Section 1)
      t.string :company_name, null: false
      t.text :company_description
      t.string :years_in_business
      
      # Service Areas (Enhanced for multiple areas + radius)
      t.jsonb :service_areas, default: []
      
      # Services (Section 2)  
      t.string :main_service_type
      t.text :service_details
      t.text :equipment_methods
      
      # What Makes You Special (Section 3)
      t.text :unique_selling_points
      t.string :certifications_licenses
      
      # Regional Knowledge (Section 4)
      t.text :local_expertise
      t.text :spring_services
      t.text :summer_services
      t.text :fall_services
      t.text :winter_services
      
      # Email Preferences (Section 5)
      t.string :email_tone, default: 'professional'
      t.text :always_include
      t.text :never_mention
      
      # Setup tracking
      t.boolean :profile_completed, default: false
      
      t.timestamps
    end
    
    # Make searches faster - with unique names to avoid conflicts
    add_index :service_provider_profiles, :jobber_account_id, name: 'idx_spp_jobber_account'
    add_index :service_provider_profiles, :main_service_type, name: 'idx_spp_service_type'
    add_index :service_provider_profiles, :service_areas, using: :gin, name: 'idx_spp_service_areas'
  end
end