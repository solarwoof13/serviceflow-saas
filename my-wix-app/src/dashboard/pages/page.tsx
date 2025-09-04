// src/dashboard/pages/page.tsx
import React, { useEffect, useState } from 'react';
import { createClient } from '@wix/sdk';

const wixClient = createClient({
  modules: { 
    auth: {},
    users: {}
  }
});

const DashboardPage: React.FC = () => {
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    fetchUser();
  }, []);

  const fetchUser = async () => {
    try {
      // Try using the users module instead
      const currentUser = await wixClient.users.getCurrentUser();
      setUser(currentUser);
      
      // Then sync with Rails
      await syncUserWithRails(currentUser);
    } catch (error) {
      console.error('User fetch failed:', error);
      // Fallback: Use window.wix for user data if available
      if (window.wix && window.wix.currentUser) {
        setUser(window.wix.currentUser);
        await syncUserWithRails(window.wix.currentUser);
      }
    }
  };

  const syncUserWithRails = async (userData: any) => {
    try {
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
      {user && <p>Welcome, {user.email}</p>}
    </div>
  );
};

export default DashboardPage;