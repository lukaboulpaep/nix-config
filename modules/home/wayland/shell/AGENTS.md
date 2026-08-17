# Wayland desktop shell

## Scope

- QML is cross-platform, but this shell deliberately targets Wayland shell surfaces and protocols. Supporting another window system requires an explicit architectural decision.
- Discover enabled compositors, hosts, package versions, and existing components from the Nix configuration; do not record current selections here.
- Keep deployment in `default.nix` and shell behavior in `src/`. The module is Linux/Wayland-specific and must stay out of macOS imports.
- Put `//@ pragma ShellId luka-shell` in `src/shell.qml`, and keep all QML imports and assets beneath `src/`.

## Architecture

- Shared UI must consume compositor-neutral services. Prefer Wayland and Freedesktop protocols; isolate compositor-specific types, IPC, and commands in backends.
- Do not build speculative backends. Add one only with a configured compositor and real-session verification.
- Prefer `Quickshell.WindowManager` for workspaces. For each panel screen, use `WindowManager.screenProjection(screen).windowsets` and respect `shouldDisplay`.
- Check capabilities before invoking Windowset operations: `canActivate`, `canDeactivate`, `canRemove`, and `canSetProjection`. Hide or disable unsupported controls.
- Do not assume fixed workspace numbers or stable numeric indices. Preserve compositor-provided identity, order, names, coordinates, active state, and urgency; workspace policy belongs in the host or backend.
- Build per-output surfaces from `Quickshell.screens`; do not hard-code output names. Account for logical pixels, fractional scaling, and output hot-plugging.
- For compositor IPC, prefer documented machine-readable event streams over polling or parsing human-readable output. Handle unavailable capabilities, unknown events, reconnects, and compositor restarts.

## Nix and safety

- Let Home Manager install dependencies, deploy the configuration, and run the shell with `graphical-session.target`. Keep runtime dependencies declarative.
- Replace existing components incrementally and avoid duplicate protocol owners, especially notification daemons and session lockers.
- Treat locking and PAM as security-sensitive. Retain the existing locker until suspend, resume, failed authentication, output changes, and shell crashes are tested.

## Verification

- Resolve documentation through Context7 using the package versions pinned by the evaluated flake.
- Keep generated `.qmlls.ini` contents uncommitted and use the editable `src/` path for hot reload during development.
- Test every claimed compositor backend in a real session. After Nix changes, evaluate or build each affected `nixosConfiguration` before switching.
