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

    response = self.class.post('/', {
      headers: {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json'
      },
      body: {
        query: query,
        variables: { visitId: visit_id }
      }.to_json
    })

    if response.success?
      response.parsed_response
    else
      { error: "Failed to fetch visit data: #{response.code}" }
    end
  end
# ADD: Test connection method
  # FIXED: Test connection method with proper nil handling
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
      'X-Jobber-GraphQL-Version' => '2023-11-15'
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
end
