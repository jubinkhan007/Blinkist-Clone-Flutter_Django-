"use client";

import React, {
  createContext,
  useContext,
  useState,
  useRef,
  useEffect,
  useCallback,
} from "react";
import { AudioTrack, ActivePlaybackSession } from "@/types";
import { api } from "@/lib/api";

interface AudioContextType {
  currentTrack: AudioTrack | null;
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  playbackRate: number;
  volume: number;
  handoffSession: ActivePlaybackSession | null;
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

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const lastSyncTimeRef = useRef<number>(0);

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
      setCurrentTrack(track);
      if (audioRef.current) {
        audioRef.current.src = track.audioUrl;
        audioRef.current.playbackRate = playbackRate;
        audioRef.current.volume = volume;
        audioRef.current.currentTime = 0;
        audioRef.current.play().catch(() => {});
      }
    },
    [playbackRate, volume]
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
