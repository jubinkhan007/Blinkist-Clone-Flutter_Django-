import { Book, Category, DailyBlink, User } from "@/types";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/v1";

// Demo fallback catalog for offline resilience
export const DEMO_BOOKS: Book[] = [
  {
    id: 1,
    title: "Atomic Habits",
    subtitle: "An Easy & Proven Way to Build Good Habits & Break Bad Ones",
    slug: "atomic-habits",
    author: {
      id: 1,
      name: "James Clear",
      bio: "James Clear is a writer and speaker focused on habits, decision making, and continuous improvement.",
    },
    categories: [
      { id: 1, name: "Productivity", slug: "productivity" },
      { id: 2, name: "Psychology", slug: "psychology" },
    ],
    cover_image_url: "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600&auto=format&fit=crop&q=80",
    estimated_read_time_minutes: 15,
    is_premium: false,
    is_daily_free: true,
    is_saved: false,
    rating: 4.9,
    rating_count: 14200,
    has_audio: true,
    description: "Atomic Habits reveals how tiny changes can lead to remarkable results. James Clear presents a proven framework for improving every day by mastering the 4 laws of behavior change.",
    what_you_will_learn: [
      "How to build systems of continuous improvement",
      "The 4 Laws of Behavior Change: Cue, Craving, Response, Reward",
      "Why small 1% changes compound into life-altering habits",
      "How to design your environment to make good habits inevitable"
    ],
    sections: [
      {
        id: 101,
        slug: "the-surprising-power-of-atomic-habits",
        order: 1,
        title: "The Surprising Power of Atomic Habits",
        duration_seconds: 180,
        estimated_read_minutes: 3,
        audio_url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
        content: `Small habits don't add up; they compound. Just like money multiplies through compound interest, the effects of your habits multiply as you repeat them.

A slight 1% improvement every day means you will be 37 times better by the end of one single year. Conversely, if you decline by 1% each day, you decrease almost down to zero.

What matters most in life is not where you are right now, but the trajectory your daily habits are pointing you toward. Are your current habits leading you toward success, health, and fulfillment, or away from it?`
      },
      {
        id: 102,
        slug: "how-your-habits-shape-your-identity",
        order: 2,
        title: "How Habits Shape Your Identity",
        duration_seconds: 210,
        estimated_read_minutes: 4,
        audio_url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
        content: `The ultimate form of intrinsic motivation is when a habit becomes part of your identity. It’s one thing to say 'I want to run a marathon'—it's another thing to say 'I am a runner.'

Every action you take is a vote for the type of person you wish to become. No single instance will transform your beliefs, but as the votes build up, the evidence of your new identity becomes undeniable.

Focus on who you want to be, not what you want to achieve.`
      },
      {
        id: 103,
        slug: "the-four-laws-of-behavior-change",
        order: 3,
        title: "The Four Laws: Make It Obvious, Attractive, Easy & Satisfying",
        duration_seconds: 240,
        estimated_read_minutes: 4,
        audio_url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
        content: `To build good habits, harness the four laws of behavior change:
1. Make it Obvious: Design your environment so that good cues are in plain sight.
2. Make it Attractive: Bundle what you need to do with what you want to do.
3. Make it Easy: Reduce friction. Master the two-minute rule: downscale your habit until it takes less than 2 minutes to start.
4. Make it Satisfying: Give yourself an immediate reward to reinforce the habit loop.`
      }
    ]
  },
  {
    id: 2,
    title: "Deep Work",
    subtitle: "Rules for Focused Success in a Distracted World",
    slug: "deep-work",
    author: {
      id: 2,
      name: "Cal Newport",
      bio: "Cal Newport is an associate professor of computer science at Georgetown University and author of seven books.",
    },
    categories: [
      { id: 1, name: "Productivity", slug: "productivity" },
      { id: 3, name: "Career & Success", slug: "career-success" },
    ],
    cover_image_url: "https://images.unsplash.com/photo-1512820790803-83ca734da794?w=600&auto=format&fit=crop&q=80",
    estimated_read_time_minutes: 14,
    is_premium: false,
    is_daily_free: false,
    is_saved: true,
    rating: 4.8,
    rating_count: 9800,
    has_audio: true,
    description: "Deep work is the ability to focus without distraction on a cognitively demanding task. Cal Newport argues that deep work is becoming rare at the exact same time it is becoming increasingly valuable.",
    what_you_will_learn: [
      "Why deep work is the superpower of the 21st century knowledge economy",
      "The four strategies for integrating deep work into your routine",
      "How to embrace boredom and retrain your focus",
      "The real danger of attention residue from switching tasks"
    ],
    sections: [
      {
        id: 201,
        slug: "deep-work-is-valuable",
        order: 1,
        title: "Deep Work Is Rare and Valuable",
        duration_seconds: 190,
        estimated_read_minutes: 3,
        audio_url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3",
        content: `Deep work is defined as professional activities performed in a state of distraction-free concentration that push your cognitive capabilities to their limit.

These efforts create new value, improve your skill, and are hard to replicate. In contrast, shallow work (answering emails, attending unfocused meetings) is easy to replicate and creates little new value.`
      },
      {
        id: 202,
        slug: "drain-the-shallows",
        order: 2,
        title: "Drain the Shallows & Quit Social Media",
        duration_seconds: 220,
        estimated_read_minutes: 4,
        audio_url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3",
        content: `Treat shallow work ruthlessly. Schedule every minute of your day in blocks, ask your employer for a shallow work budget, and embrace the power of ending your workday with a strict shutdown ritual.

By protecting your cognitive energy, you allow your brain to recharge for high-impact creative tasks.`
      }
    ]
  },
  {
    id: 3,
    title: "The Psychology of Money",
    subtitle: "Timeless Lessons on Wealth, Greed, and Happiness",
    slug: "psychology-of-money",
    author: {
      id: 3,
      name: "Morgan Housel",
      bio: "Morgan Housel is a partner at The Collaborative Fund and a former columnist at The Motley Fool.",
    },
    categories: [
      { id: 4, name: "Personal Finance", slug: "personal-finance" },
      { id: 2, name: "Psychology", slug: "psychology" },
    ],
    cover_image_url: "https://images.unsplash.com/photo-1553729459-efe14ef6055d?w=600&auto=format&fit=crop&q=80",
    estimated_read_time_minutes: 16,
    is_premium: true,
    is_daily_free: false,
    is_saved: false,
    rating: 4.9,
    rating_count: 16400,
    has_audio: true,
    description: "Doing well with money isn't necessarily about what you know. It’s about how you behave. Morgan Housel shares 19 short stories exploring the strange ways people think about money.",
    what_you_will_learn: [
      "Why personal financial success is 80% behavior and 20% knowledge",
      "The crucial difference between being rich versus being wealthy",
      "The immense compounding power of staying in the game",
      "Why room for error is the most important part of any financial plan"
    ],
    sections: [
      {
        id: 301,
        slug: "no-ones-crazy",
        order: 1,
        title: "No One's Crazy: Your Personal Experiences Shape You",
        duration_seconds: 200,
        estimated_read_minutes: 3,
        audio_url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3",
        content: `Your personal experiences with money make up maybe 0.00000001% of what’s happened in the world, but maybe 80% of how you think the world works.

People from different generations, raised by different parents who earned different incomes in different parts of the world, learn vastly different lessons. No one is crazy; everyone is operating based on their unique worldview.`
      }
    ]
  },
  {
    id: 4,
    title: "Thinking, Fast and Slow",
    subtitle: "Two Systems of the Human Mind",
    slug: "thinking-fast-and-slow",
    author: {
      id: 4,
      name: "Daniel Kahneman",
      bio: "Daniel Kahneman was an Israeli-American psychologist and Nobel laureate renowned for his work on the psychology of judgment.",
    },
    categories: [
      { id: 2, name: "Psychology", slug: "psychology" },
      { id: 5, name: "Science & Philosophy", slug: "science-philosophy" },
    ],
    cover_image_url: "https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?w=600&auto=format&fit=crop&q=80",
    estimated_read_time_minutes: 18,
    is_premium: true,
    is_daily_free: false,
    is_saved: false,
    rating: 4.7,
    rating_count: 22100,
    has_audio: true,
    description: "Daniel Kahneman takes us on a groundbreaking tour of the mind and explains the two systems that drive the way we think: System 1 (fast, intuitive) and System 2 (slow, deliberate).",
    what_you_will_learn: [
      "How cognitive biases quietly corrupt everyday decision-making",
      "When you can trust your intuition and when you must engage System 2",
      "The difference between the experiencing self and the remembering self"
    ],
    sections: [
      {
        id: 401,
        slug: "two-systems",
        order: 1,
        title: "Two Systems: The Characters of the Mental Drama",
        duration_seconds: 210,
        estimated_read_minutes: 4,
        audio_url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3",
        content: `System 1 operates automatically and quickly, with little or no effort and no sense of voluntary control. System 2 allocates attention to effortful mental operations, including complex computations.

Most of what you think and do originates in System 1, but System 2 takes over when things get difficult and normally has the last word.`
      }
    ]
  }
];

