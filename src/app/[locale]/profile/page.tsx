import { setRequestLocale } from "next-intl/server";
import { ProfileView } from "@/features/profile/components/ProfileView";

export default async function ProfilePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  return (
    <main className="mx-auto flex w-full max-w-lg flex-1 flex-col gap-6 px-6 py-12">
      <ProfileView />
    </main>
  );
}
