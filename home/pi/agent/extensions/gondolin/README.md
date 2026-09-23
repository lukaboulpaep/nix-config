# Gondolin sandbox

Pi uses one general-purpose Alpine microVM per session. Baseline guest packages
are declared in `home/pi/default.nix` under `alpine.rootfsPackages` (Git, Bash,
ripgrep, curl, SSH, jq, and basic system utilities).

There is no automatic flake evaluation, toolchain provisioning, per-project
image selection, or host-command fallback. Missing guest commands fail normally.
The central `gondolin.json` defines VM resources and HTTP/SSH allowlists.

The managed base image is rebuilt during Home Manager activation when its
builder changes. Guest disk writes are ephemeral; workspace edits persist through
the read-write mount. `GONDOLIN_GUEST_DIR` can explicitly override the base image.

Search tools honor ignore rules and support cancellation.

## Retired provisioning cache

The old `$XDG_CACHE_HOME/pi-gondolin/toolchains` directory (normally
`~/.cache/pi-gondolin/toolchains`) is no longer used. After stopping any old
Gondolin sessions, it can be deleted to reclaim space. Do not delete the sibling
`guest` directory, which holds the managed base image. No cache is automatically
removed during this rollback.

## Validation

Run `npm run check` and `npm test` from this directory. The real-VM integration
suite is opt-in with `GONDOLIN_TEST_VM=1` and requires Gondolin image assets and
hypervisor support.
