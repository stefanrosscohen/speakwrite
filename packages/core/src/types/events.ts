export interface KeystrokeEvent {
  event_type: string;
  key: string;
  code: string;
  timestamp: number;
  shift_key: boolean;
  ctrl_key: boolean;
  alt_key: boolean;
  meta_key: boolean;
  repeat: boolean;
  is_composing: boolean;
  sequence_number: number;
}
