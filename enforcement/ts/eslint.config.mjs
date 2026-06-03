// eslint.config.mjs — ESLint 9 flat-config snippet. Merge these objects into the frontend's
// existing flat config array (Vite + React + TS). Order matters: the `src/api/**` override must
// come AFTER the global block so it can switch `fetch` back on for the one allowed module.
//
// Wire-in: `npm run lint` (and `npx tsc --noEmit` for ADR-0008 strict TS, configured in tsconfig).

export default [
  {
    files: ["src/**/*.{ts,tsx}"],
    rules: {
      // ADR-0007: per-domain Zustand stores, not Redux.
      // ADR-0008: all backend calls go through the single typed client in src/api/.
      "no-restricted-imports": ["error", {
        paths: [
          { name: "redux",       message: "ADR-0007: use per-domain Zustand stores, not Redux." },
          { name: "react-redux", message: "ADR-0007: use per-domain Zustand stores, not Redux." },
          { name: "axios",       message: "ADR-0008: call the backend only through src/api/client.ts." },
        ],
      }],

      // ADR-0008: components never call fetch() directly — only the API client may.
      "no-restricted-globals": ["error",
        { name: "fetch", message: "ADR-0008: call the backend only through src/api/client.ts." },
      ],

      // ADR-0007 (heuristic, warn): React Context is fine for DI/theme, but not as a mutable
      // app-state container — that belongs in a Zustand store.
      "no-restricted-syntax": ["warn",
        {
          selector: "CallExpression[callee.name='createContext']",
          message: "ADR-0007: hold mutable app state in a Zustand store, not React Context.",
        },
      ],
    },
  },

  // The ONE place fetch is allowed: the typed API client (ADR-0008).
  {
    files: ["src/api/**/*.{ts,tsx}"],
    rules: {
      "no-restricted-globals": "off",
    },
  },
];
