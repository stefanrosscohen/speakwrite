export interface DigraphStats {
  count: number;
  mean: number;
  std_dev: number;
  median: number;
  p10: number;
  p90: number;
}

export interface Tier1Features {
  flight_time_mean: number;
  flight_time_std: number;
  flight_time_median: number;
  hold_time_mean: number;
  hold_time_std: number;
  digraph_count: number;
  digraph_matrix: Record<string, DigraphStats>;
  overlap_ratio: number;
  typing_speed_cpm: number;
}

export interface Tier2Features {
  backspace_rate: number;
  delete_rate: number;
  error_burst_count: number;
  mean_error_burst_length: number;
  immediate_correction_ratio: number;
  revision_ratio: number;
}

export interface FeatureVector {
  version: string;
  window_start_ms: number;
  window_end_ms: number;
  keystroke_count: number;
  tier1: Tier1Features;
  tier2: Tier2Features;
}
