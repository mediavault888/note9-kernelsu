# Headless Wayland base (Droidspaces container)

A Wayland desktop with no screen, no GPU, no login manager and no seat, reachable over the network.
It is meant as a stable "base": other compositors run **nested** inside it, so testing one never means rebuilding.

```
 phone (Droidspaces, NAT)                                  any device on the LAN
 ┌────────────────────────────────────────────┐
 │ Ubuntu 24.04 container                     │  :5900  VNC (TLS / RSA-AES login) ──▶ TigerVNC, Remmina…
 │  sway  WLR_BACKENDS=headless               │
 │        WLR_RENDERER=pixman (software)      │  :6080  https + login ──────────────▶ any browser (noVNC)
 │  wayvnc ×2  (public :5900, local :5901)    │
 │  websockify + noVNC 1.7 → 127.0.0.1:5901   │
 └────────────────────────────────────────────┘
```

## Install

1. Create a Droidspaces container from the official **Ubuntu 24.04 Minimal** image, as a **sparse image**. On 4.x kernels with file-based encryption, a directory rootfs breaks systemd services with "Required key not available".
2. Use `container.config` from this folder: NAT, `port_forwards=5900:5900/tcp,6080:6080/tcp`, `run_at_boot=1`. Set your own `static_nat_ip`.
3. Copy this folder into the container and run `sh install.sh` as root. It prints the generated login (user `wl`).

Ubuntu 24.04 (systemd 255) is the newest Ubuntu that boots on a 4.9 kernel. 26.04 ships systemd 259, which needs kernel 5.4+.

## Use

| | |
|---|---|
| Browser | `https://<phone-ip>:6080`, accept the self-signed certificate, log in as `wl`, then click **Connect** |
| VNC app | `<phone-ip>:5900`, user `wl` + password. Needs a viewer with VeNCrypt/TLS or RSA-AES, e.g. TigerVNC |
| Settings | `/etc/headless-wayland/config` (`RESOLUTION`, `AUTOSTART`), then `systemctl restart headless-wayland` |
| Status / screenshot | `hw-status`, `hw-shot /tmp/x.png` |
| Other compositors | inside the session: `nested labwc`, `nested weston`, `nested wayfire`, `nested cage foot` |

## Notes

- The session uses its own runtime dir `/run/headless-wayland`, not `/run/user/1000`. Otherwise logind mounts a fresh `/run/user/1000` over it when someone logs in as `wl`, which hides sway's sockets.
- noVNC cannot do TLS-VeNCrypt or RSA-AES type 5. It therefore talks to a second wayvnc bound to `127.0.0.1:5901` without VNC auth, and the protection is websockify's HTTPS plus HTTP basic auth (`--web-auth`).
- niri and Hyprland are not packaged for Ubuntu 24.04. Install a build yourself, then run it with `nested niri`.
