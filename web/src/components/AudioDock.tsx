"use client";

import React, { useState } from "react";
import Link from "next/link";
import {
  Play,
  Pause,
  RotateCcw,
  RotateCw,
  Volume2,
  VolumeX,
  X,
  BookOpen,
} from "lucide-react";
import { useAudio } from "@/context/AudioContext";

const formatTime = (seconds: number): string => {
  if (isNaN(seconds) || seconds < 0) return "0:00";
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs < 10 ? "0" : ""}${secs}`;
};

export const AudioDock: React.FC = () => {
  const {
    currentTrack,
    isPlaying,
    currentTime,
    duration,
    playbackRate,
    volume,
    togglePlay,
    seek,
    skip,
    setPlaybackRate,
    setVolume,
    closePlayer,
  } = useAudio();

  const [showSpeedMenu, setShowSpeedMenu] = useState(false);
  const [prevVolume, setPrevVolume] = useState(1);

  if (!currentTrack) return null;

  const toggleMute = () => {
    if (volume > 0) {
      setPrevVolume(volume);
      setVolume(0);
    } else {
      setVolume(prevVolume || 1);
    }
  };

  const progressPercent = duration > 0 ? (currentTime / duration) * 100 : 0;

  return (
    <aside
      aria-label="Audio player dock"
      className="fixed bottom-0 left-0 right-0 z-50 bg-white/95 dark:bg-gray-900/95 border-t border-gray-200 dark:border-gray-800 shadow-2xl backdrop-blur-lg px-4 sm:px-6 py-2.5 transition-all animate-in slide-in-from-bottom duration-300"
    >
      <div className="max-w-7xl mx-auto flex flex-col gap-1.5">
        {/* Scrubber Bar */}
        <div className="w-full flex items-center gap-3 text-[11px] font-mono text-gray-500 dark:text-gray-400">
          <span>{formatTime(currentTime)}</span>
          <div className="relative flex-1 group py-1 flex items-center">
            <input
              type="range"
              min={0}
              max={duration || 100}
              step={0.5}
              value={currentTime}
              onChange={(e) => seek(parseFloat(e.target.value))}
              className="w-full h-1.5 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-emerald-500 hover:h-2 transition-all"
              style={{
                background: `linear-gradient(to right, #10b981 ${progressPercent}%, rgba(156, 163, 175, 0.3) ${progressPercent}%)`,
              }}
              aria-label="Audio progress slider"
            />
          </div>
          <span>{formatTime(duration)}</span>
        </div>

        {/* Main Dock Controls */}
        <div className="flex items-center justify-between gap-4">
          {/* Left: Track Info */}
          <div className="flex items-center gap-3 min-w-0 max-w-[280px] sm:max-w-xs md:max-w-sm">
            <div className="relative w-11 h-11 shrink-0 rounded-lg overflow-hidden bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-xs">
              {currentTrack.coverUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={currentTrack.coverUrl}
                  alt={currentTrack.bookTitle}
                  className="w-full h-full object-cover"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-emerald-600 bg-emerald-50 dark:bg-emerald-950/40">
                  <BookOpen className="w-5 h-5" />
                </div>
              )}
            </div>

            <div className="min-w-0">
              <Link
                href={`/book/${currentTrack.bookSlug}`}
                className="block text-sm font-semibold text-gray-900 dark:text-white truncate hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
              >
                {currentTrack.bookTitle}
              </Link>
              <p className="text-xs text-gray-500 dark:text-gray-400 truncate">
                {currentTrack.sectionTitle} • <span className="font-medium">{currentTrack.authorName}</span>
              </p>
            </div>
          </div>

          {/* Center: Playback Controls */}
          <div className="flex items-center gap-2 sm:gap-4">
            {/* 15s Backward */}
            <button
              onClick={() => skip(-15)}
              className="p-2 text-gray-600 dark:text-gray-300 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 relative group"
              title="Skip backward 15 seconds"
              aria-label="Skip backward 15 seconds"
            >
              <RotateCcw className="w-4 h-4 sm:w-5 sm:h-5" />
              <span className="text-[9px] font-bold absolute bottom-1 right-1 text-gray-500 dark:text-gray-400 group-hover:text-emerald-600">
                15
              </span>
            </button>

            {/* Play/Pause */}
            <button
              onClick={togglePlay}
              className="w-11 h-11 rounded-full bg-emerald-500 hover:bg-emerald-600 text-white flex items-center justify-center shadow-lg shadow-emerald-500/25 hover:scale-105 active:scale-95 transition-all"
              aria-label={isPlaying ? "Pause audio" : "Play audio"}
            >
              {isPlaying ? (
                <Pause className="w-5 h-5 fill-current" />
              ) : (
                <Play className="w-5 h-5 fill-current ml-0.5" />
              )}
            </button>

            {/* 15s Forward */}
            <button
              onClick={() => skip(15)}
              className="p-2 text-gray-600 dark:text-gray-300 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 relative group"
              title="Skip forward 15 seconds"
              aria-label="Skip forward 15 seconds"
            >
              <RotateCw className="w-4 h-4 sm:w-5 sm:h-5" />
              <span className="text-[9px] font-bold absolute bottom-1 left-1 text-gray-500 dark:text-gray-400 group-hover:text-emerald-600">
                15
              </span>
            </button>
          </div>

          {/* Right: Rate, Volume & Close */}
          <div className="flex items-center gap-2 sm:gap-4">
            {/* Speed Rate Menu */}
            <div className="relative">
              <button
                onClick={() => setShowSpeedMenu(!showSpeedMenu)}
                className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
                title="Playback speed"
                aria-label="Playback speed"
              >
                {playbackRate}x
              </button>

              {showSpeedMenu && (
                <div className="absolute bottom-full mb-2 right-0 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl shadow-xl py-1 text-xs z-50">
                  {[0.75, 1, 1.25, 1.5, 2].map((rate) => (
                    <button
                      key={rate}
                      onClick={() => {
                        setPlaybackRate(rate);
                        setShowSpeedMenu(false);
                      }}
                      className={`block w-full px-4 py-1.5 text-left transition-colors ${
                        playbackRate === rate
                          ? "bg-emerald-50 dark:bg-emerald-950/40 text-emerald-600 font-bold"
                          : "text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
                      }`}
                    >
                      {rate}x
                    </button>
                  ))}
                </div>
              )}
            </div>

            {/* Volume Control */}
            <div className="hidden md:flex items-center gap-2">
              <button
                onClick={toggleMute}
                className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
                aria-label={volume === 0 ? "Unmute" : "Mute"}
              >
                {volume === 0 ? (
                  <VolumeX className="w-4 h-4 text-rose-500" />
                ) : (
                  <Volume2 className="w-4 h-4" />
                )}
              </button>
              <input
                type="range"
                min={0}
                max={1}
                step={0.05}
                value={volume}
                onChange={(e) => setVolume(parseFloat(e.target.value))}
                className="w-16 h-1.5 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-emerald-500"
                aria-label="Volume slider"
              />
            </div>

            {/* Close Button */}
            <button
              onClick={closePlayer}
              className="p-1.5 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              title="Close player"
              aria-label="Close audio player"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </aside>
  );
};
