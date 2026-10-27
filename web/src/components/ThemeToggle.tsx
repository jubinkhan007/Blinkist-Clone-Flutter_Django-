"use client";

import React, { useEffect, useState } from "react";
import { Sun, Moon, Laptop } from "lucide-react";

type ThemeMode = "system" | "light" | "dark";

export const ThemeToggle: React.FC = () => {
  const [theme, setTheme] = useState<ThemeMode>("system");

  useEffect(() => {
    try {
      const stored = localStorage.getItem("color-scheme") as ThemeMode | null;
      if (stored === "light" || stored === "dark") {
        setTheme(stored);
      } else {
        setTheme("system");
      }
    } catch (_) {}
  }, []);

  const handleSelect = (mode: ThemeMode) => {
    setTheme(mode);
    const meta = document.querySelector('meta[name="color-scheme"]');
    if (mode === "system") {
      try {
        localStorage.removeItem("color-scheme");
      } catch (_) {}
      if (meta) meta.setAttribute("content", "light dark");
    } else {
      try {
        localStorage.setItem("color-scheme", mode);
      } catch (_) {}
      if (meta) meta.setAttribute("content", mode);
    }
  };

  return (
    <div className="flex items-center bg-gray-100 dark:bg-gray-800 p-1 rounded-full border border-gray-200 dark:border-gray-700 text-xs text-gray-600 dark:text-gray-300">
      <button
        onClick={() => handleSelect("light")}
        className={`p-1.5 rounded-full transition-colors flex items-center justify-center ${
          theme === "light"
            ? "bg-white dark:bg-gray-700 text-amber-500 shadow-xs font-medium"
            : "hover:text-gray-900 dark:hover:text-white"
        }`}
        title="Light theme"
        aria-label="Switch to light theme"
      >
        <Sun className="w-3.5 h-3.5" />
      </button>
      <button
        onClick={() => handleSelect("system")}
        className={`p-1.5 rounded-full transition-colors flex items-center justify-center ${
          theme === "system"
            ? "bg-white dark:bg-gray-700 text-blue-500 shadow-xs font-medium"
            : "hover:text-gray-900 dark:hover:text-white"
        }`}
        title="System default"
        aria-label="Follow system theme"
      >
        <Laptop className="w-3.5 h-3.5" />
      </button>
      <button
        onClick={() => handleSelect("dark")}
        className={`p-1.5 rounded-full transition-colors flex items-center justify-center ${
          theme === "dark"
            ? "bg-white dark:bg-gray-700 text-indigo-400 shadow-xs font-medium"
            : "hover:text-gray-900 dark:hover:text-white"
        }`}
        title="Dark theme"
        aria-label="Switch to dark theme"
      >
        <Moon className="w-3.5 h-3.5" />
      </button>
    </div>
  );
};
