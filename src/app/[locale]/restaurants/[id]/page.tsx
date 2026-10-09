import { notFound } from "next/navigation";
import { setRequestLocale } from "next-intl/server";
import { z } from "zod";
import { RestaurantDetail } from "@/features/restaurants/components/RestaurantDetail";

type RestaurantPageProps = {
  params: Promise<{ locale: string; id: string }>;
};

export default async function RestaurantPage({ params }: RestaurantPageProps) {
  const { locale, id } = await params;
  setRequestLocale(locale);
  if (!z.string().uuid().safeParse(id).success) notFound();
  return <RestaurantDetail restaurantId={id} />;
}
