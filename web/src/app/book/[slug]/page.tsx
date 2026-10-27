"use client";

import React, { useEffect, useState, use, Suspense } from "react";
import Link from "next/link";
import {
  BookOpen,
  Headphones,
  Clock,
  Star,
  Bookmark,
  Play,
  CheckCircle2,
  Sparkles,
  ArrowLeft,
} from "lucide-react";
import { Book } from "@/types";
import { api } from "@/lib/api";
import { useAudio } from "@/context/AudioContext";

function BookDetailContent({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const resolvedParams = use(params);
  const slug = resolvedParams.slug;

  const [book, setBook] = useState<Book | null>(null);
  const [loading, setLoading] = useState(true);
  const [isSaved, setIsSaved] = useState(false);

  const { playTrack, currentTrack, isPlaying, togglePlay } = useAudio();

  useEffect(() => {
    async function fetchBook() {
      try {
        const data = await api.getBookBySlug(slug);
        setBook(data);
        setIsSaved(data.is_saved ?? false);
      } catch (e) {
        console.error("Failed to load book detail", e);
      } finally {
        setLoading(false);
      }
    }
    fetchBook();
  }, [slug]);

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 animate-pulse space-y-8">
        <div className="h-6 w-32 bg-gray-200 dark:bg-gray-800 rounded-md" />
        <div className="flex flex-col md:flex-row gap-8">
          <div className="w-full md:w-80 h-96 bg-gray-200 dark:bg-gray-800 rounded-2xl" />
          <div className="flex-1 space-y-4">
            <div className="h-10 w-3/4 bg-gray-200 dark:bg-gray-800 rounded-lg" />
            <div className="h-5 w-1/2 bg-gray-200 dark:bg-gray-800 rounded-md" />
            <div className="h-24 w-full bg-gray-200 dark:bg-gray-800 rounded-xl" />
          </div>
        </div>
      </div>
    );
  }

  if (!book) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-20 text-center">
        <BookOpen className="w-16 h-16 mx-auto text-gray-400 mb-4" />
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
          Book Summary Not Found
        </h1>
        <p className="text-sm text-gray-500 dark:text-gray-400 mb-6">
          The summary you are looking for might have been moved or removed.
        </p>
        <Link
          href="/explore"
          className="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-emerald-500 text-white font-semibold text-sm hover:bg-emerald-600 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Browse Library
        </Link>
      </div>
    );
  }

  const isCurrentBookPlaying =
    currentTrack?.bookSlug === book.slug && isPlaying;

  const handlePlayAudio = (sectionIndex = 0) => {
    const section = book.sections?.[sectionIndex] || {
      id: `section_${sectionIndex}`,
      title: "Key Takeaways",
      duration_seconds: 600,
      audio_url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
    };

    if (currentTrack?.bookSlug === book.slug && currentTrack.sectionIndex === sectionIndex) {
      togglePlay();
      return;
    }

    playTrack({
      id: section.id,
      bookId: book.id,
      bookSlug: book.slug,
      bookTitle: book.title,
      authorName: book.author.name,
      coverUrl: book.cover_image_url,
      sectionTitle: section.title,
      sectionIndex,
      totalSections: book.sections?.length || 1,
      audioUrl: section.audio_url || "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
      durationSeconds: section.duration_seconds || 600,
    });
  };

  const handleToggleBookmark = async () => {
    const nextSaved = !isSaved;
    setIsSaved(nextSaved);
    await api.toggleSaveBook(book.id);
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12">
      {/* Back button */}
      <Link
        href="/explore"
        className="inline-flex items-center gap-1.5 text-xs font-semibold text-gray-500 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors mb-8 group"
      >
        <ArrowLeft className="w-4 h-4 group-hover:-translate-x-1 transition-transform" />
        Back to Library
      </Link>

      {/* Book Hero Section */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-8 lg:gap-12 pb-12 border-b border-gray-200 dark:border-gray-800">
        {/* Cover Art Column */}
        <div className="md:col-span-5 lg:col-span-4">
          <div className="relative aspect-3/4 rounded-2xl overflow-hidden shadow-2xl bg-gray-100 dark:bg-gray-900 border border-gray-200 dark:border-gray-800">
            {book.cover_image_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={book.cover_image_url}
                alt={book.title}
                className="w-full h-full object-cover"
              />
            ) : (
              <div className="w-full h-full flex flex-col items-center justify-center p-6 text-emerald-600 bg-emerald-50 dark:bg-emerald-950/30">
                <BookOpen className="w-16 h-16 mb-2" />
                <span className="text-center font-bold text-gray-800 dark:text-gray-200">
                  {book.title}
                </span>
              </div>
            )}

            {book.is_daily_free && (
              <span className="absolute top-4 left-4 px-3 py-1 rounded-full text-xs font-extrabold uppercase bg-amber-500 text-white shadow-md">
                Free Daily Pick
              </span>
            )}
          </div>
        </div>

        {/* Book Info Column */}
        <div className="md:col-span-7 lg:col-span-8 flex flex-col justify-between">
          <div className="space-y-4">
            {/* Categories */}
            <div className="flex flex-wrap gap-2">
              {book.categories.map((c) => (
                <span
                  key={c.id}
                  className="px-3 py-1 rounded-full text-xs font-semibold bg-emerald-50 dark:bg-emerald-950/50 text-emerald-700 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800"
                >
                  {c.name}
                </span>
              ))}
            </div>

            {/* Title & Subtitle */}
            <h1 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold text-gray-900 dark:text-white tracking-tight">
              {book.title}
            </h1>
            {book.subtitle && (
              <p className="text-lg text-gray-600 dark:text-gray-300 font-medium leading-relaxed">
                {book.subtitle}
              </p>
            )}

            {/* Author */}
            <div className="flex items-center gap-2 pt-1 text-sm font-semibold text-gray-700 dark:text-gray-200">
              <span>By {book.author.name}</span>
            </div>

            {/* Metrics: Read time, audio, rating */}
            <div className="flex flex-wrap items-center gap-6 pt-2 text-sm text-gray-600 dark:text-gray-400">
              <span className="flex items-center gap-1.5 font-medium">
                <Clock className="w-4 h-4 text-gray-400" />
                {book.estimated_read_time_minutes} min read
              </span>

              {book.has_audio !== false && (
                <span className="flex items-center gap-1.5 font-medium text-emerald-600 dark:text-emerald-400">
                  <Headphones className="w-4 h-4" />
                  {book.estimated_read_time_minutes} min audio
                </span>
              )}

              {book.rating && (
                <span className="flex items-center gap-1 font-semibold text-gray-900 dark:text-white">
                  <Star className="w-4 h-4 fill-amber-400 text-amber-400" />
                  {book.rating.toFixed(1)} ({book.rating_count?.toLocaleString()} ratings)
                </span>
              )}
            </div>

            {/* Description */}
            <p className="text-sm sm:text-base text-gray-700 dark:text-gray-300 leading-relaxed pt-2">
              {book.description}
            </p>
          </div>

          {/* Action CTAs */}
          <div className="flex flex-wrap items-center gap-4 pt-8">
            <Link
              href={`/book/${book.slug}/read`}
              className="px-8 py-3.5 rounded-full bg-emerald-500 hover:bg-emerald-600 active:scale-95 text-white font-bold text-sm shadow-lg shadow-emerald-500/25 flex items-center justify-center gap-2 transition-all"
            >
              <BookOpen className="w-4 h-4" />
              Read Summary
            </Link>

            <button
              onClick={() => handlePlayAudio(0)}
              className="px-8 py-3.5 rounded-full bg-gray-900 hover:bg-black dark:bg-white dark:hover:bg-gray-100 active:scale-95 text-white dark:text-gray-900 font-bold text-sm shadow-md flex items-center justify-center gap-2 transition-all"
            >
              {isCurrentBookPlaying ? (
                <>
                  <span className="w-2.5 h-3.5 bg-current mx-0.5 rounded-xs" />
                  <span className="w-2.5 h-3.5 bg-current mx-0.5 rounded-xs" />
                  Pause Audio
                </>
              ) : (
                <>
                  <Play className="w-4 h-4 fill-current ml-0.5" />
                  Listen to Audio
                </>
              )}
            </button>

            <button
              onClick={handleToggleBookmark}
              className={`p-3.5 rounded-full border transition-all ${
                isSaved
                  ? "border-emerald-500 bg-emerald-50 dark:bg-emerald-950/40 text-emerald-600"
                  : "border-gray-300 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:border-emerald-500"
              }`}
              title={isSaved ? "Saved to Library" : "Save to Library"}
              aria-label={isSaved ? "Saved" : "Save to library"}
            >
              <Bookmark className={`w-4 h-4 ${isSaved ? "fill-emerald-500" : ""}`} />
            </button>
          </div>
        </div>
      </div>

      {/* What You'll Learn & Blinks Table of Contents */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 py-12">
        {/* Left Column: Key Takeaways */}
        <div className="lg:col-span-7 space-y-8">
          {book.what_you_will_learn && (
            <div className="bg-emerald-50/50 dark:bg-emerald-950/20 rounded-3xl p-6 sm:p-8 border border-emerald-100 dark:border-emerald-900/40">
              <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
                <Sparkles className="w-5 h-5 text-emerald-500" />
                What You&apos;ll Learn
              </h2>
              <ul className="space-y-3">
                {(Array.isArray(book.what_you_will_learn)
                  ? book.what_you_will_learn
                  : [book.what_you_will_learn]
                ).map((point, idx) => (
                  <li key={idx} className="flex items-start gap-3 text-sm text-gray-700 dark:text-gray-300">
                    <CheckCircle2 className="w-5 h-5 text-emerald-500 shrink-0 mt-0.5" />
                    <span>{point}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Author Bio */}
          <div className="space-y-3">
            <h2 className="text-xl font-bold text-gray-900 dark:text-white">
              About the Author
            </h2>
            <p className="text-sm text-gray-600 dark:text-gray-300 leading-relaxed">
              {book.author.bio || `${book.author.name} is an acclaimed author and thought leader in the domain of personal growth and professional excellence.`}
            </p>
          </div>
        </div>

        {/* Right Column: Blinks Table of Contents */}
        <div className="lg:col-span-5 space-y-4">
          <h2 className="text-xl font-bold text-gray-900 dark:text-white">
            Summary Blinks Outline
          </h2>

          <div className="space-y-2">
            {(book.sections && book.sections.length > 0
              ? book.sections
              : [
                  { id: 1, title: "The Surprising Power of Atomic Habits", duration_seconds: 180, order: 1 },
                  { id: 2, title: "How Habits Shape Your Identity", duration_seconds: 210, order: 2 },
                  { id: 3, title: "The Four Laws of Behavior Change", duration_seconds: 240, order: 3 },
                ]
            ).map((section, idx) => (
              <div
                key={section.id}
                className="flex items-center justify-between p-3.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-800/60 hover:border-emerald-500/50 transition-colors group"
              >
                <div className="flex items-center gap-3 min-w-0 pr-2">
                  <span className="w-6 h-6 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 text-xs font-semibold flex items-center justify-center shrink-0">
                    {idx + 1}
                  </span>
                  <span className="text-sm font-semibold text-gray-900 dark:text-white truncate group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
                    {section.title}
                  </span>
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  <span className="text-xs text-gray-400 font-mono">
                    {Math.round((section.duration_seconds || 180) / 60)} min
                  </span>
                  <button
                    onClick={() => handlePlayAudio(idx)}
                    className="p-1.5 rounded-full hover:bg-emerald-50 dark:hover:bg-emerald-950/40 text-emerald-600 transition-colors"
                    title="Play this blink"
                    aria-label={`Play blink ${idx + 1}`}
                  >
                    <Play className="w-4 h-4 fill-current" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

export default function BookDetailPage(props: {
  params: Promise<{ slug: string }>;
}) {
  return (
    <Suspense
      fallback={
        <div className="max-w-7xl mx-auto px-4 py-16 text-center text-sm text-gray-500">
          Loading book details...
        </div>
      }
    >
      <BookDetailContent {...props} />
    </Suspense>
  );
}

