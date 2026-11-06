"use client";

import React, { useState, useRef, useEffect } from "react";
import {
  Sparkles,
  X,
  Send,
  CornerDownLeft,
  Copy,
  Check,
  BookOpen,
  ArrowRight,
  Bot,
  User as UserIcon,
} from "lucide-react";
import { AskAiCitation, AskAiMessage } from "@/types";
import { api } from "@/lib/api";

interface AskBookAiDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  bookSlug: string;
  bookTitle: string;
  authorName?: string;
  currentSectionSlug?: string;
  currentSectionTitle?: string;
  onCitationClick?: (sectionSlug: string, sectionOrder?: number) => void;
}

const STARTER_PROMPTS = [
  "⚡ 3 Practical action steps",
  "👶 Explain like I'm 5",
  "📋 Step-by-step checklist",
  "💡 Real-world case study",
  "🤔 Criticisms & counterarguments",
  "🧠 Core mental models",
];

export function AskBookAiDrawer({
  isOpen,
  onClose,
  bookSlug,
  bookTitle,
  authorName,
  currentSectionSlug,
  currentSectionTitle,
  onCitationClick,
}: AskBookAiDrawerProps) {
  const [messages, setMessages] = useState<AskAiMessage[]>([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const scrollRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      setTimeout(() => {
        inputRef.current?.focus();
      }, 150);
    }
  }, [isOpen]);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages, isLoading]);

  if (!isOpen) return null;

  const handleSendMessage = async (textToSend: string) => {
    const text = textToSend.trim();
    if (!text || isLoading) return;

    const userMsgId = `user-${Date.now()}`;
    const userMessage: AskAiMessage = {
      id: userMsgId,
      text,
      isUser: true,
      timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
      sectionTitle: currentSectionTitle,
    };

    setMessages((prev) => [...prev, userMessage]);
    setInput("");
    setIsLoading(true);

    try {
      // Build history for context
      const history = messages.slice(-4).map((m) => ({
        role: m.isUser ? "user" : "model",
        content: m.text,
      }));

      const res = await api.askBookAi(bookSlug, text, currentSectionSlug, history);

      const aiMessage: AskAiMessage = {
        id: `ai-${Date.now()}`,
        text: res.answer,
        isUser: false,
        timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
        citations: res.citations,
        suggestedFollowups: res.suggested_followups,
      };

      setMessages((prev) => [...prev, aiMessage]);
    } catch (err) {
      const errorMsg: AskAiMessage = {
        id: `err-${Date.now()}`,
        text: "Sorry, I had trouble synthesizing an answer right now. Please try asking again.",
        isUser: false,
        timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
      };
      setMessages((prev) => [...prev, errorMsg]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCopy = (id: string, text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  return (
    <div className="fixed inset-0 z-50 overflow-hidden bg-black/40 backdrop-blur-xs flex justify-end animate-in fade-in duration-200">
      <div
        className="w-full max-w-lg bg-white dark:bg-zinc-900 h-full shadow-2xl flex flex-col border-l border-zinc-200 dark:border-zinc-800 animate-in slide-in-from-right duration-300"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="p-4 border-b border-zinc-200 dark:border-zinc-800 flex items-center justify-between bg-zinc-50 dark:bg-zinc-900/80">
          <div className="flex items-center gap-3 min-w-0">
            <div className="w-10 h-10 rounded-xl bg-linear-to-br from-emerald-400 to-teal-600 flex items-center justify-center text-white shadow-xs">
              <Sparkles className="w-5 h-5 animate-pulse" />
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-2">
                <h3 className="font-bold text-zinc-900 dark:text-zinc-100 text-base leading-tight truncate">
                  Ask the Book
                </h3>
                <span className="px-1.5 py-0.5 text-[10px] font-semibold bg-emerald-100 dark:bg-emerald-950/60 text-emerald-800 dark:text-emerald-300 rounded-md border border-emerald-200 dark:border-emerald-800">
                  Gemini AI
                </span>
              </div>
              <p className="text-xs text-zinc-500 dark:text-zinc-400 truncate">
                {bookTitle} {authorName ? `• ${authorName}` : ""}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 rounded-lg hover:bg-zinc-200/60 dark:hover:bg-zinc-800 transition-colors"
            title="Close Drawer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Current Section Context Banner */}
        {currentSectionTitle && (
          <div className="px-4 py-2 bg-emerald-50/80 dark:bg-emerald-950/30 border-b border-emerald-100 dark:border-emerald-900/50 flex items-center gap-2 text-xs text-emerald-900 dark:text-emerald-300">
            <BookOpen className="w-3.5 h-3.5 shrink-0 text-emerald-600 dark:text-emerald-400" />
            <span className="font-medium truncate">
              Grounded in current section: <span className="underline decoration-emerald-400">{currentSectionTitle}</span>
            </span>
          </div>
        )}

        {/* Chat Messages Body */}
        <div ref={scrollRef} className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-center px-4 py-8">
              <div className="w-14 h-14 rounded-2xl bg-emerald-100 dark:bg-emerald-950/80 text-emerald-600 dark:text-emerald-400 flex items-center justify-center mb-4">
                <Bot className="w-7 h-7" />
              </div>
              <h4 className="text-base font-semibold text-zinc-900 dark:text-zinc-100 mb-1">
                Have questions about {bookTitle}?
              </h4>
              <p className="text-xs text-zinc-500 dark:text-zinc-400 max-w-sm mb-6">
                Ask anything about the key ideas, extract actionable execution steps, or clarify complex arguments.
              </p>

              {/* Starter Chips */}
              <div className="w-full text-left">
                <p className="text-[11px] font-semibold tracking-wider text-zinc-400 dark:text-zinc-500 uppercase mb-2">
                  Suggested Questions
                </p>
                <div className="flex flex-wrap gap-2">
                  {STARTER_PROMPTS.map((prompt) => (
                    <button
                      key={prompt}
                      onClick={() => handleSendMessage(prompt)}
                      className="text-left text-xs px-3 py-2 rounded-xl bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 hover:bg-emerald-50 dark:hover:bg-emerald-950/50 hover:text-emerald-700 dark:hover:text-emerald-300 border border-zinc-200 dark:border-zinc-700 transition-all cursor-pointer flex items-center gap-1.5"
                    >
                      <span>{prompt}</span>
                      <ArrowRight className="w-3 h-3 opacity-60" />
                    </button>
                  ))}
                </div>
              </div>
            </div>
          ) : (
            messages.map((m) => (
              <div
                key={m.id}
                className={`flex gap-3 ${m.isUser ? "justify-end" : "justify-start"}`}
              >
                {!m.isUser && (
                  <div className="w-7 h-7 rounded-lg bg-emerald-600 text-white flex items-center justify-center shrink-0 mt-0.5 text-xs shadow-xs">
                    <Sparkles className="w-3.5 h-3.5" />
                  </div>
                )}
                <div className={`max-w-[85%] ${m.isUser ? "items-end" : "items-start"} flex flex-col`}>
                  <div
                    className={`rounded-2xl px-4 py-3 text-sm leading-relaxed ${
                      m.isUser
                        ? "bg-emerald-600 text-white rounded-tr-none shadow-xs"
                        : "bg-zinc-100 dark:bg-zinc-800 text-zinc-900 dark:text-zinc-100 rounded-tl-none border border-zinc-200/80 dark:border-zinc-700"
                    }`}
                  >
                    <p className="whitespace-pre-line">{m.text}</p>

                    {/* Citations */}
                    {m.citations && m.citations.length > 0 && (
                      <div className="mt-3 pt-2.5 border-t border-zinc-200 dark:border-zinc-700/60 space-y-1.5">
                        <span className="text-[10px] font-semibold uppercase tracking-wider text-zinc-500 dark:text-zinc-400">
                          Sources & Key Blink:
                        </span>
                        <div className="flex flex-wrap gap-1.5">
                          {m.citations.map((c, idx) => (
                            <button
                              key={idx}
                              onClick={() => {
                                if (c.section_slug && onCitationClick) {
                                  onCitationClick(c.section_slug, c.section_order);
                                }
                              }}
                              className="text-[11px] inline-flex items-center gap-1 px-2.5 py-1 rounded-md bg-white dark:bg-zinc-900 text-emerald-700 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800 font-medium hover:bg-emerald-50 dark:hover:bg-emerald-950 transition-colors cursor-pointer"
                            >
                              <BookOpen className="w-3 h-3 text-emerald-500" />
                              <span>{c.section_title || `Section ${c.section_order || idx + 1}`}</span>
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>

                  {/* Message Footer Actions */}
                  <div className="flex items-center gap-2 mt-1 px-1">
                    <span className="text-[10px] text-zinc-400">{m.timestamp}</span>
                    {!m.isUser && (
                      <button
                        onClick={() => handleCopy(m.id, m.text)}
                        className="text-[10px] text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-200 flex items-center gap-1 transition-colors"
                        title="Copy answer"
                      >
                        {copiedId === m.id ? (
                          <>
                            <Check className="w-3 h-3 text-emerald-500" />
                            <span className="text-emerald-500">Copied</span>
                          </>
                        ) : (
                          <>
                            <Copy className="w-3 h-3" />
                            <span>Copy</span>
                          </>
                        )}
                      </button>
                    )}
                  </div>

                  {/* Follow-up suggestions */}
                  {m.suggestedFollowups && m.suggestedFollowups.length > 0 && (
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {m.suggestedFollowups.map((suggestion, sIdx) => (
                        <button
                          key={sIdx}
                          onClick={() => handleSendMessage(suggestion)}
                          className="text-[11px] px-2.5 py-1 rounded-lg bg-zinc-50 dark:bg-zinc-800/60 hover:bg-emerald-50 dark:hover:bg-emerald-950/40 text-zinc-600 dark:text-zinc-300 hover:text-emerald-700 dark:hover:text-emerald-300 border border-zinc-200 dark:border-zinc-700/80 transition-colors text-left flex items-center gap-1"
                        >
                          <span>{suggestion}</span>
                          <ArrowRight className="w-2.5 h-2.5 opacity-60" />
                        </button>
                      ))}
                    </div>
                  )}
                </div>
                {m.isUser && (
                  <div className="w-7 h-7 rounded-lg bg-zinc-200 dark:bg-zinc-700 text-zinc-600 dark:text-zinc-300 flex items-center justify-center shrink-0 mt-0.5 text-xs">
                    <UserIcon className="w-3.5 h-3.5" />
                  </div>
                )}
              </div>
            ))
          )}

          {/* Loading Indicator */}
          {isLoading && (
            <div className="flex gap-3 justify-start items-center">
              <div className="w-7 h-7 rounded-lg bg-emerald-600 text-white flex items-center justify-center shrink-0 text-xs shadow-xs animate-pulse">
                <Sparkles className="w-3.5 h-3.5" />
              </div>
              <div className="bg-zinc-100 dark:bg-zinc-800 rounded-2xl rounded-tl-none px-4 py-3 border border-zinc-200 dark:border-zinc-700 flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
                <span className="text-xs text-zinc-500 dark:text-zinc-400 font-medium">
                  Thinking with Gemini AI...
                </span>
              </div>
            </div>
          )}
        </div>

        {/* Bottom Input Area */}
        <div className="p-4 border-t border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              handleSendMessage(input);
            }}
            className="flex items-center gap-2"
          >
            <div className="relative flex-1">
              <input
                ref={inputRef}
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                placeholder={
                  currentSectionTitle
                    ? `Ask about "${currentSectionTitle}"...`
                    : `Ask about ${bookTitle}...`
                }
                disabled={isLoading}
                className="w-full text-sm bg-zinc-100 dark:bg-zinc-800 text-zinc-900 dark:text-zinc-100 rounded-xl px-4 py-2.5 pr-10 border border-zinc-200 dark:border-zinc-700 focus:outline-hidden focus:ring-2 focus:ring-emerald-500 disabled:opacity-50 transition-all placeholder:text-zinc-400"
              />
              <button
                type="submit"
                disabled={!input.trim() || isLoading}
                className="absolute right-1.5 top-1/2 -translate-y-1/2 w-7 h-7 rounded-lg bg-emerald-600 text-white flex items-center justify-center hover:bg-emerald-500 disabled:opacity-30 disabled:hover:bg-emerald-600 transition-all cursor-pointer"
              >
                <CornerDownLeft className="w-3.5 h-3.5" />
              </button>
            </div>
          </form>
          <div className="mt-2 text-center">
            <span className="text-[10px] text-zinc-400">
              Grounded in full book context • AI responses are verified against summary text
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
