import { createHttpHooks, RealFSProvider, VM } from "@earendil-works/gondolin";
import type { GondolinConfig } from "./config.ts";

export async function configureGuestGit(
  vm: Pick<VM, "exec">,
  workspace: string,
): Promise<void> {
  // Trust only the host-mounted workspace, in the ephemeral guest's global
  // config. Never relax ownership checks for other repositories or the host.
  const result = await vm.exec(
    [
      "/usr/bin/git",
      "config",
      "--global",
      "--replace-all",
      "safe.directory",
      workspace,
    ],
    { cwd: "/" },
  );
  if (result.exitCode !== 0)
    throw new Error(
      `Gondolin Git trust initialization failed: ${result.stderr.trim()}`,
    );
}

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
    env: {
      ...env,
      // The guest sees Gondolin's proxy key, not GitHub's upstream key.
      // TOFU is limited to the ephemeral guest; Gondolin still verifies the
      // real upstream key against the host's OpenSSH known_hosts.
      ...(config.network.sshHosts.length > 0
        ? {
            GIT_SSH_COMMAND:
              "/usr/bin/ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new",
          }
        : {}),
    },
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
