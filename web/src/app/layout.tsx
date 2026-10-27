import type { Metadata } from "next";
import "./globals.css";

import { Providers } from "@/components/Providers";

export const metadata: Metadata = {
  title: "Blinkist — Big Ideas in 15 Minutes",
  description: "Understand the world's best non-fiction books through key insights, audio blinks, and interactive micro-habits.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="h-full antialiased">
      <head>
        <meta name="color-scheme" content="light dark" />
        <script
          dangerouslySetInnerHTML={{
            __html: `
              try {
                const stored = localStorage.getItem("color-scheme");
                if (stored) {
                  const meta = document.querySelector('meta[name="color-scheme"]');
                  if (meta) meta.content = stored;
                }
              } catch (_) {}
            `,
          }}
        />
      </head>
      <body className="min-h-full flex flex-col font-sans bg-background text-foreground selection:bg-emerald-500 selection:text-white">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
