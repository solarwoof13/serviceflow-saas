class ServiceProviderProfile < ApplicationRecord
  # Connect to Jobber account
  belongs_to :jobber_account
  
  # Validation rules
  validates :company_name, presence: true
  validates :main_service_type, presence: true
  validates :email_tone, inclusion: { 
    in: %w[professional friendly expert casual],
    message: "must be a valid tone"
  }
  
  # Helper methods for service areas
  def serves_location?(latitude, longitude)
    return false if service_areas.blank?
    
    service_areas.any? do |area|
      distance = calculate_distance(latitude, longitude, area['lat'], area['lng'])
      distance <= area['radius_miles']
    end
  end
  
  def add_service_area(city, state, radius_miles)
    # You can enhance this later with geocoding
    new_area = {
      'city' => city,
      'state' => state, 
      'radius_miles' => radius_miles
    }
    self.service_areas = (service_areas || []) + [new_area]
  end
  
  # Helper methods for seasonal services
  def seasonal_services(season)
    case season.to_s.downcase
    when 'spring' then spring_services
    when 'summer' then summer_services  
    when 'fall' then fall_services
    when 'winter' then winter_services
    else ''
    end
  end
  
  def current_season_services
    season = determine_current_season
    seasonal_services(season)
  end
  
  def setup_complete?
    profile_completed && 
    company_name.present? && 
    service_details.present? &&
    unique_selling_points.present?
  end

  def to_business_profile_hash
  {
    business_name: company_name,
    industry: main_service_type,
    services_offered: service_details,
    unique_approach: unique_selling_points,
    contact_info: "#{company_name} - #{certifications_licenses}",
    business_values: always_include,
    communication_style: build_communication_style,
    service_description: service_details,
    seasonal_advice: current_season_services
  }
  end

  
  private
  
  def build_communication_style
    style_guide = []
    
    # Base tone
    case email_tone
    when 'professional'
        style_guide << "Use professional, formal language"
    when 'friendly'
        style_guide << "Use warm, friendly, and personal language"
    when 'expert'
        style_guide << "Use educational, expert-level language with technical details"
    when 'casual'
        style_guide << "Use casual, approachable language"
    end
    
    # Always include
    if always_include.present?
        style_guide << "Always include: #{always_include}"
    end
    
    # Never mention
    if never_mention.present?
        style_guide << "Never mention: #{never_mention}"
    end
    
    # Regional expertise
    if local_expertise.present?
        style_guide << "Demonstrate local expertise: #{local_expertise}"
    end
    
    style_guide.join(". ")
  end

  def determine_current_season
    month = Date.current.month
    case month
    when 3..5 then 'spring'
    when 6..8 then 'summer'
    when 9..11 then 'fall'
    else 'winter'
    end
  end
  
  def calculate_distance(lat1, lon1, lat2, lon2)
    # Simple distance calculation (you can enhance this later)
    # Returns distance in miles
    rad_per_deg = Math::PI / 180
    rkm = 6371
    rm = rkm * 0.621371
    
    dlat_rad = (lat2 - lat1) * rad_per_deg
    dlon_rad = (lon2 - lon1) * rad_per_deg
    
    lat1_rad = lat1 * rad_per_deg
    lat2_rad = lat2 * rad_per_deg
    
    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    
    rm * c
  end
end