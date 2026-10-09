import { describe, expect, it } from "vitest";
import { reviewCursorFilter } from "./repository";
import type { ReviewCursor } from "./types";

const cursor: ReviewCursor = {
  id: "a4040000-0000-4000-8000-000000000005",
  rating: 4,
  helpful_count: 8,
  created_at: "2026-10-09T10:00:00.000Z",
};

describe("review keyset cursor filters", () => {
  it("uses created_at and id as stable tie-breakers for newest", () => {
    expect(reviewCursorFilter("newest", cursor)).toContain("id.lt." + cursor.id);
    expect(reviewCursorFilter("newest", cursor)).toContain("created_at.eq." + cursor.created_at);
  });

  it("continues helpful sorting through equal-count and timestamp ties", () => {
    const filter = reviewCursorFilter("helpful", cursor);
    expect(filter).toContain("helpful_count.lt.8");
    expect(filter).toContain("helpful_count.eq.8,created_at.lt." + cursor.created_at);
    expect(filter).toContain("id.lt." + cursor.id);
  });

  it("uses opposite rating comparison for low-first sorting", () => {
    expect(reviewCursorFilter("rating_low", cursor)).toContain("rating.gt.4");
    expect(reviewCursorFilter("rating_high", cursor)).toContain("rating.lt.4");
  });
});
