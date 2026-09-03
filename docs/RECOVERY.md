# Recovery

## Important secret

The optional status/overlay service uses:

```text
/opt/octoprint-status/.env
```

Recreate it after disaster recovery:

```dotenv
OCTOPRINT_URL=http://localhost
OCTOPRINT_API_KEY=<NEW OCTOPRINT API KEY>
```

Never commit the real key.

Protect the file:

```bash
sudo chmod 600 /opt/octoprint-status/.env
```

## Status service

Restore the unit to:

```text
/etc/systemd/system/octoprint-status.service
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable octoprint-status.service
sudo systemctl restart octoprint-status.service
```

Verify:

```bash
curl -s http://localhost:8787/health
echo
```

Expected:

```json
{"status":"ok"}
```

## Recommended backup exclusions

The known-good weekly OctoPrint configuration backup excludes:

```text
.octoprint/data/backup
.octoprint/timelapse
.octoprint/logs
```

Those directories are unnecessary for core disaster recovery and can be large
or actively changing during backup.

## Verify archives

```bash
for f in /path/to/backup/*.tar.gz; do
  printf '%-40s ' "$(basename "$f")"
  tar -tzf "$f" >/dev/null && echo OK || echo FAILED
done
```
