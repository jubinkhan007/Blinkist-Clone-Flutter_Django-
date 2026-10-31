"use client";

import React from "react";
import { AuthProvider } from "@/context/AuthContext";
import { AudioProvider } from "@/context/AudioContext";
import { Navbar } from "@/components/Navbar";
import { AudioDock } from "@/components/AudioDock";
import { ContinueListeningBanner } from "@/components/ContinueListeningBanner";
import { Footer } from "@/components/Footer";

export const Providers: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return (
    <AuthProvider>
      <AudioProvider>
        <div className="min-h-screen flex flex-col bg-background text-foreground">
          <Navbar />
          <main className="flex-1">{children}</main>
          <ContinueListeningBanner />
          <AudioDock />
          <Footer />
        </div>
      </AudioProvider>
    </AuthProvider>
  );
};
