# Palette 2 + CANVAS on modern OctoPrint (2026)

Community compatibility toolkit for running Mosaic Palette 2 / 2S / 2S Pro with
CANVAS on a modern OctoPrint installation.

> **Status:** early community release.
>
> The initial target is the setup validated on **OctoPrint 1.11.8**, **Python
> 3.11**, and OctoPi in September 2026. Mosaic's original plugins are much older,
> so this project applies compatibility fixes instead of pretending the upstream
> releases are current.

## What this repo does

`install.sh` is designed to be safe to rerun. It:

1. Detects the OctoPrint virtual environment.
2. Creates a timestamped backup of the current OctoPrint configuration.
3. Downloads Mosaic's final Palette 2 and CANVAS plugin releases.
4. Applies modern-Python dependency fixes.
5. Installs the tested paho-mqtt 2.1.0 dependency used by CANVAS.
6. Installs the patched plugins into OctoPrint's own virtualenv.
7. Optionally installs the custom CANVAS thumbnail and theme-compat plugins
   when their source trees are present in `plugins/`.
8. Restarts OctoPrint.
9. Runs a basic health/plugin-load verification.

It **never** stores an OctoPrint API key.

## Upstream plugin versions

- Mosaic Palette 2 plugin: **3.0.1**
- Mosaic CANVAS plugin: **3.0.3**

These are downloaded from Mosaic's GitLab repositories during installation.

## Quick start

```bash
git clone https://github.com/Pup-Saturn/palette2-octoprint-2026.git
cd palette2-octoprint-2026
chmod +x install.sh scripts/*.sh
./scripts/audit-current.sh
./install.sh --check
sudo ./install.sh
```

By default the installer assumes an OctoPi-style virtualenv at:

```text
/opt/octopi/oprint
```

Override it if necessary:

```bash
sudo OCTOPRINT_VENV=/path/to/oprint ./install.sh
```

## Repository layout

```text
.
├── install.sh
├── README.md
├── LICENSE
├── .gitignore
├── docs/
│   ├── TROUBLESHOOTING.md
│   ├── RECOVERY.md
│   └── TECHNICAL-NOTES.md
├── patches/
│   └── README.md
├── plugins/
│   ├── canvas-thumbnails/
│   └── canvas-theme-compat/
└── scripts/
    ├── audit-current.sh
    ├── capture-working-install.sh
    └── verify.sh
```

## Security

The installer does not require your OctoPrint API key or other account
credentials. It downloads the original Mosaic plugin releases and installs
the compatibility fixes locally on your OctoPrint system.

Because installation modifies the OctoPrint Python environment and requires
root privileges, `install.sh` creates a timestamped backup of the OctoPrint
configuration before making changes. You are encouraged to review the script
before running it with `sudo`.

When reporting problems or sharing diagnostic information, do not publish
OctoPrint API keys, passwords, `.env` files, `config.yaml`, TLS private keys,
Wi-Fi credentials, or other secrets.

## The compatibility fixes

### Python dependencies

The old plugin metadata assumes dependency versions that no longer match a
modern OctoPrint Python environment. This installer rewrites the plugin
requirements before installation.

Palette 2:

```python
[
    "ruamel.yaml==0.19.1",
    "python-dotenv==1.2.3",
    "six==1.17.0",
]
```

CANVAS:

```python
[
    "ruamel.yaml==0.19.1",
    "python-dotenv==1.2.3",
    "AWSIoTPythonSDK==1.6.1",
    "PyJWT==2.13.0",
    "paho-mqtt==2.1.0",
    "dictdiffer==0.10.0",
]
```

### CANVAS + paho-mqtt 2.x

CANVAS still uses paho-mqtt's legacy Callback API v1. paho-mqtt 2.1.0 retains
that API for compatibility and emits only a deprecation warning. Testing on the
tested 2026 configuration confirmed that Mosaic's original MQTT constructor
continues to connect successfully, so the installer deliberately leaves
CANVAS's MQTT source unchanged.

## CANVAS runtime compatibility

The installer also applies two small Python 3 compatibility fixes to the
downloaded CANVAS 3.0.3 source before installation:

- initializes `self.canvas = None` so an early OctoPrint `ClientOpened` event
  cannot access the attribute before CANVAS initialization creates it;
- replaces the removed `platform.linux_distribution()` call with
  `platform.freedesktop_os_release()`.

Both fixes have been tested through a complete reinstall and subsequent
OctoPrint restart.

## Thumbnail support

The project includes a custom OctoPrint plugin that generates
CANVAS-compatible thumbnails for uploaded G-code. Its source should live at:

```text
plugins/canvas-thumbnails/
```

The capture helper knows about both the development/source tree and the installed
package name `octoprint_canvasthumbnails`.

## CANVAS theme compatibility

CANVAS's UI skin predates several generations of OctoPrint UI changes. The project includes a compatibility layer that fixes stale blue/green
holdouts and current settings-dialog selectors.

Its reusable source should live at:

```text
plugins/canvas-theme-compat/
```

The capture helper searches the active OctoPrint Python environment for custom
theme packages and references to `Saturn CANVAS Theme`.

## Recovery

See `docs/RECOVERY.md`.

## Disclaimer

This is an independent community project. It is not affiliated with or endorsed
by Mosaic Manufacturing or OctoPrint. Palette, CANVAS, Mosaic, and OctoPrint are
the property/trademarks of their respective owners.
