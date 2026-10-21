# My Omarchy setup

Everything I configured on top of a fresh [Omarchy](https://omarchy.org/) install, step by step, so I can reproduce this exact machine on another computer.

- **Base:** Omarchy 4.0.5 (Arch Linux + Hyprland 0.56, Lua config)
- **Hardware it was made on:** AMD Ryzen 7 5800X, NVIDIA RTX 3070, 55" 4K TV over HDMI (`HDMI-A-1`)
- **Last updated:** 2026-10-21

Each section lists **what** was changed, **why**, and the **exact commands or file contents** to apply it. Commands that need `sudo` will ask for your password.

---

## 0. First things first: system update

A fresh offline install doesn't have the online package databases yet. Until you update, repo packages (e.g. VS Code) fail with `target not found`.

```bash
omarchy update
```

Reboot if it asks.

---

## 1. Display: 4K TV scaling

**Why:** At scale 1, a 55" 4K TV viewed from a distance makes everything tiny.

**File:** `~/.config/hypr/monitors.lua`. Add this line below the commented examples:

```lua
hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@60", position = "0x0", scale = 2.5 })
```

- `2.5` makes the UI the size of a 1536×864 screen while staying 4K sharp. Use `2` for smaller, `3` for bigger.
- Check your output name and modes with `hyprctl monitors all`. It may not be `HDMI-A-1` on another machine.

Apply and validate:

```bash
hyprctl reload && hyprctl configerrors
```

---

## 2. Keyboard: US + Brazilian layouts, normal Caps Lock

**Why:**
- Omarchy maps Caps Lock to the Compose key by default. I want a normal Caps Lock.
- My keyboard is physically US, but I need `ç` and Portuguese accents sometimes, so I switch to the Brazilian layout when writing in Portuguese.

**File:** `~/.config/hypr/input.lua`. Append at the end:

```lua
-- US and Brazilian layouts; switch with Left Alt + Right Alt.
-- Caps Lock works as a normal Caps Lock.
hl.config({
  input = {
    kb_layout = "us,br",
    kb_variant = ",",
    kb_options = "grp:alts_toggle",
  },
})
```

- **Switch layouts:** press **both Alt keys** together. The bar shows the active layout.
- On a US keyboard with the `br` layout, `ç` is on the `;` key.
- This replaces Omarchy's `compose:caps,shift:both_capslock_cancel`, so there's no Compose key anymore.

```bash
hyprctl reload && hyprctl configerrors
```

---

## 3. Default browser: Brave

```bash
omarchy install browser brave
omarchy default browser brave
```

The first command installs Brave with Omarchy's theme, Wayland flags and extensions. The second sets it as the default for Omarchy (`Super + Shift + B`) and for links opened by other apps.

---

## 4. Terminal: syntax colors and history suggestions (ble.sh)

**Why:** I had this on macOS and my old Arch install: while typing, a valid command turns **green** and an invalid one turns **red**, and the shell suggests (in gray) a previous command from history that I accept with **Tab**.

Omarchy uses **bash**, so this uses [ble.sh](https://github.com/akinomyoga/ble.sh) instead of zsh plugins. That keeps all of Omarchy's bash aliases and integrations.

**Install:**

```bash
omarchy pkg aur add blesh-git
```

**File:** `~/.bashrc`. The final file looks like this (Omarchy's default plus my additions):

```bash
# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# ble.sh: syntax colors (green/red) and history suggestions while typing
[[ -f /usr/share/blesh/ble.sh ]] && source /usr/share/blesh/ble.sh --noattach

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

# Rust (rustup/cargo)
. "$HOME/.cargo/env"

# ble.sh: Tab accepts the gray suggestion (Right Arrow works too)
if [[ ${BLE_VERSION-} ]]; then
  ble-bind -m auto_complete -f TAB auto_complete/insert
  # Valid command = green, unknown command = red
  ble-face -s command_file fg=green
  ble-face -s command_builtin fg=green
  ble-face -s command_keyword fg=green
  ble-face -s command_function fg=green
  ble-face -s command_alias fg=green
  ble-face -s syntax_error fg=red
  ble-attach
fi
```

**Rules:**
- `ble.sh --noattach` must come **before** Omarchy's rc.
- `ble-attach` must be the **last** thing in the file.
- The `.cargo/env` line only applies after Rust is installed (section 9). Without Rust, remove it.

Open a new terminal to see it working.

---

## 5. Terminal: copy on select (foot)

**Why:** Selecting text in the terminal copies it straight to the clipboard, so I can paste anywhere with `Ctrl + V`.

**File:** `~/.config/foot/foot.ini`, in the `[main]` section, right after `workers=0`:

```ini
# Copy to clipboard automatically when selecting text
selection-target=clipboard
```

Applies to new terminal windows. Check the syntax with `foot --check-config`.

---

## 6. Workspace overview on Super + Tab (Hyprspace)

**Why:** A macOS Mission Control-style overview. `Super + Tab` shows every workspace as a thumbnail and I can **drag windows between workspaces** with the mouse.

Uses the [Hyprspace](https://github.com/KZDKM/Hyprspace) plugin, built locally against the installed Hyprland headers. No sudo needed.

### 6.1 Build

```bash
mkdir -p ~/.local/src && cd ~/.local/src
git clone https://github.com/KZDKM/Hyprspace
cd Hyprspace && make all
pacman -Q hyprland > .built-for
```

This produces `~/.local/src/Hyprspace/Hyprspace.so`.

### 6.2 Load it on login

**File:** `~/.config/hypr/autostart.lua`. Append:

```lua
-- Hyprspace: workspace overview (Super + Tab)
o.exec_on_start("hyprctl plugin load " .. os.getenv("HOME") .. "/.local/src/Hyprspace/Hyprspace.so")
```

### 6.3 Bind Super + Tab

**File:** `~/.config/hypr/bindings.lua`. Append:

```lua
-- Hyprspace: Super + Tab opens the overview; drag windows between workspaces
hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Workspace overview", function()
  if hl.plugin and hl.plugin.overview then
    hl.plugin.overview.toggle()
  end
end)
```

This replaces Omarchy's default `Super + Tab` (next workspace). `Super + 1…9` still switches workspaces.

### 6.4 Load it now without logging out

```bash
hyprctl plugin load ~/.local/src/Hyprspace/Hyprspace.so
hyprctl reload && hyprctl configerrors
```

### 6.5 Rebuild automatically after Hyprland updates

A plugin must be rebuilt whenever Hyprland's version changes. This Omarchy hook does it after every `omarchy update` and sends a notification asking you to log out and back in.

Save as `~/.local/src/Hyprspace-hook/rebuild-hyprspace.hook`:

```bash
#!/bin/bash

# Rebuilds Hyprspace when the Hyprland version changes,
# so the plugin keeps loading on the next login.
src="$HOME/.local/src/Hyprspace"
marker="$src/.built-for"
current=$(pacman -Q hyprland 2>/dev/null)

[[ -d $src ]] || exit 0
[[ -f $marker && $(cat "$marker") == "$current" ]] && exit 0

if make -C "$src" all >/dev/null 2>&1; then
  echo "$current" > "$marker"
  omarchy-notification-send "Hyprspace rebuilt" "Log out and back in to use Super + Tab."
else
  omarchy-notification-send -u critical "Hyprspace failed to rebuild" "Super + Tab may not work until the plugin is updated."
fi
```

Install it:

```bash
chmod +x ~/.local/src/Hyprspace-hook/rebuild-hyprspace.hook
omarchy hook install post-update ~/.local/src/Hyprspace-hook/rebuild-hyprspace.hook
```

**Risk:** if a future Hyprland release breaks the plugin, the hook notifies you and `Super + Tab` stops working. Nothing else is affected.

---

## 7. Git identity

```bash
git config --global user.name "Erick Pimentel"
git config --global user.email "erickpimentel.business@gmail.com"
```

Omarchy's other git defaults (aliases, rebase on pull, etc.) stay as they come in `~/.config/git/config`.

---

## 8. GitHub over SSH

`gh` creates an SSH key, uploads it to GitHub and logs in, all in one go. Run it in a terminal because it asks questions:

```bash
gh auth login --hostname github.com --git-protocol ssh --web
```

Answers:
1. **Generate a new SSH key?** `Y`
2. **Passphrase:** Enter for none (simpler), or set one
3. **Title:** Enter, or a name like `omarchy-<machine>`
4. Copy the code shown, log in to GitHub in the browser and authorize

Verify:

```bash
ssh -T git@github.com     # "Hi erickpimentelbusiness! You've successfully authenticated"
gh auth status
```

The key is `~/.ssh/id_ed25519`. Each machine gets its own key, so you don't need to copy keys between computers.

---

## 9. Programming tools

### 9.1 Rust

```bash
omarchy install dev-env rust     # rustup + cargo + rustc, no sudo
cargo install rustlings          # official interactive exercises
```

`rustup` appends `. "$HOME/.cargo/env"` to the **end** of `~/.bashrc`. Move it **above** the ble.sh block (see section 4), because `ble-attach` must stay last.

### 9.2 IDEs

```bash
omarchy pkg aur add android-studio intellij-idea-ultimate-edition rustrover rustrover-jre antigravity
omarchy install editor vscode
```

| App | Notes |
|---|---|
| **Android Studio** | Downloads the Android SDK on first launch. |
| **IntelliJ IDEA** | JetBrains merged the editions into one product. Core features are free; Ultimate features need a subscription. |
| **RustRover** | Pick the free **"Non-commercial use"** license on first launch. |
| **Antigravity** | Google's AI editor. The AUR package downloads straight from Google's servers. |
| **VS Code** | Omarchy's installer applies the system theme. Add the **rust-analyzer** extension for Rust. |

**RustRover won't open ("Cannot find a runtime"):** the AUR package is split in two, and the Java runtime lives in `rustrover-jre`. Install it (included in the command above). If the AUR rate-limits you (`status 429`), a temporary workaround is to borrow IntelliJ's runtime, since both are the same 2026.2 release:

```bash
mkdir -p ~/.config/JetBrains/RustRover2026.2
echo "/opt/intellij-idea-ultimate-edition/jbr" > ~/.config/JetBrains/RustRover2026.2/rustrover.jdk
```

Once `rustrover-jre` is installed, delete that file so RustRover uses its own runtime.

---

## 9.3 Screen stays on for 8 hours

**Why:** Omarchy starts the screensaver after 2.5 minutes and locks after 5 minutes, and the display turns off 5 seconds after locking. Too fast for a desktop PC.

**File:** `~/.config/omarchy/shell.json`. Set both timeouts (in seconds) to 8 hours:

```json
"idle": {
  "screensaver": 28800,
  "lock": 28800
},
```

The shell reloads the file on save, no restart needed. The screen locks and turns off only after 8 hours idle.

---

## 9.4 Local AI: Ollama, Open WebUI and OpenCode

**Why:** Run coding and privacy/security models locally, with nothing leaving the machine. The NVMe is almost full, so everything lives on the 2 TB external SSD (Samsung T7 Shield).

**Layout:**

| Path | What | Filesystem |
|---|---|---|
| `/mnt/ssd` | The whole SSD, shared with Windows (games) | exFAT |
| `/mnt/ssd/ai/ollama/models` | Ollama models | exFAT |
| `/mnt/ssd/linux-ai.img` → `/mnt/ai` | 30 GB Linux disk image: Ollama binaries, Docker, Open WebUI | ext4 (loop) |

The SSD stays exFAT so nothing had to be erased. Docker and Ollama's binaries need a Linux filesystem (permissions, symlinks), hence the small ext4 image. Models are plain big files, so they sit directly on exFAT with 1.6 TB free.

**Gotchas I hit:**
- **Cable:** the SSD ran at USB 2.0 (480 Mbps, ~35 MB/s) with the wrong cable. Use the T7's original USB 3.2 cable. Check the link speed with `cat /sys/block/sdX/device/../../../../speed` (5000 or 10000 = USB 3).
- **exFAT zero-fills a file before writing past its end.** Creating a 300 GB image took hours, so the image is 30 GB. Grow it later with `fallocate` + `resize2fs` if needed.

### Root part (run once)

[`scripts/ai-setup-root.sh`](scripts/ai-setup-root.sh): adds `/mnt/ssd` and `/mnt/ai` to `/etc/fstab` (both `nofail`, so boot works without the SSD), creates the image, moves Docker's `data-root` to `/mnt/ai/docker` and starts Open WebUI on `127.0.0.1:3000` (no login, no telemetry, not reachable from the network).

```bash
sudo bash scripts/ai-setup-root.sh
```

### Ollama (no sudo)

```bash
mkdir -p /mnt/ai/ollama /mnt/ssd/ai/ollama/models
curl -fsSL https://github.com/ollama/ollama/releases/download/v0.40.7/ollama-linux-amd64.tar.zst | tar --zstd -x -C /mnt/ai/ollama
ln -sf /mnt/ai/ollama/bin/ollama ~/.local/bin/ollama
cp configs/ollama.service ~/.config/systemd/user/
systemctl --user daemon-reload && systemctl --user enable --now ollama
```

[`configs/ollama.service`](configs/ollama.service) runs Ollama as my user (starts at login), models on the SSD, 32k context, q8 KV cache and one model loaded at a time (8 GB VRAM + 32 GB RAM).

### Models

```bash
# Coding
ollama pull qwen3-coder:30b       # main coding agent, ~30 tok/s on the RTX 3070
ollama pull glm-4.7-flash
ollama pull gpt-oss:20b
ollama pull qwen2.5-coder:1.5b    # autocomplete / small tasks
# Privacy and security discussions
ollama pull gemma4:26b
ollama pull qwen3.6:35b
ollama pull hf.co/fdtn-ai/Foundation-Sec-8B-Reasoning-Q4_K_M-GGUF   # Cisco security specialist
```

### OpenCode

`cp configs/opencode.json ~/.config/opencode/opencode.json`. [`configs/opencode.json`](configs/opencode.json) points OpenCode at Ollama, defaults to `qwen3-coder:30b` and asks before running shell commands or editing files.

### Daily use

- **Chat (privacy/security):** open http://127.0.0.1:3000 and pick a model at the top.
- **Coding agent:** `opencode` inside a project folder.
- **Models loaded right now:** `ollama ps`. Switching models takes ~10–30 s.

---

## 10. Things I tried and removed

- **Voxtype (voice dictation):** didn't like it. Removed with `omarchy voxtype remove`. If Omarchy invites you to install it after an update, ignore it.
- **Stremio:** the AUR install got stuck before the first system update, then hit an AUR rate limit. Not installed. Options if I want it later: `omarchy pkg aur add stremio` (full app, compiles from source), the Flathub Flatpak, or the web app at `web.stremio.com`.

---

## 11. Pending / ideas for the future

- [ ] **VS Code:** `omarchy install editor vscode` (needs `omarchy update` first)
- [ ] **`rustrover-jre`:** install it and remove the IntelliJ runtime workaround (section 9.2)
- [ ] **Key repeat:** if keys repeat when held a bit too long, raise `repeat_delay` (Omarchy uses 250 ms) in `~/.config/hypr/input.lua`, e.g. to 400–500 ms

---

## Quick reference: keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Super + K` | Show all keybindings |
| `Super + Tab` | Workspace overview (Hyprspace) |
| `Super + ←→↑↓` | Focus the window in that direction |
| `Alt + Tab` | Next window |
| `Super + 1…9` | Go to workspace 1…9 |
| `Super + Shift + 1…9` | Move window to workspace 1…9 |
| `Super + Shift + ←→↑↓` | Swap window with its neighbor |
| `Super + Ctrl + Tab` | Previous workspace |
| `Super + W` | Close window |
| `Super + F` | Fullscreen |
| `Super + Enter` | Terminal |
| `Super + Shift + B` | Browser (Brave) |
| `Super + Space` | Omarchy menu |
| `Super + Alt + Space` | App launcher |
| `Left Alt + Right Alt` | Switch keyboard layout (US ↔ BR) |
