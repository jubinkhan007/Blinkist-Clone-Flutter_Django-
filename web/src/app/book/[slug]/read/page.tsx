"use client";

import React, { useEffect, useState, use, useRef, useCallback, Suspense } from "react";
import Link from "next/link";
import {
  ArrowLeft,
  ChevronLeft,
  ChevronRight,
  Headphones,
  Settings,
  List,
  CheckCircle,
  X,
  BookOpen,
  Highlighter,
  Trash2,
  Plus,
  MessageSquare,
} from "lucide-react";
import { Book, SummarySection, UserHighlight } from "@/types";
import { api } from "@/lib/api";
import { useAudio } from "@/context/AudioContext";

type ReaderTheme = "light" | "sepia" | "dark";
type ReaderFont = "serif" | "sans";
type ReaderSize = "sm" | "md" | "lg" | "xl";
type HighlightColor = "yellow" | "green" | "blue" | "pink";

function ReaderContent({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const resolvedParams = use(params);
  const slug = resolvedParams.slug;

  const [book, setBook] = useState<Book | null>(null);
  const [currentSectionIndex, setCurrentSectionIndex] = useState(0);
  const [loading, setLoading] = useState(true);

  // Typography state
  const [theme, setTheme] = useState<ReaderTheme>("light");
  const [font, setFont] = useState<ReaderFont>("serif");
  const [size, setSize] = useState<ReaderSize>("md");
  const [showSettings, setShowSettings] = useState(false);
  const [showToc, setShowToc] = useState(false);

  // Live Margin Notes & Highlights
  const [highlights, setHighlights] = useState<UserHighlight[]>([]);
  const [showNotesDrawer, setShowNotesDrawer] = useState(false);
  const [selectionToolbar, setSelectionToolbar] = useState<{
    text: string;
    x: number;
    y: number;
  } | null>(null);
  const [selectedColor, setSelectedColor] = useState<HighlightColor>("yellow");
  const [newNote, setNewNote] = useState("");
  const [showNoteInput, setShowNoteInput] = useState(false);

  const readingAreaRef = useRef<HTMLDivElement>(null);
  const { playTrack, currentTrack, isPlaying, togglePlay } = useAudio();

  const fetchHighlights = useCallback(async () => {
    try {
      const data = await api.getHighlights(slug);
      setHighlights(data);
    } catch (_) {}
  }, [slug]);

  useEffect(() => {
    async function fetchBook() {
      try {
        const data = await api.getBookBySlug(slug);
        setBook(data);
        await fetchHighlights();
      } catch (e) {
        console.error("Failed to load book in reader", e);
      } finally {
        setLoading(false);
      }
    }
    fetchBook();

    const handleFocus = () => fetchHighlights();
    window.addEventListener("focus", handleFocus);
    return () => window.removeEventListener("focus", handleFocus);
  }, [slug, fetchHighlights]);

  // Handle Text Selection for Highlighting
  const handleMouseUp = () => {
    const selection = window.getSelection();
    if (!selection || selection.isCollapsed) {
      setSelectionToolbar(null);
      return;
    }

    const text = selection.toString().trim();
    if (text.length < 4) {
      setSelectionToolbar(null);
      return;
    }

    const range = selection.getRangeAt(0);
    const rect = range.getBoundingClientRect();

    setSelectionToolbar({
      text,
      x: Math.max(10, rect.left + rect.width / 2 - 120),
      y: Math.max(10, rect.top - 55),
    });
  };

  const handleSaveHighlight = async () => {
    if (!selectionToolbar || !book) return;

    const currentSec = book.sections?.[currentSectionIndex];
    const created = await api.createHighlight({
      book_id: book.id,
      book_slug: book.slug,
      section_id: currentSec?.id,
      selected_text: selectionToolbar.text,
      color: selectedColor,
      note: newNote.trim(),
    });

    setHighlights((prev) => [created, ...prev]);
    setSelectionToolbar(null);
    setNewNote("");
    setShowNoteInput(false);
    window.getSelection()?.removeAllRanges();
  };

  const handleDeleteHighlight = async (id: number) => {
    await api.deleteHighlight(id, slug);
    setHighlights((prev) => prev.filter((h) => h.id !== id));
  };

  if (loading) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-20 animate-pulse space-y-6">
        <div className="h-6 w-48 bg-gray-200 dark:bg-gray-800 rounded-md" />
        <div className="h-10 w-3/4 bg-gray-200 dark:bg-gray-800 rounded-lg" />
        <div className="space-y-3 pt-6">
          <div className="h-4 bg-gray-200 dark:bg-gray-800 rounded-md" />
          <div className="h-4 bg-gray-200 dark:bg-gray-800 rounded-md" />
          <div className="h-4 w-5/6 bg-gray-200 dark:bg-gray-800 rounded-md" />
        </div>
      </div>
    );
  }

  if (!book || !book.sections || book.sections.length === 0) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-20 text-center">
        <BookOpen className="w-16 h-16 mx-auto text-gray-400 mb-4" />
        <h1 className="text-xl font-bold text-gray-900 dark:text-white mb-2">
          Summary Content Unavailable
        </h1>
        <p className="text-xs text-gray-500 mb-6">
          The summary blinks could not be loaded.
        </p>
        <Link
          href={`/book/${slug}`}
          className="px-6 py-2.5 rounded-full bg-emerald-500 text-white font-semibold text-xs"
        >
          Return to Book Detail
        </Link>
      </div>
    );
  }

  const sections: SummarySection[] = book.sections;
  const currentSection: SummarySection = sections[currentSectionIndex];
  const totalSections = sections.length;
  const progressPercent = ((currentSectionIndex + 1) / totalSections) * 100;

  const isCurrentBlinkAudioPlaying =
    currentTrack?.bookSlug === book.slug &&
    currentTrack?.sectionIndex === currentSectionIndex &&
    isPlaying;

  const handlePlayCurrentAudio = () => {
    if (
      currentTrack?.bookSlug === book.slug &&
      currentTrack?.sectionIndex === currentSectionIndex
    ) {
      togglePlay();
      return;
    }
    playTrack({
      id: currentSection.id,
      bookId: book.id,
      bookSlug: book.slug,
      bookTitle: book.title,
      authorName: book.author.name,
      coverUrl: book.cover_image_url,
      sectionTitle: currentSection.title,
      sectionIndex: currentSectionIndex,
      totalSections,
      audioUrl:
        currentSection.audio_url ||
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
      durationSeconds: currentSection.duration_seconds || 600,
    });
  };

  const getFontSizeClass = () => {
    switch (size) {
      case "sm":
        return "text-base leading-relaxed";
      case "lg":
        return "text-xl leading-loose";
      case "xl":
        return "text-2xl leading-loose";
      case "md":
      default:
        return "text-lg leading-relaxed";
    }
  };

  const getThemeClass = () => {
    switch (theme) {
      case "sepia":
        return "reader-theme-sepia";
      case "dark":
        return "reader-theme-dark";
      case "light":
      default:
        return "reader-theme-light";
    }
  };

  const getColorBgClass = (color: HighlightColor) => {
    switch (color) {
      case "green":
        return "bg-emerald-200/60 dark:bg-emerald-900/40 text-emerald-950 dark:text-emerald-100";
      case "blue":
        return "bg-sky-200/60 dark:bg-sky-900/40 text-sky-950 dark:text-sky-100";
      case "pink":
        return "bg-pink-200/60 dark:bg-pink-900/40 text-pink-950 dark:text-pink-100";
      case "yellow":
      default:
        return "bg-amber-200/60 dark:bg-amber-900/40 text-amber-950 dark:text-amber-100";
    }
  };

  return (
    <div className={`min-h-screen transition-colors duration-300 ${getThemeClass()}`}>
      {/* Top Reading Progress Bar */}
      <div className="fixed top-0 left-0 right-0 z-50 h-1 bg-gray-200/50">
        <div
          className="h-full bg-emerald-500 transition-all duration-300"
          style={{ width: `${progressPercent}%` }}
        />
      </div>

      {/* Reader Navigation Header */}
      <header className="sticky top-0 z-40 border-b border-black/5 backdrop-blur-md px-4 sm:px-6 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Link
            href={`/book/${book.slug}`}
            className="p-2 rounded-full hover:bg-black/5 transition-colors"
            title="Exit Reader"
            aria-label="Back to book details"
          >
            <ArrowLeft className="w-5 h-5" />
          </Link>
          <div className="min-w-0">
            <h2 className="text-xs font-semibold uppercase tracking-wider opacity-70 truncate max-w-[180px] sm:max-w-sm">
              {book.title}
            </h2>
            <p className="text-xs font-medium opacity-90 truncate">
              Blink {currentSectionIndex + 1} of {totalSections}
            </p>
          </div>
        </div>

        {/* Action Controls: Audio, Notes, TOC, Typography Settings */}
        <div className="flex items-center gap-2">
          {/* Audio Play */}
          <button
            onClick={handlePlayCurrentAudio}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-emerald-500 hover:bg-emerald-600 text-white text-xs font-semibold shadow-xs transition-colors"
            title={isCurrentBlinkAudioPlaying ? "Pause Audio" : "Listen to Blink"}
          >
            <Headphones className={`w-3.5 h-3.5 ${isCurrentBlinkAudioPlaying ? "animate-pulse" : ""}`} />
            <span className="hidden sm:inline">
              {isCurrentBlinkAudioPlaying ? "Pause" : "Listen"}
            </span>
          </button>

          {/* Notes & Highlights Drawer Toggle */}
          <button
            onClick={() => setShowNotesDrawer(!showNotesDrawer)}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-full hover:bg-black/5 text-xs font-medium transition-colors relative"
            title="Margin Notes & Quotes"
            aria-label="Margin notes and highlights"
          >
            <Highlighter className="w-4 h-4 text-amber-500" />
            <span className="text-xs font-bold">{highlights.length}</span>
          </button>

          {/* Table of Contents Drawer Toggle */}
          <button
            onClick={() => setShowToc(!showToc)}
            className="p-2 rounded-full hover:bg-black/5 transition-colors relative"
            title="Table of Contents"
            aria-label="Table of Contents"
          >
            <List className="w-4 h-4" />
          </button>

          {/* Typography Settings Toggle */}
          <button
            onClick={() => setShowSettings(!showSettings)}
            className="p-2 rounded-full hover:bg-black/5 transition-colors relative"
            title="Reading Settings"
            aria-label="Typography settings"
          >
            <Settings className="w-4 h-4" />
          </button>
        </div>
      </header>

      {/* Floating Selection Tooltip for Highlighting */}
      {selectionToolbar && (
        <div
          className="fixed z-50 bg-gray-900 text-white rounded-2xl shadow-2xl p-2 flex flex-col gap-2 border border-gray-700 animate-in fade-in zoom-in-95 duration-150"
          style={{ top: `${selectionToolbar.y}px`, left: `${selectionToolbar.x}px` }}
        >
          <div className="flex items-center gap-1.5">
            {/* Color buttons */}
            {(["yellow", "green", "blue", "pink"] as HighlightColor[]).map((c) => (
              <button
                key={c}
                onClick={() => setSelectedColor(c)}
                className={`w-6 h-6 rounded-full transition-transform ${
                  selectedColor === c ? "scale-125 ring-2 ring-white" : "opacity-80 hover:opacity-100"
                } ${
                  c === "yellow"
                    ? "bg-amber-400"
                    : c === "green"
                    ? "bg-emerald-400"
                    : c === "blue"
                    ? "bg-sky-400"
                    : "bg-pink-400"
                }`}
                title={`Highlight in ${c}`}
              />
            ))}

            <div className="h-4 w-px bg-gray-700 mx-1" />

            <button
              onClick={() => setShowNoteInput(!showNoteInput)}
              className="p-1 rounded-md hover:bg-gray-800 text-gray-300 hover:text-white"
              title="Add margin note"
            >
              <MessageSquare className="w-4 h-4" />
            </button>

            <button
              onClick={handleSaveHighlight}
              className="px-2.5 py-1 rounded-lg bg-emerald-500 hover:bg-emerald-600 text-white font-bold text-xs"
            >
              Save
            </button>
          </div>

          {showNoteInput && (
            <input
              type="text"
              placeholder="Add your margin thought..."
              value={newNote}
              onChange={(e) => setNewNote(e.target.value)}
              className="px-2 py-1 text-xs rounded-lg bg-gray-800 border border-gray-700 text-white outline-hidden placeholder:text-gray-400"
              autoFocus
            />
          )}
        </div>
      )}

      {/* Margin Notes & Highlights Drawer */}
      {showNotesDrawer && (
        <div className="fixed inset-0 z-50 flex justify-end">
          <div
            className="fixed inset-0 bg-black/40 backdrop-blur-xs"
            onClick={() => setShowNotesDrawer(false)}
          />
          <div className="relative w-88 max-w-full bg-white dark:bg-gray-800 h-full p-6 shadow-2xl flex flex-col justify-between z-10 animate-in slide-in-from-right duration-300">
            <div>
              <div className="flex items-center justify-between pb-4 border-b border-gray-100 dark:border-gray-700 mb-4">
                <div className="flex items-center gap-2">
                  <Highlighter className="w-5 h-5 text-amber-500" />
                  <h3 className="font-bold text-base text-gray-900 dark:text-white">
                    Notes & Highlights ({highlights.length})
                  </h3>
                </div>
                <button onClick={() => setShowNotesDrawer(false)}>
                  <X className="w-5 h-5 text-gray-400" />
                </button>
              </div>

              {highlights.length === 0 ? (
                <div className="text-center py-16 text-gray-400 space-y-2">
                  <Highlighter className="w-8 h-8 mx-auto opacity-50" />
                  <p className="text-xs">Select any text in the reader to highlight quotes or write margin notes.</p>
                </div>
              ) : (
                <div className="space-y-3 overflow-y-auto max-h-[75vh] pr-1">
                  {highlights.map((h) => (
                    <div
                      key={h.id}
                      className={`p-3.5 rounded-2xl border border-gray-200 dark:border-gray-700/60 relative group ${getColorBgClass(
                        h.color
                      )}`}
                    >
                      <button
                        onClick={() => handleDeleteHighlight(h.id)}
                        className="absolute top-2.5 right-2.5 p-1 rounded-md opacity-0 group-hover:opacity-100 hover:bg-black/10 transition-opacity"
                        title="Delete highlight"
                      >
                        <Trash2 className="w-3.5 h-3.5 text-rose-500" />
                      </button>

                      <p className="text-xs font-medium italic line-clamp-3">
                        &ldquo;{h.selected_text}&rdquo;
                      </p>

                      {h.note && (
                        <div className="mt-2 pt-2 border-t border-black/10 flex items-start gap-1.5 text-xs font-semibold">
                          <MessageSquare className="w-3.5 h-3.5 shrink-0 mt-0.5" />
                          <span>{h.note}</span>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="pt-4 border-t border-gray-100 dark:border-gray-700 text-xs text-gray-400 flex items-center justify-between">
              <span>⚡ Live sync across Web & Mobile</span>
            </div>
          </div>
        </div>
      )}

      {/* Typography Settings Modal / Dropdown */}
      {showSettings && (
        <div className="fixed top-14 right-4 z-50 w-72 rounded-2xl bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-2xl p-4 text-xs space-y-4 animate-in fade-in zoom-in-95 text-gray-900 dark:text-white">
          <div className="flex items-center justify-between border-b border-gray-100 dark:border-gray-700 pb-2">
            <span className="font-bold">Typography & Themes</span>
            <button onClick={() => setShowSettings(false)}>
              <X className="w-4 h-4 text-gray-400" />
            </button>
          </div>

          {/* Themes */}
          <div>
            <span className="block font-semibold mb-2 text-gray-500">Theme</span>
            <div className="grid grid-cols-3 gap-2">
              <button
                onClick={() => setTheme("light")}
                className={`py-2 rounded-xl border text-center font-medium transition-all ${
                  theme === "light"
                    ? "border-emerald-500 ring-2 ring-emerald-500/20 bg-white text-gray-900"
                    : "border-gray-200 bg-white text-gray-700"
                }`}
              >
                Light
              </button>
              <button
                onClick={() => setTheme("sepia")}
                className={`py-2 rounded-xl border text-center font-medium transition-all ${
                  theme === "sepia"
                    ? "border-emerald-500 ring-2 ring-emerald-500/20 bg-[#fbf0d9] text-[#3b2e2a]"
                    : "border-amber-200 bg-[#fbf0d9] text-[#3b2e2a]"
                }`}
              >
                Sepia
              </button>
              <button
                onClick={() => setTheme("dark")}
                className={`py-2 rounded-xl border text-center font-medium transition-all ${
                  theme === "dark"
                    ? "border-emerald-500 ring-2 ring-emerald-500/20 bg-gray-900 text-white"
                    : "border-gray-700 bg-gray-900 text-gray-300"
                }`}
              >
                Dark
              </button>
            </div>
          </div>

          {/* Font Family */}
          <div>
            <span className="block font-semibold mb-2 text-gray-500">Font Family</span>
            <div className="grid grid-cols-2 gap-2">
              <button
                onClick={() => setFont("serif")}
                className={`py-2 rounded-xl border font-serif text-sm transition-all ${
                  font === "serif"
                    ? "border-emerald-500 bg-emerald-50 dark:bg-emerald-950/40 text-emerald-600 font-bold"
                    : "border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700"
                }`}
              >
                Serif (Book)
              </button>
              <button
                onClick={() => setFont("sans")}
                className={`py-2 rounded-xl border font-sans text-sm transition-all ${
                  font === "sans"
                    ? "border-emerald-500 bg-emerald-50 dark:bg-emerald-950/40 text-emerald-600 font-bold"
                    : "border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700"
                }`}
              >
                Sans-Serif
              </button>
            </div>
          </div>

          {/* Font Size */}
          <div>
            <span className="block font-semibold mb-2 text-gray-500">Font Size</span>
            <div className="flex items-center justify-between bg-gray-100 dark:bg-gray-700/60 p-1 rounded-xl">
              {(["sm", "md", "lg", "xl"] as ReaderSize[]).map((s) => (
                <button
                  key={s}
                  onClick={() => setSize(s)}
                  className={`flex-1 py-1.5 rounded-lg font-bold text-center uppercase transition-all ${
                    size === s
                      ? "bg-white dark:bg-gray-800 text-emerald-600 shadow-xs"
                      : "text-gray-500 hover:text-gray-900 dark:hover:text-white"
                  }`}
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Table of Contents Drawer */}
      {showToc && (
        <div className="fixed inset-0 z-50 flex">
          <div
            className="fixed inset-0 bg-black/40 backdrop-blur-xs"
            onClick={() => setShowToc(false)}
          />
          <div className="relative w-80 max-w-full bg-white dark:bg-gray-800 h-full p-6 shadow-2xl flex flex-col justify-between z-10 animate-in slide-in-from-left duration-300">
            <div>
              <div className="flex items-center justify-between pb-4 border-b border-gray-100 dark:border-gray-700 mb-4">
                <h3 className="font-bold text-base text-gray-900 dark:text-white">
                  Table of Contents
                </h3>
                <button onClick={() => setShowToc(false)}>
                  <X className="w-5 h-5 text-gray-400" />
                </button>
              </div>

              <div className="space-y-2 overflow-y-auto max-h-[70vh]">
                {sections.map((sec, idx) => (
                  <button
                    key={sec.id}
                    onClick={() => {
                      setCurrentSectionIndex(idx);
                      setShowToc(false);
                      window.scrollTo({ top: 0, behavior: "smooth" });
                    }}
                    className={`w-full text-left p-3 rounded-xl flex items-start gap-3 transition-colors ${
                      idx === currentSectionIndex
                        ? "bg-emerald-50 dark:bg-emerald-950/40 text-emerald-600 dark:text-emerald-400 font-bold"
                        : "hover:bg-gray-50 dark:hover:bg-gray-700/50 text-gray-700 dark:text-gray-300"
                    }`}
                  >
                    <span className="w-5 h-5 rounded-full bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300 text-[11px] font-semibold flex items-center justify-center shrink-0 mt-0.5">
                      {idx + 1}
                    </span>
                    <span className="text-xs leading-snug line-clamp-2">
                      {sec.title}
                    </span>
                  </button>
                ))}
              </div>
            </div>

            <div className="pt-4 border-t border-gray-100 dark:border-gray-700 text-xs text-gray-500">
              {totalSections} blinks total • ~{book.estimated_read_time_minutes} minutes
            </div>
          </div>
        </div>
      )}

      {/* Main Reading Canvas */}
      <main
        ref={readingAreaRef}
        onMouseUp={handleMouseUp}
        className="max-w-2xl mx-auto px-4 sm:px-6 py-12 md:py-16 select-text"
      >
        {/* Blink Title Header */}
        <div className="mb-8 space-y-2">
          <span className="text-xs font-bold uppercase tracking-wider text-emerald-600 dark:text-emerald-400">
            Key Idea {currentSectionIndex + 1} of {totalSections}
          </span>
          <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight">
            {currentSection.title}
          </h1>
        </div>

        {/* Blink Content */}
        <div
          className={`${font === "serif" ? "font-reader-serif" : "font-reader-sans"} ${getFontSizeClass()} space-y-6 opacity-95`}
        >
          {currentSection.content ? (
            currentSection.content.split("\n\n").map((para, i) => (
              <p key={i} className="leading-relaxed">
                {para}
              </p>
            ))
          ) : (
            <p className="leading-relaxed">
              In this chapter, the core takeaway centers around behavioral psychology and continuous improvement. Developing positive micro-habits enables compounding growth over time.
            </p>
          )}
        </div>

        {/* Bottom Blink Pagination & Complete Book Actions */}
        <div className="mt-16 pt-8 border-t border-black/10 flex items-center justify-between gap-4">
          <button
            onClick={() => {
              if (currentSectionIndex > 0) {
                setCurrentSectionIndex(currentSectionIndex - 1);
                window.scrollTo({ top: 0, behavior: "smooth" });
              }
            }}
            disabled={currentSectionIndex === 0}
            className={`flex items-center gap-2 px-5 py-2.5 rounded-full text-xs font-semibold transition-all ${
              currentSectionIndex === 0
                ? "opacity-30 cursor-not-allowed"
                : "hover:bg-black/5"
            }`}
          >
            <ChevronLeft className="w-4 h-4" />
            Previous Blink
          </button>

          {currentSectionIndex < totalSections - 1 ? (
            <button
              onClick={() => {
                setCurrentSectionIndex(currentSectionIndex + 1);
                window.scrollTo({ top: 0, behavior: "smooth" });
              }}
              className="flex items-center gap-2 px-6 py-2.5 rounded-full bg-emerald-500 hover:bg-emerald-600 text-white text-xs font-bold shadow-md shadow-emerald-500/20 active:scale-95 transition-all"
            >
              Next Blink
              <ChevronRight className="w-4 h-4" />
            </button>
          ) : (
            <Link
              href={`/book/${book.slug}`}
              className="flex items-center gap-2 px-6 py-2.5 rounded-full bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-md transition-all"
            >
              <CheckCircle className="w-4 h-4" />
              Finish Summary
            </Link>
          )}
        </div>
      </main>
    </div>
  );
}

export default function ReaderPage(props: {
  params: Promise<{ slug: string }>;
}) {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center text-sm text-gray-500">
          Loading reader...
        </div>
      }
    >
      <ReaderContent {...props} />
    </Suspense>
  );
}
