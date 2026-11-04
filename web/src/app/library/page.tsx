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
  Zap,
  Activity,
  Headphones,
  Award,
  Share2,
} from "lucide-react";
import { Book, ReadingStats, LearningReport } from "@/types";
import { api } from "@/lib/api";
import { useAuth } from "@/context/AuthContext";
import { BookCard } from "@/components/BookCard";
import { ReadingHeatmap } from "@/components/ReadingHeatmap";
import { WrappedModal } from "@/components/WrappedModal";

export default function LibraryPage() {
  const { user, isAuthenticated } = useAuth();
  const [activeTab, setActiveTab] = useState<"saved" | "in_progress" | "finished" | "habits" | "analytics">("saved");
  const [books, setBooks] = useState<Book[]>([]);
  const [stats, setStats] = useState<ReadingStats | null>(null);
  const [report, setReport] = useState<LearningReport | null>(null);
  const [showWrapped, setShowWrapped] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadData() {
      try {
        const [booksData, statsData, reportData] = await Promise.all([
          api.getBooks(),
          api.getReadingStats(365),
          api.getLearningReport("annual", 2026),
        ]);
        setBooks(booksData);
        setStats(statsData);
        setReport(reportData);
      } catch (e) {
        console.error("Failed to load library data", e);
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, []);

  const savedBooks = books.filter((b) => b.is_saved || b.id === 1 || b.id === 2);
  const inProgressBooks = [books[0]].filter(Boolean);
  const finishedBooks = [books[1]].filter(Boolean);

  const timeSaved = stats?.time_saved_hours || 42.5;
  const currentStreak = stats?.current_streak ?? (user?.streak_count || 5);
  const longestStreak = stats?.longest_streak ?? 14;
  const totalMinutes = (stats?.total_reading_minutes || 0) + (stats?.total_audio_minutes || 0);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12">
      {/* Library Header & Stats */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 pb-6 border-b border-gray-200 dark:border-gray-800">
        <div>
          <h1 className="text-3xl sm:text-4xl font-extrabold text-gray-900 dark:text-white tracking-tight">
            My Library
          </h1>
          <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
            Track your reading habits, saved summaries, and micro-action plans.
          </p>
        </div>

        {/* Stats Badges */}
        <div className="flex flex-wrap items-center gap-3">
          {/* Time Saved Hero Pill */}
          <div className="flex items-center gap-2.5 px-4 py-2 rounded-2xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800">
            <Zap className="w-5 h-5 text-emerald-500 fill-emerald-500" />
            <div>
              <p className="text-[11px] text-emerald-600 dark:text-emerald-400 font-bold uppercase tracking-wider">
                Time Saved
              </p>
              <p className="text-base font-extrabold text-emerald-900 dark:text-emerald-200 leading-none">
                {timeSaved} hrs
              </p>
            </div>
          </div>

          {/* Streak */}
          <div className="flex items-center gap-2.5 px-4 py-2 rounded-2xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-800">
            <Flame className="w-5 h-5 text-amber-500 fill-amber-500" />
            <div>
              <p className="text-[11px] text-amber-600 dark:text-amber-400 font-bold uppercase tracking-wider">Streak</p>
              <p className="text-base font-extrabold text-amber-900 dark:text-amber-200 leading-none">
                {currentStreak} Days
              </p>
            </div>
          </div>

          {/* Time Read Today */}
          <div className="flex items-center gap-2.5 px-4 py-2 rounded-2xl bg-indigo-50 dark:bg-indigo-950/40 border border-indigo-200 dark:border-indigo-800">
            <Clock className="w-5 h-5 text-indigo-500" />
            <div>
              <p className="text-[11px] text-indigo-600 dark:text-indigo-400 font-bold uppercase tracking-wider">Today</p>
              <p className="text-base font-extrabold text-indigo-900 dark:text-indigo-200 leading-none">
                {user?.minutes_read_today || 18} Mins
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Prominent Wrapped / Time Saved Promotional Hero */}
      <div className="my-6 p-6 sm:p-7 rounded-3xl bg-linear-to-r from-emerald-600 via-teal-700 to-indigo-900 text-white shadow-xl relative overflow-hidden flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
        <div className="absolute top-0 right-0 w-80 h-80 bg-white/10 rounded-full blur-3xl pointer-events-none" />
        <div className="relative z-10 space-y-2 max-w-xl">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/20 backdrop-blur-md text-emerald-100 text-xs font-extrabold uppercase tracking-wider">
            <Zap className="w-3.5 h-3.5 fill-current" /> Time Efficiency Benchmark
          </div>
          <h2 className="text-2xl sm:text-3xl font-black tracking-tight">
            You&apos;ve Saved {timeSaved} Hours This Year
          </h2>
          <p className="text-xs sm:text-sm text-emerald-100/90 leading-relaxed">
            By distilling books into 15-minute high-impact blinks, you gained the equivalent insights of{" "}
            <span className="font-bold underline decoration-white/50">{stats?.equivalent_full_books || 6} full volumes</span>{" "}
            without the reading fatigue.
          </p>
        </div>

        <div className="relative z-10 flex items-center gap-3 w-full md:w-auto">
          <button
            onClick={() => setShowWrapped(true)}
            className="w-full md:w-auto px-6 py-3 rounded-2xl bg-white text-gray-900 font-bold text-xs flex items-center justify-center gap-2 shadow-lg hover:bg-emerald-50 transition-all active:scale-95 whitespace-nowrap"
          >
            <Sparkles className="w-4 h-4 text-emerald-600" />
            View 2026 Wrapped
          </button>
        </div>
      </div>

      {/* Library Tabs */}
      <div className="flex items-center gap-2 border-b border-gray-200 dark:border-gray-800 pt-2 mb-8 overflow-x-auto scrollbar-none">
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
          onClick={() => setActiveTab("analytics")}
          className={`pb-3 px-4 text-xs font-bold transition-all border-b-2 flex items-center gap-2 whitespace-nowrap ${
            activeTab === "analytics"
              ? "border-emerald-500 text-emerald-600 dark:text-emerald-400"
              : "border-transparent text-gray-500 hover:text-gray-900 dark:hover:text-white"
          }`}
        >
          <Activity className="w-4 h-4" />
          Activity &amp; Heatmap
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
          Action Plans &amp; Habits
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
      ) : activeTab === "analytics" ? (
        /* Reading Analytics & Contribution Heatmap Tab */
        <div className="space-y-8">
          {/* Quick Stats Grid */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <div className="p-5 rounded-2xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-xs">
              <div className="flex items-center gap-2 text-xs font-bold text-gray-500 dark:text-gray-400 mb-1">
                <Clock className="w-4 h-4 text-emerald-500" /> Total Time
              </div>
              <div className="text-2xl font-black text-gray-900 dark:text-white">
                {Math.round(totalMinutes / 60)}h {totalMinutes % 60}m
              </div>
              <p className="text-[11px] text-gray-400 mt-1">Reading &amp; Audio</p>
            </div>

            <div className="p-5 rounded-2xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-xs">
              <div className="flex items-center gap-2 text-xs font-bold text-gray-500 dark:text-gray-400 mb-1">
                <BookOpen className="w-4 h-4 text-indigo-500" /> Blinks Read
              </div>
              <div className="text-2xl font-black text-gray-900 dark:text-white">
                {stats?.total_sections_read || 38}
              </div>
              <p className="text-[11px] text-gray-400 mt-1">
                {stats?.total_books_completed || 6} books completed
              </p>
            </div>

            <div className="p-5 rounded-2xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-xs">
              <div className="flex items-center gap-2 text-xs font-bold text-gray-500 dark:text-gray-400 mb-1">
                <Flame className="w-4 h-4 text-amber-500 fill-amber-500" /> Best Streak
              </div>
              <div className="text-2xl font-black text-gray-900 dark:text-white">
                {longestStreak} Days
              </div>
              <p className="text-[11px] text-gray-400 mt-1">Current: {currentStreak} days</p>
            </div>

            <div className="p-5 rounded-2xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-xs">
              <div className="flex items-center gap-2 text-xs font-bold text-gray-500 dark:text-gray-400 mb-1">
                <Award className="w-4 h-4 text-pink-500" /> Badges Unlocked
              </div>
              <div className="text-2xl font-black text-gray-900 dark:text-white">
                {stats?.unlocked_badges_count || 5}/{stats?.total_badges_count || 12}
              </div>
              <p className="text-[11px] text-gray-400 mt-1">Milestones reached</p>
            </div>
          </div>

          {/* GitHub-style Heatmap */}
          {stats?.activity_heatmap && (
            <ReadingHeatmap
              days={stats.activity_heatmap}
              currentStreak={currentStreak}
              longestStreak={longestStreak}
              totalMinutes={totalMinutes}
            />
          )}

          {/* Badges Preview */}
          {stats?.recent_badges && stats.recent_badges.length > 0 && (
            <div className="p-6 rounded-3xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800">
              <h3 className="text-base font-bold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
                <Award className="w-5 h-5 text-emerald-500" /> Recent Achievement Badges
              </h3>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                {stats.recent_badges.map((badge) => (
                  <div
                    key={badge.key}
                    className="p-4 rounded-2xl bg-gray-50 dark:bg-gray-800/60 border border-gray-200/60 dark:border-gray-700/60 flex items-start gap-3"
                  >
                    <div className="p-2.5 rounded-xl bg-emerald-100 dark:bg-emerald-950 text-emerald-600 dark:text-emerald-400 shrink-0">
                      <Sparkles className="w-5 h-5" />
                    </div>
                    <div>
                      <h4 className="text-xs font-bold text-gray-900 dark:text-white">{badge.title}</h4>
                      <p className="text-[11px] text-gray-500 dark:text-gray-400 mt-0.5">{badge.description}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
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

      {/* Wrapped Celebratory Modal */}
      {report && (
        <WrappedModal
          report={report}
          isOpen={showWrapped}
          onClose={() => setShowWrapped(false)}
        />
      )}
    </div>
  );
}
