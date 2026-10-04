"use client";

import React, { useState } from "react";
import { AuthProvider } from "@/features/auth/hooks/useAuth";
import { LoginModal } from "@/features/auth/components/LoginModal";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

export function AppProviders({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        {children}
        <LoginModal />
      </AuthProvider>
    </QueryClientProvider>
  );
}
