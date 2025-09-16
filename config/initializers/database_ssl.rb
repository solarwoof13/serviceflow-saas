# config/initializers/database_ssl.rb
if Rails.env.production? && ENV['DATABASE_URL']
  require 'uri'
  
  db_url = URI.parse(ENV['DATABASE_URL'])
  
  ActiveRecord::Base.establish_connection(
    adapter: 'postgresql',
    host: db_url.host,
    port: db_url.port,
    database: db_url.path[1..-1],
    username: db_url.user,
    password: db_url.password,
    sslmode: 'require',
    prepared_statements: false
  )
end