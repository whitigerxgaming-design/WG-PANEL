<div align="center">

# 🐯 WG PANEL

**One-command game & bot hosting panel — Minecraft, Discord bots and more.**

White-tiger theme · Built-in registration · Auto node setup · Free Cloudflare link (no domain needed)

</div>

---

## ✨ Features

- 🔐 Built-in **Register** page (no Blueprint needed)
- 🖥️ Console, File Manager, Activity logs, Databases, Backups
- 🥚 Nests, Eggs and Mounts (Minecraft, Discord bots, and more)
- 🌍 Locations, Nodes and Allocations — a node, location and default ports are **created automatically**
- 🎨 Admin-only **theme colour editor** (Admin → WG Theme)
- 🌐 Use your own domain with free SSL, a free `trycloudflare.com` link, or just your server IP
- 🇬🇧 English only

## 📋 Requirements

- A fresh VPS with **Ubuntu 22.04 / 24.04** or **Debian 11 / 12**
- At least **2 GB RAM** (4 GB recommended)
- Root access

## 🚀 Install

Run these on your VPS as **root**:

```bash
apt update && apt install -y git
git clone https://github.com/whitigerxgaming-design/WG-PANEL.git
cd WG-PANEL
bash install.sh
```

## 🧭 Installer menu

```
1) Install Panel
2) Install Wings only (this server becomes a node for another panel)
3) Install Panel + Wings on this server   <- recommended
4) Uninstall
5) Re-apply WG theme
```

Then it asks:

| Question | Options |
|---|---|
| How will people open the panel? | `1` My own domain (free SSL) · `2` Free trycloudflare link · `3` Server IP |
| Admin account | email, username, first name, last name, password |

When finished it prints your panel link. Open it and log in.

## 🥚 Adding Minecraft / Discord bot eggs

Community eggs are downloaded to `/opt/wg-eggs`.
Go to **Admin → Nests**, create or open a nest, and **Import Egg** using the `.json` files from that folder.

## 📦 No KVM? Compatibility mode

If your server has no systemd (Docker container, LXC, some free hosts), the installer switches to **compatibility mode** automatically and runs everything with `supervisor`.
- The **panel works** in this mode.
- **Wings (game servers) needs Docker.** If Docker can't run on your host, the panel is installed without Wings and you attach a node from another server later.
- After a container restart, run `wg-start` to bring all services back.

## 🔥 Firewall ports

Open: `80`, `443`, `8080`, `2022` and your game ports (`25565` and up).

## ⚠️ Notes

- `trycloudflare.com` links change when the server restarts. Use a domain for a permanent address.
- Based on the open-source [Pterodactyl](https://pterodactyl.io) panel (MIT license).

## 📄 License

MIT — made by **WG**
