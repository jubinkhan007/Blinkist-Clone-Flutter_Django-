"use client";

import React, {
  createContext,
  useContext,
  useState,
  useRef,
  useEffect,
  useCallback,
} from "react";
import { AudioTrack, ActivePlaybackSession, VoicePersona } from "@/types";
import { api } from "@/lib/api";
import { sentry } from "@/lib/sentry";

interface AudioContextType {
  currentTrack: AudioTrack | null;
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  playbackRate: number;
  volume: number;
  handoffSession: ActivePlaybackSession | null;
  selectedVoice: VoicePersona | null;
  availableVoices: VoicePersona[];
  isSwitchingVoice: boolean;
  setVoice: (voiceId: string) => Promise<boolean>;
  playTrack: (track: AudioTrack) => void;
  togglePlay: () => void;
  pause: () => void;
  resume: () => void;
  seek: (seconds: number) => void;
  skip: (seconds: number) => void;
  setPlaybackRate: (rate: number) => void;
  setVolume: (volume: number) => void;
  closePlayer: () => void;
  dismissHandoff: () => void;
  resumeHandoff: () => Promise<void>;
}

const AudioContext = createContext<AudioContextType>({
  currentTrack: null,
  isPlaying: false,
  currentTime: 0,
  duration: 0,
  playbackRate: 1,
  volume: 1,
  handoffSession: null,
  selectedVoice: null,
  availableVoices: [],
  isSwitchingVoice: false,
  setVoice: async () => false,
  playTrack: () => {},
  togglePlay: () => {},
  pause: () => {},
  resume: () => {},
  seek: () => {},
  skip: () => {},
  setPlaybackRate: () => {},
  setVolume: () => {},
  closePlayer: () => {},
  dismissHandoff: () => {},
  resumeHandoff: async () => {},
});

