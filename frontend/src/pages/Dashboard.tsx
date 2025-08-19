import React from 'react';
import styled from 'styled-components';

const Container = styled.div`
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
`;

const Dashboard: React.FC = () => {
  return (
    <Container>
      <h1>Dashboard - Coming Soon!</h1>
    </Container>
  );
};

export default Dashboard;