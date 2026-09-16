import { readFileSync } from "node:fs";
import { isObject, isStringArray } from "./utils.ts";

export type GondolinConfig = {
  vm: {
    cpus: number;
    memory: string;
    workspace: string;
  };
  network: {
    httpHosts: string[];
    sshHosts: string[];
  };
};

const configUrl = new URL("../../gondolin.json", import.meta.url);

export class ConfigError extends Error {
  override readonly name = "ConfigError";
}

function isVmConfig(value: unknown): value is GondolinConfig["vm"] {
  if (!isObject(value)) {
    return false;
  }

  return (
    typeof value.cpus === "number" &&
    Number.isSafeInteger(value.cpus) &&
    value.cpus > 0 &&
    typeof value.memory === "string" &&
    value.memory.length > 0 &&
    typeof value.workspace === "string" &&
    value.workspace.startsWith("/")
  );
}

function isNetworkConfig(value: unknown): value is GondolinConfig["network"] {
  return (
    isObject(value) &&
    isStringArray(value.httpHosts) &&
    isStringArray(value.sshHosts)
  );
}

function isGondolinConfig(value: unknown): value is GondolinConfig {
  return (
    isObject(value) && isVmConfig(value.vm) && isNetworkConfig(value.network)
  );
}

export function parseConfig(contents: string): GondolinConfig {
  let value: unknown;

  try {
    value = JSON.parse(contents);
  } catch (error) {
    throw new ConfigError("Gondolin configuration contains invalid JSON", {
      cause: error,
    });
  }

  if (!isGondolinConfig(value)) {
    throw new ConfigError(
      "Gondolin configuration must contain valid vm and network settings",
    );
  }
  return value;
}

export function loadConfig(): GondolinConfig {
  let contents: string;
  try {
    contents = readFileSync(configUrl, "utf8");
  } catch (error) {
    throw new ConfigError(
      `Cannot read Gondolin configuration at ${configUrl}`,
      {
        cause: error,
      },
    );
  }

  return parseConfig(contents);
}
