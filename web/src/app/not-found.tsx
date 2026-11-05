import Link from "next/link";
import { BookOpen, Compass, Home } from "lucide-react";

export default function NotFound() {
  return (
    <div className="min-h-[70vh] flex items-center justify-center px-4 py-16">
      <div className="max-w-md w-full text-center space-y-6">
        <div className="inline-flex items-center justify-center w-20 h-20 rounded-3xl bg-emerald-50 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800 shadow-sm">
          <BookOpen className="w-10 h-10" />
        </div>

        <div className="space-y-2">
          <p className="text-xs uppercase font-extrabold tracking-widest text-emerald-600 dark:text-emerald-400">
            404 Error
          </p>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight">
            Summary Not Found
          </h1>
          <p className="text-sm text-gray-600 dark:text-gray-400">
            The book or page you are looking for might have been moved or doesn&apos;t exist yet. Explore our curated library of bestsellers instead!
          </p>
        </div>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-3 pt-2">
          <Link
            href="/"
            className="w-full sm:w-auto px-6 py-3 rounded-full bg-emerald-500 hover:bg-emerald-600 text-white font-bold text-xs flex items-center justify-center gap-2 shadow-md shadow-emerald-500/20 transition-all"
          >
            <Home className="w-4 h-4" />
            Back to Home
          </Link>
          <Link
            href="/explore"
            className="w-full sm:w-auto px-6 py-3 rounded-full bg-gray-100 hover:bg-gray-200 dark:bg-gray-800 dark:hover:bg-gray-700 text-gray-900 dark:text-white font-bold text-xs flex items-center justify-center gap-2 transition-all"
          >
            <Compass className="w-4 h-4" />
            Explore Library
          </Link>
        </div>
      </div>
    </div>
  );
}
