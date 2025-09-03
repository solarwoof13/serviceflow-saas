// src/dashboard/pages/page.tsx
import React, { useEffect } from 'react';
import { createClient, WixClient } from '@wix/sdk';

const wixClient = createClient({ modules: { auth: WixClient } });

const DashboardPage: React.FC = () => {
  useEffect(() => {
    syncUserWithRails();
  }, []);

  const syncUserWithRails = async () => {
    try {
      const userData = await wixClient.auth.getCurrentUser();
      
      const response = await fetch('http://localhost:3000/api/v1/wix/sync_user', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          wix_user: {
            wix_id: userData.id,
            email: userData.email,
            subscription_level: 'startup'
          }
        })
      });
      
      const result = await response.json();
      console.log('User synced:', result);
    } catch (error) {
      console.error('Sync failed:', error);
    }
  };

  return (
    <div>
      <h1>ServiceFlow Dashboard</h1>
      {/* Add your dashboard content here */}
    </div>
  );
};

export default DashboardPage;