"use client";

import React, { useState } from "react";
import Link from "next/link";
import { Clock, Star, Headphones, Bookmark, Play, BookOpen } from "lucide-react";
import { Book } from "@/types";
import { useAudio } from "@/context/AudioContext";

interface BookCardProps {
  book: Book;
  onBookmarkChange?: (isSaved: boolean) => void;
}

export const BookCard: React.FC<BookCardProps> = ({ book, onBookmarkChange }) => {
  const { playTrack, currentTrack, isPlaying, togglePlay } = useAudio();
  const [isSaved, setIsSaved] = useState(book.is_saved ?? false);

  const isCurrentBookPlaying =
    currentTrack?.bookSlug === book.slug && isPlaying;

  const handlePlayClick = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();

    if (currentTrack?.bookSlug === book.slug) {
      togglePlay();
      return;
    }

    const firstSection = book.sections?.[0];
    playTrack({
      id: firstSection?.id || `book_${book.id}`,
      bookId: book.id,
      bookSlug: book.slug,
      bookTitle: book.title,
      authorName: book.author.name,
      coverUrl: book.cover_image_url,
      sectionTitle: firstSection?.title || "Key Takeaway 1",
      sectionIndex: 0,
      totalSections: book.sections?.length || 1,
      audioUrl: firstSection?.audio_url || "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
      durationSeconds: firstSection?.duration_seconds || 600,
    });
  };

  const handleBookmarkToggle = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    const nextSaved = !isSaved;
    setIsSaved(nextSaved);
    onBookmarkChange?.(nextSaved);
  };

  return (
    <div className="group relative flex flex-col bg-white dark:bg-gray-800/80 rounded-2xl border border-gray-200 dark:border-gray-700/80 overflow-hidden shadow-xs hover:shadow-xl hover:border-emerald-500/50 dark:hover:border-emerald-500/50 transition-all duration-300">
      {/* Cover Image & Quick Action Overlay */}
      <Link href={`/book/${book.slug}`} className="relative aspect-4/3 w-full bg-gray-100 dark:bg-gray-900 overflow-hidden block">
        {book.cover_image_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={book.cover_image_url}
            alt={book.title}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
          />
        ) : (
          <div className="w-full h-full flex flex-col items-center justify-center p-4 bg-linear-to-br from-emerald-500/10 to-teal-500/20 text-emerald-600">
            <BookOpen className="w-12 h-12 mb-2 stroke-[1.5]" />
            <span className="text-xs font-semibold uppercase tracking-wider text-center text-gray-700 dark:text-gray-300">
              {book.title}
            </span>
          </div>
        )}

        {/* Free Daily Pick Badge */}
        {book.is_daily_free && (
          <span className="absolute top-3 left-3 px-2.5 py-0.5 rounded-full text-[11px] font-bold tracking-wide uppercase bg-amber-500 text-white shadow-md">
            Free Daily Pick
          </span>
        )}

        {/* Bookmark Button */}
        <button
          onClick={handleBookmarkToggle}
          className="absolute top-3 right-3 p-2 rounded-full bg-white/90 dark:bg-gray-900/90 backdrop-blur-xs text-gray-600 dark:text-gray-300 hover:text-emerald-500 dark:hover:text-emerald-400 transition-colors shadow-sm"
          title={isSaved ? "Remove from Library" : "Save to Library"}
          aria-label={isSaved ? "Remove bookmark" : "Add bookmark"}
        >
          <Bookmark className={`w-4 h-4 ${isSaved ? "fill-emerald-500 text-emerald-500" : ""}`} />
        </button>

        {/* Floating Quick Play Button */}
        <button
          onClick={handlePlayClick}
          className="absolute bottom-3 right-3 w-10 h-10 rounded-full bg-emerald-500 hover:bg-emerald-600 text-white flex items-center justify-center shadow-lg shadow-emerald-500/30 opacity-90 group-hover:opacity-100 group-hover:scale-105 active:scale-95 transition-all"
          title={isCurrentBookPlaying ? "Pause audio summary" : "Listen to audio summary"}
          aria-label={isCurrentBookPlaying ? "Pause audio" : "Listen to audio"}
        >
          {isCurrentBookPlaying ? (
            <div className="w-3.5 h-3.5 flex items-center justify-center">
              <span className="w-1 h-3.5 bg-white mx-0.5 rounded-xs" />
              <span className="w-1 h-3.5 bg-white mx-0.5 rounded-xs" />
            </div>
          ) : (
            <Play className="w-4 h-4 fill-current ml-0.5" />
          )}
        </button>
      </Link>

      {/* Book Metadata */}
      <div className="p-4 flex-1 flex flex-col justify-between gap-3">
        <div>
          {/* Categories */}
          <div className="flex flex-wrap gap-1.5 mb-2">
            {book.categories.slice(0, 2).map((cat) => (
              <span
                key={cat.id}
                className="text-[11px] font-medium text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/40 px-2 py-0.5 rounded-md"
              >
                {cat.name}
              </span>
            ))}
          </div>

          <Link href={`/book/${book.slug}`} className="block">
            <h3 className="font-bold text-gray-900 dark:text-white line-clamp-1 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
              {book.title}
            </h3>
          </Link>
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5 line-clamp-1 font-medium">
            {book.author.name}
          </p>
        </div>

        {/* Footer Info: Duration, Rating, Audio Tag */}
        <div className="pt-2 border-t border-gray-100 dark:border-gray-700/60 flex items-center justify-between text-xs text-gray-500 dark:text-gray-400">
          <div className="flex items-center gap-3">
            <span className="flex items-center gap-1">
              <Clock className="w-3.5 h-3.5 text-gray-400" />
              {book.estimated_read_time_minutes} min
            </span>

            {book.has_audio !== false && (
              <span className="flex items-center gap-1 text-emerald-600 dark:text-emerald-400" title="Audio available">
                <Headphones className="w-3.5 h-3.5" />
                Audio
              </span>
            )}
          </div>

          {book.rating && (
            <span className="flex items-center gap-1 font-semibold text-gray-700 dark:text-gray-200">
              <Star className="w-3.5 h-3.5 fill-amber-400 text-amber-400" />
              {book.rating.toFixed(1)}
            </span>
          )}
        </div>
      </div>
    </div>
  );
};
