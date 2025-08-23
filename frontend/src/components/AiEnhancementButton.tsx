import React, { useState } from 'react';
import styled from 'styled-components';
import { Sparkles, Loader2, CheckCircle, X } from 'lucide-react';

interface AiEnhancementButtonProps {
  text: string;
  onEnhance: (enhancedText: string) => void;
  enhancementType: 'company_description' | 'service_details' | 'unique_selling_points' | 'local_expertise';
  context?: {
    service_type?: string;
    years_in_business?: string;
  };
  disabled?: boolean;
}

const ButtonContainer = styled.div`
  position: relative;
  margin-top: 0.5rem;
  display: flex;
  justify-content: flex-end;
`;

const EnhanceButton = styled.button<{ disabled: boolean }>`
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  font-weight: 600;
  border-radius: 8px;
  transition: all 0.2s ease;
  border: none;
  cursor: ${props => props.disabled ? 'not-allowed' : 'pointer'};
  
  ${props => props.disabled ? `
    background: #e5e7eb;
    color: #9ca3af;
  ` : `
    background: linear-gradient(135deg, #8b5cf6 0%, #06b6d4 100%);
    color: white;
    
    &:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 12px rgba(139, 92, 246, 0.3);
      background: linear-gradient(135deg, #7c3aed 0%, #0891b2 100%);
    }
    
    &:active {
      transform: translateY(0);
    }
  `}
`;

const Modal = styled.div`
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
`;

const ModalContent = styled.div`
  background: white;
  border-radius: 16px;
  max-width: 600px;
  width: 100%;
  max-height: 80vh;
  overflow: hidden;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
`;

const ModalHeader = styled.div`
  padding: 1.5rem;
  border-bottom: 1px solid #e5e7eb;
  background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
  
  display: flex;
  align-items: center;
  justify-content: space-between;
`;

const ModalTitle = styled.div`
  display: flex;
  align-items: center;
  gap: 0.75rem;
`;

const IconContainer = styled.div`
  width: 40px;
  height: 40px;
  background: linear-gradient(135deg, #8b5cf6 0%, #06b6d4 100%);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
`;

const TitleText = styled.div`
  h3 {
    font-size: 1.125rem;
    font-weight: 600;
    color: #111827;
    margin: 0 0 0.25rem 0;
  }
  
  p {
    font-size: 0.875rem;
    color: #6b7280;
    margin: 0;
  }
`;

const CloseButton = styled.button`
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: #f3f4f6;
  color: #6b7280;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s ease;
  
  &:hover {
    background: #e5e7eb;
    color: #374151;
  }
`;

const OriginalText = styled.div`
  padding: 1rem 1.5rem;
  background: #f9fafb;
  border-bottom: 1px solid #e5e7eb;
  
  p {
    margin: 0 0 0.5rem 0;
    font-size: 0.875rem;
    color: #6b7280;
    font-weight: 500;
  }
  
  div {
    font-style: italic;
    color: #374151;
    padding: 0.5rem;
    background: white;
    border-radius: 6px;
    border: 1px solid #e5e7eb;
  }
`;

const SuggestionsContainer = styled.div`
  padding: 1.5rem;
  max-height: 400px;
  overflow-y: auto;
`;

const SuggestionCard = styled.div`
  border: 2px solid #e5e7eb;
  border-radius: 12px;
  padding: 1rem;
  margin-bottom: 1rem;
  cursor: pointer;
  transition: all 0.2s ease;
  position: relative;
  
  &:hover {
    border-color: #8b5cf6;
    background: #faf5ff;
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(139, 92, 246, 0.1);
  }
  
  &:last-child {
    margin-bottom: 0;
  }
`;

const SuggestionHeader = styled.div`
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
`;

const SuggestionNumber = styled.div`
  width: 24px;
  height: 24px;
  background: linear-gradient(135deg, #8b5cf6 0%, #06b6d4 100%);
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 600;
  flex-shrink: 0;
`;

const SuggestionText = styled.div`
  color: #374151;
  line-height: 1.5;
  font-size: 0.95rem;
`;

const CheckIcon = styled(CheckCircle)`
  position: absolute;
  top: 1rem;
  right: 1rem;
  color: #8b5cf6;
  opacity: 0;
  transition: opacity 0.2s ease;
  
  ${SuggestionCard}:hover & {
    opacity: 1;
  }
`;

const ErrorMessage = styled.div`
  padding: 1rem 1.5rem;
  background: #fef2f2;
  color: #dc2626;
  border-left: 4px solid #dc2626;
  margin: 1rem 1.5rem;
  border-radius: 0 6px 6px 0;
  font-size: 0.875rem;
`;

const LoadingContainer = styled.div`
  padding: 3rem 1.5rem;
  text-align: center;
  
  div {
    margin-bottom: 1rem;
  }
  
  p {
    color: #6b7280;
    font-size: 0.875rem;
  }
`;

const SpinningLoader = styled(Loader2)`
  animation: spin 1s linear infinite;
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
`;

const AiEnhancementButton: React.FC<AiEnhancementButtonProps> = ({
  text,
  onEnhance,
  enhancementType,
  context = {},
  disabled = false
}) => {
  const [isLoading, setIsLoading] = useState(false);
  const [suggestions, setSuggestions] = useState<string[]>([]);
  const [showModal, setShowModal] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleEnhance = async () => {
    if (!text || text.trim().length < 3) {
      setError('Please enter some text first');
      return;
    }

    setIsLoading(true);
    setError(null);
    setShowModal(true);
    
    try {
      const response = await fetch('http://localhost:4000/api/v1/ai_enhancement', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          text: text.trim(),
          enhancement_type: enhancementType,
          context: context
        })
      });

      const data = await response.json();
      
      if (response.ok && data.suggestions) {
        setSuggestions(data.suggestions);
      } else {
        setError(data.error || 'Enhancement failed. Please try again.');
      }
    } catch (err) {
      setError('Network error. Please check your connection and try again.');
      console.error('Enhancement error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSelectSuggestion = (suggestion: string) => {
    onEnhance(suggestion);
    setShowModal(false);
    setSuggestions([]);
    setError(null);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setSuggestions([]);
    setError(null);
    setIsLoading(false);
  };

  return (
    <>
      <ButtonContainer>
        <EnhanceButton
          onClick={handleEnhance}
          disabled={disabled || !text || text.trim().length < 3}
        >
          <Sparkles size={16} />
          Enhance with AI
        </EnhanceButton>
      </ButtonContainer>

      {showModal && (
        <Modal onClick={handleCloseModal}>
          <ModalContent onClick={(e) => e.stopPropagation()}>
            <ModalHeader>
              <ModalTitle>
                <IconContainer>
                  <Sparkles size={20} color="white" />
                </IconContainer>
                <TitleText>
                  <h3>AI-Enhanced Suggestions</h3>
                  <p>Choose the version that best represents your business</p>
                </TitleText>
              </ModalTitle>
              <CloseButton onClick={handleCloseModal}>
                <X size={16} />
              </CloseButton>
            </ModalHeader>

            <OriginalText>
              <p>Original text:</p>
              <div>"{text}"</div>
            </OriginalText>

            {isLoading && (
              <LoadingContainer>
                <div>
                  <SpinningLoader size={32} color="#8b5cf6" />
                </div>
                <p>AI is crafting professional suggestions for your business...</p>
              </LoadingContainer>
            )}

            {error && (
              <ErrorMessage>
                {error}
              </ErrorMessage>
            )}

            {suggestions.length > 0 && (
              <SuggestionsContainer>
                {suggestions.map((suggestion, index) => (
                  <SuggestionCard
                    key={index}
                    onClick={() => handleSelectSuggestion(suggestion)}
                  >
                    <SuggestionHeader>
                      <SuggestionNumber>{index + 1}</SuggestionNumber>
                    </SuggestionHeader>
                    <SuggestionText>{suggestion}</SuggestionText>
                    <CheckIcon size={20} />
                  </SuggestionCard>
                ))}
              </SuggestionsContainer>
            )}
          </ModalContent>
        </Modal>
      )}
    </>
  );
};

export default AiEnhancementButton;