"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import {
  Sparkles,
  Headphones,
  CheckCircle,
  TrendingUp,
  ArrowRight,
  ShieldCheck,
  Star,
  Play,
  Calendar,
} from "lucide-react";
import { Book, DailyBlink, Category } from "@/types";
import { api } from "@/lib/api";
import { BookCard } from "@/components/BookCard";
import { useAudio } from "@/context/AudioContext";

export default function HomePage() {
  const [books, setBooks] = useState<Book[]>([]);
  const [dailyBlink, setDailyBlink] = useState<DailyBlink | null>(null);
  const [categories, setCategories] = useState<Category[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<string>("all");
  const [loading, setLoading] = useState(true);

  const { playTrack, currentTrack, isPlaying, togglePlay } = useAudio();

  useEffect(() => {
    async function loadData() {
      try {
        const [booksData, dailyData, catsData] = await Promise.all([
          api.getBooks(),
          api.getDailyBlink(),
          api.getCategories(),
        ]);
        setBooks(booksData);
        setDailyBlink(dailyData);
        setCategories(catsData);
      } catch (e) {
        console.error("Failed to load homepage data", e);
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, []);

  const filteredBooks =
    selectedCategory === "all"
      ? books
      : books.filter((b) => b.categories.some((c) => c.slug === selectedCategory));

  const isDailyBlinkPlaying =
    dailyBlink &&
    currentTrack?.bookSlug === dailyBlink.book.slug &&
    isPlaying;

  const handlePlayDailyBlink = () => {
    if (!dailyBlink) return;
    if (currentTrack?.bookSlug === dailyBlink.book.slug) {
      togglePlay();
      return;
    }
    playTrack({
      id: `daily_${dailyBlink.id}`,
      bookId: dailyBlink.book.id,
      bookSlug: dailyBlink.book.slug,
      bookTitle: dailyBlink.book.title,
      authorName: dailyBlink.book.author.name,
      coverUrl: dailyBlink.book.cover_image_url,
      sectionTitle: dailyBlink.title,
      sectionIndex: 0,
      totalSections: 1,
      audioUrl: dailyBlink.audio_url || "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
      durationSeconds: dailyBlink.duration_seconds || 600,
    });
  };

  return (
    <div className="flex flex-col gap-16 md:gap-24 pb-16">
      {/* Hero Section */}
      <section className="relative overflow-hidden pt-12 md:pt-20 pb-8 bg-radial-[at_top_right] from-emerald-500/10 via-background to-background">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col items-center text-center">
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-emerald-100 dark:bg-emerald-950/60 border border-emerald-300 dark:border-emerald-800 text-xs font-semibold text-emerald-800 dark:text-emerald-300 mb-6 shadow-xs animate-in fade-in slide-in-from-top-4 duration-500">
            <Sparkles className="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" />
            <span>Over 6,500+ Top Non-Fiction Book Summaries in Audio & Text</span>
          </div>

          <h1 className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-extrabold tracking-tight text-gray-900 dark:text-white max-w-4xl leading-[1.1] mb-6">
            Big ideas in{" "}
            <span className="text-transparent bg-clip-text bg-linear-to-r from-emerald-600 to-teal-500">
              15 minutes.
            </span>
          </h1>

          <p className="text-base sm:text-lg md:text-xl text-gray-600 dark:text-gray-300 max-w-2xl mb-8 leading-relaxed">
            Understand key takeaways from the world&apos;s best non-fiction books. Read key insights, listen to audio narration, and transform insights into real-world habits.
          </p>

          <div className="flex flex-col sm:flex-row items-center gap-4 w-full sm:w-auto">
            <Link
              href="/explore"
              className="w-full sm:w-auto px-8 py-3.5 rounded-full bg-emerald-500 hover:bg-emerald-600 active:scale-95 text-white font-semibold text-base shadow-lg shadow-emerald-500/30 flex items-center justify-center gap-2 transition-all"
            >
              Start 7-Day Free Trial
              <ArrowRight className="w-4 h-4" />
            </Link>

            <Link
              href="/explore"
              className="w-full sm:w-auto px-8 py-3.5 rounded-full bg-gray-100 hover:bg-gray-200 dark:bg-gray-800 dark:hover:bg-gray-700 active:scale-95 text-gray-800 dark:text-white font-semibold text-base transition-all"
            >
              Explore Catalog
            </Link>
          </div>

          <div className="flex items-center gap-6 mt-10 text-xs text-gray-500 dark:text-gray-400 font-medium">
            <span className="flex items-center gap-1.5">
              <CheckCircle className="w-4 h-4 text-emerald-500" />
              Cancel anytime
            </span>
            <span className="flex items-center gap-1.5">
              <CheckCircle className="w-4 h-4 text-emerald-500" />
              Unlimited audio & text
            </span>
            <span className="flex items-center gap-1.5">
              <CheckCircle className="w-4 h-4 text-emerald-500" />
              Cross-device progress
            </span>
          </div>
        </div>
      </section>

      {/* Today's Daily Audio Blink Banner */}
      {dailyBlink && (
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
          <div className="relative rounded-3xl bg-linear-to-r from-emerald-900 to-teal-950 text-white p-6 sm:p-8 md:p-10 shadow-2xl overflow-hidden border border-emerald-800/40">
            <div className="absolute top-0 right-0 w-96 h-96 bg-emerald-500/10 rounded-full blur-3xl -mr-20 -mt-20 pointer-events-none" />

            <div className="relative flex flex-col md:flex-row items-start md:items-center justify-between gap-6 z-10">
              <div className="space-y-3 max-w-2xl">
                <div className="flex items-center gap-2">
                  <span className="px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-emerald-500 text-white shadow-xs">
                    Free Daily Pick
                  </span>
                  <span className="text-xs text-emerald-200 font-medium">
                    Available free for 24 hours
                  </span>
                </div>

                <h2 className="text-2xl sm:text-3xl font-extrabold tracking-tight">
                  {dailyBlink.book.title}
                </h2>
                <p className="text-sm sm:text-base text-emerald-100/90 line-clamp-2">
                  {dailyBlink.book.subtitle || dailyBlink.book.description}
                </p>

                <p className="text-xs text-emerald-300 font-semibold">
                  By {dailyBlink.book.author.name} • {Math.round(dailyBlink.duration_seconds / 60)} min audio summary
                </p>
              </div>

              <div className="flex items-center gap-3 shrink-0 w-full sm:w-auto">
                <button
                  onClick={handlePlayDailyBlink}
                  className="flex-1 sm:flex-none px-6 py-3.5 rounded-full bg-white hover:bg-emerald-50 text-emerald-950 font-bold text-sm flex items-center justify-center gap-2 shadow-lg transition-transform active:scale-95"
                  aria-label={isDailyBlinkPlaying ? "Pause Daily Blink" : "Play Daily Blink"}
                >
                  {isDailyBlinkPlaying ? (
                    <>
                      <span className="w-2.5 h-3.5 bg-emerald-900 mx-0.5 rounded-xs" />
                      <span className="w-2.5 h-3.5 bg-emerald-900 mx-0.5 rounded-xs" />
                      Pause Daily Blink
                    </>
                  ) : (
                    <>
                      <Play className="w-4 h-4 fill-emerald-950 ml-0.5" />
                      Listen Today (Free)
                    </>
                  )}
                </button>

                <Link
                  href={`/book/${dailyBlink.book.slug}/read`}
                  className="px-5 py-3.5 rounded-full bg-emerald-800/80 hover:bg-emerald-800 text-white font-medium text-sm transition-colors text-center"
                >
                  Read
                </Link>
              </div>
            </div>
          </div>
        </section>
      )}

      {/* Category Pills & Trending Books Grid */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
        <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-8">
          <div>
            <div className="flex items-center gap-2 text-emerald-600 dark:text-emerald-400 font-semibold text-xs tracking-wider uppercase mb-1">
              <TrendingUp className="w-4 h-4" />
              <span>Curated Summaries</span>
            </div>
            <h2 className="text-2xl sm:text-3xl font-extrabold text-gray-900 dark:text-white">
              Trending & Must-Reads
            </h2>
          </div>

          <Link
            href="/explore"
            className="text-sm font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 flex items-center gap-1 group"
          >
            View all categories
            <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
          </Link>
        </div>

        {/* Category Pills */}
        <div className="flex items-center gap-2 overflow-x-auto pb-4 mb-6 scrollbar-none">
          <button
            onClick={() => setSelectedCategory("all")}
            className={`px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all ${
              selectedCategory === "all"
                ? "bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
                : "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
            }`}
          >
            All Categories
          </button>
          {categories.map((cat) => (
            <button
              key={cat.id}
              onClick={() => setSelectedCategory(cat.slug)}
              className={`px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all ${
                selectedCategory === cat.slug
                  ? "bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
                  : "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
              }`}
            >
              {cat.name}
            </button>
          ))}
        </div>

        {/* Books Grid */}
        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {[1, 2, 3, 4].map((n) => (
              <div
                key={n}
                className="h-72 rounded-2xl bg-gray-100 dark:bg-gray-800 animate-pulse"
              />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {filteredBooks.map((book) => (
              <BookCard key={book.id} book={book} />
            ))}
          </div>
        )}
      </section>

      {/* How Blinkist Works - Value Propositions */}
      <section className="bg-gray-50 dark:bg-gray-900/60 py-16 border-y border-gray-200 dark:border-gray-800">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-2xl mx-auto mb-12">
            <h2 className="text-2xl sm:text-3xl font-extrabold text-gray-900 dark:text-white mb-3">
              Designed for Busy Minds
            </h2>
            <p className="text-sm sm:text-base text-gray-600 dark:text-gray-400">
              Transform moments in between into continuous personal growth.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="bg-white dark:bg-gray-800 p-8 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-xs">
              <div className="w-12 h-12 rounded-xl bg-emerald-100 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400 flex items-center justify-center mb-5">
                <Headphones className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2">
                Listen on the Go
              </h3>
              <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                Professionally narrated audio blinks with variable playback speeds and lock-screen scrubber controls. Perfect for commuting or walking.
              </p>
            </div>

            <div className="bg-white dark:bg-gray-800 p-8 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-xs">
              <div className="w-12 h-12 rounded-xl bg-blue-100 dark:bg-blue-950/60 text-blue-600 dark:text-blue-400 flex items-center justify-center mb-5">
                <Sparkles className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2">
                In-Reader AI Companion
              </h3>
              <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                Ask questions about complex ideas directly within the reader, synthesize core principles, and test your knowledge with interactive flashcards.
              </p>
            </div>

            <div className="bg-white dark:bg-gray-800 p-8 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-xs">
              <div className="w-12 h-12 rounded-xl bg-purple-100 dark:bg-purple-950/60 text-purple-600 dark:text-purple-400 flex items-center justify-center mb-5">
                <Calendar className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2">
                1-Tap Action Plans & Habits
              </h3>
              <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                Turn knowledge into action. Synthesize customized 7-day or 14-day micro-habit roadmaps and export directly to Notion, Markdown, or calendar (.ics).
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Pricing / Membership Tier Preview */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
        <div className="text-center max-w-2xl mx-auto mb-12">
          <h2 className="text-3xl font-extrabold text-gray-900 dark:text-white mb-3">
            Choose Your Learning Path
          </h2>
          <p className="text-base text-gray-600 dark:text-gray-400">
            Start with our 7-day free trial. Cancel anytime with zero commitment.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-4xl mx-auto">
          {/* Free Tier */}
          <div className="rounded-3xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-800/60 p-8 flex flex-col justify-between">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-gray-500">
                Free Plan
              </span>
              <h3 className="text-2xl font-bold text-gray-900 dark:text-white mt-1">
                Blinkist Basic
              </h3>
              <div className="mt-4 flex items-baseline">
                <span className="text-4xl font-extrabold text-gray-900 dark:text-white">$0</span>
                <span className="ml-1 text-sm text-gray-500">/ forever</span>
              </div>
              <ul className="mt-6 space-y-3 text-sm text-gray-600 dark:text-gray-300">
                <li className="flex items-center gap-2">
                  <CheckCircle className="w-4 h-4 text-emerald-500" />
                  1 Free Daily Audio Blink each day
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="w-4 h-4 text-emerald-500" />
                  Explore book descriptions & key takeaways
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="w-4 h-4 text-emerald-500" />
                  Personal library bookmarking
                </li>
              </ul>
            </div>

            <Link
              href="/explore"
              className="mt-8 block text-center px-6 py-3 rounded-xl border border-gray-300 dark:border-gray-700 text-gray-700 dark:text-gray-200 font-semibold hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
            >
              Start Free
            </Link>
          </div>

          {/* Premium Tier */}
          <div className="relative rounded-3xl border-2 border-emerald-500 bg-white dark:bg-gray-800 p-8 shadow-xl flex flex-col justify-between">
            <span className="absolute -top-3.5 right-6 px-3 py-1 rounded-full text-xs font-extrabold uppercase tracking-wide bg-emerald-500 text-white shadow-md">
              Most Popular
            </span>

            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-emerald-600 dark:text-emerald-400">
                Premium Access
              </span>
              <h3 className="text-2xl font-bold text-gray-900 dark:text-white mt-1">
                Blinkist Plus
              </h3>
              <div className="mt-4 flex items-baseline">
                <span className="text-4xl font-extrabold text-gray-900 dark:text-white">$8.33</span>
                <span className="ml-1 text-sm text-gray-500">/ month (billed annually)</span>
              </div>
              <ul className="mt-6 space-y-3 text-sm text-gray-600 dark:text-gray-300">
                <li className="flex items-center gap-2">
                  <CheckCircle className="w-4 h-4 text-emerald-500" />
                  Unlimited access to 6,500+ text & audio summaries
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="w-4 h-4 text-emerald-500" />
                  Offline downloads & background listening
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="w-4 h-4 text-emerald-500" />
                  Interactive Flashcards & Spaced Repetition
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle className="w-4 h-4 text-emerald-500" />
                  AI Micro-Habit Roadmaps & Action Plans
                </li>
              </ul>
            </div>

            <Link
              href="/login"
              className="mt-8 block text-center px-6 py-3.5 rounded-xl bg-emerald-500 hover:bg-emerald-600 active:scale-95 text-white font-bold shadow-lg shadow-emerald-500/25 transition-all"
            >
              Start 7-Day Free Trial
            </Link>
          </div>
        </div>
      </section>

      {/* Social Proof / Trust Banner */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <div className="inline-flex items-center gap-1 text-amber-500 mb-2">
          {[...Array(5)].map((_, i) => (
            <Star key={i} className="w-5 h-5 fill-current" />
          ))}
        </div>
        <p className="text-lg font-bold text-gray-900 dark:text-white">
          Loved by 28+ million readers worldwide
        </p>
        <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
          Named App of the Year by Apple & Google Play
        </p>
      </section>
    </div>
  );
}
