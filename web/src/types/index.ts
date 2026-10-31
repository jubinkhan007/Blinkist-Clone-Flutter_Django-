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

export interface UserHighlight {
  id: number;
  book_id: number;
  book_slug?: string;
  section_id?: number | null;
  section_title?: string;
  selected_text: string;
  note?: string;
  color: "yellow" | "green" | "blue" | "pink";
  created_at: string;
  updated_at?: string;
}

export interface ActivePlaybackSession {
  has_active_session: boolean;
  can_resume?: boolean;
  prompt_message?: string;
  book_id?: number;
  book_slug?: string;
  book_title?: string;
  author_name?: string;
  cover_image_url?: string | null;
  section_id?: number | null;
  section_title?: string;
  section_order?: number;
  total_sections?: number;
  position_seconds?: number;
  formatted_position?: string;
  duration_seconds?: number;
  audio_url?: string | null;
  device_type?: "web" | "mobile" | "unknown";
  device_name?: string;
  is_playing?: boolean;
  updated_at?: string;
}

