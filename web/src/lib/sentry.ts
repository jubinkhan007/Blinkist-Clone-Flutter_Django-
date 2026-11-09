/**
 * Web Sentry APM & Real-Time Error Tracking
 *
 * Lightweight, production-grade error reporting client supporting the Sentry v7
 * Store protocol with automatic client/server environment detection, breadcrumbs,
 * unhandled promise rejection tracking, and zero runtime dependencies.
 */

export interface SentryBreadcrumb {
  message: string;
  category?: string;
  level?: "info" | "warning" | "error" | "debug";
  timestamp?: number;
  data?: Record<string, any>;
}

export interface SentryUser {
  id?: string | number;
  email?: string;
  username?: string;
  ip_address?: string;
}

export interface SentryContext {
  tags?: Record<string, string>;
  extra?: Record<string, any>;
  level?: "fatal" | "error" | "warning" | "info" | "debug";
  fingerprint?: string[];
}

interface ParsedDsn {
  protocol: string;
  publicKey: string;
  host: string;
  projectId: string;
}

class SentryClient {
  private dsn: string;
  private environment: string;
  private release: string;
  private parsedDsn: ParsedDsn | null = null;
  private breadcrumbs: SentryBreadcrumb[] = [];
  private maxBreadcrumbs: number = 30;
  private currentUser: SentryUser | null = null;
  private globalTags: Record<string, string> = {};
  private isInitialized: boolean = false;

  constructor() {
    this.dsn = process.env.NEXT_PUBLIC_SENTRY_DSN || "";
    this.environment =
      process.env.NEXT_PUBLIC_SENTRY_ENVIRONMENT ||
      process.env.NODE_ENV ||
      "production";
    this.release = process.env.NEXT_PUBLIC_SENTRY_RELEASE || "blinkist-web@1.0.0";

    this.parsedDsn = this.parseDsn(this.dsn);
  }

  private parseDsn(dsn: string): ParsedDsn | null {
    if (!dsn || !dsn.trim()) return null;
    try {
      const url = new URL(dsn.trim());
      const publicKey = url.username;
      const host = url.host;
      const pathParts = url.pathname.split("/").filter(Boolean);
      const projectId = pathParts[pathParts.length - 1];

      if (!publicKey || !host || !projectId) return null;

      return {
        protocol: url.protocol.replace(":", ""),
        publicKey,
        host,
        projectId,
      };
    } catch (_) {
      return null;
    }
  }

  public init(): void {
    if (this.isInitialized) return;
    this.isInitialized = true;

    if (typeof window !== "undefined") {
      // Global uncaught error listener
      window.addEventListener("error", (event: ErrorEvent) => {
        this.captureException(event.error || new Error(event.message), {
          tags: { source: "window.onerror" },
          extra: { filename: event.filename, lineno: event.lineno, colno: event.colno },
        });
      });

      // Global unhandled promise rejection listener
      window.addEventListener("unhandledrejection", (event: PromiseRejectionEvent) => {
        const error =
          event.reason instanceof Error
            ? event.reason
            : new Error(typeof event.reason === "string" ? event.reason : "Unhandled Promise Rejection");

        this.captureException(error, {
          tags: { source: "unhandledrejection" },
          extra: { reason: String(event.reason) },
        });
      });

      // Record navigation breadcrumb
      this.addBreadcrumb({
        category: "navigation",
        message: `App initialized at ${window.location.pathname}`,
        level: "info",
      });
    }
  }

  public addBreadcrumb(breadcrumb: SentryBreadcrumb): void {
    const entry: SentryBreadcrumb = {
      timestamp: Math.floor(Date.now() / 1000),
      level: "info",
      ...breadcrumb,
    };
    this.breadcrumbs.push(entry);
    if (this.breadcrumbs.length > this.maxBreadcrumbs) {
      this.breadcrumbs.shift();
    }
  }

  public setUser(user: SentryUser | null): void {
    this.currentUser = user;
    if (user) {
      this.addBreadcrumb({
        category: "auth",
        message: `User identity bound: ${user.email || user.id}`,
        level: "info",
      });
    }
  }

