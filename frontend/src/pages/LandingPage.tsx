import React from 'react';
import styled from 'styled-components';
import { ArrowRight, Zap, Brain, Target } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

const Container = styled.div`
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  text-align: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 50%, #00d4aa 100%);
`;

const Logo = styled.div`
  margin-bottom: 2rem;
  img {
    width: 150px;
    height: auto;
    filter: drop-shadow(0 10px 20px rgba(0, 0, 0, 0.2));
  }
`;

const Hero = styled.div`
  max-width: 800px;
  margin-bottom: 4rem;
`;

const Title = styled.h1`
  font-size: 3.5rem;
  font-weight: 800;
  background: linear-gradient(135deg, #667eea 0%, #00d4aa 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  margin-bottom: 1rem;
  
  @media (max-width: 768px) {
    font-size: 2.5rem;
  }
`;

const Tagline = styled.p`
  font-size: 1.2rem;
  color: rgba(255, 255, 255, 0.8);
  margin-bottom: 1.5rem;
  font-weight: 300;
  letter-spacing: 2px;
  text-transform: uppercase;
`;

const Subtitle = styled.p`
  font-size: 1.5rem;
  color: rgba(255, 255, 255, 0.9);
  margin-bottom: 2rem;
  
  @media (max-width: 768px) {
    font-size: 1.2rem;
  }
`;

const CTAButton = styled.button`
  background: linear-gradient(135deg, #667eea 0%, #00d4aa 100%);
  color: white;
  font-size: 1.2rem;
  font-weight: 600;
  padding: 1rem 2rem;
  border-radius: 12px;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin: 0 auto 3rem;
  transition: all 0.3s ease;
  box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
  
  &:hover {
    transform: translateY(-3px);
    box-shadow: 0 8px 25px rgba(102, 126, 234, 0.4);
    background: linear-gradient(135deg, #5a67d8 0%, #00b894 100%);
  }
`;

const Features = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 2rem;
  max-width: 1000px;
  margin-bottom: 3rem;
`;

const Feature = styled.div`
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(20px);
  border-radius: 20px;
  padding: 2.5rem;
  border: 1px solid rgba(255, 255, 255, 0.2);
  transition: all 0.3s ease;
  
  &:hover {
    transform: translateY(-5px);
    background: rgba(255, 255, 255, 0.15);
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
  }
`;

const FeatureIcon = styled.div`
  width: 70px;
  height: 70px;
  background: linear-gradient(135deg, #667eea 0%, #00d4aa 100%);
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1.5rem;
  
  svg {
    color: white;
    width: 28px;
    height: 28px;
  }
`;

const FeatureTitle = styled.h3`
  color: white;
  font-size: 1.3rem;
  margin-bottom: 1rem;
  font-weight: 600;
`;

const FeatureText = styled.p`
  color: rgba(255, 255, 255, 0.8);
  font-size: 1rem;
  line-height: 1.6;
`;

const Pricing = styled.div`
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(20px);
  border-radius: 20px;
  padding: 3rem;
  border: 1px solid rgba(255, 255, 255, 0.2);
  color: white;
  max-width: 600px;
  
  h3 {
    font-size: 1.5rem;
    margin-bottom: 1rem;
    background: linear-gradient(135deg, #667eea 0%, #00d4aa 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  
  p {
    color: rgba(255, 255, 255, 0.8);
    font-size: 1.1rem;
  }
`;

const LandingPage: React.FC = () => {
  const navigate = useNavigate();

  return (
    <Container>
      <Logo>
        <img src="/serviceflow_logo_wht.jpg" alt="ServiceFlow AI" />
      </Logo>

      <Hero>
        <Title>SERVICEFLOW</Title>
        <Tagline>artificial intelligence</Tagline>
        <Subtitle>
          AI-powered customer follow-ups that sound like they come from 20-year industry veterans
        </Subtitle>
        <CTAButton onClick={() => navigate('/signup')}>
          Get Started - $29/month
          <ArrowRight size={20} />
        </CTAButton>
      </Hero>

      <Features>
        <Feature>
          <FeatureIcon>
            <Brain />
          </FeatureIcon>
          <FeatureTitle>Industry Intelligence</FeatureTitle>
          <FeatureText>
            AI learns your business expertise, regional knowledge, and service philosophy to write expert-level emails
          </FeatureText>
        </Feature>

        <Feature>
          <FeatureIcon>
            <Zap />
          </FeatureIcon>
          <FeatureTitle>Instant Automation</FeatureTitle>
          <FeatureText>
            Connects to your Jobber account and automatically sends personalized follow-ups after every visit
          </FeatureText>
        </Feature>

        <Feature>
          <FeatureIcon>
            <Target />
          </FeatureIcon>
          <FeatureTitle>Regional Expertise</FeatureTitle>
          <FeatureText>
            Mentions local conditions, seasonal advice, and area-specific knowledge that impresses customers
          </FeatureText>
        </Feature>
      </Features>

      <Pricing>
        <h3>Launch Special: $29/month for first 3 months</h3>
        <p>Then $59/month • Cancel anytime • 30-day money-back guarantee</p>
      </Pricing>
    </Container>
  );
};

export default LandingPage;