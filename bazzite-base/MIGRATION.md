# MIGRATION.md — halcyon rebuild: bootc Containerfile + p03 kernel + RPM monorepo

**Status:** plan (not yet executed) — replaces the former `ANDAMAN-MIGRATION.md`.
**Date:** 2026-09-19 · **Target Fedora:** 44 · **Plan iterations:** 5 (three required + two verification passes; logged in §1.3)

---

## 1. Foundations

### 1.1 Goals

1. **Move off BlueBuild** to a plain `Containerfile` system we fully control (FROM `quay.io/fedora/fedora-bootc`), rebuilt brick by brick.
2. **Replace the Fedora kernel with the p03 kernel** (CatPieLeaf/linux-p03) and its NVIDIA-open driver, keeping SELinux enforcing (verification steps included; full policy work is a later plan).
3. **Stand up a personal RPM monorepo** (`aahsnr-work/halcyon-packages`, anda-based, GitHub Actions builds, GitHub Pages serving) that ultimately owns **every** non-Fedora package the image needs — with **automated version management for every RPM** (no manual bumps, ever).
4. **Convert every Flatpak app** in the current flatpaks recipe to native RPMs from the monorepo.
5. **Mimic the current halcyon image** in every other respect (fonts, Plymouth, greetd + noctalia-greeter, nix, chezmoi, ujust, motd, backgrounds, verification gates), brick by brick.

### 1.2 Non-goals

