import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";

const BROKER_URL = (process.env.BROWSPI_BROWSER_BROKER_URL || "http://127.0.0.1:8766").replace(/\/+$/, "");

const browserGuidelines = [
  "Use browser_get_page_context before browser_click when the page changed or when you need current-page information.",
  "Prefer DOM sarathiId values from browser_get_page_context over browser_click coordinates.",
  "Ask for explicit user confirmation before destructive, payment, checkout, delete, remove, subscribe, buy, pay, or confirm actions.",
  "Do not enter passwords, API keys, tokens, or other secrets with browser_type unless the user explicitly provided the secret and confirmed that it should be entered.",
  "Never bypass CAPTCHAs or anti-bot checks with browser tools.",
  "For current-page questions, call browser_get_page_context and answer without unnecessary browser actions.",
  "Do not request cookies or localStorage, and do not rely on password field values; Browspi redacts password values."
];

const dangerousPattern = /\b(pay|payment|buy|checkout|delete|remove|subscribe|confirm)\b/i;
const browserIntentPattern = /\b(browser|web|page|tab|site|url|open|search|find|click|type|press|scroll|youtube|google|github|article|current page|браузер|вкладк|страниц|сайт|открой|найди|поищи|клик|нажми|введи|напиши|проскрол|пролист|текущей странице|ютуб|гугл|гитхаб)\b/i;
const browserToolNames = [
  "browser_open_tab",
  "browser_get_active_tab",
  "browser_get_page_context",
  "browser_click",
  "browser_type",
  "browser_press",
  "browser_scroll",
  "browser_screenshot",
  "browser_wait"
];

type BrowserToolParams = Record<string, unknown>;

async function callBroker(action: string, params: BrowserToolParams, signal?: AbortSignal) {
  const response = await fetch(`${BROKER_URL}/browser-tools/call`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ action, params }),
    signal
  });

  let payload: any = null;
  const text = await response.text();
  if (text) {
    try { payload = JSON.parse(text); }
    catch { payload = { success: false, message: text }; }
  }

  if (!response.ok || payload?.success === false) {
    const message = payload?.message || payload?.error || `Browser broker error ${response.status}`;
    const error = new Error(message);
    (error as any).payload = payload;
    throw error;
  }

  return payload ?? { success: true };
}

function toolResult(result: any) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
    details: result ?? {}
  };
}

function toolError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  const payload = (error as any)?.payload;
  return {
    content: [{ type: "text" as const, text: JSON.stringify({ success: false, message, ...(payload ? { payload } : {}) }, null, 2) }],
    details: { success: false, message, payload },
    isError: true
  };
}

function registerBrowserTool(pi: ExtensionAPI, config: {
  name: string;
  label: string;
  description: string;
  action: string;
  parameters: any;
  promptSnippet: string;
  confirmDangerous?: (params: any) => boolean;
}) {
  pi.registerTool({
    name: config.name,
    label: config.label,
    description: config.description,
    promptSnippet: config.promptSnippet,
    promptGuidelines: config.name === "browser_get_page_context" ? browserGuidelines : [],
    parameters: config.parameters,
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      try {
        if (config.confirmDangerous?.(params)) {
          if (!ctx.hasUI) {
            throw new Error("Blocked dangerous browser action because no interactive confirmation UI is available.");
          }
          const ok = await ctx.ui.confirm(
            "Confirm browser action",
            `Allow ${config.name} with arguments ${JSON.stringify(params)}?`
          );
          if (!ok) throw new Error("User declined browser action.");
        }
        return toolResult(await callBroker(config.action, params as BrowserToolParams, signal));
      } catch (error) {
        return toolError(error);
      }
    }
  });
}

