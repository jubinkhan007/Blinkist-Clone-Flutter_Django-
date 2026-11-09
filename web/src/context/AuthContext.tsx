"use client";

import React, { createContext, useContext, useState, useEffect } from "react";
import { User } from "@/types";
import { sentry } from "@/lib/sentry";

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password?: string) => Promise<boolean>;
  logout: () => void;
  register: (email: string, username: string, password?: string) => Promise<boolean>;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  isAuthenticated: false,
  isLoading: true,
  login: async () => false,
  logout: () => {},
  register: async () => false,
});

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    try {
      const storedUser = localStorage.getItem("blinkist_user");
      if (storedUser) {
        const parsed = JSON.parse(storedUser);
        setUser(parsed);
        sentry.setUser({ id: parsed.id, email: parsed.email, username: parsed.username });
      } else {
        // Default authenticated demo guest for seamless experience
        const demoUser: User = {
          id: 1,
          username: "reader_alex",
          email: "alex@blinkist.dev",
          name: "Alex Johnson",
          is_premium: true,
          streak_count: 5,
          minutes_read_today: 18,
        };
        setUser(demoUser);
        localStorage.setItem("blinkist_user", JSON.stringify(demoUser));
        sentry.setUser({ id: demoUser.id, email: demoUser.email, username: demoUser.username });
      }
    } catch (_) {}
    setIsLoading(false);
  }, []);

  const login = async (email: string): Promise<boolean> => {
    const loggedUser: User = {
      id: 1,
      username: email.split("@")[0],
      email,
      name: email.split("@")[0].replace(".", " "),
      is_premium: true,
      streak_count: 5,
      minutes_read_today: 12,
    };
    setUser(loggedUser);
    sentry.setUser({ id: loggedUser.id, email: loggedUser.email, username: loggedUser.username });
    localStorage.setItem("blinkist_user", JSON.stringify(loggedUser));
    localStorage.setItem("blinkist_token", "demo_jwt_token_header");
    return true;
  };

  const register = async (email: string, username: string): Promise<boolean> => {
    const newUser: User = {
      id: 2,
      username,
      email,
      name: username,
      is_premium: true,
      streak_count: 1,
      minutes_read_today: 0,
    };
    setUser(newUser);
    sentry.setUser({ id: newUser.id, email: newUser.email, username: newUser.username });
    localStorage.setItem("blinkist_user", JSON.stringify(newUser));
    localStorage.setItem("blinkist_token", "demo_jwt_token_header");
    return true;
  };

  const logout = () => {
    setUser(null);
    sentry.setUser(null);
    localStorage.removeItem("blinkist_user");
    localStorage.removeItem("blinkist_token");
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user,
        isLoading,
        login,
        logout,
        register,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
