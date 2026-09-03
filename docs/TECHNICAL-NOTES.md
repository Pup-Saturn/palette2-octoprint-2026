# Technical notes

## Why this exists

Mosaic's Palette 2 and CANVAS OctoPrint plugins are legacy software. Their final
public releases were built for an older OctoPrint/Python dependency ecosystem.

A modern install can fail for several independent reasons:

- dependency declarations incompatible with modern Python packages;
- `ruamel.yaml` packaging/version changes;
- paho-mqtt 2.x callback API changes;
- OctoPrint UI/DOM changes that expose old CANVAS theme assumptions.

The goal here is to apply narrowly scoped compatibility patches while leaving
Mosaic's core Palette/CANVAS behavior intact.

## Known-good baseline

Initial community validation:

- OctoPrint 1.11.8
- Python 3.11 virtualenv
- OctoPi
- Palette 2S Pro
- CANVAS cloud integration
- custom CANVAS thumbnail rendering
- current-OctoPrint CANVAS theme compatibility

## Do not blindly copy an entire site-packages tree

The installer downloads the upstream plugins and applies reproducible changes.
Only genuinely custom code should live in `plugins/`.

That makes the repository auditable and avoids publishing unrelated packages,
machine-specific configuration, or secrets.

## Why keep paho-mqtt 2.x

Older community fixes often pinned `paho-mqtt<2`. The known-good 2026 setup can
instead patch the CANVAS client constructor to request the v1 callback API.
That keeps a current MQTT package while preserving CANVAS's legacy callback
signatures.

## Licensing

Do not copy Mosaic's entire plugin source into this repository unless its
license clearly allows redistribution in the intended form and all required
notices are preserved. Prefer a patch-and-download installer.
