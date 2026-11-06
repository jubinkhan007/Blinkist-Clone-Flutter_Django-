"use client";

import React, { useState } from "react";
import { Mic, Check, Sparkles, Volume2, X, Lock } from "lucide-react";
import { useAudio } from "@/context/AudioContext";
import { VoicePersona } from "@/types";

interface VoiceSwitcherModalProps {
  isOpen: boolean;
  onClose: () => void;
  onUpgradeClick?: () => void;
}

export const VoiceSwitcherModal: React.FC<VoiceSwitcherModalProps> = ({
  isOpen,
  onClose,
  onUpgradeClick,
}) => {
  const { availableVoices, selectedVoice, setVoice, isSwitchingVoice } = useAudio();
  const [previewingVoiceId, setPreviewingVoiceId] = useState<string | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSelectVoice = async (voice: VoicePersona) => {
    setErrorMsg(null);
    if (voice.is_premium && voice.is_unlocked === false) {
      if (onUpgradeClick) {
        onUpgradeClick();
      } else {
        setErrorMsg(`${voice.name} is a Premium AI voice. Upgrade to Blinkist Plus to unlock British and Innovator narrators.`);
      }
      return;
    }

    const success = await setVoice(voice.id);
    if (success) {
      onClose();
    }
  };

  const playPreviewSample = (e: React.MouseEvent, voiceId: string) => {
    e.stopPropagation();
    setPreviewingVoiceId(voiceId);
    setTimeout(() => {
      setPreviewingVoiceId(null);
    }, 2500);
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="voice-modal-title"
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200"
      onClick={onClose}
    >
      <div
        className="relative w-full max-w-lg bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl shadow-2xl p-6 overflow-hidden max-h-[90vh] flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-start justify-between pb-4 border-b border-gray-100 dark:border-gray-800">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-50 dark:bg-emerald-950/60 border border-emerald-200 dark:border-emerald-800 flex items-center justify-center text-emerald-600 dark:text-emerald-400">
              <Mic className="w-5 h-5" />
            </div>
            <div>
              <h2
                id="voice-modal-title"
                className="text-lg font-bold text-gray-900 dark:text-white flex items-center gap-2"
              >
                Narrator Voice
                <span className="text-[10px] font-mono font-semibold uppercase px-2 py-0.5 rounded-full bg-emerald-100 dark:bg-emerald-900/50 text-emerald-700 dark:text-emerald-300">
                  AI Multi-Voice
                </span>
              </h2>
              <p className="text-xs text-gray-500 dark:text-gray-400">
                Choose the AI voice persona that best matches your learning focus.
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
            aria-label="Close narrator voice modal"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {errorMsg && (
          <div className="mt-3 p-3 text-xs bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-800 text-amber-800 dark:text-amber-300 rounded-xl flex items-center gap-2 animate-in fade-in">
            <Sparkles className="w-4 h-4 shrink-0" />
            <span>{errorMsg}</span>
          </div>
        )}

        {/* Voice Persona List */}
        <div className="flex-1 overflow-y-auto py-4 space-y-2.5">
          {availableVoices.map((voice) => {
            const isSelected = selectedVoice?.id === voice.id;
            const isLocked = voice.is_premium && voice.is_unlocked === false;

            return (
              <div
                key={voice.id}
                onClick={() => handleSelectVoice(voice)}
                className={`group relative p-3.5 rounded-xl border transition-all cursor-pointer flex items-center justify-between gap-3 ${
                  isSelected
                    ? "bg-emerald-50/70 dark:bg-emerald-950/40 border-emerald-500/60 shadow-xs ring-1 ring-emerald-500/30"
                    : "bg-white dark:bg-gray-850/60 border-gray-200 dark:border-gray-800 hover:border-gray-300 dark:hover:border-gray-700 hover:bg-gray-50/80 dark:hover:bg-gray-800/60"
                }`}
              >
                <div className="flex items-center gap-3.5 min-w-0">
                  <div className="w-11 h-11 shrink-0 rounded-xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center text-xl shadow-xs border border-gray-200/60 dark:border-gray-700/60">
                    {voice.avatar}
                  </div>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="text-sm font-semibold text-gray-900 dark:text-white">
                        {voice.name}
                      </h3>
                      <span className="text-[11px] font-medium text-emerald-600 dark:text-emerald-400">
                        {voice.persona}
                      </span>
                      {voice.is_premium && (
                        <span className="text-[9px] font-bold uppercase tracking-wider px-1.5 py-0.5 rounded-sm bg-purple-100 dark:bg-purple-950/70 text-purple-700 dark:text-purple-300 border border-purple-200 dark:border-purple-800 flex items-center gap-0.5">
                          <Sparkles className="w-2.5 h-2.5" /> PRO
                        </span>
                      )}
                      <span className="text-[10px] text-gray-400 dark:text-gray-500">
                        • {voice.accent}
                      </span>
                    </div>
                    <p className="text-xs text-gray-500 dark:text-gray-400 line-clamp-1 mt-0.5">
                      {voice.description}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  {/* Sample Audio Preview button */}
                  <button
                    onClick={(e) => playPreviewSample(e, voice.id)}
                    className="p-1.5 rounded-lg text-gray-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-gray-100 dark:hover:bg-gray-750 transition-colors"
                    title={`Preview ${voice.name}'s voice`}
                    aria-label={`Preview ${voice.name}'s voice`}
                  >
                    <Volume2
                      className={`w-4 h-4 ${
                        previewingVoiceId === voice.id ? "text-emerald-500 animate-pulse" : ""
                      }`}
                    />
                  </button>

                  {/* Lock or Check indicator */}
                  {isLocked ? (
                    <div className="w-7 h-7 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center text-gray-400">
                      <Lock className="w-3.5 h-3.5" />
                    </div>
                  ) : isSelected ? (
                    <div className="w-7 h-7 rounded-full bg-emerald-500 text-white flex items-center justify-center shadow-xs">
                      {isSwitchingVoice ? (
                        <div className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      ) : (
                        <Check className="w-4 h-4" />
                      )}
                    </div>
                  ) : (
                    <div className="w-7 h-7 rounded-full border border-gray-300 dark:border-gray-700 group-hover:border-gray-400" />
                  )}
                </div>
              </div>
            );
          })}
        </div>

        {/* Footer */}
        <div className="pt-3 border-t border-gray-100 dark:border-gray-800 flex items-center justify-between text-xs text-gray-500 dark:text-gray-400">
          <p className="flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 inline-block" />
            Selection syncs seamlessly across phone and desktop
          </p>
          <button
            onClick={onClose}
            className="px-4 py-1.5 text-xs font-semibold rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};
