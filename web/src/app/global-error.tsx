"use client";

import React, { useEffect, useState } from "react";
import { sentry } from "@/lib/sentry";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const [eventId, setEventId] = useState<string | null>(null);

  useEffect(() => {
    console.error("Global critical layout crash:", error);
    try {
      const id = sentry.captureException(error, {
        level: "fatal",
        tags: { boundary: "global_error" },
        extra: { digest: error.digest },
      });
      setEventId(id);
    } catch (_) {}
  }, [error]);

  return (
    <html lang="en">
      <body className="bg-zinc-950 text-white min-h-screen flex items-center justify-center p-6 font-sans">
        <div className="max-w-md w-full text-center space-y-6">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-red-950/80 text-red-400 border border-red-800">
            ⚠️
          </div>
          <div className="space-y-2">
            <h1 className="text-2xl font-black tracking-tight">Critical Application Error</h1>
            <p className="text-sm text-zinc-400">
              The application encountered a critical runtime error. Telemetry incident has been dispatched to Sentry.
            </p>
            {eventId && (
              <p className="text-xs font-mono text-zinc-500 pt-2">
                Incident ID: <span className="underline select-all text-zinc-300">{eventId}</span>
              </p>
            )}
          </div>
          <button
            onClick={() => reset()}
            className="px-6 py-2.5 rounded-full bg-emerald-500 hover:bg-emerald-600 text-white font-bold text-xs shadow-lg transition-all cursor-pointer"
          >
            Reload Application
          </button>
        </div>
      </body>
    </html>
  );
}