- No CoreOS, no IoT base, no uCore.
- No Koji, no Fyra Labs infrastructure (Subatomic's public instance is employees-only — JWT held by Fyra staff only).
- Keep brave-browser, vscode, zed on their existing vendor/Terra repos for now (determination in §6.6).
- Full SELinux *policy authoring* is out of scope for this document — this plan keeps SELinux **enforcing** and verifies each component, but new policy modules are a separate effort.

### 1.3 Decision log (both Q&A rounds + iteration history)

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Base image: **`quay.io/fedora/fedora-bootc`** (standard) | Verified comparison in §2.1 — minimal variants are CI/curation content sets with unstable naming and stripped tools; base-main is built FROM Silverblue with pinned ublue kernels that fight a custom kernel. |
| D2 | Kernel: **p03, staged** — consume `catpieleaf/kernel-p03` COPR first, transfer CatPieLeaf's build files into the monorepo, build monthly in Actions | COPR already ships `kernel-p03`, `kernel-p03-gcc` and `kernel-p03-nvidia-open`, ABI-matched; staged ownership lowers risk. |
| D3 | NVIDIA: consume **`kernel-p03-nvidia-open`** from the COPR first; self-built akmods documented as a later phase | The COPR ships it built against its own kernels — self-building would duplicate working packages from day one. |
| D4 | Serving: **GitHub Pages** static dnf repo | No server; 1 GB site / 100 GB-mo is ample for ~50 packages; proven community patterns. Subatomic self-host documented as upgrade path (§10.2). |
| D5 | Monorepo: **`aahsnr-work/halcyon-packages`**, anda-based | User decision; anda gives monorepo change-detection (`anda ci`), build orchestration (`anda build`) and version automation (`anda update` + update.rhai). |
| D6 | brave/vscode: **stay on vendor repos** | Determination in §6.6. |
| D7 | TeX Live: **Arch-style grouped RPMs from dated tlnet-archive snapshots**, monthly/3-weekly cadence | Verified design in §7.3. |
| D8 | BlueBuild removal: recipes/ + blue-build action replaced by **Containerfile + plain workflows** | User directive. |

**Plan iterations:** v1 (architecture draft — rejected, insufficient coverage) → v2 (gap-fill: gaming-stack sourcing, TeX Live Arch split, anda/rpmautospec verification) → v3 (five-stage doc structure + template set) → v4 (base-comparison verification against Bazzite's Containerfile and Fedora bootc GitLab) → v5 (final, approved).

### 1.4 The rakuOS lesson

RakuOS-base (the Fedora-bootc base of the p03 distribution) **does not build with cachyos-kernel**: the CachyOS kernel's COPR packaging does not slot into a Fedora-bootc build the way Fedora-SRPM-derived kernel packages do. p03's own packaging was explicitly designed around this — a **modular RPM spec applied to Fedora Koji (and openSUSE) kernel SRPMs**, so the resulting packages keep Fedora's kernel package conventions (names, file triggers, devel/layout) and drop cleanly into a bootc build. Consequence for us: **consume p03's packages or vendor p03's spec — never substitute the CachyOS kernel** in this build.

---

## 2. Base image — verified three-way comparison

Verified against the [Fedora bootc Base Images GitLab README](https://gitlab.com/Fedora/bootc/base-images), [Fedora Docs "Base images"](https://docs.fedoraproject.org/en-US/bootc/base-images/), and [ublue-os/main's Containerfile](https://github.com/ublue-os/main/blob/main/Containerfile) (September 2026).

| | `fedora-bootc-minimal` | `quay.io/fedora/fedora-bootc` (standard) | `ghcr.io/ublue-os/base-main` |
|---|---|---|---|
| What it is | CI/curation **content set** ("a convenient centralization point … intended as a starting point" for a container base) | **The default published base** — "the default, what is published as quay.io/repository/fedora/fedora-bootc" | ublue's "common main image … with minimal (but important) adjustments to Fedora" |
| Build lineage | content set: standard → **minimal-plus** (shared base of IoT, Atomic Desktops, CoreOS) → **minimal** | standard content set | built **FROM `quay.io/fedora-ostree-desktops/silverblue`** — the GNOME desktop stack is included |
| Published tags | released-tier publishing covers **standard only**; minimal/minimal-plus exist as dev-tier tags (`quay.io/bootc-devel/fedora-bootc-44-minimal`) — *"location and naming of these images is subject to change"* | stable, daily | `ghcr.io/ublue-os/base-main` (+ kinoite, silverblue outputs; sway/budgie/cosmic removed Oct 2025) |
| Contents | stripped vs standard (community builds note **no persistent journal**, no kernel/tools extras); exact contents **not enumerated** in docs | kernel, systemd, dnf5, bootc, podman, full networking, filesystem tools (~1.95 GB uncompressed) | Silverblue desktop + **prebuilt ublue akmods** bind-mounted from `ghcr.io/ublue-os/akmods:main-<ver>` + `akmods-nvidia-open` stage + **pinned ublue kernel** (e.g. `6.19.14-300.fc44.x86_64`) + chsh removal hardening + `bootc container lint` |
| Kernel handling | inherits Fedora kernel; stripped tooling complicates module builds | stock Fedora kernel, freely replaceable in the Containerfile | **pinned ublue kernel + ublue akmods machinery — conflicts with a custom p03 kernel** |
| Verdict | ❌ unstable naming + stripped tools fight akmods/NVIDIA builds | ✅ **CHOSEN** — clean slate, no kernel assumptions, stable tag | ❌ pinned-kernel machinery conflicts with p03; drags the GNOME stack |

**Confirmed in the build:** our Containerfile replaces the stock kernel with p03 RPMs and installs `kernel-p03-nvidia-open` — base-main would have required un-doing its own kernel pinning first.

---

## 3. BlueBuild → Containerfile switch (how)

### 3.1 What changes in the halcyon repo

| BlueBuild era | Containerfile era |
|---|---|
| `recipes/halcyon.yml` + `recipes/modules/*.yml` | **`Containerfile`** (+ `containerfile.d/` helper scripts) |
| `.github/workflows/build.yml` → `blue-build/github-action@v1.13` | `.github/workflows/build.yml` → plain steps: checkout → free disk space → **build** (podman/buildah or docker buildx) → **cosign sign** → **push** to `ghcr.io/aahsnr-work/halcyon` |
| BlueBuild modules (`type: dnf/files/script/systemd/…`) | plain `RUN` steps + `COPY` of a `system/` tree + build scripts under `build.d/` |
| BlueBuild `type: signing` | explicit `cosign sign --key env://COSIGN_PRIVATE_KEY` step (secret `SIGNING_SECRET` unchanged) |
| BlueBuild tag scheme (`:latest`, `:20260919`, `:44`, `:20260919-44`, `:<sha>-44`) | reproduced manually in the workflow's `podman tag` step |
| local build: `bluebuild build recipes/halcyon.yml` | local build: `podman build --pull -t localhost/halcyon:latest .` |

### 3.2 Containerfile skeleton (full template in §9-T8)

```dockerfile
FROM quay.io/fedora/fedora-bootc:44
COPY system/ /                      # static tree (same layout as today's files/system)
COPY build.d /tmp/build.d
RUN /tmp/build.d/01-kernel.sh       # p03 kernel + nvidia-open (§4.3)
RUN /tmp/build.d/02-repos.sh        # RPM Fusion, halcyon-packages, COPRs (transition only)
RUN /tmp/build.d/10-gaming.sh       # steam, lutris, gamescope, scx, umu … (§4.4)
RUN /tmp/build.d/20-desktop.sh      # hyprland stack (COPR now, monorepo later), greetd, noctalia
RUN /tmp/build.d/30-locale-fonts.sh
RUN /tmp/build.d/40-devtools.sh     # replaces the brew pipeline with RPMs (§6)
RUN /tmp/build.d/50-system.sh       # services, tmpfiles, plymouth, ujust, motd
RUN /tmp/build.d/90-verify.sh       # the same gates that exist today, relocated
RUN ["bootc", "container", "lint"]  # same final check ublue runs
```

### 3.3 Workflow skeleton (full template in §9-T8/T10)

- `push`/`schedule`/`workflow_dispatch` triggers (same as today).
- Step: free runner disk (the BlueBuild action did `maximize_build_space`; replicated with the standard rm-of-toolcache snippet).
- Step: `podman build` with the same tag scheme (`latest`, date, `44`, `date-44`, `sha-44`).
- Step: `cosign sign` (reuse the existing `SIGNING_SECRET`) then `podman push` for every tag.
- The **Copr health-wait step is retired** with the COPR dependency (§7).

### 3.4 Provenance verification replacement

BlueBuild-era gates assert COPR vendor stamps (`Fedora Copr - user lionheartp`). In the Containerfile era the equivalent guard is the same `rpm -q --qf '%{VENDOR}'` pattern pointed at whatever installs each package set: `halcyon` (our monorepo builds), `Fedora Project`, `RPM Fusion`, vendor repos — one assert per repo class, relocated into `90-verify.sh`.

---

## 4. Kernel: p03 (staged) + NVIDIA-open

### 4.1 What p03 is (verified from the COPR page and CatPieLeaf/linux-p03)

- Patchset: **Firelzrd, CachyOS, TKG, XanMod, Clear Linux** "and more"; schedulers **MuQSS**; **BBRv3**; **750 Hz** tick; **LTO/ThinLTO** (ThinLTO used in the Copr builds); **ADIOS** I/O scheduler; Surface and handheld support; a custom p03 panic screen. Marketed as "a zero-misplay kernel with Firelzrd".
- Packaging: a **modular RPM spec applied to Fedora Koji and openSUSE kernel SRPMs** — Fedora conventions preserved (this is exactly why it drops into a bootc build while cachyos-kernel does not — §1.4).
- Distribution: COPR **`catpieleaf/kernel-p03`** — chroots **f43 / f44 / f45 / rawhide**, **x86_64 only**. Packages: **`kernel-p03`** (main; x86-64-v3 optimized), **`kernel-p03-gcc`** (x86-64-v2 fallback for older CPUs), **`kernel-p03-nvidia-open`** (NVIDIA open kernel modules built against p03).
- The specfile is derived from **CachyOS's Fedora kernel COPR spec** — i.e. the packaging machinery is proven, only the patchset differs.

### 4.2 Staged kernel plan

**Stage K1 (transition — COPR consumption).** `02-kernel.sh` in the Containerfile enables `catpieleaf/kernel-p03` (repo cleanup after install, same pattern as today's lionheartp handling) and installs:
```sh
dnf5 install -y kernel-p03 kernel-p03-nvidia-open
# remove the stock kernel last, --allowerasing handles the swap:
dnf5 --allowerasing remove kernel kernel-core kernel-modules kernel-modules-extra || true
```
Then `bootc container lint` catches any initramfs/dracut regressions; `kernel-p03`'s spec already runs the Fedora kernel postinstall machinery (strongmods/weak-updates), because it is Fedora-SRPM-derived.

**Stage K2 (ownership — monorepo build).** Transfer `CatPieLeaf/linux-p03`'s spec + patch/tooling into the monorepo (`anda/systems/kernel-p03/`), build monthly (or on Fedora kernel SRPM rebase) in GitHub Actions:
- Job: privileged `ghcr.io/terrapkg/builder:f44` container (mock), or a `--rpm-builder=rpmbuild` anda mode; **~1 h build** fits comfortably in the 6 h public-runner job limit; disk freed via the standard runner-cleanup step.
- Outputs: `kernel-p03`, `kernel-p03-gcc`, `kernel-p03-nvidia-open` → published to the Pages repo; halcyon's `halcyon-packages.repo` then replaces the COPR.
- Reference for feasibility: Terra builds its own package set this way in CI; kernel builds are just longer.

### 4.3 NVIDIA-open

- **K1:** `kernel-p03-nvidia-open` (COPR) — already ABI-matched to `kernel-p03`.
- **K2 (later phase):** self-built akmods-style packages against `kernel-p03-devel` in CI (ublue-os/akmods pattern: build akmod RPMs per kernel release, sign with MOK). Documented, not scheduled.

### 4.4 SELinux (status: in plan)

- p03 is Fedora-SRPM-derived → carries Fedora's kernel config lineage including `CONFIG_SECURITY_SELINUX`. **VERIFY at Phase-1 first build:** `grep CONFIG_SECURITY_SELINUX /boot/config-$(uname -r)` after booting p03.
- `kernel-p03-nvidia-open` modules must run under enforcing SELinux: VERIFY by booting with `enforcing=1` and checking `ausearch -m avc` for module-loading denials; if denials appear, the interim fix is a small local policy module (`audit2allow`), full policy work deferred.
- The image keeps the Fedora `targeted` policy unchanged; `setroubleshoot` packages already in the recipe remain.

### 4.5 Handheld / hardware note

p03 ships Surface and handheld support patches (upstream Linux-surface lineage). The **jupiter/steamdeck** Bazzite packages remain droppable on desktop hardware (§5.2) and re-addable via monorepo imports if a Deck becomes a target.

---

## 5. Gaming stack — brick-by-brick sourcing (verified against Bazzite's own Containerfile, spec_files/, and the ublue-os/bazzite + bazzite-org/bazzite COPRs, September 2026)

### 5.1 Sourcing table

| Package (current halcyon) | Source after the base switch | Notes |
|---|---|---|
| steam | **RPM Fusion free** (`steam`, `steam-libs`, `steam-libs-i686`) | `bazzite-steam`, `bazzite-steam-bpm`, `bazzite-steam-firstrun`, `bazzite-steam-brand` are **plain shell scripts Bazzite drops in `/usr/bin`** (not RPMs) + a `steam.desktop` Exec sed — recreate them from `ublue-os/bazzite/system_files/desktop/shared/usr/bin/` or run vanilla `steam`. |
| lutris | **Fedora** (`lutris`) | Bazzite seds the desktop file (`PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python`) — optional replicate. |
| gamescope (x86_64 + i686 libs) | **Terra** (`terra-gamescope`, `terra-gamescope-libs` 3.16.29^1 incl. i686) or Fedora `gamescope` 3.16.29 (64-bit only) | 32-bit gamescope libs exist only in Terra. |
| mangohud (x86_64 + i686) | **Fedora** (`mangohud`) or **Terra** (`terra-mangohud` incl. i686) | i686 overlay support via Terra. |
| gamemode | **Fedora** (`gamemode`) | Current Bazzite actually removes it; keep if desired. |
| scx-scheds, scx-tools | **Terra** (`scx-scheds`, `scx-tools` 1.1.3) or COPR `bieszczaders/kernel-cachyos-addons` (what Bazzite installs) | Not in Fedora proper (Fedora only has the `scx_c_schedulers` demo). Needs sched_ext — p03 carries it via its Fedora base + patchset. |
| umu-launcher, umu-wrapper | **Terra** (`umu-launcher` 1.4.4, `umu-wrapper` 0.2.0) or monorepo import | Not in Fedora (review Bugzilla #2318468 open). |
| bazaar | **COPR `ublue-os/packages`** (0.9.4) or monorepo import | Official channel is the Flathub Flatpak — RPM exists only via the ublue COPR. |
| bazzite-portal | **Terra** (`bazzite-portal` 0.2.4) | ublue-authored, Terra-packaged. |
| distroshelf-helper | **Monorepo import** — Bazzite-internal, no public RPM found | Ships from `ranfdev/DistroShelf` integration scripts; the DistroShelf spec (§7.1) can carry it. |
| input-remapper | **Fedora** (`input-remapper` 2.2.1) | — |
| usbip, evtest, ydotool | **Fedora** | ydotool service enablement copied from Bazzite's recipe logic. |
| xwiimote-ng, ryzenadj | **Monorepo import** (specs from `bazzite-org/bazzite` COPR SCM) | Not in Fedora/Terra. |
| distrobox, podman (+socket) | **Fedora** | — |
| jupiter-hw-support-btrfs, steamdeck-dsp/backgrounds, powerbuttond, vpower, sdgyrodsu, galileo-mura, jupiter-fan-control | **Droppable on desktop**; re-addable via monorepo imports from `ublue-os/bazzite/spec_files/` (Valve upstream ships .debs only) | Handheld-only functionality. |
| RPM Fusion enablement | `dnf5 -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm` (keys ship in the release RPMs; install with `--nogpgcheck` per RPM Fusion practice; add `rpmfusion-*-appstream-data` on dnf5) | Never use rpm-ostree inside image builds. |

### 5.2 Sequencing note

The handheld set (§5.1 last row) is explicitly **deferred**: it is Deck-specific and each package needs Bazzite's patched specs. The desktop gaming stack is fully covered by RPM Fusion + Fedora + Terra + 3 monorepo imports (bazaar, xwiimote-ng, ryzenadj).

---

## 6. RPM monorepo — `aahsnr-work/halcyon-packages`

### 6.1 Layout (anda-based, per Terra's `terrapkg/packages` conventions)

```
halcyon-packages/
├── anda.hcl                              # root project manifest
├── anda/
│   ├── systems/kernel-p03/               # Stage K2: kernel + nvidia-open (§4.2)
│   ├── desktops/hyprland-git/            # anda.hcl + hyprland-git.spec + update.rhai
│   ├── desktops/… (7-package stack)
│   ├── apps/zen-browser/  apps/bitwarden/  apps/ticktick/
│   ├── apps/obsidian/     apps/zotero/     apps/pyprland/
│   ├── apps/distroshelf/  apps/distroshelf-helper/
│   ├── tools/<22 former brew formulas>/
│   └── texlive/                          # grouped TL packaging (§7.3)
├── .github/workflows/                    # autobuild.yml, update.yml, publish.yml
└── repo/                                 # client .repo file + GPG key
```

Each package directory: `anda.hcl` (`project pkg { rpm { spec = "<name>.spec" } }` — block must be named `pkg`; spec filename must equal the package name — mock limitation), the spec, sources/patches, optional `update.rhai`.

### 6.2 The four build-types (every package is exactly one)

| Type | What it is | Examples |
|---|---|---|
| **A — source-build** | spec compiles upstream sources (git snapshot or release tarball) | pyprland, DistroShelf, distroshelf-helper, future monorepo-native packages |
| **B — upstream-binary wrapper** | spec downloads a vendor artifact (rpm/tar.gz/AppImage), repackages/installs it — the Arch-PKGBUILD pattern | Bitwarden, TickTick, Obsidian, Zotero, bun, pixi, opencode |
| **C — imported spec + autobump** | build files taken from the GitHub repo the COPR (or Terra) points to, vendored into the monorepo and rebuilt by us | Hyprland stack ×7 (LionHeartP/HyprlandRPM), zen-browser (sneexy spec repo), bazaar/xwiimote-ng/ryzenadj (bazzite COPR SCMs), homebrew formulas already in Fedora/COPR/Terra |
| **D — meta/group** | metapackages that pull sets together; specs generated from a mapping | TeX Live groups (§7.3), a `halcyon-gaming` meta if useful |

### 6.3 Serving + signing (GitHub Pages)

- `rpmsign --addsign` with the repo's **fresh RSA-3072 key** (Fedora 44's RPM 6 / rpm-sequoia rejects SHA-1 — never reuse an old key).
- `createrepo_c` per `fedora/44/x86_64/`, then `gpg --detach-sign --armor repodata/repomd.xml` (only repomd is detach-signed; clients use `repo_gpgcheck=1`).
- Published to the `gh-pages` branch → `https://aahsnr-work.github.io/halcyon-packages/fedora/44/x86_64/`; public key + `.repo` file at the root.
- Limits: 1 GB site / 100 GB-mo — comfortable for the current roster (~1–2 GB with TeX Live groups pruned).

### 6.4 Auto-versioning — every RPM, no human

Two complementary mechanisms; every package gets at least one:

1. **`anda update` + per-package `update.rhai`** (verified API from Terra's real scripts):
   - `gh("owner/repo")` → latest GitHub release tag;
   - `rpm.version(v)` → rewrites the spec `Version:`;
   - `get(url)` / `find_all(regex)` / `sub()` → scrape non-GitHub upstreams (e.g. TickTick's download page, Zotero's release channel) and rewrite `Source0`/`Version`;
   - `anda update` walks the whole monorepo on a cron (Terra runs theirs every 10 minutes; ours: daily), then opens PRs/commits the bumps.
2. **Release-API polling workflow** (`update.yml`): a matrix over `packages.json`, one jq call to the GitHub API (or upstream version endpoint) per package, opening a PR when `Version` in the spec lags. Covers any package whose upstream is *ahead* of its source build — the "sources behind the latest release" requirement.
Both converge on the same rule: **a maintainer never edits a version by hand.** Even packages whose specs were imported from Fedora/COPR get an `update.rhai` or polling entry (imported Fedora specs lose Fedora's automation when copied out).

### 6.5 Build + publish workflows

- `autobuild.yml`: push/PR → `anda ci` (JSON matrix of changed packages) → per-package `anda build` in `ghcr.io/terrapkg/builder:f44` (privileged — mock requirement; Terra runs exactly this on public runners) → artifacts.
- `publish.yml`: on successful build of `main` → import GPG key from `GPG_PRIVATE_KEY` secret → `rpmsign --addsign` → `createrepo_c` → detach-sign repomd → deploy Pages.
- Kernel builds (Stage K2) are the same pipeline with a longer job.

### 6.6 brave-browser and vscode — determination

**They stay on their vendor repos; they do NOT enter the monorepo.**

- Both vendors run their own signed, auto-updating dnf repos (Brave S3 repo, Microsoft repo) — version-lag risk is already zero, which is the entire reason the monorepo exists.
- Wrapping them (type B) would add a rebuild+publish cycle that only re-ships the vendor's own bits, plus MOK/vendor-key verification churn on every upstream release.
- Their repo enablement/cleanup logic in `apps.yml`/`apps-verify.sh` ports unchanged to the Containerfile era.
- **Revisit triggers:** a vendor repo outage pattern like Copr's, a need to patch/patch-brand the packages, or a move to air-gapped hosting. Template §9-T2 covers the wrap if ever needed.

---

## 7. TeX Live — Arch-style grouped RPMs

### 7.1 Problem

Fedora packages TeX Live from one giant SRPM as `texlive-scheme-*` + `texlive-collection-*` subpackages, upgraded **only as a release Change** (TL2023 for F38–F44; TL2025 approved for F45) — years between updates. The `install-tl.sh` pipeline tracked tlnet continuously but baked files outside RPM (unowned, unremovable).

### 7.2 Arch's model (the template — verified from `texlive-texmf` PKGBUILD)

Arch splits upstream TeX Live into **43 packages**: `texlive-basic` (based on scheme-medium), `texlive-bin` (compiled binaries), one `texlive-<collection>` per upstream collection (latexextra, fontsextra, bibtexextra, pictures, publishers, science, music, pstricks, context, luatex, xetex, metapost, plaingeneric, fontutils, formatsextra, games, humanities, mathscience, doc, meta, and the lang* set — langchinese/japanese/korean/greek/cjk/cyrillic/european/other/arabic/french/english/polish/czechslovak/german/spanish/italian/portuguese), plus `texlive-meta`. Generation: parse `texlive.tlpdb` → per-collection runfiles (docs excluded → texlive-doc), `depend` lines → package deps, `execute AddFormat`/`addMap`/`AddHyphen` → fragments installed to `/var/lib/texmf/arch/installedpkgs/` consumed by pacman hooks in texlive-basic that regenerate fmtutil.cnf/updmap.cfg/language.dat at install time.

### 7.3 halcyon-packages design (monthly / 3-weekly cadence)

1. **Snapshot pinning:** use dated historical mirrors — `https://texlive.info/tlnet-archive/YYYY/MM/DD/tlnet` (daily archives since 2019-08-30; verified live) — the same date for the installer and tlmgr (`tlmgr refuses cross-year repository mismatches`; same-year snapshot updates are deterministic).
2. **Splitter** (`anda/texlive/splitter/`): install the snapshot to a staging dir via `install-tl --profile` (unattended profile; the installer writes a reusable profile to `tlpkg/texlive.profile`), parse `tlpkg/texlive.tlpdb` exactly like Arch's `prepare()` (collection blocks → runfiles → deps; AddFormat/addMap/AddHyphen → fragments), and emit one RPM per **Arch-named group** (`texlive-basic`, `texlive-binextra`, `texlive-latexextra`, `texlive-fontsextra`, `texlive-lang*`, …) plus `texlive-meta`.
3. **Fragments + triggers:** RPM file-triggers (or the fragments-installed-to-`/var/lib/texmf/halcyon/installedpkgs` pattern) regenerate formats/maps/hyphenation on install — the direct RPM analogue of Arch's pacman hooks.
4. **Cadence:** monthly (or every 3 weeks) — the workflow pins the archive date of the day it runs, builds the whole group set **atomically together** (one snapshot for all groups), publishes to the monorepo, and bumps the image's TeX Live meta-packages.
5. **Explicitly NOT done:** chasing daily tlnet (no stable upstream state — upstream devs recommend dated snapshots), and mixing snapshot dates between groups.

---

## 8. Package-by-package appendix

### 8.1 Flatpak → RPM conversions (current flatpaks recipe: DistroShelf, OnlyOffice, Bitwarden, TickTick + Flatseal)

| Flatpak (today) | New RPM | Type | Version automation |
|---|---|---|---|
| com.ranfdev.DistroShelf | `distroshelf` + `distroshelf-helper` | **A — source build** (custom spec; the user-designated one) | GitHub API tag polling on `ranfdev/DistroShelf`; **VERIFY** upstream build system (Flutter vs Meson) before writing the spec — fetch `ranfdev/DistroShelf` build files |
| org.onlyoffice.desktopeditors | `onlyoffice-desktopeditors` | **B — wrapper** over the vendor RPM via OnlyOffice's own dnf repo, **or** a wrapper spec pinning the upstream RPM | **VERIFY** repo URL: `https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice.repo` (check it resolves and serves F44-compatible rpms) |
| com.bitwarden.desktop | `bitwarden` | **B — wrapper** over the official vendor RPM (repackaged into our spec — Arch-PKGBUILD style) | GitHub API tag polling on `bitwarden/clients` (**VERIFY** the exact rpm asset naming on releases) |
| com.ticktick.TickTick | `ticktick` | **B — wrapper** over the official vendor RPM/tarball | **VERIFY** TickTick's Linux download URL pattern + version detection (vendor does not publish a GitHub API) |
| io.github.flattool.Warehouse, Protontricks, Mission Center, ProtonPlus, Refine, Extension Manager, org.mozilla.firefox, org.gnome.* | dropped | — | Native-replacement needs are covered elsewhere (bleachbit, flatseal…); Firefox is replaced by zen-browser (§8.3) |
| (Flathub repo itself) | **not configured** | — | No Flatpak stack on the new image — every former Flatpak app is native |

### 8.2 Obsidian — `obsidian` (type B, tar.gz → RPM)

Arch's official packaging converts the official **`.tar.gz`** (not the AppImage) into an installed tree. Our spec mirrors that: `Source0` = `https://github.com/obsidianmd/obsidian-releases/releases/download/v<version>/obsidian-<version>.tar.gz` (verified naming on the releases API during the install-obsidian.sh work — the same release carries AppImage + tar.gz), `%install` copies `usr/` into the filesystem (`/opt/Obsidian` + `/usr/bin/obsidian` symlink + desktop + icons per the Arch PKGBUILD pattern), with the **GitHub-API sha256 digest check** already proven in `install-obsidian.sh`. Version automation: `gh("obsidianmd/obsidian-releases")` in `update.rhai` — with the caveat encoded there that `releases/latest` is periodically mobile-only, so poll the release list and select the newest with a Linux asset.

### 8.3 zen-browser — `zen-browser` (type C import)

Build files imported from the GitHub repo the **sneexy/zen-browser** COPR points to (spec wraps upstream prebuilt tarballs — no source build). Autobump: polling workflow on zen-browser's release channel. Vendor gate in `apps-verify.sh` changes from `sneexy` to `halcyon` once our build ships.

### 8.4 Hyprland stack — 7 packages (type C imports)

`hyprland-git`, `hyprland-guiutils`, `hyprpwcenter`, `hyprshutdown`, `noctalia-git`, `noctalia-greeter-git`, `xdg-desktop-portal-hyprland` — build files imported from **`LionHeartP/HyprlandRPM`** (the repo the lionheartp COPR builds). Sequencing: hyprland-git first (sets the ABI generation: aquamarine/hyprlang/hyprutils/hyprgraphics/hyprcursor pins), the rest rebuild against it. Autobump via `update.rhai` on the upstream Hyprland/noctalia repos. Provenance gate flips `lionheartp` → `halcyon`.

### 8.5 pyprland — `pyprland` (type A, hatchling)

`%pyproject`-based spec (BuildRequires: `pyproject-rpm-macros`, `hatchling`), source = the release tarball (`archive/refs/tags/<tag>.tar.gz`), installs the venv-less console scripts via `%pyproject_install` + `%pyproject_save_files pyprland`; the user service unit and the `ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland` drop-in ship as extra sources in the same spec. Autobump: `gh("hyprland-community/pyprland")`.

### 8.6 Zotero — `zotero` (type B, tarball wrapper)

`Source0` = versioned URL `https://download.zotero.org/client/release/<version>/Zotero-<version>_linux-x86_64.tar.bz2` (the versioned form of the channel URL already used by `install-zotero.sh`); `%install` replicates the current script (extract to `/usr/lib/zotero`, `set_launcher_icon`, desktop file, autoupdate disabled). Version automation: scrape the Zotero download channel (**VERIFY** — Zotero publishes no API or checksums; upstream position documented in `install-zotero.sh`).

### 8.7 Former homebrew formulas — 22 RPMs (type A/C/B mix)

| Formula | Fedora 44 | Source of build files |
|---|---|---|
| bat, ripgrep, fd, fzf, direnv, pandoc, gnuplot, cava, chafa, btop, zellij, gum-class tools | ✓ Fedora | **Import Fedora dist-git specs** (`src.fedoraproject.org/rpms/<name>`) into the monorepo + add autobump |
| eza, starship, lazygit, uv, atuin, tealdeer, dust, yazi | VERIFY each (several exist in Fedora, several only in COPRs) | Fedora dist-git if present, else the COPR's SCM repo, else **A** source-build spec |
| bun, pixi, opencode | ✗ (upstream prebuilt binaries only) | **B — wrapper** specs over upstream release binaries (bun: oven-sh/bun releases; pixi: prefix-dev; opencode: sst/opencode) — version automation via GitHub API |
| (texlive via install-tl) | replaced | §7.3 grouped RPMs |
Formula removal also **retires the entire brew pipeline**: `install-brew-bundle.sh`, `brew-bundle-extract`, `brew-bundle-install`, `halcyon-brew-bundle.service`, `brew-bundle.service`, the `/usr/share/halcyon/brew-bundle.tar.zst` payload, and the Brewfile — replaced by monorepo RPMs plus the `40-devtools.sh` Containerfile stage.

### 8.8 Summary roster

~50 monorepo packages total: 7 Hyprland stack + zen-browser + 22 brew replacements + texlive groups (~20–40 depending on grouping granularity) + obsidian/zotero/bitwarden/ticktick/pyprland/distroshelf(+helper) + optional imports (bazaar, xwiimote-ng, ryzenadj, kernel-p03 in Stage K2).

---

## 9. Containerfile module mapping (current halcyon → new system)

| Current module (recipes/) | Containerfile stage | Notes |
|---|---|---|
| removals.yml (inventory, guarded-removals, file-footprint, gnome-extensions, fonts-cleanup) | mostly **obsolete** — fedora-bootc has no GNOME to remove; a trimmed `05-prune.sh` removes what fedora-bootc does ship that halcyon rejects | keep the fonts-cleanup logic only if the base ships unwanted fonts |
| core.yml (dnf install list) | `02-packages.sh` | same package list, minus COPR-hosted bits |
| desktop.yml (COPR + verify) | `20-desktop.sh` + gates in `90-verify.sh` | COPR → halcyon-packages (§8.4) |
| apps.yml | `21-apps.sh` | vscode/brave vendor repos; zed (Terra) unchanged; zen → monorepo |
| fonts.yml | `30-fonts.sh` | nerd fonts + google fonts as today |
| flatpaks.yml | **removed** | replaced by §8.1 RPMs; no Flatpak stack |
| nix.yml | `31-nix.sh` + files tree | var-nix.service, nix.mount, tmpfiles, profile hook unchanged |
| brew.yml + brew services | **removed** | replaced by §8.7 RPMs |
| build-scripts.yml (obsidian/zotero/pyprland/texlive/python) | `40-*.sh` during transition → **retired** as monorepo RPMs land | texlive keeps the snapshot logic inside the monorepo build instead |
| files.yml (system tree, justfiles, chezmoi) | `COPY system/ /` + `50-*.sh` | unchanged content, same layout |
| services.yml | `50-system.sh` (`systemctl enable` equivalents) | unchanged list minus brew units |
| branding.yml (plymouth assets, motd, os-release) | `60-branding.sh` | asset-generation logic carried over |
| initramfs module | `dracut -f` inside the kernel stage (§4.2) | explicit in the Containerfile |
| signing module | CI cosign step | unchanged secret |
| verify scripts | `90-verify.sh` | gates relocated per §3.4 |

---

## 10. Template appendix (copyable files)

### T1 — source-build RPM spec template

```spec
# speclint: shell=dontcare
Name:           <pkg>
Version:        0.1.0
Release:        %autorelease
Summary:        <one-line summary>
License:        <SPDX>
URL:            https://github.com/<owner>/<repo>
Source0:        %{url}/archive/refs/tags/v%{version}/<repo>-%{version}.tar.gz
BuildRequires:  gcc
BuildRequires:  make
Requires:       <runtime deps>
%description
%{summary}.
%prep
%forgeautosetup -p1
%build
%make_build
%install
%make_install PREFIX=%{_prefix}
%files
%license LICENSE
%doc README.md
%{_bindir}/<pkg>
%changelog
%autochangelog
```
Version automation: `update.rhai` with `rpm.version(gh("<owner>/<repo>"))`.

### T2 — upstream-binary wrapper spec template (Bitwarden / TickTick / Obsidian / Zotero pattern)

```spec
Name:           <pkg>
Version:        0.0.0          # rewritten by update automation
Release:        %autorelease
Summary:        <app> (packaged from the official upstream release)
License:        <SPDX>
URL:            https://<vendor>
# official artifact; checksum verified against the vendor's published digest
Source0:        <vendor-url-with-%{version}>
Source1:        <pkg>.desktop
BuildArch:      x86_64
BuildRequires:  /usr/bin/desktop-file-validate
%description
%{summary}.
%prep
%setup -q -c -T
mkdir vendor && cd vendor
curl -fsSL "%{SOURCE0}" -o artifact
# sha256="$(curl -fsSL <vendor-checksum-url>)" — verify when the vendor publishes one
%install
mkdir -p %{buildroot}%{_libdir}/<pkg> %{buildroot}%{_bindir}
install -m0644 vendor/* %{buildroot}%{_libdir}/<pkg>/  # per artifact layout
ln -s %{_libdir}/<pkg>/<bin> %{buildroot}%{_bindir}/<pkg>
install -Dm0644 %{SOURCE1} %{buildroot}%{_datadir}/applications/<pkg>.desktop
%files
%{_libdir}/<pkg>/
%{_bindir}/<pkg>
%{_datadir}/applications/<pkg>.desktop
%changelog
%autochangelog
```

### T3 — meta/group spec template (TeX Live groups)

```spec
Name:           texlive-<group>
Version:        20260901      # the tlnet-archive snapshot date (YYYYMMDD)
Release:        1
Summary:        TeX Live <group> collection
License:        GPL-1.0-or-later
BuildArch:      noarch
# generated: requires the exact group members from the snapshot tlpdb
Requires:       texlive-basic
Requires:       texlive-<dep-group>
# Provides: tex(<ctan-pkg>) — one per upstream package in this group, from the tlpdb
%description
TeX Live <group>: the <group> collection of the TeX Live <snapshot-date> snapshot,
split per the Arch-style grouping defined in §7.3.
%files
# file list generated by the splitter from the tlpdb runfiles
%changelog
- <date> halcyon-autobuild - regenerated from tlnet-archive <snapshot-date>
```

### T4 — python-hatchling spec template (pyprland pattern)

```spec
Name:           pyprland
Version:        3.4.4
Release:        %autorelease
Summary:        Hyprland companion daemon and CLI
License:        MIT
URL:            https://github.com/hyprland-community/pyprland
Source0:        %{url}/archive/refs/tags/%{version}/pyprland-%{version}.tar.gz
Source1:        pyprland.service
BuildRequires:  pyproject-rpm-macros python3-devel
BuildArch:      x86_64
%description
%{summary}.
%prep
%forgeautosetup -p1
%generate_buildrequires
%pyproject_buildrequires
%build
%pyproject_wheel
%install
%pyproject_install
%pyproject_save_files -l pyprland
install -Dm0644 %{SOURCE1} %{buildroot}%{_userunitdir}/pyprland.service
mkdir -p %{buildroot}%{_userunitdir}/pyprland.service.d
cat > %{buildroot}%{_userunitdir}/pyprland.service.d/10-halcyon.conf <<'EOF'
[Unit]
ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland
EOF
%files -f %pyproject_files
%license LICENSE
%{_userunitdir}/pyprland.service
%dir %{_userunitdir}/pyprland.service.d
%{_userunitdir}/pyprland.service.d/10-halcyon.conf
%changelog
%autochangelog
```

### T5 — `anda.hcl` package manifest template

```hcl
project pkg {
  rpm {
    spec = "<pkg>.spec"
  }
  labels {
    nightly = "1"   # opt-in/out of update.yml subsets, per Terra convention
  }
}
```

### T6 — `update.rhai` autobump template

```rhai
// GitHub-release upstream:
rpm.version(gh("<owner>/<repo>"));
// non-GitHub upstream (scrape + regex):
// let html = get("https://<vendor>/download");
// let v = find_all(`<version pattern>`, html); rpm.version(v[0]);
// optional: sub() to rewrite pinned Source URLs / commit hashes in the spec
```

### T7 — version-bump GitHub workflow template

```yaml
name: update
on:
  schedule: [{cron: "17 04 * * *"}]
  workflow_dispatch:
jobs:
  bump:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          # per-package GitHub-API release poll (jq) vs spec Version:
          # open a PR per outdated package (gh pr create), or direct-push
          # to a bump branch for review
```

### T8 — image Containerfile template

See §3.2 for the skeleton; stages in order: `01-kernel.sh` (p03 + nvidia-open + dracut) → `02-repos.sh` (RPM Fusion + halcyon-packages + transitional COPRs) → `10-gaming.sh` → `20-desktop.sh` → `21-apps.sh` → `30-fonts.sh` → `31-nix.sh` → `40-devtools.sh` → `50-system.sh` (services/tmpfiles/ujust/motd) → `60-branding.sh` → `90-verify.sh` → `bootc container lint`. Every stage: `dnf5 -y` with `--setopt=install_weak_deps=False` where strictness matters, repo cleanup after each external-repo install.

### T9 — monorepo autobuild workflow template

```yaml
name: autobuild
on: [push, pull_request, workflow_dispatch]
jobs:
  matrix:
    runs-on: ubuntu-latest
    outputs: {matrix: ${{ steps.ci.outputs.matrix }}}
    steps:
      - uses: actions/checkout@v4
      - id: ci
        run: echo "matrix=$(anda ci)" >> "$GITHUB_OUTPUT"
  build:
    needs: matrix
    runs-on: ubuntu-latest
    container: {image: "ghcr.io/terrapkg/builder:f44", options: "--privileged"}
    strategy: {matrix: ${{ fromJson(needs.matrix.outputs.matrix) }}}
    steps:
      - uses: actions/checkout@v4
      - run: dnf5 builddep -y <pkg>.spec && anda build -D "vendor halcyon" -c f44-x86_64 <pkg-dir>
      - uses: actions/upload-artifact@v4
        with: {name: "rpm-${{ matrix.pkg }}", path: "anda-build/rpm/rpms/"}
```

### T10 — publish workflow template

```yaml
name: publish
on: {workflow_run: {workflows: [autobuild], types: [completed], branches: [main]}}
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "${{ secrets.GPG_PRIVATE_KEY }}" | base64 -d | gpg --batch --import
      - run: rpmsign --addsign **/*.rpm   # %_gpg_name set via macros or -D
      - run: createrepo_c fedora/44/x86_64 && gpg --detach-sign --armor fedora/44/x86_64/repodata/repomd.xml
      - uses: actions/deploy-pages@v4     # or git-push the gh-pages worktree
```

### T11 — `halcyon-packages.repo`

```ini
[halcyon-packages]
name=halcyon-packages
baseurl=https://aahsnr-work.github.io/halcyon-packages/fedora/$releasever/$basearch/
enabled=1
type=rpm-md
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://aahsnr-work.github.io/halcyon-packages/RPM-GPG-KEY-halcyon-packages
```

### T12 — image verification script template (`90-verify.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail
fail=0
gate() { # gate <desc> <cmd…>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "  PASS  $desc"; else echo "  FAIL  $desc"; fail=1; fi
}
gate "p03 kernel installed"  rpm -q kernel-p03
gate "nvidia-open built for p03" rpm -q kernel-p03-nvidia-open
gate "greeter wrapper" test -x /usr/bin/noctalia-greeter-session
gate "monorepo repo file" grep -q halcyon-packages /etc/yum.repos.d/halcyon-packages.repo
gate "obsidian desktop" test -f /usr/share/applications/obsidian.desktop
gate "SELinux enforcing target" test "$(getenforce)" = Enforcing
for p in hyprland-git noctalia-git zen-browser steam lutris; do
  gate "rpm present: $p" rpm -q "$p"
done
[ "$fail" = 0 ] || { echo "verification failed"; exit 1; }
```

---

## 11. Cutover, rollback, risks

### 11.1 Cutover order

1. Stand up `halcyon-packages` (monorepo + Pages) — **Phase 0–3**.
2. Rebuild halcyon's image from the Containerfile **while it still consumes COPRs** (transitional) — proves the Containerfile system independently.
3. Flip package sources to the monorepo per group (Hyprland stack first, then brew replacements, then TeX Live, then flatpak replacements) — each flip is one commit; provenance gates re-pointed at each flip.
4. Retire COPR references and the Copr health-wait step; drop the transitional repo files.

### 11.2 Rollback

Every flip is one commit: reverting it restores the previous source (COPR/vendor). Keep a `copr-fallback` branch with the pre-migration desktop/apps blocks. The monorepo is additive — nothing COPR-side is destroyed. The old BlueBuild recipe set is preserved on a `bluebuild-archive` branch when the Containerfile lands.

### 11.3 Risks

| Risk | Mitigation |
|---|---|
| Kernel builds near the 6 h Actions limit | Free-disk step + ccache; kernel is monthly, not daily. |
| p03 + SELinux enforcement (NVIDIA, module loads) | VERIFY steps in §4.4; interim audit2allow policies; full policy later. |
| Pages 1 GB cap as the roster grows | Prune old NVRs (noports pattern); upgrade path = self-hosted Subatomic (same monorepo, different publish step). |
| Upstream ABI churn (hyprland-git) | Provenance gate + pinned subprojects; we now own the rebuild latency. |
| Gaming gaps vs Bazzite (bazzite-steam scripts, HDR/session bits) | Sourcing table §5.1; known HDR/session quirks are upstream-version-dependent — test on hardware. |
| Spec imports rot (Fedora dist-git moves) | Autobump workflows cover version; spec *structure* drift is reviewed at each rebuild. |

### 11.4 VERIFY items (couldn't be web-verified — check commands included)

| Item | Check |
|---|---|
| Bitwarden rpm asset naming | `gh release view --repo bitwarden/clients --json assets` |
| TickTick Linux download URL + version detection | inspect `https://ticktick.com/about/download` |
| OnlyOffice repo file freshness | `curl -s https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice.repo` |
| DistroShelf build system (Flutter vs Meson) | inspect `github.com/ranfdev/DistroShelf` build files |
| p03 kernel config keeps SELinux | `grep CONFIG_SECURITY_SELINUX /boot/config-$(uname -r)` after first p03 boot |
| nwg-look / eza / starship / uv / yazi / tealdeer / atuin / dust Fedora presence | `dnf repoquery <name>` on F44 |

## 12. References

anda: https://github.com/FyraLabs/anda · Terra CI: https://github.com/terrapkg/packages · Subatomic policy: https://docs.terrapkg.com/reference/faq/ · Bazzite build: https://github.com/ublue-os/bazzite (Containerfile, spec_files/) · ublue akmods: https://github.com/ublue-os/akmods · base-main Containerfile: https://github.com/ublue-os/main/blob/main/Containerfile · bootc base images: https://gitlab.com/Fedora/bootc/base-images · Fedora bootc docs: https://docs.fedoraproject.org/en-US/bootc/ · RPM Fusion: https://rpmfusion.org/Configuration · Arch texlive: https://gitlab.archlinux.org/archlinux/packaging/packages/texlive-texmf · tlnet archive: https://texlive.info/tlnet-archive/ · install-tl: https://tug.org/texlive/doc/install-tl.html · rpmautospec: https://github.com/fedora-infra/rpmautospec · RPM 6 strictness: https://github.com/rpm-software-management/rpm-sequoia/issues/22 · p03: https://github.com/CatPieLeaf/linux-p03 · COPR: https://copr.fedorainfracloud.org/coprs/catpieleaf/kernel-p03/ · RakuOS: https://rakuos.org · Hyprland specs: https://github.com/LionHeartP/HyprlandRPM · Pages limits: https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits
