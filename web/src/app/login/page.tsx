"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { BookOpen, ArrowRight, ShieldCheck, Sparkles } from "lucide-react";
import { useAuth } from "@/context/AuthContext";

export default function LoginPage() {
  const router = useRouter();
  const { login, register } = useAuth();

  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (!email.trim()) {
      setError("Please enter your email address.");
      return;
    }

    try {
      if (isSignUp) {
        await register(email.trim(), username.trim() || email.split("@")[0], password);
      } else {
        await login(email.trim(), password);
      }
      router.push("/explore");
    } catch {
      setError("Failed to sign in. Please try again.");
    }
  };

  const handleDemoLogin = async () => {
    await login("alex@blinkist.dev");
    router.push("/explore");
  };

  return (
    <div className="min-h-[85vh] flex items-center justify-center px-4 sm:px-6 py-12">
      <div className="w-full max-w-md space-y-8 bg-white dark:bg-gray-800 p-8 sm:p-10 rounded-3xl border border-gray-200 dark:border-gray-700 shadow-2xl">
        {/* Brand Header */}
        <div className="text-center space-y-2">
          <Link href="/" className="inline-flex items-center gap-2">
            <div className="w-10 h-10 rounded-xl bg-emerald-500 text-white flex items-center justify-center shadow-md shadow-emerald-500/20">
              <BookOpen className="w-5 h-5" />
            </div>
            <span className="text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
              blinkist<span className="text-emerald-500 font-black">.</span>
            </span>
          </Link>

          <h2 className="text-2xl font-extrabold text-gray-900 dark:text-white tracking-tight pt-2">
            {isSignUp ? "Create your account" : "Welcome back"}
          </h2>
          <p className="text-xs text-gray-500 dark:text-gray-400">
            {isSignUp
              ? "Start your 7-day free trial with unlimited audio & text."
              : "Sign in to access your library, bookmarks, and streaks."}
          </p>
        </div>

        {error && (
          <div className="p-3 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 text-xs text-rose-600 dark:text-rose-400">
            {error}
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          {isSignUp && (
            <div>
              <label className="block text-xs font-semibold text-gray-700 dark:text-gray-300 mb-1">
                Your Name
              </label>
              <input
                type="text"
                placeholder="Alex Johnson"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                className="w-full px-4 py-2.5 text-sm rounded-xl bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700 focus:border-emerald-500 focus:bg-white text-gray-900 dark:text-white outline-hidden transition-all"
              />
            </div>
          )}

          <div>
            <label className="block text-xs font-semibold text-gray-700 dark:text-gray-300 mb-1">
              Email Address
            </label>
            <input
              type="email"
              placeholder="alex@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-2.5 text-sm rounded-xl bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700 focus:border-emerald-500 focus:bg-white text-gray-900 dark:text-white outline-hidden transition-all"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-700 dark:text-gray-300 mb-1">
              Password
            </label>
            <input
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-2.5 text-sm rounded-xl bg-gray-50 dark:bg-gray-900 border border-gray-200 dark:border-gray-700 focus:border-emerald-500 focus:bg-white text-gray-900 dark:text-white outline-hidden transition-all"
            />
          </div>

          <button
            type="submit"
            className="w-full py-3 rounded-full bg-emerald-500 hover:bg-emerald-600 active:scale-95 text-white font-bold text-sm shadow-lg shadow-emerald-500/25 flex items-center justify-center gap-2 transition-all"
          >
            {isSignUp ? "Start 7-Day Free Trial" : "Sign In"}
            <ArrowRight className="w-4 h-4" />
          </button>
        </form>

        {/* Quick Demo Access Button */}
        <div className="pt-2">
          <button
            onClick={handleDemoLogin}
            type="button"
            className="w-full py-2.5 rounded-full bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-800 dark:text-white font-semibold text-xs flex items-center justify-center gap-2 transition-colors"
          >
            <Sparkles className="w-3.5 h-3.5 text-emerald-500" />
            Quick Demo Sign-In (1-Tap)
          </button>
        </div>

        {/* Toggle Mode */}
        <div className="text-center pt-2 text-xs text-gray-500 dark:text-gray-400">
          {isSignUp ? (
            <p>
              Already have an account?{" "}
              <button
                type="button"
                onClick={() => setIsSignUp(false)}
                className="font-bold text-emerald-600 dark:text-emerald-400 hover:underline"
              >
                Sign In
              </button>
            </p>
          ) : (
            <p>
              Don&apos;t have an account?{" "}
              <button
                type="button"
                onClick={() => setIsSignUp(true)}
                className="font-bold text-emerald-600 dark:text-emerald-400 hover:underline"
              >
                Create Account
              </button>
            </p>
          )}
        </div>

        <div className="flex items-center justify-center gap-2 text-[11px] text-gray-400 pt-4 border-t border-gray-100 dark:border-gray-700">
          <ShieldCheck className="w-3.5 h-3.5 text-emerald-500" />
          <span>256-bit encrypted secure session</span>
        </div>
      </div>
    </div>
  );
}
