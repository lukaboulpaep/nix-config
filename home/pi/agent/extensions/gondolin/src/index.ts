import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { loadConfig } from "./config/config.ts";
import { createVm } from "./config/vm.ts";
import { createGuestTools } from "./tools.ts";

export default function main(pi: ExtensionAPI) {
  const hostWorkspace = process.cwd();
  const config = loadConfig();
  let vm: Awaited<ReturnType<typeof createVm>> | undefined;
  let ready = false;
  const guest = createGuestTools(
    () => {
      if (!vm || !ready)
        throw new Error("Gondolin is not ready; host execution is disabled");
      return vm;
    },
    hostWorkspace,
    config.vm.workspace,
  );

  for (const tool of guest.tools) {
    pi.registerTool(tool);
  }

  // Block unsupported built-in execution backends rather than leaving an escape hatch.
  pi.on("tool_call", async (event) => {
    if (event.toolName === "powershell" || !ready) {
      return {
        block: true,
        reason: "Gondolin sandbox unavailable or unsupported tool",
      };
    }
  });
  pi.on("user_bash", async () => ({ operations: guest.bashOperations }));
  pi.on("before_agent_start", async (event) => ({
    systemPrompt: `${event.systemPrompt}\n\nTools execute in a Gondolin Alpine VM. Guest working directory: ${config.vm.workspace}. Host workspace ${hostWorkspace} is mounted there read-write; changes persist on the host. Other absolute paths refer to the guest. Host environment and credentials are not forwarded.`,
  }));

  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.setStatus("gondolin", "Gondolin: starting");

    try {
      vm = await createVm(config, hostWorkspace);
      await vm.start();
      const probe = await vm.exec(["/bin/bash", "-lc", 'test -d "$PWD"'], {
        cwd: config.vm.workspace,
      });
      if (probe.exitCode !== 0)
        throw new Error("Gondolin workspace probe failed");
      ready = true;
      ctx.ui.setStatus("gondolin", `Gondolin: ${vm.id.slice(0, 8)}`);
    } catch (error) {
      ready = false;
      await vm?.close().catch(() => {});
      vm = undefined;
      ctx.ui.setStatus("gondolin", "Gondolin: unavailable (tools blocked)");
      ctx.ui.notify(
        error instanceof Error ? error.message : "Gondolin failed to start",
        "error",
      );

      throw error;
    }
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    ready = false;
    const activeVm = vm;
    vm = undefined;

    if (activeVm) {
      await activeVm.close();
    }

    ctx.ui.setStatus("gondolin", undefined);
  });
}