export const DEMO_CATEGORIES: Category[] = [
  { id: 1, name: "Productivity", slug: "productivity", description: "Get more done with less friction" },
  { id: 2, name: "Psychology", slug: "psychology", description: "Understand human behavior and cognition" },
  { id: 3, name: "Career & Success", slug: "career-success", description: "Accelerate your professional trajectory" },
  { id: 4, name: "Personal Finance", slug: "personal-finance", description: "Build wealth and financial independence" },
  { id: 5, name: "Science & Philosophy", slug: "science-philosophy", description: "Big questions about reality and meaning" },
  { id: 6, name: "Leadership & Management", slug: "leadership", description: "Inspire teams and execute vision" },
];

class ApiClient {
  private getHeaders(): HeadersInit {
    const headers: HeadersInit = {
      "Content-Type": "application/json",
    };
    if (typeof window !== "undefined") {
      const token = localStorage.getItem("blinkist_token");
      if (token) {
        headers["Authorization"] = `Bearer ${token}`;
      }
    }
    return headers;
  }

  async getBooks(categorySlug?: string, search?: string): Promise<Book[]> {
    try {
      let url = `${API_BASE_URL}/catalog/books/`;
      const params = new URLSearchParams();
      if (categorySlug) params.append("category", categorySlug);
      if (search) params.append("search", search);
      if (params.toString()) url += `?${params.toString()}`;

      const res = await fetch(url, { headers: this.getHeaders(), cache: "no-store" });
      if (!res.ok) throw new Error("Backend unavailable");
      const data = await res.json();
      return Array.isArray(data) ? data : data.results || DEMO_BOOKS;
    } catch {
      let filtered = [...DEMO_BOOKS];
      if (categorySlug) {
        filtered = filtered.filter(b => b.categories.some(c => c.slug === categorySlug));
      }
      if (search) {
        const q = search.toLowerCase();
        filtered = filtered.filter(b => b.title.toLowerCase().includes(q) || b.author.name.toLowerCase().includes(q));
      }
      return filtered;
    }
  }

