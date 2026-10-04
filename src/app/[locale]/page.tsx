import { getTranslations, setRequestLocale } from "next-intl/server";
import { ProfileView } from "@/features/profile/components/ProfileView";
import { GuestActionDemo } from "@/features/auth/components/GuestActionDemo";

type HomePageProps = {
  params: Promise<{ locale: string }>;
};

export default async function HomePage({ params }: HomePageProps) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("home");

  return (
    <main className="mx-auto flex min-h-full w-full max-w-lg flex-1 flex-col justify-center gap-6 px-6 py-12">
      <div>
        <h1 className="text-3xl font-semibold tracking-tight">{t("title")}</h1>
        <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">
          {t("subtitle")}
        </p>
      </div>

      {/* Demo chế độ Khách vs Hành động ghi (DoD M2: khách chỉ xem, ghi yêu cầu đăng nhập) */}
      <GuestActionDemo />

      {/* Quản lý hồ sơ, đăng xuất, xoá tài khoản */}
      <ProfileView />
    </main>
  );
}
