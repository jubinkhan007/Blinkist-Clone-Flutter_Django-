"use client";

import React from "react";
import { Smartphone, Play, X, Headphones } from "lucide-react";
import { useAudio } from "@/context/AudioContext";

export const ContinueListeningBanner: React.FC = () => {
  const { handoffSession, resumeHandoff, dismissHandoff, currentTrack } = useAudio();

  if (!handoffSession || !handoffSession.can_resume) return null;

  return (
    <div
      role="region"
      aria-label="Continue listening cross-device prompt"
      className={`fixed left-4 sm:left-6 z-40 max-w-md w-[calc(100%-2rem)] sm:w-auto bg-gray-900/95 dark:bg-gray-800/95 text-white p-4 rounded-2xl shadow-2xl border border-gray-700/80 backdrop-blur-xl animate-in fade-in slide-in-from-bottom-4 duration-300 transition-all ${
        currentTrack ? "bottom-24" : "bottom-6"
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        {/* Device Icon & Details */}
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 flex items-center justify-center shrink-0">
            {handoffSession.device_type === "mobile" ? (
              <Smartphone className="w-5 h-5" />
            ) : (
              <Headphones className="w-5 h-5" />
            )}
          </div>

          <div className="min-w-0">
            <div className="flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider text-emerald-400">
              <span>Continue Listening</span>
              <span>•</span>
              <span className="text-gray-300 capitalize">{handoffSession.device_name || "Mobile App"}</span>
            </div>
            <h4 className="text-sm font-bold text-white truncate max-w-[220px] sm:max-w-[280px]">
              {handoffSession.book_title}
            </h4>
            <p className="text-xs text-gray-300 font-mono">
              Pick up at <span className="font-bold text-emerald-300">{handoffSession.formatted_position || "00:00"}</span>
            </p>
          </div>
        </div>

        {/* Dismiss Button */}
        <button
          onClick={dismissHandoff}
          className="text-gray-400 hover:text-white p-1 rounded-full transition-colors"
          title="Dismiss"
          aria-label="Dismiss continue listening prompt"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Action Row */}
      <div className="mt-3 pt-3 border-t border-gray-800 flex items-center justify-end gap-2">
        <button
          onClick={dismissHandoff}
          className="px-3 py-1.5 rounded-lg text-xs font-semibold text-gray-400 hover:text-white transition-colors"
        >
          Not Now
        </button>
        <button
          onClick={resumeHandoff}
          className="px-4 py-1.5 rounded-full bg-emerald-500 hover:bg-emerald-600 active:scale-95 text-white text-xs font-bold flex items-center gap-1.5 shadow-md shadow-emerald-500/20 transition-all"
        >
          <Play className="w-3.5 h-3.5 fill-current" />
          Resume from {handoffSession.formatted_position || "00:00"}
        </button>
      </div>
    </div>
  );
};
