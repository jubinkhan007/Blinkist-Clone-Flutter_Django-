"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import {
  Bookmark,
  Flame,
  Clock,
  CheckCircle,
  BookOpen,
  Calendar,
  Sparkles,
  ArrowRight,
} from "lucide-react";
import { Book } from "@/types";
import { api } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import { BookCard } from "@/components/BookCard";

export default function LibraryPage() {
  const { user, isAuthenticated } = useAuth();
  const [activeTab, setActiveTab] = useState<"saved" | "in_progress" | "finished" | "habits">("saved");
  const [books, setBooks] = useState<Book[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadBooks() {
      try {
        const data = await api.getBooks();
        setBooks(data);
      } catch (e) {
        console.error("Failed to load library books", e);
      } finally {
        setLoading(false);
      }
    }
    loadBooks();
  }, []);

  const savedBooks = books.filter((b) => b.is_saved || b.id === 1 || b.id === 2);
  const inProgressBooks = [books[0]].filter(Boolean);
  const finishedBooks = [books[1]].filter(Boolean);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12">
      {/* Library Header & Stats */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 pb-8 border-b border-gray-200 dark:border-gray-800">
        <div>
          <h1 className="text-3xl sm:text-4xl font-extrabold text-gray-900 dark:text-white tracking-tight">
            My Library
          </h1>
          <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
            Track your reading habits, saved summaries, and micro-action plans.
          </p>
        </div>

        {/* Stats Badges */}
        <div className="flex items-center gap-4">
          {/* Streak */}
          <div className="flex items-center gap-2.5 px-4 py-2 rounded-2xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-800">
            <Flame className="w-5 h-5 text-amber-500 fill-amber-500" />
            <div>
              <p className="text-xs text-amber-600 dark:text-amber-400 font-semibold">Streak</p>
              <p className="text-base font-extrabold text-amber-900 dark:text-amber-200 leading-none">
                {user?.streak_count || 5} Days
              </p>
            </div>
          </div>

          {/* Time Read Today */}
          <div className="flex items-center gap-2.5 px-4 py-2 rounded-2xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800">
            <Clock className="w-5 h-5 text-emerald-500" />
            <div>
              <p className="text-xs text-emerald-600 dark:text-emerald-400 font-semibold">Today</p>
              <p className="text-base font-extrabold text-emerald-900 dark:text-emerald-200 leading-none">
                {user?.minutes_read_today || 18} Mins
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Library Tabs */}
      <div className="flex items-center gap-2 border-b border-gray-200 dark:border-gray-800 pt-6 mb-8 overflow-x-auto scrollbar-none">
        <button
          onClick={() => setActiveTab("saved")}
          className={`pb-3 px-4 text-xs font-bold transition-all border-b-2 flex items-center gap-2 whitespace-nowrap ${
            activeTab === "saved"
              ? "border-emerald-500 text-emerald-600 dark:text-emerald-400"
              : "border-transparent text-gray-500 hover:text-gray-900 dark:hover:text-white"
          }`}
        >
          <Bookmark className="w-4 h-4" />
          Saved Summaries ({savedBooks.length})
        </button>

        <button
          onClick={() => setActiveTab("in_progress")}
          className={`pb-3 px-4 text-xs font-bold transition-all border-b-2 flex items-center gap-2 whitespace-nowrap ${
            activeTab === "in_progress"
              ? "border-emerald-500 text-emerald-600 dark:text-emerald-400"
              : "border-transparent text-gray-500 hover:text-gray-900 dark:hover:text-white"
          }`}
        >
          <BookOpen className="w-4 h-4" />
          In Progress ({inProgressBooks.length})
        </button>

        <button
          onClick={() => setActiveTab("finished")}
          className={`pb-3 px-4 text-xs font-bold transition-all border-b-2 flex items-center gap-2 whitespace-nowrap ${
            activeTab === "finished"
              ? "border-emerald-500 text-emerald-600 dark:text-emerald-400"
              : "border-transparent text-gray-500 hover:text-gray-900 dark:hover:text-white"
          }`}
        >
          <CheckCircle className="w-4 h-4" />
          Finished ({finishedBooks.length})
        </button>

        <button
          onClick={() => setActiveTab("habits")}
          className={`pb-3 px-4 text-xs font-bold transition-all border-b-2 flex items-center gap-2 whitespace-nowrap ${
            activeTab === "habits"
              ? "border-emerald-500 text-emerald-600 dark:text-emerald-400"
              : "border-transparent text-gray-500 hover:text-gray-900 dark:hover:text-white"
          }`}
        >
          <Calendar className="w-4 h-4" />
          Action Plans & Habits
        </button>
      </div>

      {/* Content based on Tab */}
      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {[1, 2, 3, 4].map((n) => (
            <div key={n} className="h-72 rounded-2xl bg-gray-100 dark:bg-gray-800 animate-pulse" />
          ))}
        </div>
      ) : activeTab === "saved" ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {savedBooks.map((book) => (
            <BookCard key={book.id} book={book} />
          ))}
        </div>
      ) : activeTab === "in_progress" ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {inProgressBooks.map((book) => (
            <BookCard key={book.id} book={book} />
          ))}
        </div>
      ) : activeTab === "finished" ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {finishedBooks.map((book) => (
            <BookCard key={book.id} book={book} />
          ))}
        </div>
      ) : (
        /* Action Plans & Micro-Habits Tab */
        <div className="max-w-3xl space-y-6">
          <div className="p-6 rounded-3xl bg-linear-to-br from-emerald-500/10 to-teal-500/10 border border-emerald-200 dark:border-emerald-800/60 flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
            <div className="space-y-2">
              <div className="flex items-center gap-2">
                <span className="px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-emerald-500 text-white">
                  Active 7-Day Plan
                </span>
                <span className="text-xs text-emerald-600 dark:text-emerald-400 font-semibold">
                  Atomic Habits Roadmap
                </span>
              </div>
              <h3 className="text-xl font-bold text-gray-900 dark:text-white">
                Day 3: Two-Minute Rule Implementation
              </h3>
              <p className="text-xs text-gray-600 dark:text-gray-300">
                &ldquo;Downscale your habit until it takes less than two minutes to perform.&rdquo;
              </p>
            </div>

            <Link
              href="/book/atomic-habits"
              className="px-6 py-3 rounded-full bg-emerald-500 hover:bg-emerald-600 text-white text-xs font-bold shadow-md shadow-emerald-500/20 whitespace-nowrap"
            >
              Check-in Today
            </Link>
          </div>

          <div className="p-6 rounded-2xl bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-purple-100 dark:bg-purple-950/60 text-purple-600 flex items-center justify-center">
                <Sparkles className="w-5 h-5" />
              </div>
              <div>
                <h4 className="text-sm font-bold text-gray-900 dark:text-white">
                  Generate Action Plan for Any Book
                </h4>
                <p className="text-xs text-gray-500">
                  Synthesize structured micro-habits and export to Notion, Markdown, or Apple/Google Calendar.
                </p>
              </div>
            </div>

            <Link
              href="/explore"
              className="text-xs font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 flex items-center gap-1"
            >
              Pick a Book <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>
        </div>
      )}
    </div>
  );
}
