class AiEnhancementService
  include HTTParty
  
  def initialize
    @api_key = ENV['GROK_SIGNUP_API_KEY']
    @api_url = ENV['GROK_SIGNUP_API_URL'] || 'https://api.x.ai/v1/chat/completions'
    @model = ENV['GROK_SIGNUP_MODEL'] || 'grok-4-0709'
    @temperature = ENV['GROK_SIGNUP_TEMPERATURE']&.to_f || 0.7
  end

  def enhance_text(text, enhancement_type, context = {})
      # Add debug logging right here at the start of the method
    Rails.logger.debug "Enhancement Request:"
    Rails.logger.debug "  Text: #{text}"
    Rails.logger.debug "  Type: #{enhancement_type}"
    Rails.logger.debug "  Context: #{context.inspect}"
    
    return mock_enhancement(text, enhancement_type, context) unless @api_key.present?
    
    prompt = build_enhancement_prompt(text, enhancement_type, context)
    
    response = HTTParty.post(@api_url, {
      headers: {
        'Authorization' => "Bearer #{@api_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        model: @model,
        messages: [
          {
            role: 'system',
            content: 'You are an expert business writing assistant. Always provide exactly 3 different improved versions of the business text. Use clean, professional language without markdown formatting, headers, or special characters. Number your responses as OPTION 1:, OPTION 2:, OPTION 3: followed by the improved text.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: 1500,
        temperature: @temperature
      }.to_json
    })
    
    if response.success?
      content = response.parsed_response.dig('choices', 0, 'message', 'content')
      parse_suggestions(content)
    else
      Rails.logger.error "AI Enhancement failed: #{response.body}"
      { error: "Enhancement temporarily unavailable" }
    end
  rescue => e
    Rails.logger.error "AI Enhancement error: #{e.message}"
    mock_enhancement(text, enhancement_type, context)
  end

  def mock_enhancement(text, enhancement_type, context)
    # Smart service type detection
    service_type = determine_service_type(context, text)
    years = context[:years_in_business] || 'established'
    
    case enhancement_type
    when 'company_description'
      {
        suggestions: [
          "Professional #{service_type.downcase} company with #{years} of proven expertise, delivering reliable solutions and exceptional customer service with a commitment to quality and satisfaction.",
          "Trusted local #{service_type.downcase} specialists focused on building lasting relationships through dependable service, transparent communication, and superior results.",
          "Expert #{service_type.downcase} professionals combining industry experience with modern techniques to provide comprehensive solutions tailored to each client's unique needs."
        ]
      }
    when 'service_details'
      core_service = extract_core_service_from_text(text)
      {
        suggestions: [
          "Comprehensive #{core_service} including thorough consultation, professional execution, quality assurance, and ongoing support to ensure optimal results and complete customer satisfaction.",
          "Expert #{core_service} utilizing industry-standard practices, proven methodologies, and meticulous attention to detail for reliable, long-lasting results that exceed expectations.",
          "Full-service #{core_service} from initial assessment through project completion, featuring transparent pricing, timely delivery, and guaranteed satisfaction with every engagement."
        ]
      }
    when 'unique_selling_points'
      {
        suggestions: [
          "Licensed and insured professionals with proven #{service_type.downcase} expertise, competitive pricing, and 100% satisfaction guarantee on all work performed with exceptional attention to detail.",
          "Local industry leaders known for reliability, transparent communication, and consistently delivering #{service_type.downcase} projects on time and within budget every single time.",
          "Certified #{service_type.downcase} specialists using premium materials and advanced techniques, backed by comprehensive warranties and award-winning customer service excellence."
        ]
      }
    when 'local_expertise'
      {
        suggestions: [
          "Deep understanding of local regulations, climate conditions, and regional requirements specific to #{service_type.downcase}, ensuring all work meets or exceeds municipal standards and codes.",
          "Extensive knowledge of area-specific challenges and solutions, built through years of serving the local community and understanding unique regional #{service_type.downcase} needs and conditions.",
          "Established relationships with local suppliers, inspectors, and contractors, plus intimate familiarity with neighborhood characteristics and municipal #{service_type.downcase} requirements and best practices."
        ]
      }
    else
      { suggestions: ["Professional enhancement of: #{text} with specialized #{service_type.downcase} expertise and local market knowledge"] }
    end
  end

  private

  def build_enhancement_prompt(text, enhancement_type, context)
    service_type = context[:service_type] || 'service business'
    years = context[:years_in_business] || 'established'
    
    case enhancement_type
    when 'company_description'
      prompt = "You are a professional business copywriter. Transform casual or informal business descriptions into polished, professional copy while preserving the core business offerings.\n\n"
      prompt += "Guidelines:\n"
      prompt += "- Elevate informal language to professional terminology (e.g., 'weed' → 'cannabis', 'stuff' → 'products/services')\n"
      prompt += "- Maintain accuracy about actual business offerings - do not avoid or replace legitimate business terms\n"
      prompt += "- Use industry-standard professional language\n"
      prompt += "- Keep the essential business concept intact\n\n"
      prompt += "Transform this #{service_type} company description:\n\n"
      prompt += "Original: \"#{text}\"\n\n"
      prompt += "Business context:\n"
      prompt += "- Years in business: #{years}\n"
      prompt += "- Service type: #{service_type}\n\n"
      prompt += "Requirements:\n"
      prompt += "- Professional and trustworthy tone\n"
      prompt += "- Highlight expertise and experience\n"
      prompt += "- Include specific customer benefits\n"
      prompt += "- 2-3 sentences maximum\n"
      prompt += "- Industry-appropriate language\n\n"
      prompt += "Provide exactly 3 improved versions in this format:\n"
      prompt += "OPTION 1: [improved version here]\n"
      prompt += "OPTION 2: [improved version here]\n"
      prompt += "OPTION 3: [improved version here]"
      
    when 'service_details'
      prompt = "You are a professional business copywriter. Transform service descriptions into polished, professional copy while maintaining the actual business offerings.\n\n"
      prompt += "Guidelines:\n"
      prompt += "- Elevate casual language to professional industry terms\n"
      prompt += "- Preserve the core services and products offered\n"
      prompt += "- Use appropriate business and technical terminology\n"
      prompt += "- Do not avoid legitimate business categories\n\n"
      prompt += "Enhance this service description:\n\n"
      prompt += "Original: \"#{text}\"\n"
      prompt += "Service type: #{service_type}\n\n"
      prompt += "Improve by:\n"
      prompt += "- Adding specific service details\n"
      prompt += "- Mentioning methods/equipment used\n"
      prompt += "- Highlighting expertise and thoroughness\n"
      prompt += "- Using appropriate industry terminology\n"
      prompt += "- Emphasizing quality and professionalism\n\n"
      prompt += "Provide 3 enhanced versions:\n"
      prompt += "OPTION 1: [detailed & comprehensive]\n"
      prompt += "OPTION 2: [benefit-focused]\n"
      prompt += "OPTION 3: [technical & expert]"
      
    when 'unique_selling_points'
      prompt = "You are a professional business copywriter. Create compelling value propositions that elevate the business while maintaining accuracy about their offerings.\n\n"
      prompt += "Guidelines:\n"
      prompt += "- Transform casual language into professional business terminology\n"
      prompt += "- Preserve the actual business concept and offerings\n"
      prompt += "- Use confident, industry-appropriate language\n"
      prompt += "- Focus on benefits and expertise\n\n"
      prompt += "Transform these selling points:\n\n"
      prompt += "Original: \"#{text}\"\n"
      prompt += "Business type: #{service_type}\n\n"
      prompt += "Create compelling USPs that:\n"
      prompt += "- Address specific customer pain points\n"
      prompt += "- Highlight competitive advantages\n"
      prompt += "- Use confident, professional language\n"
      prompt += "- Include measurable benefits when possible\n"
      prompt += "- Sound trustworthy and authentic\n\n"
      prompt += "Provide 3 different approaches:\n"
      prompt += "OPTION 1: [results-focused USPs]\n"
      prompt += "OPTION 2: [trust & reliability focused]\n"
      prompt += "OPTION 3: [expertise & innovation focused]"
      
    when 'local_expertise'
      prompt = "You are a professional business copywriter. Enhance local expertise descriptions using professional language while preserving the business focus.\n\n"
      prompt += "Guidelines:\n"
      prompt += "- Elevate informal language to professional terminology\n"
      prompt += "- Maintain the core business offerings and expertise areas\n"
      prompt += "- Use industry-standard professional language\n"
      prompt += "- Focus on credibility and local knowledge\n\n"
      prompt += "Enhance this local expertise:\n\n"
      prompt += "Original: \"#{text}\"\n"
      prompt += "Service type: #{service_type}\n\n"
      prompt += "Improve by:\n"
      prompt += "- Highlighting specific regional knowledge\n"
      prompt += "- Mentioning local conditions/challenges\n"
      prompt += "- Adding credibility markers\n"
      prompt += "- Demonstrating community connection\n"
      prompt += "- Including location-specific advantages\n\n"
      prompt += "Provide 3 versions:\n"
      prompt += "OPTION 1: [community-focused expertise]\n"
      prompt += "OPTION 2: [technical local knowledge]\n"
      prompt += "OPTION 3: [experience-based authority]"
      
    else
      "Improve this business text to be more professional and compelling while maintaining complete accuracy: #{text}"
    end
    
    prompt
  end

  def parse_suggestions(content)
    # Clean up any markdown formatting first
    cleaned_content = content.gsub(/^#+\s*.*?\n/, '') # Remove markdown headers
    cleaned_content = cleaned_content.gsub(/\*\*(.*?)\*\*/, '\1') # Remove bold markdown
    
    if cleaned_content.include?('OPTION')
      # Split by OPTION markers and clean up
      options = cleaned_content.split(/OPTION \d+:/).reject(&:blank?)
      suggestions = options.map do |option|
        # Remove brackets, labels, and clean up
        cleaned = option.strip
        cleaned = cleaned.gsub(/^\[.*?\]\s*/, '') # Remove [version] labels
        cleaned = cleaned.gsub(/^\[|\]$/, '') # Remove any remaining brackets
        cleaned = cleaned.gsub(/^-\s*/, '') # Remove leading dashes
        cleaned.strip
      end.reject(&:blank?)
    else
      # If no OPTION format, try to split by numbered lists or line breaks
      lines = cleaned_content.split(/\n+/).reject(&:blank?)
      suggestions = lines.map do |line|
        # Clean up numbered lists and formatting
        cleaned = line.strip
        cleaned = cleaned.gsub(/^\d+\.\s*/, '') # Remove "1. " numbering
        cleaned = cleaned.gsub(/^-\s*/, '') # Remove leading dashes
        cleaned = cleaned.gsub(/^\[.*?\]\s*/, '') # Remove [labels]
        cleaned.strip
      end.reject(&:blank?).select { |s| s.length > 20 } # Only keep substantial suggestions
    end
    
    # Ensure we always have at least 1 suggestion, max 3
    final_suggestions = suggestions.first(3)
    if final_suggestions.empty?
      # Fallback: use the original content cleaned up
      cleaned_fallback = cleaned_content.strip
      cleaned_fallback = cleaned_fallback.gsub(/^\[.*?\]\s*/, '')
      final_suggestions = [cleaned_fallback]
    end
    
    { suggestions: final_suggestions }
  end

  def determine_service_type(context, text)
    provided_service = context[:service_type].to_s.strip
    
    # List of predefined form options
    predefined_services = [
      'Beekeeping Services',
      'Lawn Care & Maintenance', 
      'Pest Control',
      'Snow Removal',
      'Cleaning Services',
      'HVAC Services',
      'Plumbing',
      'Electrical',
      'Landscaping'
    ]
    
    # If it's a predefined service (not "Other" or empty), use it
    if predefined_services.include?(provided_service)
      return provided_service
    end
    
    # If it's "Other" or empty, extract from text
    if provided_service.empty? || provided_service == 'Other'
      return extract_service_from_text(text)
    end
    
    # Fallback to provided service (in case new options are added)
    provided_service.presence || 'Service Provider'
  end

  def extract_service_from_text(text)
    # Enhanced extraction for "Other" services
    cleaned_text = text.downcase.strip
    
    # Look for "we do/provide/offer [service]" patterns
    service_patterns = [
      /(?:we (?:do|provide|offer|specialize in|focus on)|our business is|specializing in)\s+(.+?)(?:\s+(?:for|to|with|and)|[,.]|$)/,
      /(?:expert|professional|certified)\s+(.+?)\s+(?:services?|company|business|provider)/,
      /(.+?)\s+(?:services?|company|business|solutions?)(?:\s+for)?/,
      /(?:providing|offering)\s+(.+?)(?:\s+(?:for|to|with)|$)/
    ]
    
    service_patterns.each do |pattern|
      if match = cleaned_text.match(pattern)
        service = match[1].strip
        
        # Clean up the extracted service
        service = service.gsub(/^(a|an|the)\s+/, '') # Remove articles
        service = service.gsub(/\s+(services?|work|solutions?)$/, '') # Remove trailing words
        service = service.gsub(/\s+(and|or|with).+$/, '') # Remove everything after conjunctions
        
        # Add "services" if it doesn't end appropriately
        unless service.match?(/(?:services?|work|solutions?|care|maintenance|management|consulting|support)$/i)
          service += " services"
        end
        
        return service.titleize
      end
    end
    
    # If no pattern matches, try to extract meaningful words
    words = cleaned_text.split(/\s+/)
    service_words = words.select do |word|
      word.length > 3 && 
      !%w[with that this they them have been will would could should very really most some many].include?(word) &&
      !word.match?(/^(we|our|and|the|for|are|can|all|you|your|also|very|much|like|such)$/i)
    end
    
    if service_words.any?
      main_service = service_words.first(2).join(' ')
      main_service += " services" unless main_service.include?('service')
      main_service.titleize
    else
      "Service Provider"
    end
  end

  def extract_core_service_from_text(text)
    # Extract the core activity from service details
    cleaned_text = text.downcase.strip
    
    # Look for action-based descriptions
    action_patterns = [
      /(?:we )?(?:provide|offer|perform|handle|manage|maintain|install|repair|clean|remove|deliver|execute|conduct)\s+(.+?)(?:\s+(?:for|to|with|using|and)|[,.]|$)/,
      /(?:specializing in|focused on|expert in|experienced with)\s+(.+?)(?:\s+(?:for|to|with|using|and)|[,.]|$)/,
      /(.+?)\s+(?:for (?:customers?|clients?|businesses?|homes?|properties?|commercial|residential))/
    ]
    
    action_patterns.each do |pattern|
      if match = cleaned_text.match(pattern)
        service = match[1].strip
        service = service.gsub(/^(a|an|the)\s+/, '') # Remove articles
        return service
      end
    end
    
    # Fallback: clean up the original text
    cleaned_text.gsub(/^(we|our)\s+/, '').gsub(/\s+(for|to|with).+$/, '').strip
  end
end