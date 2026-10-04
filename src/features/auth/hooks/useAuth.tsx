"use client";

import React, { createContext, useContext, useEffect, useState } from "react";
import { User, Session } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/client";
import { authRepository } from "@/features/auth/repository";
import { Profile } from "@/features/auth/types";

interface AuthContextType {
  user: User | null;
  profile: Profile | null;
  session: Session | null;
  isLoading: boolean;
  isGuest: boolean;
  refreshProfile: () => Promise<void>;
  requireAuth: (action: () => void | Promise<void>) => Promise<void>;
  showLoginModal: boolean;
  setShowLoginModal: (show: boolean) => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [pendingAction, setPendingAction] = useState<(() => void | Promise<void>) | null>(null);

  const supabase = React.useMemo(() => createClient(), []);

  const loadProfile = async (userId: string) => {
    try {
      const p = await authRepository.getProfile(userId);
      setProfile(p);
    } catch (err) {
      console.error("Lỗi tải hồ sơ:", err);
    }
  };

  const refreshProfile = async () => {
    if (user?.id) {
      await loadProfile(user.id);
    }
  };

  useEffect(() => {
    // 1. Kiểm tra session ban đầu
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      if (session?.user) {
        loadProfile(session.user.id);
      }
      setIsLoading(false);
    });

    // 2. Lắng nghe thay đổi trạng thái Auth
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, currentSession) => {
      setSession(currentSession);
      setUser(currentSession?.user ?? null);
      if (currentSession?.user) {
        await loadProfile(currentSession.user.id);
        // Nếu vừa đăng nhập và có hành động ghi đang chờ, thực thi
        if (pendingAction) {
          try {
            await pendingAction();
          } finally {
            setPendingAction(null);
            setShowLoginModal(false);
          }
        }
      } else {
        setProfile(null);
      }
      setIsLoading(false);
    });

    return () => {
      subscription.unsubscribe();
    };
  }, [supabase, pendingAction]);

  // Hành vi cho chế độ Khách (Guest mode):
  // Khách xem bình thường. Chỉ khi gọi requireAuth() để thực hiện ghi mới mở modal đăng nhập.
  const requireAuth = async (action: () => void | Promise<void>) => {
    if (user) {
      await action();
    } else {
      setPendingAction(() => action);
      setShowLoginModal(true);
    }
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        profile,
        session,
        isLoading,
        isGuest: !user,
        refreshProfile,
        requireAuth,
        showLoginModal,
        setShowLoginModal,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
