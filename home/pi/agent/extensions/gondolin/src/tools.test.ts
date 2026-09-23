import assert from "node:assert/strict";
import {
  access,
  mkdir,
  mkdtemp,
  readFile,
  rm,
  stat,
  writeFile,
} from "node:fs/promises";
import { spawn } from "node:child_process";
import type { VM } from "@earendil-works/gondolin";
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
  signal?: AbortSignal,
): Promise<string> {
  const tool: ToolDefinition | undefined = guest.tools.find(
    (candidate) => candidate.name === name,
  );
  assert.ok(tool, `expected ${name} to be registered`);

  const result = await tool.execute(
    "test-call",
    params,
    signal,
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

// Exercise the adapters with real ripgrep and a temporary filesystem, without
// requiring nested virtualization. Production still executes only via VM APIs.
describe("search ignore rules and cancellation", () => {
  let workspace: string;
  let guest: GuestTools;
  let lastSignal: AbortSignal | undefined;
  let abortRead: AbortController | undefined;
  let abortEnumeration: AbortController | undefined;
  let executions: number;

  before(async () => {
    workspace = await mkdtemp(path.join(tmpdir(), "gondolin-search-"));
    await mkdir(path.join(workspace, "sub"));
    await mkdir(path.join(workspace, "ignored"));
    await writeFile(
      path.join(workspace, ".gitignore"),
      "*.log\n!keep.log\nignored/\n/root.txt\n",
    );
    await writeFile(
      path.join(workspace, "sub/.gitignore"),
      "private.txt\n!nested.log\n",
    );
    for (const file of [
      "drop.log",
      "keep.log",
      "root.txt",
      "visible.txt",
      "ignored/secret.txt",
      "sub/private.txt",
      "sub/nested.log",
      "sub/drop.log",
      "sub/root.txt",
      "sub/space name.txt",
    ]) {
      await writeFile(path.join(workspace, file), "needle\n");
    }
    executions = 0;
    const fakeVm = {
      fs: {
        access: async (file: string, options?: { signal?: AbortSignal }) => {
          options?.signal?.throwIfAborted();
          await access(file);
        },
        stat: async (file: string, options?: { signal?: AbortSignal }) => {
          options?.signal?.throwIfAborted();
          return stat(file);
        },
        readFile: async (
          file: string,
          options: { encoding: "utf8"; signal?: AbortSignal },
        ) => {
          if (abortRead) {
            abortRead.abort();
            options.signal?.throwIfAborted();
          }
          return readFile(file, options);
        },
      },
      exec: (args: string[], options: { cwd: string; signal: AbortSignal }) => {
        executions++;
        lastSignal = options.signal;
        if (abortEnumeration) {
          const controller = abortEnumeration;
          queueMicrotask(() => controller.abort());
        }
        const child = spawn(args[0]!, args.slice(1), {
          cwd: options.cwd,
          signal: options.signal,
          stdio: ["ignore", "pipe", "pipe"],
        });
        const result = new Promise<{ exitCode: number }>((resolve, reject) => {
          child.on("error", reject);
          child.on("close", (code) => resolve({ exitCode: code ?? 1 }));
        });
        // Small fixtures produce no stderr; consume it to avoid blocked pipes.
        child.stderr.resume();
        return Object.assign(result, {
          async *output() {
            for await (const data of child.stdout) {
              yield { stream: "stdout", data: Buffer.from(data) };
            }
          },
        });
      },
    } as unknown as VM;
    guest = createGuestTools(() => fakeVm, workspace, workspace);
  });

  after(async () => {
    await rm(workspace, { recursive: true, force: true });
  });

  for (const name of ["find", "grep"]) {
    const params = name === "find" ? { pattern: "*" } : { pattern: "needle" };
    it(`${name} respects nested ignores, negations, anchored rules, and spaces outside Git repos`, async () => {
      const output = await executeTool(guest, name, params);
      for (const included of [
        "keep.log",
        "visible.txt",
        "sub/nested.log",
        "sub/root.txt",
        "sub/space name.txt",
      ]) {
        assert.ok(output.includes(included), `missing ${included}: ${output}`);
      }
      for (const excluded of ["drop.log", "private.txt", "secret.txt"]) {
        assert.ok(
          !output.includes(excluded),
          `unexpected ${excluded}: ${output}`,
        );
      }
      assert.ok(
        !output.split("\n").some((line) => line.startsWith("root.txt")),
      );
    });

    it(`${name} honors parent rules when searching a subdirectory`, async () => {
      const output = await executeTool(guest, name, { ...params, path: "sub" });
      assert.match(output, /nested.log/);
      assert.doesNotMatch(output, /drop.log|private.txt/);
    });

    it(`${name} does not start work when already cancelled`, async () => {
      const controller = new AbortController();
      controller.abort();
      const before = executions;
      await assert.rejects(
        executeTool(guest, name, params, controller.signal),
        /abort/i,
      );
      assert.equal(executions, before);
    });

    it(`${name} cancels an in-flight enumeration`, async () => {
      const controller = new AbortController();
      abortEnumeration = controller;
      try {
        await assert.rejects(
          executeTool(guest, name, params, controller.signal),
          /abort/i,
        );
        assert.equal(lastSignal?.aborted, true);
        // Let the underlying adapter finish cleanup after Pi rejects find.
        await new Promise((resolve) => setTimeout(resolve, 20));
      } finally {
        abortEnumeration = undefined;
      }
    });

    it(`${name} stops enumeration when the result limit is reached`, async () => {
      await executeTool(guest, name, { ...params, limit: 1 });
      assert.equal(lastSignal?.aborted, true);
    });
  }

  it("grep propagates cancellation during a file read instead of skipping the file", async () => {
    const controller = new AbortController();
    abortRead = controller;
    try {
      await assert.rejects(
        executeTool(guest, "grep", { pattern: "needle" }, controller.signal),
        /abort/i,
      );
      assert.equal(lastSignal?.aborted, true);
    } finally {
      abortRead = undefined;
    }
  });

  it("grep can still search an explicitly selected ignored file", async () => {
    assert.match(
      await executeTool(guest, "grep", { pattern: "needle", path: "drop.log" }),
      /needle/,
    );
  });
});
