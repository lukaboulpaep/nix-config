import { createHttpHooks, RealFSProvider, VM } from "@earendil-works/gondolin";
import type { GondolinConfig } from "./config.ts";

export async function createVm(
  config: GondolinConfig,
  hostWorkspace: string,
): Promise<VM> {
  const { httpHooks, env } = createHttpHooks({
    allowedHosts: config.network.httpHosts,
  });
  const imagePath = process.env.GONDOLIN_GUEST_DIR?.trim();

  return VM.create({
    sessionLabel: `pi ${hostWorkspace}`,
    cpus: config.vm.cpus,
    memory: config.vm.memory,
    ...(imagePath ? { sandbox: { imagePath } } : {}),
    httpHooks,
    env,
    dns: {
      mode: "synthetic",
      syntheticHostMapping: "per-host",
    },
    ssh: {
      allowedHosts: config.network.sshHosts,
      agent: process.env.SSH_AUTH_SOCK,
    },
    vfs: {
      mounts: {
        [config.vm.workspace]: new RealFSProvider(hostWorkspace),
      },
    },
  });
}
