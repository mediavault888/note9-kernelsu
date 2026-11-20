# note9-kernelsu

KernelSU-Next (built-in, manual hooks) for the **Samsung Galaxy Note 9 Exynos (SM-N960F, `crownlte`)**
on **official LineageOS 20 (Android 13)**, the last official build: `lineage-20.0-20241226-nightly-crownlte-signed.zip`.

Status: **working**. The manager shows `Working · BUILT-IN (LEGACY) · v3.4.0-legacy (33327-5)`, hook mode Manual, and all tabs (Superuser, Module).

| | |
|---|---|
| Kernel | `4.9.118-ksu`, LineageOS `android_kernel_samsung_exynos9810` @ `6a9461f9460c` (exact source of the ROM's own kernel) |
| Toolchain | clang r416183b + GCC 4.9 binutils (same as the LineageOS build) |
| KernelSU | KernelSU-Next `legacy` @ `e5f5ec99` + 4.9 fixes below |
| Manager | KernelSU-Next v3.4.2 (uapi 5). The kernel reports uapi 5 (see fix 6) |
| Extras for containers | SYSVIPC, FHANDLE, OVERLAY_FS, BRIDGE, MACVLAN, CPUSETS, CGROUP_FREEZER, BINFMT_MISC, IPv6 NAT (USER_NS/PID_NS/DEVTMPFS were already on). `droidspaces check`: all required features found |

## Files

- `release/boot-los20-kernelsu.img`: ready-to-flash BOOT image. Only the kernel is replaced; ramdisk, DT and header are byte-identical to the stock LOS20 boot.img.
- `patches/0001-…`: kernel tree changes: manual hooks (execve, faccessat, newfstatat/fstatat64, read, reboot, input, slow_avc_audit), shared `latest_granting`, and the `path_umount` and SELinux backports that KernelSU's Kbuild adds.
- `patches/0002-…`: fixes to KernelSU-Next legacy for 4.9 (below).
- `configs/kernelsu-containers.config`: config fragment.
- `scripts/build.sh`: reproduces the image from scratch. `scripts/repack_boot.py`: Samsung DTBH boot.img repacker.

## KernelSU-Next fixes needed on 4.9

1. **SELinux AVC flood.** `reset_avc_cache()` used a private seqno on 4.9, so the AVC rejected every insert (`avc: seqno 1 < latest_notif 2`, about 700k log lines, slower permission checks). It now bumps the policy's `latest_granting` (made non-static in `ss/services.c`).
2. **`su` on a fresh install.** The manual-hook `ksu_handle_execveat_sucompat()` always redirected to `/data/adb/ksud`, so `su` failed with ENOENT before the manager had installed ksud. It now falls back to `/system/bin/sh` like the syscall path does.
3. **Manager never detected: ENOKEY.** On pre-5.4 fscrypt, the keys live in the process keyring. `track_throne()` runs under `ksu_cred` (no keyring), so opening `/data/app/*/base.apk` returned `-126`. On ENOKEY the open is retried with the caller's original creds.
4. **Wrong `kernel_read()` argument order.** 4.9 has `kernel_read(file, offset, buf, count)`. apk_sign, throne_tracker, allowlist and ksud_integration called the new form (hidden by `-Wno-int-conversion`), so the signature check read garbage. They now use `ksu_kernel_read_compat()`.
5. Small fixes: `ns_get_path()` returns `void *` before 4.11; `AT_FDCWD` was passed as an `int *`.
6. **Allowlist lost on every reboot.** Same pre-5.4 fscrypt keyring problem: the allowlist is saved under `ksu_cred` (no keyring), so the file under encrypted `/data/adb` ends up empty (`allowlist file invalid: 0`). `ksu_cred` now gets init's session keyring as soon as KernelSU captures it.
7. **uapi 6 → 5.** The legacy branch moved to uapi 6 (module preinit + LOOKUP_SYMBOLS) after the v3.4.2 manager release. With 6, the manager shows "version 5 too low" and hides the Superuser and Module tabs. Preinit is disabled in this build, so the kernel reports 5, which is fully compatible.

## Kernel fix (Samsung/LineageOS 4.9, not KernelSU)

- **`/proc` mount deadlock.** In `fs/super.c`, `mount_ns_option()` (CONFIG_PROC_PARSE_OPTION_ON_MOUNT) returned `-EINVAL` on an unknown proc option without releasing the superblock it got locked from `sget_userns()`. systemd's `ProtectProc=` (`hidepid=invisible`) triggers this, and from then on every proc mount in that pid namespace hangs in `grab_super()` (D state, needs a reboot). Fixed with `deactivate_locked_super()`.

- **ksud never ran at boot (no module scripts, no autostart).** `/data` is mounted `nosuid`, and 4.9 has no `process2:nosuid_transition` (added in 4.14), so init's `exec u:r:ksu:s0 -- /data/adb/ksud …` failed with `security_bounded_transition denied` / `Permission denied`. `check_nnp_nosuid()` in `security/selinux/hooks.c` now allows the nosuid (not NNP) case only when the target is KernelSU's own domain; normal SELinux transition checks still apply. With this, `ksud post-fs-data/services/boot-completed` run, and so do module scripts such as Droidspaces' run-at-boot.

## Containers (Droidspaces) on this kernel

- Works: Ubuntu 22.04 (systemd 249) boots to `running` with SELinux **enforcing**.
- **Use a sparse ext4 image rootfs (`use_sparse_image=1`), not a plain directory on `/data`.** On 4.9, fscrypt keys are per keyring, and systemd gives each service a new session keyring, so services fail with `Required key not available` (203/EXEC). Files inside a loop-mounted image are not fscrypt-encrypted.
- No IPv4 from DHCP on some routers (a LineageOS issue, not KernelSU): set a static IP in the Wi-Fi settings, otherwise the container NAT has no uplink.

## Headless Wayland base

`droidspaces/headless-wayland/`: an Ubuntu 24.04 Droidspaces container running sway (headless, software rendering) with VNC on :5900 and browser access (noVNC over HTTPS) on :6080. Other compositors run nested inside it. One installer script sets it all up; see its README.

## Install (from LineageOS 20 already installed)

```
adb reboot download
heimdall flash --BOOT release/boot-los20-kernelsu.img
```
Then install the KernelSU-Next manager APK. Back to stock: flash the ROM's original `boot.img` the same way.

Fresh install: flash LOS20 `recovery.img` (`heimdall flash --RECOVERY`), boot recovery (Vol Up + Bixby + Power), then Factory reset → Format data, Apply update → `adb sideload lineage-…zip`, boot once, then flash BOOT as above.

Use at your own risk. Kernel source is GPL-2.0; everything needed to rebuild is in `scripts/build.sh` and `patches/`.
