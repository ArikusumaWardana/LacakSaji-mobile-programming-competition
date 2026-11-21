// Ambient type declarations for Supabase Edge Functions (Deno runtime)
// so standard TypeScript IDE servers can type-check functions cleanly.

declare module "jsr:@supabase/functions-js/edge-runtime.d.ts" {}

declare namespace Deno {
  const env: {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    delete(key: string): void;
    toObject(): Record<string, string>;
  };

  interface ServeHandlerInfo {
    remoteAddr: {
      transport: string;
      hostname: string;
      port: number;
    };
  }

  type ServeHandler = (
    request: Request,
    info?: ServeHandlerInfo,
  ) => Response | Promise<Response>;

  interface ServeOptions {
    port?: number;
    hostname?: string;
    signal?: AbortSignal;
    onError?: (error: unknown) => Response | Promise<Response>;
    onListen?: (params: { hostname: string; port: number }) => void;
  }

  function serve(handler: ServeHandler): { finished: Promise<void> };
  function serve(
    options: ServeOptions,
    handler: ServeHandler,
  ): { finished: Promise<void> };
}
