## halcyon — lean Hyprland gaming desktop on fedora-bootc

Thank you for contributing!

- Read [AGENTS.md](https://github.com/aahsnr-work/halcyon/blob/container/AGENTS.md)
  first — it documents the build architecture rules (stage order, repo
  lifecycle, per-stage verification, bootc constraints) every change must respect.
- Run `just check` and `just lint` locally before opening the PR; if you touched
  `build_files/python-packages/`, also `just lint-python` and `just test-python`.
- Use a [semantic](https://www.conventionalcommits.org) PR title (`feat:`, `fix:`,
  `refactor:`, `docs:`, `chore:`, …). `.github/workflows/semantic-pr.yml`
  enforces it on the title.
- Changes under `build_files/` cost a full ~40-minute CI build on mistake —
  double-check package names against `packages.json` groups.

### Checklist

- [ ] `just check` / `just lint` pass locally
- [ ] Every new gate was inverted once and confirmed to fail
- [ ] New install stage has a `<stage>-verify` companion wired into the same RUN
- [ ] Third-party repos enabled and disabled within the same stage
- [ ] Nothing new lands in `/var`, `/usr/etc`, `/usr/local` or `/boot`
- [ ] Every binary a new ujust recipe calls is in `packages.json`
- [ ] Workflow changes: no `@main`/`@master` pins, no `ubuntu-latest`
- [ ] Comments explaining _why_ are preserved
