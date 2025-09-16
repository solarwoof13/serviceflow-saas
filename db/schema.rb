# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_09_15_161405) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "email_deduplication_logs", force: :cascade do |t|
    t.bigint "wix_user_id"
    t.bigint "jobber_account_id"
    t.bigint "visit_id"
    t.string "job_id", null: false
    t.string "customer_email", null: false
    t.string "webhook_topic"
    t.jsonb "webhook_data", default: {}
    t.string "email_status"
    t.string "email_provider"
    t.string "email_id"
    t.text "email_subject"
    t.text "email_content"
    t.text "block_reason"
    t.datetime "email_sent_at"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id", "customer_email"], name: "idx_email_dedup", unique: true
    t.index ["jobber_account_id"], name: "index_email_deduplication_logs_on_jobber_account_id"
    t.index ["sent_at"], name: "index_email_deduplication_logs_on_sent_at"
    t.index ["visit_id"], name: "index_email_deduplication_logs_on_visit_id"
    t.index ["wix_user_id"], name: "index_email_deduplication_logs_on_wix_user_id"
  end

  create_table "emails", force: :cascade do |t|
    t.bigint "jobber_account_id", null: false
    t.bigint "visit_id"
    t.string "recipient_email", null: false
    t.string "subject"
    t.text "content"
    t.string "status", default: "pending"
    t.string "sendgrid_message_id"
    t.jsonb "sendgrid_response"
    t.datetime "sent_at"
    t.datetime "data_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_expires_at"], name: "index_emails_on_data_expires_at"
    t.index ["jobber_account_id"], name: "index_emails_on_jobber_account_id"
    t.index ["sendgrid_message_id"], name: "index_emails_on_sendgrid_message_id"
    t.index ["sent_at"], name: "index_emails_on_sent_at"
    t.index ["status"], name: "index_emails_on_status"
    t.index ["visit_id"], name: "index_emails_on_visit_id"
  end

  create_table "features", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_features_on_name"
  end

  create_table "jobber_accounts", force: :cascade do |t|
    t.string "jobber_id"
    t.string "name"
    t.string "jobber_access_token"
    t.datetime "jobber_access_token_expired_by", precision: nil
    t.string "jobber_refresh_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.boolean "needs_reauthorization", default: false
    t.string "account_id"
    t.text "processed_visit_ids", default: [], array: true
    t.index ["account_id"], name: "index_jobber_accounts_on_account_id", unique: true
    t.index ["jobber_id"], name: "index_jobber_accounts_on_jobber_id", unique: true
    t.index ["processed_visit_ids"], name: "index_jobber_accounts_on_processed_visit_ids", using: :gin
  end

  create_table "service_provider_profiles", force: :cascade do |t|
    t.bigint "jobber_account_id", null: false
    t.string "company_name", null: false
    t.text "company_description"
    t.string "years_in_business"
    t.jsonb "service_areas", default: []
    t.string "main_service_type"
    t.text "service_details"
    t.text "equipment_methods"
    t.text "unique_selling_points"
    t.string "certifications_licenses"
    t.text "local_expertise"
    t.text "spring_services"
    t.text "summer_services"
    t.text "fall_services"
    t.text "winter_services"
    t.string "email_tone", default: "professional"
    t.text "always_include"
    t.text "never_mention"
    t.boolean "profile_completed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jobber_account_id"], name: "idx_spp_jobber_account"
    t.index ["jobber_account_id"], name: "index_service_provider_profiles_on_jobber_account_id"
    t.index ["main_service_type"], name: "idx_spp_service_type"
    t.index ["service_areas"], name: "idx_spp_service_areas", using: :gin
  end

  create_table "subscription_features", force: :cascade do |t|
    t.bigint "subscription_id", null: false
    t.bigint "feature_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_id"], name: "index_subscription_features_on_feature_id"
    t.index ["subscription_id"], name: "index_subscription_features_on_subscription_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "jobber_account_id", null: false
    t.string "plan_type", default: "basic"
    t.integer "retention_days", default: 60
    t.integer "email_limit", default: 100
    t.integer "emails_sent_this_period", default: 0
    t.datetime "billing_period_start"
    t.datetime "billing_period_end"
    t.boolean "active", default: true
    t.string "stripe_subscription_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_subscriptions_on_active"
    t.index ["billing_period_end"], name: "index_subscriptions_on_billing_period_end"
    t.index ["jobber_account_id"], name: "index_subscriptions_on_jobber_account_id"
  end

  create_table "visits", force: :cascade do |t|
    t.bigint "wix_user_id"
    t.bigint "jobber_account_id"
    t.string "jobber_visit_id", null: false
    t.string "job_number"
    t.string "customer_name"
    t.string "customer_email"
    t.jsonb "property_address", default: {}
    t.text "service_notes"
    t.datetime "completed_at"
    t.datetime "data_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_expires_at"], name: "index_visits_on_data_expires_at"
    t.index ["jobber_account_id"], name: "index_visits_on_jobber_account_id"
    t.index ["jobber_visit_id"], name: "index_visits_on_jobber_visit_id", unique: true
    t.index ["wix_user_id"], name: "index_visits_on_wix_user_id"
  end

  create_table "webhook_events", force: :cascade do |t|
    t.string "event_type", null: false
    t.string "jobber_item_id"
    t.jsonb "payload", default: {}
    t.string "processing_status", default: "pending"
    t.text "error_message"
    t.bigint "jobber_account_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_webhook_events_on_created_at"
    t.index ["event_type", "created_at"], name: "index_webhook_events_on_event_type_and_created_at"
    t.index ["jobber_account_id"], name: "index_webhook_events_on_jobber_account_id"
    t.index ["jobber_item_id"], name: "index_webhook_events_on_jobber_item_id"
    t.index ["processing_status"], name: "index_webhook_events_on_processing_status"
  end

  create_table "wix_users", force: :cascade do |t|
    t.string "wix_user_id", null: false
    t.string "email"
    t.string "display_name"
    t.bigint "jobber_account_id"
    t.string "subscription_plan", default: "basic"
    t.integer "retention_days", default: 60
    t.integer "email_limit", default: 100
    t.integer "emails_sent_this_period", default: 0
    t.datetime "billing_period_start"
    t.datetime "billing_period_end"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_wix_users_on_email"
    t.index ["jobber_account_id"], name: "index_wix_users_on_jobber_account_id"
    t.index ["wix_user_id"], name: "index_wix_users_on_wix_user_id", unique: true
  end

  add_foreign_key "email_deduplication_logs", "jobber_accounts"
  add_foreign_key "email_deduplication_logs", "wix_users"
  add_foreign_key "emails", "jobber_accounts"
  add_foreign_key "emails", "visits"
  add_foreign_key "service_provider_profiles", "jobber_accounts"
  add_foreign_key "subscription_features", "features"
  add_foreign_key "subscription_features", "subscriptions"
  add_foreign_key "subscriptions", "jobber_accounts"
  add_foreign_key "visits", "jobber_accounts"
  add_foreign_key "visits", "wix_users"
  add_foreign_key "webhook_events", "jobber_accounts"
  add_foreign_key "wix_users", "jobber_accounts"
end
