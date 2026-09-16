import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { after, before, describe, it } from "node:test";
import type {
  ExtensionContext,
  ToolDefinition,
} from "@earendil-works/pi-coding-agent";
import { createVm } from "./config/vm.ts";
import { createGuestTools } from "./tools.ts";

const TEST_CONTEXT = {} as ExtensionContext;

type GuestTools = ReturnType<typeof createGuestTools>;

async function executeTool(
  guest: GuestTools,
  name: string,
  params: Record<string, unknown>,
): Promise<string> {
  const tool: ToolDefinition | undefined = guest.tools.find(
    (candidate) => candidate.name === name,
  );
  assert.ok(tool, `expected ${name} to be registered`);

  const result = await tool.execute(
    "test-call",
    params,
    undefined,
    undefined,
    TEST_CONTEXT,
  );
  return result.content
    .filter((item) => item.type === "text")
    .map((item) => item.text)
    .join("\n");
}

describe("when the VM is unavailable", () => {
  const guest = createGuestTools(
    () => {
      throw new Error("VM unavailable");
    },
    process.cwd(),
    "/workspace",
  );

  const calls: ReadonlyArray<readonly [string, Record<string, unknown>]> = [
    ["read", { path: "/etc/passwd" }],
    ["write", { path: "/workspace/test", content: "test" }],
    [
      "edit",
      {
        path: "/etc/passwd",
        edits: [{ oldText: "root", newText: "test" }],
      },
    ],
    ["bash", { command: "echo host-fallback" }],
    ["ls", {}],
    ["find", { pattern: "*" }],
    ["grep", { pattern: "root" }],
  ];

  for (const [name, params] of calls) {
    it(`${name} fails closed instead of using the host`, async () => {
      await assert.rejects(() => executeTool(guest, name, params));
    });
  }

  it("user shell commands fail closed instead of using the host", async () => {
    await assert.rejects(
      () =>
        guest.bashOperations.exec("true", process.cwd(), {
          onData() {},
        }),
      /VM unavailable/,
    );
  });
});

describe(
  "tool routing through a real VM",
  { skip: process.env.GONDOLIN_TEST_VM !== "1", timeout: 120_000 },
  () => {
    let workspace: string;
    let vm: Awaited<ReturnType<typeof createVm>>;
    let guest: GuestTools;

    before(async () => {
      workspace = await mkdtemp(path.join(tmpdir(), "gondolin-tools-"));
      await writeFile(path.join(workspace, "input.txt"), "original\n");
      vm = await createVm(
        {
          vm: { cpus: 2, memory: "2G", workspace: "/project" },
          network: { httpHosts: [], sshHosts: [] },
        },
        workspace,
      );
      await vm.start();
      guest = createGuestTools(() => vm, workspace, "/project");
    });

    after(async () => {
      await vm?.close();
      await rm(workspace, { recursive: true, force: true });
    });

    it("bash runs in Alpine at the guest workspace without host environment variables", async () => {
      process.env.GONDOLIN_HOST_SECRET_TEST = "host secret";
      try {
        const output = await executeTool(guest, "bash", {
          command:
            "cat /etc/os-release; pwd; printf '%s' \"${GONDOLIN_HOST_SECRET_TEST-unset}\"",
        });
        assert.match(output, /Alpine[\s\S]*\/project[\s\S]*unset/);
      } finally {
        delete process.env.GONDOLIN_HOST_SECRET_TEST;
      }
    });

    it("read maps an absolute host-workspace path into the guest mount", async () => {
      const output = await executeTool(guest, "read", {
        path: path.join(workspace, "input.txt"),
      });
      assert.match(output, /original/);
    });

    it("edit writes through the guest mount to the host workspace", async () => {
      await executeTool(guest, "edit", {
        path: "input.txt",
        edits: [{ oldText: "original", newText: "changed" }],
      });
      assert.equal(
        await readFile(path.join(workspace, "input.txt"), "utf8"),
        "changed\n",
      );
    });

    it("write creates host-workspace files through the guest mount", async () => {
      await executeTool(guest, "write", {
        path: "sub/output.txt",
        content: "guest output\n",
      });
      assert.equal(
        await readFile(path.join(workspace, "sub/output.txt"), "utf8"),
        "guest output\n",
      );
    });

    it("ls lists the guest workspace", async () => {
      assert.match(await executeTool(guest, "ls", {}), /input.txt/);
    });

    it("find searches files in the guest workspace", async () => {
      assert.match(
        await executeTool(guest, "find", { pattern: "*.txt" }),
        /sub\/output.txt/,
      );
    });

    it("grep reads file contents inside the guest", async () => {
      assert.match(
        await executeTool(guest, "grep", { pattern: "changed" }),
        /input.txt/,
      );
    });

    it("user shell commands ignore explicitly supplied host environment variables", async () => {
      let output = "";
      await guest.bashOperations.exec(
        "pwd; printf '%s' \"${GONDOLIN_HOST_SECRET_TEST-unset}\"",
        workspace,
        {
          onData: (data) => {
            output += data.toString();
          },
          env: { GONDOLIN_HOST_SECRET_TEST: "host secret" },
        },
      );
      assert.equal(output.trim(), "/project\nunset");
    });

    it("user shell commands honor timeouts", async () => {
      await assert.rejects(
        () =>
          guest.bashOperations.exec("sleep 10", workspace, {
            onData() {},
            timeout: 0.1,
          }),
        /timeout/,
      );
    });

    it("user shell commands honor cancellation", async () => {
      const controller = new AbortController();
      controller.abort();
      await assert.rejects(
        () =>
          guest.bashOperations.exec("true", workspace, {
            onData() {},
            signal: controller.signal,
          }),
        /aborted/,
      );
    });
  },
);
