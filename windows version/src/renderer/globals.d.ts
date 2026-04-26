import type { PiChatAPI } from '../preload';

declare global {
  interface Window {
    pichat: PiChatAPI;
  }
}

export {};
