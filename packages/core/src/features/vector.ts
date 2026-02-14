import type { DigraphStats } from "../types/features";
import { mean, stdDev, median, percentile } from "./utils";

export function digraphStatsFromSamples(
  samples: number[],
): DigraphStats | null {
  if (samples.length < 5) return null;

  const sorted = [...samples].sort((a, b) => a - b);
  const n = sorted.length;
  const m = sorted.reduce((sum, v) => sum + v, 0) / n;
  const variance = sorted.reduce((sum, v) => sum + (v - m) ** 2, 0) / (n - 1);

  return {
    count: n,
    mean: m,
    std_dev: Math.sqrt(variance),
    median: sorted[Math.floor(n / 2)],
    p10: sorted[Math.floor(n * 0.1)],
    p90: sorted[Math.min(Math.floor(n * 0.9), n - 1)],
  };
}

export { mean, stdDev, median, percentile };
