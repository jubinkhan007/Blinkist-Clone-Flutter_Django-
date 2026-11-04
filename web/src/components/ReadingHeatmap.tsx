"use client";

import React, { useState } from "react";
import { HeatmapDay } from "@/types";
import { Flame, Calendar, Clock, BookOpen, Headphones } from "lucide-react";

interface ReadingHeatmapProps {
  days: HeatmapDay[];
  currentStreak: number;
  longestStreak: number;
  totalMinutes: number;
}

export function ReadingHeatmap({
  days,
  currentStreak,
  longestStreak,
  totalMinutes,
}: ReadingHeatmapProps) {
  const [hoveredDay, setHoveredDay] = useState<HeatmapDay | null>(null);
  const [filterMode, setFilterMode] = useState<"all" | "reading" | "audio">("all");

  // Organize days into columns of 7 (Monday = index 0 .. Sunday = index 6)
  // Ensure we group days into weeks
  const weeks: HeatmapDay[][] = [];
  let currentWeek: HeatmapDay[] = [];

  // Pad beginning if first day is not Monday
  if (days.length > 0) {
    const firstDayOfWeek = days[0].day_of_week; // 0 = Mon
    for (let i = 0; i < firstDayOfWeek; i++) {
      currentWeek.push({
        date: "",
        day_of_week: i,
        reading_minutes: 0,
        audio_minutes: 0,
        total_minutes: 0,
        books_completed: 0,
        intensity: 0,
        is_active: false,
      });
    }
  }

  days.forEach((day) => {
    currentWeek.push(day);
    if (currentWeek.length === 7) {
      weeks.push(currentWeek);
      currentWeek = [];
    }
  });

  if (currentWeek.length > 0) {
    while (currentWeek.length < 7) {
      currentWeek.push({
        date: "",
        day_of_week: currentWeek.length,
        reading_minutes: 0,
        audio_minutes: 0,
        total_minutes: 0,
        books_completed: 0,
        intensity: 0,
        is_active: false,
      });
    }
    weeks.push(currentWeek);
  }

  const getIntensityClass = (intensity: number) => {
    switch (intensity) {
      case 1:
        return "bg-emerald-200 dark:bg-emerald-900/60 hover:ring-2 hover:ring-emerald-400";
      case 2:
        return "bg-emerald-400 dark:bg-emerald-700 hover:ring-2 hover:ring-emerald-300";
      case 3:
        return "bg-emerald-500 dark:bg-emerald-600 hover:ring-2 hover:ring-emerald-300";
      case 4:
        return "bg-emerald-600 dark:bg-emerald-500 hover:ring-2 hover:ring-emerald-200 shadow-sm";
      default:
        return "bg-gray-100 dark:bg-gray-800/80 hover:bg-gray-200 dark:hover:bg-gray-700";
    }
  };

  const getDayIntensity = (day: HeatmapDay) => {
    if (!day.date) return 0;
    if (filterMode === "reading") {
      if (day.reading_minutes === 0) return 0;
      if (day.reading_minutes <= 5) return 1;
      if (day.reading_minutes <= 15) return 2;
      if (day.reading_minutes <= 30) return 3;
      return 4;
    }
    if (filterMode === "audio") {
      if (day.audio_minutes === 0) return 0;
      if (day.audio_minutes <= 10) return 1;
      if (day.audio_minutes <= 20) return 2;
      if (day.audio_minutes <= 35) return 3;
      return 4;
    }
    return day.intensity;
  };

  const activeDaysCount = days.filter((d) => d.is_active).length;

  return (
    <div className="bg-white dark:bg-gray-900 rounded-3xl p-6 sm:p-8 border border-gray-200 dark:border-gray-800 shadow-sm transition-all">
      {/* Header with Stats & Filter Pills */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div>
          <div className="flex items-center gap-2">
            <Calendar className="w-5 h-5 text-emerald-500" />
            <h3 className="text-xl font-bold text-gray-900 dark:text-white">
              Reading & Listening Activity
            </h3>
          </div>
          <p className="text-xs sm:text-sm text-gray-500 dark:text-gray-400 mt-1">
            {activeDaysCount} active days in the last year • {Math.round(totalMinutes / 60)} total hours
          </p>
        </div>

        {/* Filter Toggle */}
        <div className="flex items-center gap-1.5 p-1 bg-gray-100 dark:bg-gray-800 rounded-xl text-xs font-semibold">
          <button
            onClick={() => setFilterMode("all")}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              filterMode === "all"
                ? "bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm font-bold"
                : "text-gray-500 hover:text-gray-900 dark:hover:text-white"
            }`}
          >
            All Activity
          </button>
          <button
            onClick={() => setFilterMode("reading")}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-all ${
              filterMode === "reading"
                ? "bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm font-bold"
                : "text-gray-500 hover:text-gray-900 dark:hover:text-white"
            }`}
          >
            <BookOpen className="w-3.5 h-3.5" />
            Reading
          </button>
          <button
            onClick={() => setFilterMode("audio")}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-all ${
              filterMode === "audio"
                ? "bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm font-bold"
                : "text-gray-500 hover:text-gray-900 dark:hover:text-white"
            }`}
          >
            <Headphones className="w-3.5 h-3.5" />
            Audio
          </button>
        </div>
      </div>

      {/* Heatmap Grid */}
      <div className="overflow-x-auto pb-4 scrollbar-thin">
        <div className="inline-flex flex-col gap-1.5 min-w-[720px]">
          {/* Days of week labels + Grid Columns */}
          <div className="flex gap-1.5">
            {/* Weekday indicators */}
            <div className="flex flex-col justify-between py-1 text-[10px] font-semibold text-gray-400 select-none pr-2 h-[120px]">
              <span>Mon</span>
              <span>Wed</span>
              <span>Fri</span>
              <span>Sun</span>
            </div>

            {/* Weeks columns */}
            <div className="flex gap-1.5">
              {weeks.map((week, wIndex) => (
                <div key={wIndex} className="flex flex-col gap-1.5">
                  {week.map((day, dIndex) => {
                    const intensity = getDayIntensity(day);
                    const isBlank = !day.date;

                    return (
                      <div
                        key={dIndex}
                        onMouseEnter={() => !isBlank && setHoveredDay(day)}
                        onMouseLeave={() => setHoveredDay(null)}
                        className={`w-3.5 h-3.5 rounded-sm transition-all cursor-pointer ${
                          isBlank
                            ? "opacity-0 pointer-events-none"
                            : getIntensityClass(intensity)
                        }`}
                      />
                    );
                  })}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Footer / Tooltip & Legend */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 pt-4 border-t border-gray-100 dark:border-gray-800 text-xs text-gray-500 dark:text-gray-400">
        {/* Dynamic Tooltip */}
        <div className="h-6 flex items-center gap-2">
          {hoveredDay ? (
            <div className="flex items-center gap-2 text-gray-900 dark:text-white font-medium animate-in fade-in duration-150">
              <span className="font-bold text-emerald-600 dark:text-emerald-400">
                {hoveredDay.date}:
              </span>
              <span>
                {hoveredDay.total_minutes} mins (
                {hoveredDay.reading_minutes}m read, {hoveredDay.audio_minutes}m audio)
              </span>
              {hoveredDay.books_completed > 0 && (
                <span className="px-2 py-0.5 rounded-full bg-emerald-100 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-300 font-bold text-[10px]">
                  🏆 {hoveredDay.books_completed} completed
                </span>
              )}
            </div>
          ) : (
            <span className="italic">Hover over any day to see activity details</span>
          )}
        </div>

        {/* Intensity Legend */}
        <div className="flex items-center gap-2 self-end sm:self-auto">
          <span className="text-[11px]">Less</span>
          <div className="flex gap-1 items-center">
            <div className="w-3 h-3 rounded-sm bg-gray-100 dark:bg-gray-800" />
            <div className="w-3 h-3 rounded-sm bg-emerald-200 dark:bg-emerald-900/60" />
            <div className="w-3 h-3 rounded-sm bg-emerald-400 dark:bg-emerald-700" />
            <div className="w-3 h-3 rounded-sm bg-emerald-500 dark:bg-emerald-600" />
            <div className="w-3 h-3 rounded-sm bg-emerald-600 dark:bg-emerald-500" />
          </div>
          <span className="text-[11px]">More</span>
        </div>
      </div>
    </div>
  );
}
