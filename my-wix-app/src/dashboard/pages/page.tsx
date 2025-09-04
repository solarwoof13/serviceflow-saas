// src/dashboard/pages/page.tsx
import React, { useEffect, useState } from 'react';

const DashboardPage: React.FC = () => {
  const [syncResult, setSyncResult] = useState<any>(null);

  useEffect(() => {
    testRailsConnection();
  }, []);

  const testRailsConnection = async () => {
    try {
      const response = await fetch('http://localhost:3000/api/v1/wix/sync_user', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          wix_user: {
            wix_id: 'test_user_123',
            email: 'test@example.com',
            subscription_level: 'startup'
          }
        })
      });
      
      const result = await response.json();
      setSyncResult(result);
      console.log('Rails connection test:', result);
    } catch (error) {
      console.error('Rails connection failed:', error);
      setSyncResult({ error: error.message });
    }
  };

  return (
    <div>
      <h1>ServiceFlow Dashboard</h1>
      <button onClick={testRailsConnection}>Test Rails Connection</button>
      {syncResult && (
        <pre>{JSON.stringify(syncResult, null, 2)}</pre>
      )}
    </div>
  );
};

export default DashboardPage;