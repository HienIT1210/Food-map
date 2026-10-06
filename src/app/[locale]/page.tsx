import { setRequestLocale } from "next-intl/server";
import { MapComponent } from "@/features/map/components/MapComponent";
import { GuestActionDemo } from "@/features/auth/components/GuestActionDemo";

type HomePageProps = {
  params: Promise<{ locale: string }>;
};

export default async function HomePage({ params }: HomePageProps) {
  const { locale } = await params;
  setRequestLocale(locale);

  return (
    <main className="flex min-h-screen w-full flex-col">
      <MapComponent />
      
      {/* 
        Trong tương lai, GuestActionDemo hoặc các thành phần khác có thể
        được chuyển vào modal hoặc bottom sheet khác. 
      */}
      <div className="absolute bottom-20 left-4 z-10 opacity-80 scale-75 origin-bottom-left">
        <GuestActionDemo />
      </div>
    </main>
  );
}
