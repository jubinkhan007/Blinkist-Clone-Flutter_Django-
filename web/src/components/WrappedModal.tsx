"use client";

import React, { useState } from "react";
import { LearningReport } from "@/types";
import {
  X,
  Sparkles,
  Zap,
  Clock,
  BookOpen,
  Headphones,
  Flame,
  Award,
  Share2,
  Check,
  Compass,
  Brain,
  Briefcase,
  ChevronRight,
} from "lucide-react";
import Image from "next/image";

interface WrappedModalProps {
  report: LearningReport;
  isOpen: boolean;
  onClose: () => void;
}

export function WrappedModal({ report, isOpen, onClose }: WrappedModalProps) {
  const [copied, setCopied] = useState(false);

  if (!isOpen) return null;

  const handleShare = () => {
    navigator.clipboard.writeText(report.shareable_text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2500);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6 overflow-y-auto bg-black/80 backdrop-blur-md animate-in fade-in duration-200">
      <div className="relative w-full max-w-2xl bg-gradient-to-br from-slate-900 via-emerald-950/60 to-slate-950 text-white rounded-3xl border border-emerald-500/30 shadow-2xl overflow-hidden my-auto max-h-[90vh] flex flex-col">
        {/* Glow Effects */}
        <div className="absolute top-0 right-0 w-96 h-96 bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute bottom-0 left-0 w-80 h-80 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none" />

        {/* Header Bar */}
        <div className="relative z-10 flex items-center justify-between px-6 py-5 border-b border-white/10">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-xl font-black tracking-tight text-white flex items-center gap-2">
                {report.period_label}
                <span className="px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 font-bold text-xs uppercase tracking-wider border border-emerald-500/30">
                  Wrapped
                </span>
              </h2>
              <p className="text-xs text-emerald-300/70 font-medium">Your personalized reading & learning recap</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-full bg-white/10 hover:bg-white/20 text-gray-300 hover:text-white transition-all"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Scrollable Body */}
        <div className="relative z-10 overflow-y-auto p-6 sm:p-8 space-y-8 scrollbar-thin">
          {/* 1. Learner Archetype Card */}
          <div className="relative p-6 sm:p-7 rounded-2xl bg-gradient-to-r from-emerald-900/50 to-indigo-950/50 border border-emerald-500/30 shadow-lg text-center overflow-hidden">
            <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-emerald-500/20 border border-emerald-400/40 text-emerald-300 mb-4 shadow-inner">
              <Brain className="w-8 h-8" />
            </div>
            <p className="text-xs uppercase font-extrabold tracking-widest text-emerald-400 mb-1">
              Your Learning Archetype
            </p>
            <h3 className="text-2xl sm:text-3xl font-black text-white tracking-tight mb-2">
              {report.learner_archetype}
            </h3>
            <p className="text-xs sm:text-sm text-gray-300 max-w-lg mx-auto leading-relaxed">
              {report.learner_archetype_description}
            </p>
          </div>

          {/* 2. Hero Time Saved Counter */}
          <div className="p-6 rounded-2xl bg-white/5 border border-white/10 text-center relative overflow-hidden">
            <div className="flex items-center justify-center gap-2 text-amber-400 mb-2">
              <Zap className="w-5 h-5 fill-amber-400" />
              <span className="text-xs font-bold uppercase tracking-wider">Supercharged Efficiency</span>
            </div>
            <div className="text-4xl sm:text-5xl font-black text-white tracking-tight">
              {report.time_saved_hours}{" "}
              <span className="text-emerald-400 text-2xl sm:text-3xl font-extrabold">Hours Saved</span>
            </div>
            <p className="text-xs sm:text-sm text-gray-300 mt-2 max-w-md mx-auto">
              By consuming key book insights instead of full 6-hour volumes, you reclaimed over{" "}
              <span className="text-emerald-300 font-bold">{report.time_saved_days} full days</span> of productive time!
            </p>
          </div>

          {/* 3. Core Metrics Grid */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3.5">
            <div className="p-4 rounded-xl bg-white/5 border border-white/10 text-center">
              <Clock className="w-5 h-5 text-emerald-400 mx-auto mb-1.5" />
              <div className="text-2xl font-black text-white">{report.total_hours}h</div>
              <div className="text-[11px] text-gray-400 font-medium">Time Learned</div>
            </div>

            <div className="p-4 rounded-xl bg-white/5 border border-white/10 text-center">
              <BookOpen className="w-5 h-5 text-indigo-400 mx-auto mb-1.5" />
              <div className="text-2xl font-black text-white">{report.books_completed_count}</div>
              <div className="text-[11px] text-gray-400 font-medium">Summaries Finished</div>
            </div>

            <div className="p-4 rounded-xl bg-white/5 border border-white/10 text-center">
              <Flame className="w-5 h-5 text-amber-400 mx-auto mb-1.5 fill-amber-400" />
              <div className="text-2xl font-black text-white">{report.longest_streak}d</div>
              <div className="text-[11px] text-gray-400 font-medium">Longest Streak</div>
            </div>

            <div className="p-4 rounded-xl bg-white/5 border border-white/10 text-center">
              <Award className="w-5 h-5 text-pink-400 mx-auto mb-1.5" />
              <div className="text-2xl font-black text-white">{report.key_ideas_retained}</div>
              <div className="text-[11px] text-gray-400 font-medium">Notes & Highlights</div>
            </div>
          </div>

          {/* 4. Audio vs. Reading Breakdown */}
          <div className="p-5 rounded-2xl bg-white/5 border border-white/10">
            <div className="flex items-center justify-between text-xs font-bold text-gray-300 mb-2.5">
              <span className="flex items-center gap-1.5 text-emerald-400">
                <Headphones className="w-4 h-4" /> Audio ({report.audio_percentage}%)
              </span>
              <span className="flex items-center gap-1.5 text-indigo-400">
                <BookOpen className="w-4 h-4" /> Text Reading ({report.reading_percentage}%)
              </span>
            </div>
            {/* Split Progress Bar */}
            <div className="w-full h-3 rounded-full bg-white/10 overflow-hidden flex">
              <div
                style={{ width: `${report.audio_percentage}%` }}
                className="bg-emerald-500 h-full transition-all duration-500"
              />
              <div
                style={{ width: `${report.reading_percentage}%` }}
                className="bg-indigo-500 h-full transition-all duration-500"
              />
            </div>
          </div>

          {/* 5. Top Categories */}
          {report.top_categories.length > 0 && (
            <div>
              <h4 className="text-xs uppercase font-extrabold tracking-wider text-gray-400 mb-3">
                Top Subject Domains
              </h4>
              <div className="space-y-2.5">
                {report.top_categories.map((cat, idx) => (
                  <div key={idx} className="flex items-center justify-between gap-3 p-2.5 rounded-xl bg-white/5 border border-white/5">
                    <div className="flex items-center gap-2.5 min-w-0">
                      <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: cat.color }} />
                      <span className="text-xs sm:text-sm font-semibold text-white truncate">{cat.name}</span>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                      <span className="text-xs font-bold text-gray-400">{cat.count} books</span>
                      <span className="px-2 py-0.5 rounded-md bg-white/10 text-xs font-extrabold text-emerald-400">
                        {cat.percentage}%
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 6. Top Book Spotlight */}
          {report.top_book && (
            <div className="p-4 sm:p-5 rounded-2xl bg-white/5 border border-white/10 flex items-center gap-4">
              {report.top_book.cover_image_url && (
                <div className="relative w-14 h-20 rounded-lg overflow-hidden shrink-0 shadow-md">
                  <Image
                    src={report.top_book.cover_image_url}
                    alt={report.top_book.title}
                    fill
                    className="object-cover"
                    sizes="56px"
                  />
                </div>
              )}
              <div className="min-w-0 flex-1">
                <span className="text-[10px] uppercase font-bold tracking-wider text-emerald-400">
                  Most Engaged Title
                </span>
                <h5 className="text-sm sm:text-base font-bold text-white truncate">
                  {report.top_book.title}
                </h5>
                <p className="text-xs text-gray-400 truncate">{report.top_book.author}</p>
                <div className="mt-1 text-[11px] text-emerald-300 font-semibold">
                  ✓ {report.top_book.sections_completed} key blinks mastered
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="relative z-10 px-6 py-4 border-t border-white/10 flex flex-col sm:flex-row items-center justify-between gap-3 bg-slate-950/80">
          <p className="text-xs text-gray-400 text-center sm:text-left">
            Keep up the habit! New summaries drop every day.
          </p>
          <button
            onClick={handleShare}
            className="w-full sm:w-auto px-6 py-2.5 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-gray-950 font-bold text-xs flex items-center justify-center gap-2 transition-all shadow-lg shadow-emerald-500/20 active:scale-95"
          >
            {copied ? (
              <>
                <Check className="w-4 h-4" />
                Copied to Clipboard!
              </>
            ) : (
              <>
                <Share2 className="w-4 h-4" />
                Share Your Wrapped
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
