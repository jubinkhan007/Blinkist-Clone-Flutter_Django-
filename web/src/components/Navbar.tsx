"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { BookOpen, Search, Bookmark, Flame, Headphones, User as UserIcon } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { useAudio } from "@/context/AudioContext";
import { ThemeToggle } from "./ThemeToggle";

export const Navbar: React.FC = () => {
  const router = useRouter();
  const { user, isAuthenticated, logout } = useAuth();
  const { isPlaying, currentTrack } = useAudio();
  const [searchQuery, setSearchQuery] = useState("");
  const [showUserMenu, setShowUserMenu] = useState(false);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchQuery.trim()) {
      router.push(`/explore?search=${encodeURIComponent(searchQuery.trim())}`);
    }
  };

  return (
    <header className="sticky top-0 z-40 w-full border-b border-gray-200 dark:border-gray-800 bg-white/95 dark:bg-gray-900/95 backdrop-blur-md">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between gap-4">
        {/* Brand Logo */}
        <div className="flex items-center gap-8">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-9 h-9 rounded-xl bg-emerald-500 text-white flex items-center justify-center shadow-md shadow-emerald-500/20 group-hover:bg-emerald-600 transition-colors">
              <BookOpen className="w-5 h-5" />
            </div>
            <span className="text-xl font-bold tracking-tight text-gray-900 dark:text-white flex items-center">
              blinkist<span className="text-emerald-500 font-black text-2xl leading-none">.</span>
            </span>
          </Link>

          {/* Nav Links */}
          <nav className="hidden md:flex items-center gap-6 text-sm font-medium text-gray-600 dark:text-gray-300">
            <Link
              href="/explore"
              className="hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
            >
              Explore
            </Link>
            <Link
              href="/explore?category=productivity"
              className="hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
            >
              Categories
            </Link>
            <Link
              href="/library"
              className="hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors flex items-center gap-1.5"
            >
              <Bookmark className="w-4 h-4 text-emerald-500" />
              My Library
            </Link>
          </nav>
        </div>

        {/* Search Bar */}
        <div className="flex-1 max-w-md hidden sm:block">
          <form onSubmit={handleSearchSubmit} className="relative">
            <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500" />
            <input
              type="text"
              placeholder="Search 6,500+ books, authors & topics..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2 text-sm rounded-full bg-gray-100 dark:bg-gray-800 border border-transparent focus:border-emerald-500 focus:bg-white dark:focus:bg-gray-900 text-gray-900 dark:text-white outline-hidden transition-all placeholder:text-gray-400"
            />
          </form>
        </div>

        {/* Right Actions */}
        <div className="flex items-center gap-3">
          {/* Active Audio Waveform Indicator */}
          {currentTrack && (
            <div className="hidden lg:flex items-center gap-2 px-3 py-1.5 rounded-full bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800 text-xs font-medium text-emerald-700 dark:text-emerald-400">
              <Headphones className={`w-3.5 h-3.5 ${isPlaying ? "animate-pulse" : ""}`} />
              <span className="truncate max-w-[120px]">{currentTrack.bookTitle}</span>
            </div>
          )}

          {/* Reading Streak Counter */}
          {user && (
            <div
              className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-800 text-xs font-semibold text-amber-700 dark:text-amber-400"
              title={`${user.streak_count || 1} day reading streak`}
            >
              <Flame className="w-3.5 h-3.5 fill-amber-500 text-amber-500" />
              <span>{user.streak_count || 1}</span>
            </div>
          )}

          {/* Theme Toggle */}
          <ThemeToggle />

          {/* User Profile / Auth */}
          {isAuthenticated && user ? (
            <div className="relative">
              <button
                onClick={() => setShowUserMenu(!showUserMenu)}
                className="w-9 h-9 rounded-full bg-emerald-100 dark:bg-emerald-900/60 text-emerald-700 dark:text-emerald-300 font-semibold text-sm flex items-center justify-center border border-emerald-200 dark:border-emerald-700 hover:ring-2 hover:ring-emerald-500/20 transition-all"
                aria-label="User menu"
              >
                {user.name ? user.name.charAt(0).toUpperCase() : user.username.charAt(0).toUpperCase()}
              </button>

              {showUserMenu && (
                <div className="absolute right-0 mt-2 w-56 rounded-2xl bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-xl py-2 z-50 text-sm animate-in fade-in slide-in-from-top-2">
                  <div className="px-4 py-2 border-b border-gray-100 dark:border-gray-700">
                    <p className="font-semibold text-gray-900 dark:text-white truncate">
                      {user.name || user.username}
                    </p>
                    <p className="text-xs text-gray-500 dark:text-gray-400 truncate">{user.email}</p>
                    <span className="inline-block mt-1 text-[11px] font-medium px-2 py-0.5 rounded-full bg-emerald-100 dark:bg-emerald-900/50 text-emerald-700 dark:text-emerald-300">
                      Premium Member
                    </span>
                  </div>
                  <Link
                    href="/library"
                    onClick={() => setShowUserMenu(false)}
                    className="block px-4 py-2 text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700/50"
                  >
                    My Library
                  </Link>
                  <button
                    onClick={() => {
                      setShowUserMenu(false);
                      logout();
                    }}
                    className="w-full text-left px-4 py-2 text-rose-600 dark:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-950/30"
                  >
                    Sign Out
                  </button>
                </div>
              )}
            </div>
          ) : (
            <Link
              href="/login"
              className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-emerald-500 hover:bg-emerald-600 text-white font-medium text-xs sm:text-sm shadow-xs transition-colors"
            >
              <UserIcon className="w-3.5 h-3.5" />
              Sign In
            </Link>
          )}
        </div>
      </div>
    </header>
  );
};
