export interface Author {
  id: number;
  name: string;
  bio?: string;
  avatar_url?: string;
}

export interface Category {
  id: number;
  name: string;
  slug: string;
  description?: string;
}

export interface SummarySection {
  id: number;
  slug: string;
  order: number;
  title: string;
  duration_seconds: number;
  estimated_read_minutes: number;
  audio_url?: string | null;
  content?: string | null;
}

export interface Book {
  id: number;
  title: string;
  subtitle?: string;
  slug: string;
  author: Author;
  categories: Category[];
  cover_image_url?: string | null;
  estimated_read_time_minutes: number;
  is_premium: boolean;
  is_daily_free?: boolean;
  is_saved?: boolean;
  rating?: number;
  rating_count?: number;
  has_audio?: boolean;
  description?: string;
  what_you_will_learn?: string[] | string;
  sections?: SummarySection[];
}

export interface User {
  id: number;
  username: string;
  email: string;
  name?: string;
  is_premium?: boolean;
  streak_count?: number;
  minutes_read_today?: number;
}

export interface DailyBlink {
  id: number;
  date: string;
  book: Book;
  title: string;
  audio_url?: string | null;
  duration_seconds: number;
}

export interface AudioTrack {
  id: number | string;
  bookId: number;
  bookSlug: string;
  bookTitle: string;
  authorName: string;
  coverUrl?: string | null;
  sectionTitle: string;
  sectionIndex: number;
  totalSections: number;
  audioUrl: string;
  durationSeconds: number;
}