export default function (pi: ExtensionAPI) {
  registerBrowserTool(pi, {
    name: "browser_open_tab",
    label: "Browser: Open Tab",
    description: "Open a URL in a Chrome tab via Browspi.",
    action: "browser.openTab",
    promptSnippet: "Open a browser tab at a URL.",
    parameters: Type.Object({
      url: Type.String({ description: "URL or host to open" }),
      active: Type.Optional(Type.Boolean({ description: "Whether to activate the tab (default true)" }))
    })
  });

  registerBrowserTool(pi, {
    name: "browser_get_active_tab",
    label: "Browser: Active Tab",
    description: "Get the current active Chrome tab metadata.",
    action: "browser.getActiveTab",
    promptSnippet: "Get active browser tab URL and title.",
    parameters: Type.Object({})
  });

  registerBrowserTool(pi, {
    name: "browser_get_page_context",
    label: "Browser: Page Context",
    description: "Get current page URL, title, visible text, and optionally DOM element ids or screenshot.",
    action: "browser.getPageContext",
    promptSnippet: "Inspect the current browser page, including DOM sarathiId values for actions.",
    parameters: Type.Object({
      includeDom: Type.Optional(Type.Boolean({ description: "Include actionable DOM snapshot (default true)" })),
      includeText: Type.Optional(Type.Boolean({ description: "Include visible page text (default true)" })),
      includeScreenshot: Type.Optional(Type.Boolean({ description: "Include screenshot only when needed (default false)" }))
    })
  });

  registerBrowserTool(pi, {
    name: "browser_click",
    label: "Browser: Click",
    description: "Click a page element by sarathiId, visible text, or coordinates.",
    action: "browser.click",
    promptSnippet: "Click browser page elements; prefer sarathiId from page context.",
    confirmDangerous: (params) => dangerousPattern.test(String(params?.text || "")),
    parameters: Type.Object({
      sarathiId: Type.Optional(Type.String({ description: "DOM sarathiId from browser_get_page_context" })),
      text: Type.Optional(Type.String({ description: "Visible text/label fallback when sarathiId is unavailable" })),
      x: Type.Optional(Type.Number({ description: "Viewport x coordinate fallback" })),
      y: Type.Optional(Type.Number({ description: "Viewport y coordinate fallback" }))
    })
  });

  registerBrowserTool(pi, {
    name: "browser_type",
    label: "Browser: Type",
    description: "Type text into a focused or identified page element.",
    action: "browser.type",
    promptSnippet: "Type into a browser input; use sarathiId when possible.",
    parameters: Type.Object({
      sarathiId: Type.Optional(Type.String({ description: "DOM sarathiId of input/textarea/contenteditable element" })),
      text: Type.String({ description: "Text to enter" }),
      clear: Type.Optional(Type.Boolean({ description: "Clear existing value before typing (default true)" }))
    })
  });

  registerBrowserTool(pi, {
    name: "browser_press",
    label: "Browser: Press Key",
    description: "Send a keypress to the active page element.",
    action: "browser.press",
    promptSnippet: "Press Enter, Escape, Tab, or another key in the browser.",
    parameters: Type.Object({ key: Type.String({ description: "Key name, e.g. Enter, Escape, Tab" }) })
  });

  registerBrowserTool(pi, {
    name: "browser_scroll",
    label: "Browser: Scroll",
    description: "Scroll the current page up or down.",
    action: "browser.scroll",
    promptSnippet: "Scroll the browser page up or down.",
    parameters: Type.Object({
      direction: Type.Union([Type.Literal("up"), Type.Literal("down")]),
      amount: Type.Optional(Type.Number({ description: "Pixels to scroll; defaults to about one viewport" }))
    })
  });

  registerBrowserTool(pi, {
    name: "browser_screenshot",
    label: "Browser: Screenshot",
    description: "Capture the visible browser tab as a PNG data URL. Use sparingly because screenshots may contain sensitive information.",
    action: "browser.screenshot",
    promptSnippet: "Capture a visible browser screenshot when visual context is necessary.",
    parameters: Type.Object({})
  });

  registerBrowserTool(pi, {
    name: "browser_wait",
    label: "Browser: Wait",
    description: "Wait for a specified number of milliseconds.",
    action: "browser.wait",
    promptSnippet: "Wait briefly for page loads or dynamic content.",
    parameters: Type.Object({ ms: Type.Number({ description: "Milliseconds to wait" }) })
  });

  try {
    pi.setActiveTools([...new Set([...pi.getActiveTools(), ...browserToolNames])]);
  } catch {
    // If active-tool management is unavailable in a future runtime, registration still works.
  }

  pi.on("before_agent_start", async (event) => {
    const prompt = String(event.prompt || "");
    if (!browserIntentPattern.test(prompt)) return;
    return {
      systemPrompt: `${event.systemPrompt}\n\nBrowser control instructions:\n- You have real browser tools named browser_open_tab, browser_get_active_tab, browser_get_page_context, browser_click, browser_type, browser_press, browser_scroll, browser_screenshot, and browser_wait.\n- If the user asks to open a site, search the web, find information online, inspect the current page, click, type, press keys, or scroll, use these tools. Do not say you cannot browse.\n- For current-page questions, call browser_get_page_context first and answer from the returned context.\n- For search tasks, open a search engine or target site, use browser_get_page_context, and continue until you can answer or explain what blocked progress.\n- Prefer sarathiId from browser_get_page_context over coordinates for browser_click/browser_type.\n- Stop using browser tools once the requested browser task is complete, then give the user a concise result.`
    };
  });
}
