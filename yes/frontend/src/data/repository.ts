import { initialData } from '@/data/fixtures';
import type { AppData } from '@/data/types';

export interface AppRepository {
  load(): Promise<AppData>;
  save(data: AppData): Promise<void>;
  reset(): Promise<AppData>;
}

const cloneInitialData = (): AppData => JSON.parse(JSON.stringify(initialData)) as AppData;
const STORAGE_KEY = 'elly.mock-data.v1';

/**
 * Drop-in development repository. The eventual client repository only needs
 * to implement the same three methods; screens never import fixtures directly.
 */
export const mockRepository: AppRepository = {
  async load() {
    if (typeof localStorage !== 'undefined') {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        try {
          const data = JSON.parse(saved) as AppData;
          for (const place of data.profile.savedPlaces) {
            if (place.label === 'ELLY Office') place.label = 'Work';
          }
          for (const event of data.profile.calendarEvents) {
            if (event.location.label === 'ELLY Office') event.location.label = 'Work';
            if (event.subtitle === 'ELLY Office · Level 4') event.subtitle = 'Work · Level 4';
          }
          return data;
        } catch {
          localStorage.removeItem(STORAGE_KEY);
        }
      }
    }
    return cloneInitialData();
  },
  async save(data) {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    }
  },
  async reset() {
    const next = cloneInitialData();
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    }
    return next;
  },
};
