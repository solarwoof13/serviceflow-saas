import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import styled from 'styled-components';
import { GlobalStyles } from './styles/GlobalStyles';
import LandingPage from './pages/LandingPage';
import SignupFlow from './pages/SignupFlow';
import Dashboard from './pages/Dashboard';

const AppContainer = styled.div`
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
`;

function App() {
  return (
    <Router>
      <AppContainer>
        <GlobalStyles />
        <Routes>
          <Route path="/" element={<LandingPage />} />
          <Route path="/signup/*" element={<SignupFlow />} />
          <Route path="/dashboard" element={<Dashboard />} />
        </Routes>
      </AppContainer>
    </Router>
  );
}

export default App;