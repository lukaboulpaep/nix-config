import { registerHooks } from "node:module";

// Pi provides these private server modules in its own runtime. The published
// coding-agent package imports them eagerly, so standalone extension tests use
// inert stubs for the server APIs that the Gondolin extension never calls.
const stubs = new Map([
  [
    "@earendil-works/pi-server",
    `export class ServerError extends Error {}
export class SessionAmbiguousError extends Error {}
export class SessionNotFoundError extends Error {}`,
  ],
  [
    "@earendil-works/pi-server/unix",
    `export function createUnixServer() { throw new Error("unused test stub"); }
export function getUnixSocketPath() { throw new Error("unused test stub"); }`,
  ],
]);

registerHooks({
  resolve(specifier, context, nextResolve) {
    const source = stubs.get(specifier);
    if (source === undefined) return nextResolve(specifier, context);
    return {
      format: "module",
      shortCircuit: true,
      url: `data:text/javascript,${encodeURIComponent(source)}`,
    };
  },
});
