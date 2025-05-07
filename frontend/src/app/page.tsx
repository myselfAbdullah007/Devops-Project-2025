'use client';

import { useState, useEffect } from 'react';
import { User } from '@/types/user';
import UserForm from '@/components/UserForm';

const API_BASE_URL = `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:5001'}/api`;

export default function Home() {
  const [users, setUsers] = useState<User[]>([]);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchUsers = async () => {
    try {
      setIsLoading(true);
      setError(null);
      console.log('Fetching users from:', `${API_BASE_URL}/users`);
      
      const response = await fetch(`${API_BASE_URL}/users`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        }
      });
      
      console.log('Response status:', response.status);
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.message || `HTTP error! status: ${response.status}`);
      }
      
      const data = await response.json();
      console.log('Received data:', data);
      setUsers(data);
    } catch (error) {
      console.error('Error fetching users:', error);
      setError(error instanceof Error ? error.message : 'Failed to load users. Please try again later.');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    console.log('API Base URL:', API_BASE_URL);
    fetchUsers();
  }, []);

  const handleCreateUser = async (userData: Partial<User>) => {
    try {
      setError(null);
      console.log('Creating user with data:', userData);
      
      const response = await fetch(`${API_BASE_URL}/users`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(userData),
      });

      console.log('Response status:', response.status);
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.message || `HTTP error! status: ${response.status}`);
      }

      await fetchUsers();
      setIsFormOpen(false);
    } catch (error) {
      console.error('Error creating user:', error);
      setError(error instanceof Error ? error.message : 'Failed to create user. Please try again.');
    }
  };

  const handleUpdateUser = async (userData: Partial<User>) => {
    if (!selectedUser) return;
    try {
      setError(null);
      const response = await fetch(`${API_BASE_URL}/users/${selectedUser._id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify(userData),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.message || 'Failed to update user');
      }

      await fetchUsers();
      setSelectedUser(null);
      setIsFormOpen(false);
    } catch (error) {
      console.error('Error updating user:', error);
      setError(error instanceof Error ? error.message : 'Failed to update user. Please try again.');
    }
  };

  const handleDeleteUser = async (userId: string) => {
    try {
      setError(null);
      const response = await fetch(`${API_BASE_URL}/users/${userId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.message || 'Failed to delete user');
      }

      await fetchUsers();
    } catch (error) {
      console.error('Error deleting user:', error);
      setError(error instanceof Error ? error.message : 'Failed to delete user. Please try again.');
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-50">
        <div className="text-xl text-purple-600">Loading...</div>
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-gradient-to-br from-gray-50 to-purple-50 px-4 py-8">
      <div className="container mx-auto max-w-6xl">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-purple-900">User Management</h1>
          <button
            onClick={() => {
              setSelectedUser(null);
              setIsFormOpen(true);
            }}
            className="px-6 py-2.5 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors duration-200 shadow-md hover:shadow-lg"
          >
            Add User
          </button>
        </div>

        {error && (
          <div className="mb-4 p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg">
            {error}
          </div>
        )}

        {isFormOpen && (
          <div className="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center">
            <div className="bg-white p-8 rounded-xl w-full max-w-md shadow-2xl">
              <h2 className="text-2xl font-bold mb-6 text-purple-900">
                {selectedUser ? 'Edit User' : 'Create User'}
              </h2>
              <UserForm
                user={selectedUser || undefined}
                onSubmit={selectedUser ? handleUpdateUser : handleCreateUser}
                onCancel={() => {
                  setIsFormOpen(false);
                  setSelectedUser(null);
                }}
              />
            </div>
          </div>
        )}

        <div className="grid gap-6">
          {users.length === 0 ? (
            <div className="text-center py-12 bg-white rounded-xl shadow-sm">
              <div className="text-gray-500 text-lg">
                No users found. Add a new user to get started.
              </div>
            </div>
          ) : (
            users.map((user) => (
              <div
                key={user._id}
                className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow duration-200"
              >
                <div className="flex justify-between items-center">
                  <div>
                    <h3 className="text-xl font-semibold text-purple-900">{user.name}</h3>
                    <p className="text-gray-600">{user.email}</p>
                    <p className="text-gray-500 text-sm">Age: {user.age}</p>
                  </div>
                  <div className="space-x-3">
                    <button
                      onClick={() => {
                        setSelectedUser(user);
                        setIsFormOpen(true);
                      }}
                      className="px-4 py-2 bg-purple-100 text-purple-700 rounded-lg hover:bg-purple-200 transition-colors duration-200"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => handleDeleteUser(user._id)}
                      className="px-4 py-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors duration-200"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </main>
  );
}
