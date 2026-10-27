import React from "react";
import Link from "next/link";
import { BookOpen } from "lucide-react";

export const Footer: React.FC = () => {
  return (
    <footer className="border-t border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 py-12 px-4 sm:px-6 lg:px-8 text-sm text-gray-500 dark:text-gray-400 mt-auto pb-28">
      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-4 gap-8">
        {/* Brand */}
        <div className="space-y-4">
          <Link href="/" className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-emerald-500 text-white flex items-center justify-center font-bold">
              <BookOpen className="w-4 h-4" />
            </div>
            <span className="text-lg font-bold tracking-tight text-gray-900 dark:text-white">
              blinkist<span className="text-emerald-500 font-black">.</span>
            </span>
          </Link>
          <p className="text-xs leading-relaxed text-gray-600 dark:text-gray-400">
            Big ideas in 15 minutes. Understand the key insights from the world&apos;s best non-fiction books through text and audio summaries.
          </p>
          <p className="text-xs text-gray-400">
            © 2026 Blinkist Clone. All rights reserved.
          </p>
        </div>

        {/* Explore Categories */}
        <div>
          <h4 className="font-semibold text-gray-900 dark:text-white mb-3 text-xs uppercase tracking-wider">
            Explore
          </h4>
          <ul className="space-y-2 text-xs">
            <li>
              <Link href="/explore?category=productivity" className="hover:text-emerald-500 transition-colors">
                Productivity & Time Management
              </Link>
            </li>
            <li>
              <Link href="/explore?category=psychology" className="hover:text-emerald-500 transition-colors">
                Psychology & Mindset
              </Link>
            </li>
            <li>
              <Link href="/explore?category=personal-finance" className="hover:text-emerald-500 transition-colors">
                Personal Finance & Investing
              </Link>
            </li>
            <li>
              <Link href="/explore?category=career-success" className="hover:text-emerald-500 transition-colors">
                Career & Leadership
              </Link>
            </li>
          </ul>
        </div>

        {/* Features */}
        <div>
          <h4 className="font-semibold text-gray-900 dark:text-white mb-3 text-xs uppercase tracking-wider">
            Product Features
          </h4>
          <ul className="space-y-2 text-xs">
            <li>
              <Link href="/explore" className="hover:text-emerald-500 transition-colors">
                Daily Audio Blink
              </Link>
            </li>
            <li>
              <Link href="/library" className="hover:text-emerald-500 transition-colors">
                Micro-Habit Action Plans
              </Link>
            </li>
            <li>
              <Link href="/library" className="hover:text-emerald-500 transition-colors">
                Reading Streaks & Goal Tracker
              </Link>
            </li>
            <li>
              <Link href="/explore" className="hover:text-emerald-500 transition-colors">
                Key Takeaways & Flashcards
              </Link>
            </li>
          </ul>
        </div>

        {/* Legal & App */}
        <div>
          <h4 className="font-semibold text-gray-900 dark:text-white mb-3 text-xs uppercase tracking-wider">
            Apps & Platforms
          </h4>
          <p className="text-xs text-gray-600 dark:text-gray-400 mb-3 leading-relaxed">
            Read on desktop or continue listening seamlessly on iOS and Android with live progress sync.
          </p>
          <div className="flex flex-col gap-2">
            <span className="inline-flex items-center text-xs font-medium text-emerald-600 dark:text-emerald-400">
              ⚡ Web, iOS & Android Supported
            </span>
          </div>
        </div>
      </div>
    </footer>
  );
};
