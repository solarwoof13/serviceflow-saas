import axios from 'axios';

// Configure API base URL
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:4000';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // For Jobber OAuth cookies
});

// Types
export interface ServiceProviderProfile {
  id?: number;
  company_name: string;
  company_description: string;
  years_in_business: string;
  main_service_type: string;
  service_details: string;
  unique_selling_points: string;
  local_expertise: string;
  spring_services: string;
  summer_services: string;
  fall_services: string;
  winter_services: string;
  email_tone: string;
  profile_completed: boolean;
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}

// API Functions
export const serviceProviderAPI = {
  // Create new profile
  createProfile: async (profileData: Partial<ServiceProviderProfile>): Promise<ApiResponse<ServiceProviderProfile>> => {
    try {
      const response = await api.post('/api/v1/service_provider_profile', {
        service_provider_profile: profileData
      });
      return { success: true, data: response.data };
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.error || 'Failed to create profile' 
      };
    }
  },

  // Update existing profile
  updateProfile: async (profileData: Partial<ServiceProviderProfile>): Promise<ApiResponse<ServiceProviderProfile>> => {
    try {
      const response = await api.patch('/api/v1/service_provider_profile', {
        service_provider_profile: profileData
      });
      return { success: true, data: response.data };
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.error || 'Failed to update profile' 
      };
    }
  },

  // Get existing profile
  getProfile: async (): Promise<ApiResponse<ServiceProviderProfile>> => {
    try {
      const response = await api.get('/api/v1/service_provider_profile');
      return { success: true, data: response.data };
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.error || 'Failed to get profile' 
      };
    }
  },

  // Jobber OAuth
  initiateJobberAuth: async (): Promise<{ authUrl: string }> => {
    const response = await api.get('/auth/jobber');
    return response.data;
  },

  // Test email generation
  generateTestEmail: async (profileData: Partial<ServiceProviderProfile>): Promise<ApiResponse<{ email_content: string }>> => {
    try {
      const response = await api.post('/api/v1/test_email', {
        service_provider_profile: profileData
      });
      return { success: true, data: response.data };
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.error || 'Failed to generate test email' 
      };
    }
  }
};

export default api;