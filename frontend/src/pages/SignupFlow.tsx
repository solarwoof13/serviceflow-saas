import React, { useState } from 'react';
import styled from 'styled-components';
import { ArrowRight, ArrowLeft, CheckCircle, Brain, Loader, AlertCircle } from 'lucide-react';
import { serviceProviderAPI, ServiceProviderProfile } from '../services/api';
import AiEnhancementButton from '../components/AiEnhancementButton';

// Types
interface BusinessProfile {
  companyName: string;
  companyDescription: string;
  yearsInBusiness: string;
  mainServiceType: string;
  serviceDetails: string;
  uniqueSellingPoints: string;
  serviceAreas: string;
  emailTone: string;
  localExpertise: string;
  springServices: string;
  summerServices: string;
  fallServices: string;
  winterServices: string;
}

const Container = styled.div`
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 50%, #00d4aa 100%);
`;

const SignupCard = styled.div`
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  border-radius: 24px;
  padding: 3rem;
  max-width: 600px;
  width: 100%;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
`;

const ProgressBar = styled.div`
  display: flex;
  justify-content: space-between;
  margin-bottom: 3rem;
`;

const ProgressStep = styled.div<{ active: boolean; completed: boolean }>`
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 0.9rem;
  transition: all 0.3s ease;
  
  ${props => props.completed && `
    background: linear-gradient(135deg, #667eea 0%, #00d4aa 100%);
    color: white;
  `}
  
  ${props => props.active && !props.completed && `
    background: linear-gradient(135deg, #667eea 0%, #00d4aa 100%);
    color: white;
    transform: scale(1.1);
  `}
  
  ${props => !props.active && !props.completed && `
    background: #e2e8f0;
    color: #64748b;
  `}
`;

const Title = styled.h2`
  font-size: 2rem;
  color: #1a202c;
  margin-bottom: 0.5rem;
  font-weight: 700;
`;

const Subtitle = styled.p`
  color: #64748b;
  margin-bottom: 2rem;
  font-size: 1.1rem;
`;

const FormGroup = styled.div`
  margin-bottom: 1.5rem;
`;

const Label = styled.label`
  display: block;
  color: #374151;
  font-weight: 600;
  margin-bottom: 0.5rem;
`;

const Input = styled.input`
  width: 100%;
  padding: 1rem;
  border: 2px solid #e5e7eb;
  border-radius: 12px;
  font-size: 1rem;
  transition: all 0.2s ease;
  
  &:focus {
    border-color: #667eea;
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
  }
`;

const TextArea = styled.textarea`
  width: 100%;
  padding: 1rem;
  border: 2px solid #e5e7eb;
  border-radius: 12px;
  font-size: 1rem;
  min-height: 120px;
  resize: vertical;
  font-family: inherit;
  transition: all 0.2s ease;
  
  &:focus {
    border-color: #667eea;
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
  }
`;

const Select = styled.select`
  width: 100%;
  padding: 1rem;
  border: 2px solid #e5e7eb;
  border-radius: 12px;
  font-size: 1rem;
  background: white;
  transition: all 0.2s ease;
  
  &:focus {
    border-color: #667eea;
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
  }
`;

const ButtonGroup = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 2rem;
`;

const Button = styled.button<{ variant?: 'primary' | 'secondary'; loading?: boolean }>`
  padding: 1rem 2rem;
  border-radius: 12px;
  font-size: 1rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  transition: all 0.2s ease;
  position: relative;
  
  ${props => props.variant === 'primary' ? `
    background: linear-gradient(135deg, #667eea 0%, #00d4aa 100%);
    color: white;
    border: none;
    
    &:hover:not(:disabled) {
      transform: translateY(-2px);
      box-shadow: 0 8px 25px rgba(102, 126, 234, 0.3);
    }
  ` : `
    background: transparent;
    color: #64748b;
    border: 2px solid #e5e7eb;
    
    &:hover:not(:disabled) {
      border-color: #cbd5e1;
    }
  `}
  
  &:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    transform: none !important;
  }
  
  ${props => props.loading && `
    color: transparent;
  `}
`;

const LoadingSpinner = styled.div`
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  
  svg {
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
`;

const HelpText = styled.p`
  font-size: 0.9rem;
  color: #64748b;
  margin-top: 0.5rem;
  line-height: 1.4;
`;

const ErrorMessage = styled.div`
  background: #fee2e2;
  color: #dc2626;
  padding: 1rem;
  border-radius: 12px;
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
`;

const SuccessMessage = styled.div`
  background: #d1fae5;
  color: #065f46;
  padding: 1rem;
  border-radius: 12px;
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
`;

const SignupFlow: React.FC = () => {
  const [currentStep, setCurrentStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  
  const [businessProfile, setBusinessProfile] = useState<BusinessProfile>({
    companyName: '',
    companyDescription: '',
    yearsInBusiness: '',
    mainServiceType: '',
    serviceDetails: '',
    uniqueSellingPoints: '',
    serviceAreas: '',
    emailTone: 'friendly',
    localExpertise: '',
    springServices: '',
    summerServices: '',
    fallServices: '',
    winterServices: ''
  });

  const updateProfile = (field: keyof BusinessProfile, value: string) => {
    setBusinessProfile(prev => ({ ...prev, [field]: value }));
    setError(null); // Clear errors when user types
  };

  const saveProfile = async () => {
    setLoading(true);
    setError(null);
    
    try {
      // Convert frontend format to backend format
      const profileData: Partial<ServiceProviderProfile> = {
        company_name: businessProfile.companyName,
        company_description: businessProfile.companyDescription,
        years_in_business: businessProfile.yearsInBusiness,
        main_service_type: businessProfile.mainServiceType,
        service_details: businessProfile.serviceDetails,
        unique_selling_points: businessProfile.uniqueSellingPoints,
        local_expertise: businessProfile.localExpertise,
        spring_services: businessProfile.springServices,
        summer_services: businessProfile.summerServices,
        fall_services: businessProfile.fallServices,
        winter_services: businessProfile.winterServices,
        email_tone: businessProfile.emailTone,
        profile_completed: currentStep === 6
      };

      console.log('Saving profile data:', profileData);
      const result = await serviceProviderAPI.createProfile(profileData);
      
      if (result.success) {
        setSuccess('Profile saved successfully! 🎉');
        console.log('Profile saved:', result.data);
      } else {
        setError(result.error || 'Failed to save profile');
        console.error('Save failed:', result.error);
      }
    } catch (err) {
      setError('Network error. Please try again.');
      console.error('Network error:', err);
    } finally {
      setLoading(false);
    }
  };

  const nextStep = async () => {
    // Auto-save on step 4 (after seasonal services)
    if (currentStep === 4) {
      await saveProfile();
    }
    
    if (currentStep < 6) {
      setCurrentStep(prev => prev + 1);
    }
  };

  const prevStep = () => {
    if (currentStep > 1) {
      setCurrentStep(prev => prev - 1);
      setError(null);
      setSuccess(null);
    }
  };

  const isStepValid = () => {
    switch (currentStep) {
      case 1:
        return businessProfile.companyName.trim() && 
               businessProfile.companyDescription.trim() && 
               businessProfile.yearsInBusiness;
      case 2:
        return businessProfile.mainServiceType && 
               businessProfile.serviceDetails.trim();
      case 3:
        return businessProfile.uniqueSellingPoints.trim();
      case 4:
        return true; // Seasonal services are optional
      default:
        return true;
    }
  };

  const renderStep = () => {
    switch (currentStep) {
      case 1:
        return (
          <>
            <Title>Tell us about your business</Title>
            <Subtitle>Help us understand your company so we can create the perfect customer emails</Subtitle>
            
            <FormGroup>
              <Label>Company Name *</Label>
              <Input
                type="text"
                placeholder="e.g., Kinnickinnic Bees"
                value={businessProfile.companyName}
                onChange={(e) => updateProfile('companyName', e.target.value)}
              />
            </FormGroup>

            <FormGroup>
              <Label>Describe your business *</Label>
              <TextArea
                placeholder="e.g., Family-owned beekeeping operation specializing in treatment-free hive management with 15+ years experience in sustainable practices..."
                value={businessProfile.companyDescription}
                onChange={(e) => updateProfile('companyDescription', e.target.value)}
              />
               <AiEnhancementButton
                  text={businessProfile.companyDescription}
                  onEnhance={(enhanced) => updateProfile('companyDescription', enhanced)}
                  enhancementType="company_description"
                  context={{
                    service_type: businessProfile.mainServiceType,
                    years_in_business: businessProfile.yearsInBusiness
                  }}
                />
              <HelpText>This helps our AI understand your expertise level and business personality</HelpText>
            </FormGroup>

            <FormGroup>
              <Label>Years in business *</Label>
              <Select
                value={businessProfile.yearsInBusiness}
                onChange={(e) => updateProfile('yearsInBusiness', e.target.value)}
              >
                <option value="">Select...</option>
                <option value="1-2 years">1-2 years</option>
                <option value="3-5 years">3-5 years</option>
                <option value="6-10 years">6-10 years</option>
                <option value="11-20 years">11-20 years</option>
                <option value="20+ years">20+ years</option>
              </Select>
            </FormGroup>
          </>
        );

      case 2:
        return (
          <>
            <Title>What services do you provide?</Title>
            <Subtitle>The more specific you are, the smarter your AI emails will be</Subtitle>
            
            <FormGroup>
              <Label>Primary service type *</Label>
              <Select
                value={businessProfile.mainServiceType}
                onChange={(e) => updateProfile('mainServiceType', e.target.value)}
              >
                <option value="">Select your main service...</option>
                <option value="Beekeeping Services">Beekeeping Services</option>
                <option value="Lawn Care & Maintenance">Lawn Care & Maintenance</option>
                <option value="Pest Control">Pest Control</option>
                <option value="Snow Removal">Snow Removal</option>
                <option value="Cleaning Services">Cleaning Services</option>
                <option value="HVAC Services">HVAC Services</option>
                <option value="Plumbing">Plumbing</option>
                <option value="Electrical">Electrical</option>
                <option value="Landscaping">Landscaping</option>
                <option value="Other">Other</option>
              </Select>
            </FormGroup>

            <FormGroup>
              <Label>Detailed service description *</Label>
              <TextArea
                placeholder="e.g., Hive inspections, honey harvesting, swarm removal, queen replacement. We specialize in treatment-free methods and sustainable practices..."
                value={businessProfile.serviceDetails}
                onChange={(e) => updateProfile('serviceDetails', e.target.value)}
              />
              <AiEnhancementButton
                text={businessProfile.serviceDetails}
                onEnhance={(enhanced) => updateProfile('serviceDetails', enhanced)}
                enhancementType="service_details"
                context={{
                  service_type: businessProfile.mainServiceType,
                  years_in_business: businessProfile.yearsInBusiness
                }}
              />
              <HelpText>Include your methods, equipment, and any specialties</HelpText>
            </FormGroup>

            <FormGroup>
              <Label>Service areas</Label>
              <Input
                type="text"
                placeholder="e.g., Twin Cities metro, Madison, Milwaukee - 40 mile radius each"
                value={businessProfile.serviceAreas}
                onChange={(e) => updateProfile('serviceAreas', e.target.value)}
              />
              <HelpText>Where do you provide services? (Cities, regions, radius)</HelpText>
            </FormGroup>
          </>
        );

      case 3:
        return (
          <>
            <Title>What makes you different?</Title>
            <Subtitle>Help us highlight what sets your business apart from competitors</Subtitle>
            
            <FormGroup>
              <Label>Your unique selling points *</Label>
              <TextArea
                placeholder="e.g., Treatment-free beekeeping specialists, family-owned for 15 years, 24/7 emergency swarm removal, satisfaction guarantee, certified organic practices..."
                value={businessProfile.uniqueSellingPoints}
                onChange={(e) => updateProfile('uniqueSellingPoints', e.target.value)}
              />
              <AiEnhancementButton
                text={businessProfile.uniqueSellingPoints}
                onEnhance={(enhanced) => updateProfile('uniqueSellingPoints', enhanced)}
                enhancementType="unique_selling_points"
                context={{
                  service_type: businessProfile.mainServiceType,
                  years_in_business: businessProfile.yearsInBusiness
                }}
              />
              <HelpText>What do customers choose you over competitors? Certifications, experience, guarantees, methods...</HelpText>
            </FormGroup>

            <FormGroup>
              <Label>Local expertise</Label>
              <TextArea
                placeholder="e.g., Experience with Minnesota/Wisconsin climate, late spring buildup management, winter survival techniques for northern climates..."
                value={businessProfile.localExpertise}
                onChange={(e) => updateProfile('localExpertise', e.target.value)}
              />
              <AiEnhancementButton
                text={businessProfile.localExpertise}
                onEnhance={(enhanced) => updateProfile('localExpertise', enhanced)}
                enhancementType="local_expertise"
                context={{
                  service_type: businessProfile.mainServiceType,
                  years_in_business: businessProfile.yearsInBusiness
                }}
              />
              <HelpText>What local knowledge should we mention? Climate, regulations, regional challenges...</HelpText>
            </FormGroup>

            <FormGroup>
              <Label>Email tone</Label>
              <Select
                value={businessProfile.emailTone}
                onChange={(e) => updateProfile('emailTone', e.target.value)}
              >
                <option value="professional">Professional & Formal</option>
                <option value="friendly">Friendly & Personal</option>
                <option value="expert">Expert & Educational</option>
                <option value="casual">Casual & Approachable</option>
              </Select>
            </FormGroup>
          </>
        );

      case 4:
        return (
          <>
            <Title>Seasonal services</Title>
            <Subtitle>Tell us what you do during different seasons for smarter timing</Subtitle>
            
            <FormGroup>
              <Label>Spring services</Label>
              <Input
                type="text"
                placeholder="e.g., Hive inspections, queen assessment, colony health checks"
                value={businessProfile.springServices}
                onChange={(e) => updateProfile('springServices', e.target.value)}
              />
            </FormGroup>

            <FormGroup>
              <Label>Summer services</Label>
              <Input
                type="text"
                placeholder="e.g., Honey harvest, swarm prevention, varroa monitoring"
                value={businessProfile.summerServices}
                onChange={(e) => updateProfile('summerServices', e.target.value)}
              />
            </FormGroup>

            <FormGroup>
              <Label>Fall services</Label>
              <Input
                type="text"
                placeholder="e.g., Winter preparation, feeding assistance, equipment winterizing"
                value={businessProfile.fallServices}
                onChange={(e) => updateProfile('fallServices', e.target.value)}
              />
            </FormGroup>

            <FormGroup>
              <Label>Winter services</Label>
              <Input
                type="text"
                placeholder="e.g., Equipment maintenance, hive monitoring, planning"
                value={businessProfile.winterServices}
                onChange={(e) => updateProfile('winterServices', e.target.value)}
              />
            </FormGroup>
          </>
        );

      case 5:
        return (
          <>
            <Title>Connect your Jobber account</Title>
            <Subtitle>We'll securely connect to trigger automated emails after your visits</Subtitle>
            
            <div style={{ textAlign: 'center', padding: '2rem 0' }}>
              <Button variant="primary" style={{ margin: '0 auto' }}>
                <Brain size={20} />
                Connect with Jobber
              </Button>
              <HelpText style={{ marginTop: '1rem', textAlign: 'center' }}>
                Secure OAuth connection - we only access visit completion data
              </HelpText>
            </div>
          </>
        );

      case 6:
        return (
          <>
            <Title>You're all set!</Title>
            <Subtitle>Start getting intelligent customer follow-ups automatically</Subtitle>
            
            <div style={{ 
              background: 'linear-gradient(135deg, #667eea 0%, #00d4aa 100%)',
              color: 'white',
              padding: '2rem',
              borderRadius: '16px',
              textAlign: 'center',
              marginBottom: '2rem'
            }}>
              <CheckCircle size={48} style={{ marginBottom: '1rem' }} />
              <h3 style={{ marginBottom: '0.5rem' }}>Ready to Launch!</h3>
              <p>Your AI is configured with your business expertise</p>
            </div>

            <div style={{ textAlign: 'center' }}>
              <Button variant="primary" style={{ margin: '0 auto' }}>
                Start $29 Trial
                <ArrowRight size={20} />
              </Button>
              <HelpText style={{ marginTop: '1rem', textAlign: 'center' }}>
                $29/month for first 3 months, then $59/month
              </HelpText>
            </div>
          </>
        );

      default:
        return null;
    }
  };

  return (
    <Container>
      <SignupCard>
        <ProgressBar>
          {[1, 2, 3, 4, 5, 6].map(step => (
            <ProgressStep
              key={step}
              active={step === currentStep}
              completed={step < currentStep}
            >
              {step < currentStep ? <CheckCircle size={16} /> : step}
            </ProgressStep>
          ))}
        </ProgressBar>

        {error && (
          <ErrorMessage>
            <AlertCircle size={16} />
            {error}
          </ErrorMessage>
        )}

        {success && (
          <SuccessMessage>
            <CheckCircle size={16} />
            {success}
          </SuccessMessage>
        )}

        {renderStep()}

        <ButtonGroup>
          <Button
            variant="secondary"
            onClick={prevStep}
            disabled={currentStep === 1 || loading}
          >
            <ArrowLeft size={16} />
            Back
          </Button>

          <Button
            variant="primary"
            onClick={nextStep}
            disabled={currentStep === 6 || !isStepValid() || loading}
            loading={loading}
          >
            {loading && <LoadingSpinner><Loader size={16} /></LoadingSpinner>}
            {currentStep === 6 ? 'Complete' : 'Continue'}
            {!loading && <ArrowRight size={16} />}
          </Button>
        </ButtonGroup>
      </SignupCard>
    </Container>
  );
};

export default SignupFlow;