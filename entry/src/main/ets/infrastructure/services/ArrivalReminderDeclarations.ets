import { GeoFence } from '@amap/amap_lbs_location';

export interface GeoFenceListLike {
  length?: number;
  size?: number | (() => number);
  get?: (index: number) => GeoFence | undefined;
  forEach?: (callback: (value: GeoFence) => void) => void;
}
