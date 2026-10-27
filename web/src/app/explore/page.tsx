"use client";

import React, { useEffect, useState, useMemo, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { Search, SlidersHorizontal, BookOpen } from "lucide-react";
import { Book, Category } from "@/types";
import { api } from "@/lib/api";
import { BookCard } from "@/components/BookCard";

function ExploreContent() {
  const searchParams = useSearchParams();
  const initialCategory = searchParams.get("category") || "all";
  const initialSearch = searchParams.get("search") || "";

  const [books, setBooks] = useState<Book[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<string>(initialCategory);
  const [searchQuery, setSearchQuery] = useState<string>(initialSearch);
  const [sortBy, setSortBy] = useState<string>("popular");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      try {
        const [booksData, catsData] = await Promise.all([
          api.getBooks(),
          api.getCategories(),
        ]);
        setBooks(booksData);
        setCategories(catsData);
      } catch (err) {
        console.error("Failed to load catalog", err);
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, []);

  const filteredBooks = useMemo(() => {
    let result = [...books];

    // Filter by category
    if (selectedCategory !== "all") {
      result = result.filter((b) =>
        b.categories.some((c) => c.slug === selectedCategory)
      );
    }

    // Filter by search query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      result = result.filter(
        (b) =>
          b.title.toLowerCase().includes(q) ||
          b.author.name.toLowerCase().includes(q) ||
          b.categories.some((c) => c.name.toLowerCase().includes(q))
      );
    }

    // Sort
    if (sortBy === "rating") {
      result.sort((a, b) => (b.rating || 0) - (a.rating || 0));
    } else if (sortBy === "duration_asc") {
      result.sort(
        (a, b) => a.estimated_read_time_minutes - b.estimated_read_time_minutes
      );
    } else if (sortBy === "title") {
      result.sort((a, b) => a.title.localeCompare(b.title));
    }

    return result;
  }, [books, selectedCategory, searchQuery, sortBy]);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12">
      {/* Header */}
      <div className="mb-8 space-y-2">
        <h1 className="text-3xl sm:text-4xl font-extrabold text-gray-900 dark:text-white tracking-tight">
          Explore the Library
        </h1>
        <p className="text-sm sm:text-base text-gray-600 dark:text-gray-400">
          Discover summaries of bestselling non-fiction books in 15-minute text & audio.
        </p>
      </div>

      {/* Search and Filters Bar */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4 mb-8">
        {/* Search Input */}
        <div className="relative flex-1 max-w-lg">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500" />
          <input
            type="text"
            placeholder="Search by title, author, or keyword..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 text-sm rounded-xl bg-gray-100 dark:bg-gray-800/80 border border-transparent focus:border-emerald-500 focus:bg-white dark:focus:bg-gray-900 text-gray-900 dark:text-white outline-hidden transition-all placeholder:text-gray-400"
          />
        </div>

        {/* Sort Dropdown */}
        <div className="flex items-center gap-2 text-xs font-medium text-gray-600 dark:text-gray-300 self-end md:self-auto">
          <SlidersHorizontal className="w-4 h-4 text-gray-400" />
          <span>Sort by:</span>
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            className="bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg px-3 py-1.5 text-xs text-gray-900 dark:text-white outline-hidden cursor-pointer"
          >
            <option value="popular">Most Popular</option>
            <option value="rating">Highest Rated</option>
            <option value="duration_asc">Shortest First</option>
            <option value="title">Alphabetical (A-Z)</option>
          </select>
        </div>
      </div>

      {/* Category Pills */}
      <div className="flex items-center gap-2 overflow-x-auto pb-4 mb-8 scrollbar-none">
        <button
          onClick={() => setSelectedCategory("all")}
          className={`px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all ${
            selectedCategory === "all"
              ? "bg-emerald-500 text-white shadow-md shadow-emerald-500/20"
              : "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
          }`}
        >
          All Topics
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

      {/* Book Grid */}
      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {[1, 2, 3, 4, 5, 6, 7, 8].map((n) => (
            <div
              key={n}
              className="h-72 rounded-2xl bg-gray-100 dark:bg-gray-800 animate-pulse"
            />
          ))}
        </div>
      ) : filteredBooks.length > 0 ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {filteredBooks.map((book) => (
            <BookCard key={book.id} book={book} />
          ))}
        </div>
      ) : (
        <div className="text-center py-20 px-4 bg-gray-50 dark:bg-gray-800/40 rounded-3xl border border-gray-200 dark:border-gray-700/60">
          <BookOpen className="w-12 h-12 mx-auto text-gray-400 mb-3" />
          <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-1">
            No books found
          </h3>
          <p className="text-xs text-gray-500 dark:text-gray-400 mb-4">
            Try adjusting your search query or choosing another category.
          </p>
          <button
            onClick={() => {
              setSearchQuery("");
              setSelectedCategory("all");
            }}
            className="px-4 py-2 rounded-full bg-emerald-500 text-white text-xs font-semibold hover:bg-emerald-600 transition-colors"
          >
            Reset Filters
          </button>
        </div>
      )}
    </div>
  );
}

export default function ExplorePage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-sm text-gray-500">Loading catalog...</div>}>
      <ExploreContent />
    </Suspense>
  );
}
