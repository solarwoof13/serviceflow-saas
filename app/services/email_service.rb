require 'sendgrid-ruby'
include SendGrid

class EmailService
  def self.send_customer_email(to:, subject:, content:, from_name: nil)
    new.send_customer_email(to: to, subject: subject, content: content, from_name: from_name)
  end
  
  def initialize
    @api_key = ENV['SENDGRID_API_KEY']
    @from_email = ENV['FROM_EMAIL'] || 'noreply@serviceflow.com'
    @from_name = ENV['FROM_NAME'] || 'ServiceFlow'
  end
  
  def send_customer_email(to:, subject:, content:, from_name: nil)
    # Check if SendGrid is configured
    unless @api_key.present?
      Rails.logger.warn "📧 SENDGRID_API_KEY not found - using mock email"
      return mock_email_response(to, subject, content)
    end
    
    Rails.logger.info "📧 Sending email via SendGrid..."
    Rails.logger.info "   To: #{to}"
    Rails.logger.info "   Subject: #{subject}"
    Rails.logger.info "   From: #{@from_email}"
    Rails.logger.info "   Content length: #{content.length} characters"
    
    begin
      # Create email payload using SendGrid's expected format
      mail_data = {
        personalizations: [
          {
            to: [{ email: to }],
            subject: subject
          }
        ],
        from: {
          email: @from_email,
          name: from_name || @from_name
        },
        content: [
          {
            type: 'text/plain',
            value: content
          }
        ]
      }
      
      # Send via SendGrid
      sg = SendGrid::API.new(api_key: @api_key)
      response = sg.client.mail._('send').post(request_body: mail_data.to_json)
      
      if response.status_code.to_i.between?(200, 299)
        Rails.logger.info "✅ Email sent successfully via SendGrid"
        Rails.logger.info "   Status: #{response.status_code}"
        
        {
          success: true,
          message: "Email sent successfully via SendGrid",
          email_id: extract_message_id(response),
          status_code: response.status_code,
          provider: 'sendgrid'
        }
      else
        error_msg = "SendGrid error: #{response.status_code} - #{response.body}"
        Rails.logger.error "❌ #{error_msg}"
        
        {
          success: false,
          error: error_msg,
          status_code: response.status_code,
          provider: 'sendgrid'
        }
      end
      
    rescue => e
      error_msg = "Email service error: #{e.message}"
      Rails.logger.error "💥 #{error_msg}"
      Rails.logger.error e.backtrace[0..2].join("\n")
      
      {
        success: false,
        error: error_msg,
        provider: 'sendgrid'
      }
    end
  end
  
  # Send HTML email (for future rich formatting)
  def send_html_email(to:, subject:, html_content:, text_content: nil, from_name: nil)
    unless @api_key.present?
      return mock_email_response(to, subject, html_content)
    end
    
    begin
      from = Email.new(email: @from_email, name: from_name || @from_name)
      to_email = Email.new(email: to)
      
      # Create mail with both HTML and text content
      mail = Mail.new(from, subject, to_email)
      mail.contents = [
        Content.new(type: 'text/plain', value: text_content || strip_html(html_content)),
        Content.new(type: 'text/html', value: html_content)
      ]
      
      sg = SendGrid::API.new(api_key: @api_key)
      response = sg.client.mail._('send').post(request_body: mail.to_json)
      
      if response.status_code.to_i.between?(200, 299)
        Rails.logger.info "✅ HTML email sent successfully"
        
        {
          success: true,
          message: "HTML email sent successfully",
          email_id: extract_message_id(response),
          status_code: response.status_code,
          provider: 'sendgrid'
        }
      else
        {
          success: false,
          error: "SendGrid HTML error: #{response.status_code} - #{response.body}",
          provider: 'sendgrid'
        }
      end
      
    rescue => e
      {
        success: false,
        error: "HTML email error: #{e.message}",
        provider: 'sendgrid'
      }
    end
  end
  
  private
  
  def mock_email_response(to, subject, content)
    email_id = "mock_#{SecureRandom.hex(8)}"
    
    Rails.logger.info "📧 MOCK EMAIL (SendGrid not configured):"
    Rails.logger.info "   To: #{to}"
    Rails.logger.info "   Subject: #{subject}"
    Rails.logger.info "   Content: #{content[0..100]}..."
    Rails.logger.info "   Mock ID: #{email_id}"
    
    {
      success: true,
      message: "Email sent successfully (mock mode)",
      email_id: email_id,
      provider: 'mock',
      mock: true
    }
  end
  
  def extract_message_id(response)
    # Try to extract message ID from SendGrid response headers
    message_id = response.headers['X-Message-Id'] if response.respond_to?(:headers)
    message_id || "sg_#{SecureRandom.hex(8)}"
  end
  
  def strip_html(html_content)
    # Simple HTML tag removal for text fallback
    html_content.gsub(/<[^>]*>/, '').strip
  end
end