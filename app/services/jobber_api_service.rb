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
end
