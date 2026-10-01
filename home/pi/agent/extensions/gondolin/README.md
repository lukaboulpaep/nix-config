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

## GitHub pushes via the host SSH agent

SSH egress is allowed only to `github.com`. Gondolin uses the `SSH_AUTH_SOCK`
inherited by Pi to authenticate upstream; neither private keys nor the agent
socket are mounted into the guest. HTTP access remains disabled.

The existing Zsh/keychain configuration loads `~/.ssh/id_ed25519`. Before
starting Pi, run these commands **in a host terminal**:

```sh
ssh-add -l                         # Check that your GitHub key is loaded
ssh -T git@github.com              # Verify authentication and known_hosts
```

If necessary, load your key with `ssh-add ~/.ssh/id_ed25519`. Verify any new
GitHub host-key fingerprint against GitHub's published fingerprints before
accepting it. GitHub's successful `ssh -T` greeting normally exits with status 1.
Launch Pi from that same terminal so it inherits the agent socket.

Git inside the guest uses noninteractive SSH with `StrictHostKeyChecking=accept-new`
for Gondolin's proxy key, stored only in the ephemeral guest. The real GitHub
host key is still checked against the **host's** `~/.ssh/known_hosts` by Gondolin;
upstream verification is not disabled. No GitHub token is required for SSH remotes.

After deploying the updated Home Manager configuration, restart Pi to create a
new VM with this allowlist. Test without pushing:

```sh
git ls-remote origin
```

VM initialization configures `safe.directory` for exactly `vm.workspace` in the
ephemeral guest's global Git configuration before enabling tools. This handles
the host/guest ownership difference without per-command flags, wildcard trust,
or changes to the host's Git configuration. Initialization failures keep tools
blocked. Restart Pi after deploying this change; existing VMs do not pick it up.

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
