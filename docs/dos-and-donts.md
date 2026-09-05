# Dos and Don'ts with AbletonOS

A collection of recommendations when interacting with AbletonOS.

## Occasionally clear `/tmp/ableton-cache`

Some users report high CPU load and battery drain due to Live scanning this cache.

Run as root user:

```bash
rm -rf /tmp/ableton-cache
```