  public setTag(key: string, value: string): void {
    this.globalTags[key] = value;
  }

  public captureException(error: any, context?: SentryContext): string {
    const eventId = this.generateEventId();
    const errObj = error instanceof Error ? error : new Error(String(error));

    if (process.env.NODE_ENV === "development") {
      console.error(`[Sentry Alert] Captured exception (${eventId}):`, errObj, context);
    }

    if (!this.parsedDsn) {
      return eventId;
    }

    const payload = {
      event_id: eventId,
      timestamp: Math.floor(Date.now() / 1000),
      platform: "javascript",
      level: context?.level || "error",
      logger: "nextjs-client",
      environment: this.environment,
      release: this.release,
      sdk: {
        name: "blinkist.sentry.nextjs",
        version: "1.0.0",
      },
      exception: {
        values: [
          {
            type: errObj.name || "Error",
            value: errObj.message || "Unknown error",
            stacktrace: this.parseStackTrace(errObj.stack),
          },
        ],
      },
      breadcrumbs: {
        values: [...this.breadcrumbs],
      },
      user: this.currentUser || undefined,
      tags: {
        ...this.globalTags,
        ...(context?.tags || {}),
      },
      extra: {
        ...(context?.extra || {}),
        url: typeof window !== "undefined" ? window.location.href : undefined,
      },
    };

    this.sendEvent(payload);
    return eventId;
  }

  public captureMessage(
    message: string,
    level: "fatal" | "error" | "warning" | "info" | "debug" = "info",
    context?: SentryContext
  ): string {
    const eventId = this.generateEventId();

    if (process.env.NODE_ENV === "development") {
      console.log(`[Sentry Message] ${level.toUpperCase()} (${eventId}): ${message}`, context);
    }

    if (!this.parsedDsn) {
      return eventId;
    }

    const payload = {
      event_id: eventId,
      timestamp: Math.floor(Date.now() / 1000),
      platform: "javascript",
      level,
      message: {
        formatted: message,
      },
      environment: this.environment,
      release: this.release,
      breadcrumbs: {
        values: [...this.breadcrumbs],
      },
      user: this.currentUser || undefined,
      tags: {
        ...this.globalTags,
        ...(context?.tags || {}),
      },
      extra: context?.extra || {},
    };

    this.sendEvent(payload);
    return eventId;
  }

  private async sendEvent(payload: Record<string, any>): Promise<void> {
    if (!this.parsedDsn) return;

    const { protocol, publicKey, host, projectId } = this.parsedDsn;
    const storeUrl = `${protocol}://${host}/api/${projectId}/store/?sentry_key=${publicKey}&sentry_version=7`;

    try {
      if (typeof window !== "undefined" && "fetch" in window) {
        await fetch(storeUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify(payload),
          keepalive: true,
          mode: "cors",
        });
      }
    } catch (_) {
      // Avoid recursive error throws when telemetry delivery encounters network failures
    }
  }

  private parseStackTrace(stack?: string) {
    if (!stack) return undefined;
    const lines = stack.split("\n").slice(1);
    const frames = lines
      .map((line) => {
        const match = line.match(/^\s*at (?:(.+?)\s+\()?(?:(.+?):(\d+):(\d+)\)?|(.+?))$/);
        if (!match) return { filename: line.trim() };
        return {
          function: match[1] || "?",
          filename: match[2] || match[5] || "unknown",
          lineno: parseInt(match[3] || "0", 10),
          colno: parseInt(match[4] || "0", 10),
        };
      })
      .reverse();

    return frames.length > 0 ? { frames } : undefined;
  }

  private generateEventId(): string {
    const chars = "0123456789abcdef";
    let res = "";
    for (let i = 0; i < 32; i++) {
      res += chars[Math.floor(Math.random() * chars.length)];
    }
    return res;
  }
}

export const sentry = new SentryClient();

// Auto-initialize when running in browser
if (typeof window !== "undefined") {
  sentry.init();
}