  async getBookBySlug(slug: string): Promise<Book> {
    try {
      const res = await fetch(`${API_BASE_URL}/catalog/books/${slug}/`, {
        headers: this.getHeaders(),
        cache: "no-store",
      });
      if (!res.ok) throw new Error("Book not found in backend");
      return await res.json();
    } catch {
      const found = DEMO_BOOKS.find(b => b.slug === slug);
      if (!found) throw new Error(`Book with slug "${slug}" not found`);
      return found;
    }
  }

  async getCategories(): Promise<Category[]> {
    try {
      const res = await fetch(`${API_BASE_URL}/catalog/categories/`, {
        headers: this.getHeaders(),
        cache: "no-store",
      });
      if (!res.ok) throw new Error("Categories unavailable");
      const data = await res.json();
      return Array.isArray(data) ? data : data.results || DEMO_CATEGORIES;
    } catch {
      return DEMO_CATEGORIES;
    }
  }

  async getDailyBlink(): Promise<DailyBlink> {
    try {
      const res = await fetch(`${API_BASE_URL}/media/daily-blink/`, {
        headers: this.getHeaders(),
        cache: "no-store",
      });
      if (!res.ok) throw new Error("Daily Blink unavailable");
      return await res.json();
    } catch {
      return {
        id: 999,
        date: "2026-10-26",
        book: DEMO_BOOKS[0],
        title: "Today's Daily Blink: Mastering The 1% Rule",
        audio_url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
        duration_seconds: 600,
      };
    }
  }

  async toggleSaveBook(bookId: number): Promise<boolean> {
    try {
      const res = await fetch(`${API_BASE_URL}/catalog/books/${bookId}/toggle-save/`, {
        method: "POST",
        headers: this.getHeaders(),
      });
      if (res.ok) {
        const data = await res.json();
        return data.is_saved;
      }
    } catch (_) {}
    return true;
  }
}

export const api = new ApiClient();