export const AudioProvider: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  const [currentTrack, setCurrentTrack] = useState<AudioTrack | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [playbackRate, setPlaybackRateState] = useState(1);
  const [volume, setVolumeState] = useState(1);
  const [handoffSession, setHandoffSession] = useState<ActivePlaybackSession | null>(null);
  const [availableVoices, setAvailableVoices] = useState<VoicePersona[]>([]);
  const [selectedVoice, setSelectedVoice] = useState<VoicePersona | null>(null);
  const [isSwitchingVoice, setIsSwitchingVoice] = useState(false);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const lastSyncTimeRef = useRef<number>(0);

  // Load voice personas and user preferred voice on mount
  useEffect(() => {
    async function loadVoices() {
      try {
        const catalog = await api.getVoiceCatalog();
        if (catalog && catalog.voices) {
          setAvailableVoices(catalog.voices);
          const savedVoiceId =
            typeof window !== "undefined"
              ? localStorage.getItem("blinkist_preferred_voice")
              : null;
          const initialVoice =
            catalog.voices.find((v) => v.id === savedVoiceId) ||
            catalog.voices.find((v) => v.id === catalog.default_voice) ||
            catalog.voices[0];
          setSelectedVoice(initialVoice || null);
        }
      } catch (_) {}
    }
    loadVoices();
  }, []);

  // Check for active sessions from other devices on mount and tab focus
  const checkCrossDeviceSession = useCallback(async () => {
    try {
      const session = await api.getActivePlaybackSession("web");
      if (session && session.has_active_session && session.can_resume) {
        // Only prompt if different track or significantly different position
        setHandoffSession(session);
      }
    } catch (_) {}
  }, []);

  useEffect(() => {
    checkCrossDeviceSession();

    const handleVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        checkCrossDeviceSession();
      }
    };

    window.addEventListener("focus", checkCrossDeviceSession);
    document.addEventListener("visibilitychange", handleVisibilityChange);

    return () => {
      window.removeEventListener("focus", checkCrossDeviceSession);
      document.removeEventListener("visibilitychange", handleVisibilityChange);
    };
  }, [checkCrossDeviceSession]);

  useEffect(() => {
    const audio = new Audio();
    audioRef.current = audio;

    const onTimeUpdate = () => {
      setCurrentTime(audio.currentTime);

      // Heartbeat sync every 5 seconds while playing
      const now = Date.now();
      if (now - lastSyncTimeRef.current > 5000 && currentTrack) {
        lastSyncTimeRef.current = now;
        api.updateActivePlaybackSession({
          book_id: currentTrack.bookId,
          book_slug: currentTrack.bookSlug,
          section_id: typeof currentTrack.id === "number" ? currentTrack.id : null,
          position_seconds: audio.currentTime,
          duration_seconds: audio.duration,
          device_type: "web",
          device_name: "Desktop Web",
          is_playing: true,
        });
      }
    };

    const onLoadedMetadata = () => {
      setDuration(audio.duration || 0);
    };

    const onEnded = () => {
      setIsPlaying(false);
      setCurrentTime(0);
      if (currentTrack) {
        api.updateActivePlaybackSession({
          book_id: currentTrack.bookId,
          book_slug: currentTrack.bookSlug,
          section_id: typeof currentTrack.id === "number" ? currentTrack.id : null,
          position_seconds: audio.duration || 0,
          duration_seconds: audio.duration,
          device_type: "web",
          device_name: "Desktop Web",
          is_playing: false,
          is_finished: true,
        });
      }
    };

    const onPlay = () => setIsPlaying(true);
    const onPause = () => {
      setIsPlaying(false);
      if (currentTrack) {
        api.updateActivePlaybackSession({
          book_id: currentTrack.bookId,
          book_slug: currentTrack.bookSlug,
          section_id: typeof currentTrack.id === "number" ? currentTrack.id : null,
          position_seconds: audio.currentTime,
          duration_seconds: audio.duration,
          device_type: "web",
          device_name: "Desktop Web",
          is_playing: false,
        });
      }
    };

    audio.addEventListener("timeupdate", onTimeUpdate);
    audio.addEventListener("loadedmetadata", onLoadedMetadata);
    audio.addEventListener("ended", onEnded);
    audio.addEventListener("play", onPlay);
    audio.addEventListener("pause", onPause);

    return () => {
      audio.pause();
      audio.removeEventListener("timeupdate", onTimeUpdate);
      audio.removeEventListener("loadedmetadata", onLoadedMetadata);
      audio.removeEventListener("ended", onEnded);
      audio.removeEventListener("play", onPlay);
      audio.removeEventListener("pause", onPause);
    };
  }, [currentTrack]);

  const playTrack = useCallback(
    (track: AudioTrack) => {
      const trackWithVoice: AudioTrack = {
        ...track,
        voiceId: track.voiceId || selectedVoice?.id || "christopher",
        voiceName: track.voiceName || selectedVoice?.name || "Christopher",
      };
      setCurrentTrack(trackWithVoice);

      sentry.addBreadcrumb({
        category: "audio",
        message: `Started audio playback: "${track.sectionTitle || track.bookTitle}" (${trackWithVoice.voiceName})`,
        data: { bookSlug: track.bookSlug, voiceId: trackWithVoice.voiceId },
      });

      if (audioRef.current) {
        audioRef.current.src = track.audioUrl;
        audioRef.current.playbackRate = playbackRate;
        audioRef.current.volume = volume;
        audioRef.current.currentTime = 0;
        audioRef.current.play().catch(() => {});
      }
    },
    [playbackRate, volume, selectedVoice]
  );

  const setVoice = useCallback(
    async (voiceId: string): Promise<boolean> => {
      const targetVoice = availableVoices.find((v) => v.id === voiceId);
      if (!targetVoice) return false;

      setSelectedVoice(targetVoice);
      if (typeof window !== "undefined") {
        localStorage.setItem("blinkist_preferred_voice", voiceId);
      }
      api.setPreferredVoice(voiceId);

      // Seamless live voice switching if current track has section details
      if (currentTrack && currentTrack.bookSlug && currentTrack.sectionSlug) {
        setIsSwitchingVoice(true);
        try {
          const audioData = await api.getSectionVoiceAudio(
            currentTrack.bookSlug,
            currentTrack.sectionSlug,
            voiceId
          );
          if (audioData && audioData.audio_url && audioRef.current) {
            const wasPlaying = isPlaying;
            const currentPos = audioRef.current.currentTime;
            audioRef.current.src = audioData.audio_url;
            audioRef.current.currentTime = currentPos;
            setCurrentTime(currentPos);
            setCurrentTrack({
              ...currentTrack,
              audioUrl: audioData.audio_url,
              voiceId: targetVoice.id,
              voiceName: targetVoice.name,
            });
            if (wasPlaying) {
              audioRef.current.play().catch(() => {});
            }
          }
        } catch (_) {
        } finally {
          setIsSwitchingVoice(false);
        }
      }
      return true;
    },
    [availableVoices, currentTrack, isPlaying]
  );

  const togglePlay = useCallback(() => {
    if (!audioRef.current || !currentTrack) return;
    if (isPlaying) {
      audioRef.current.pause();
    } else {
      audioRef.current.play().catch(() => {});
    }
  }, [isPlaying, currentTrack]);

  const pause = useCallback(() => {
    audioRef.current?.pause();
  }, []);

  const resume = useCallback(() => {
    audioRef.current?.play().catch(() => {});
  }, []);

  const seek = useCallback((seconds: number) => {
    if (audioRef.current) {
      audioRef.current.currentTime = seconds;
      setCurrentTime(seconds);
    }
  }, []);

  const skip = useCallback(
    (seconds: number) => {
      if (audioRef.current) {
        const nextTime = Math.max(
          0,
          Math.min(audioRef.current.currentTime + seconds, duration)
        );
        audioRef.current.currentTime = nextTime;
        setCurrentTime(nextTime);
      }
    },
    [duration]
  );

  const setPlaybackRate = useCallback((rate: number) => {
    setPlaybackRateState(rate);
    if (audioRef.current) {
      audioRef.current.playbackRate = rate;
    }
  }, []);

  const setVolume = useCallback((vol: number) => {
    setVolumeState(vol);
    if (audioRef.current) {
      audioRef.current.volume = vol;
    }
  }, []);

  const closePlayer = useCallback(() => {
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = "";
    }
    setCurrentTrack(null);
    setIsPlaying(false);
    setCurrentTime(0);
    setDuration(0);
  }, []);

  const dismissHandoff = useCallback(() => {
    setHandoffSession(null);
  }, []);

  const resumeHandoff = useCallback(async () => {
    if (!handoffSession) return;
    const session = handoffSession;
    setHandoffSession(null);

    // Call backend handoff API
    await api.handoffPlaybackSession("web", "Desktop Web");

    // Load and seek track
    const track: AudioTrack = {
      id: session.section_id || `book_${session.book_id}`,
      bookId: session.book_id || 1,
      bookSlug: session.book_slug || "atomic-habits",
      bookTitle: session.book_title || "Book",
      authorName: session.author_name || "Author",
      coverUrl: session.cover_image_url,
      sectionTitle: session.section_title || "Summary",
      sectionIndex: Math.max(0, (session.section_order || 1) - 1),
      totalSections: session.total_sections || 1,
      audioUrl: session.audio_url || "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
      durationSeconds: session.duration_seconds || 600,
    };

    setCurrentTrack(track);
    if (audioRef.current) {
      audioRef.current.src = track.audioUrl;
      audioRef.current.currentTime = session.position_seconds || 0;
      setCurrentTime(session.position_seconds || 0);
      audioRef.current.play().catch(() => {});
    }
  }, [handoffSession]);

  return (
    <AudioContext.Provider
      value={{
        currentTrack,
        isPlaying,
        currentTime,
        duration,
        playbackRate,
        volume,
        handoffSession,
        selectedVoice,
        availableVoices,
        isSwitchingVoice,
        setVoice,
        playTrack,
        togglePlay,
        pause,
        resume,
        seek,
        skip,
        setPlaybackRate,
        setVolume,
        closePlayer,
        dismissHandoff,
        resumeHandoff,
      }}
    >
      {children}
    </AudioContext.Provider>
  );
};

export const useAudio = () => useContext(AudioContext);
