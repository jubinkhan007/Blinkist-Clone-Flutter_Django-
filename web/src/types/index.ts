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

export interface VoicePersona {
  id: string;
  name: string;
  persona: string;
  gender: "male" | "female";
  accent: string;
  description: string;
  avatar: string;
  is_default: boolean;
  is_premium: boolean;
  is_unlocked?: boolean;
  speed_recommendation?: number;
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
  availableVoices?: VoicePersona[];
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
  sectionSlug?: string;
  voiceId?: string;
  voiceName?: string;
  availableVoices?: VoicePersona[];
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

export interface HeatmapDay {
  date: string;
  day_of_week: number; // 0 = Mon, 6 = Sun
  reading_minutes: number;
  audio_minutes: number;
  total_minutes: number;
  books_completed: number;
  intensity: number; // 0..4
  is_active: boolean;
}

export interface ReadingPeriodStats {
  reading_minutes: number;
  audio_minutes: number;
  total_minutes: number;
  days_active: number;
  books_completed: number;
}

export interface UserBadgeItem {
  key: string;
  title: string;
  description: string;
  category: string;
  icon: string;
  is_unlocked: boolean;
  unlocked_at?: string | null;
  current_progress: number;
  target_progress: number;
  progress_percent: number;
}

export interface ReadingStats {
  current_streak: number;
  longest_streak: number;
  last_active_date?: string | null;
  is_active_today: boolean;
  total_sections_read: number;
  total_books_completed: number;
  total_audio_minutes: number;
  total_reading_minutes: number;
  total_highlights: number;
  time_saved_hours: number;
  time_saved_minutes: number;
  monthly_time_saved_hours: number;
  equivalent_full_books: number;
  weekly_activity: boolean[];
  weekly: ReadingPeriodStats;
  monthly: ReadingPeriodStats;
  activity_heatmap: HeatmapDay[];
  unlocked_badges_count: number;
  total_badges_count: number;
  recent_badges: UserBadgeItem[];
}

export interface TopCategory {
  name: string;
  count: number;
  percentage: number;
  color: string;
  icon: string;
}

export interface TopBook {
  id: number;
  slug?: string;
  title: string;
  author: string;
  cover_image_url?: string | null;
  sections_completed: number;
}

export interface LearningReport {
  period_type: "annual" | "monthly";
  period_label: string;
  year: number;
  total_minutes: number;
  total_hours: number;
  reading_minutes: number;
  audio_minutes: number;
  audio_percentage: number;
  reading_percentage: number;
  books_completed_count: number;
  sections_completed_count: number;
  time_saved_hours: number;
  time_saved_days: number;
  top_categories: TopCategory[];
  learner_archetype: string;
  learner_archetype_description: string;
  completed_action_plans: number;
  habits_formed: number;
  key_ideas_retained: number;
  active_days_count: number;
  current_streak: number;
  longest_streak: number;
  top_book?: TopBook | null;
  shareable_text: string;
}


