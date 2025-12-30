# QuakeC ↔ Python Compatibility Notes

This project bridges QuakeC (everything is a 32-bit float) with Python. Keep the interface boring and predictable.

## Numeric Limits

- QuakeC uses 32-bit floats (about 6–7 decimal digits of precision).
- Avoid sending large integer IDs/timestamps across the boundary as floats.

## Units

- Quake angles are degrees (yaw/pitch).
- Quake positions/velocities are Quake units (not meters).

## NDJSON Formatting

- One JSON object per line (`\n` terminated).
- Keep telemetry lines reasonably small; if you need more data, send multiple messages instead of one giant object.

## Float Formatting Quirks

Some engine/printf combinations can emit scientific notation (example: `1e-6`) for very small/large values.

Recommendations:
- Prefer “Quake-ish” ranges (health/ammo/pos/vel).
- Clamp/round values before logging if needed.
- Don’t encode protocol-critical values (IDs, timestamps) as floats.

## Timing / Sync

- Quake runs on its own tick/frame loop; Python may run faster/slower.
- For training, prefer a request/response style loop (send action after receiving the latest state) to avoid backlog/latency.
