#!/usr/bin/env bash
POMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$POMO_ROOT/.env"
if [[ -n ${TIMER_ACCESS_PATH:-} ]]; then
    exit 0
fi
if [[ -z ${TIMER_ACCESS_INPUT:-} ]]; then
    echo 'Set TIMER_ACCESS_INPUT in .env' >&2
    exit 1
fi
if command -v shasum >/dev/null 2>&1; then
    path=$(printf '%s' "$TIMER_ACCESS_INPUT" | shasum -a 256 | cut -c1-24)
else
    path=$(printf '%s' "$TIMER_ACCESS_INPUT" | sha256sum | cut -c1-24)
fi
umask 077
printf '\nTIMER_ACCESS_PATH=%s\n' "$path" >> "$POMO_ROOT/.env"
chmod 600 "$POMO_ROOT/.env"
