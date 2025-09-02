class JobberApiService
  include HTTParty
  base_uri 'https://api.getjobber.com/api/graphql'

  def self.fetch_visit_details(visit_id, access_token)
    new(access_token).fetch_visit_details(visit_id)
  end

  def initialize(access_token)
    @access_token = access_token
  end

  
  def fetch_visit_details(visit_id)
    Rails.logger.info "🔍 Fetching visit details for: #{visit_id}"
    
    # Check if this looks like a test/mock visit ID
    if test_visit_id?(visit_id)
      Rails.logger.info "🧪 Test visit ID detected - skipping API call to avoid GraphQL error"
      return { error: "Test visit ID - API call skipped", test_data: true }
    end
    
    query = <<~GRAPHQL
      query GetVisitAndJob($visitId: EncodedId!) {
        visit(id: $visitId) {
          id
          title
          job {
            id
            jobNumber
            client {
              id
              firstName
              lastName
              companyName
              emails {
                address
                primary
              }
            }
            property {
              address {
                street
                city
                province
                postalCode
              }
            }
            lineItems {
              nodes {
                name
                description
              }
            }
          }
          notes {
            nodes {
              ... on JobNote {
                id
                message
                createdAt
              }
            }
          }
        }
      }
    GRAPHQL

    headers = {
      'Authorization' => "Bearer #{@access_token}",
      'Content-Type' => 'application/json',
      'X-Jobber-GraphQL-Version' => '2025-04-16'
    }

    payload = {
      query: query,
      variables: { visitId: visit_id }
    }

    begin
      response = HTTParty.post(
        'https://api.getjobber.com/api/graphql',
        headers: headers,
        body: payload.to_json,
        timeout: 30
      )

      Rails.logger.info "📡 Visit API Response code: #{response.code}"
      Rails.logger.info "📡 Visit API Response body: #{response.body[0..500]}..." if response.body

      if response.code == 200
        parsed = response.parsed_response
        
        if parsed['errors']
          # Check if this is a test ID validation error
          invalid_id_error = parsed['errors'].any? do |error|
            error['message']&.include?('not a valid EncodedId') ||
            error['extensions']&.dig('problems')&.any? { |p| p['message']&.include?('not a valid EncodedId') }
          end
          
          if invalid_id_error
            Rails.logger.warn "⚠️ Invalid visit ID format (likely test data): #{parsed['errors']}"
            return { error: "Invalid visit ID format - likely test data", invalid_id: true }
          else
            Rails.logger.error "❌ GraphQL errors: #{parsed['errors']}"
            return { error: "GraphQL errors: #{parsed['errors']}" }
          end
        elsif parsed['data'] && parsed['data']['visit']
          Rails.logger.info "✅ Successfully fetched visit data"
          return parsed['data']['visit']
        else
          Rails.logger.warn "⚠️ No visit data found"
          return { error: "No visit data found" }
        end
      else
        Rails.logger.error "❌ HTTP error: #{response.code}"
        Rails.logger.error "❌ Response body: #{response.body}"
        return { error: "HTTP error: #{response.code}" }
      end

    rescue StandardError => e
      Rails.logger.error "❌ Exception fetching visit: #{e.message}"
      return { error: "Exception: #{e.message}" }
    end
  end

  # Test connection method
  def self.test_connection(access_token)
    Rails.logger.info "🧪 Testing Jobber API connection..."
    
    simple_query = <<~GRAPHQL
      query TestQuery {
        account {
          id
          name
        }
      }
    GRAPHQL
    
    headers = {
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json',
      'X-Jobber-GraphQL-Version' => '2025-04-16'
    }
    
    payload = {
      query: simple_query
    }
    
    begin
      response = HTTParty.post(
        'https://api.getjobber.com/api/graphql',
        headers: headers,
        body: payload.to_json,
        timeout: 10
      )
      
      Rails.logger.info "📡 Test API Response code: #{response&.code}"
      Rails.logger.info "📡 Test API Response body: #{response&.body}"
      
      if response && response.code == 200 && response.body.present?
        parsed = response.parsed_response
        Rails.logger.info "📡 Parsed response: #{parsed.inspect}"
        
        if parsed && parsed['data'] && parsed['data']['account']
          Rails.logger.info "✅ API connection successful! Account: #{parsed['data']['account']['name']}"
          return true
        elsif parsed && parsed['errors']
          Rails.logger.error "❌ GraphQL errors in test: #{parsed['errors']}"
          return false
        else
          Rails.logger.error "❌ API connection failed - unexpected response structure"
          return false
        end
      else
        Rails.logger.error "❌ API connection failed - HTTP #{response&.code || 'nil response'}"
        return false
      end
    rescue StandardError => e
      Rails.logger.error "❌ API connection test failed: #{e.message}"
      return false
    end
  end

  private

  # Check if visit ID looks like test/mock data
  def test_visit_id?(visit_id)
    return true if visit_id.nil? || visit_id.empty?
    
    # Common test patterns
    test_patterns = [
      /^test_/i,          # Starts with "test_"
      /^mock_/i,          # Starts with "mock_" 
      /^dev_/i,           # Starts with "dev_"
      /^demo_/i,          # Starts with "demo_"
      /test\d+/i,         # Contains "test" followed by numbers
      /fake/i             # Contains "fake"
    ]
    
    test_patterns.any? { |pattern| visit_id.match?(pattern) }
  end
end