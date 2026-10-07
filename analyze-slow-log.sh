#!/usr/bin/env bash
# analyze-slow-log.sh — Top-N report from a MySQL/MariaDB slow query log.
#
# Usage: analyze-slow-log.sh [--log /var/log/mysql/mysql-slow.log] [--top 20] [--min-seconds 0]
#
# Groups queries by a normalised fingerprint (literals collapsed to '?'), then
# ranks them by total execution time. No pt-query-digest required — pure awk/sort.
set -euo pipefail

LOG=/var/log/mysql/mysql-slow.log
TOP=20
MIN_SECONDS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --log)         LOG="$2"; shift 2 ;;
        --top)         TOP="$2"; shift 2 ;;
        --min-seconds) MIN_SECONDS="$2"; shift 2 ;;
        -h|--help)     sed -n '2,6p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

[[ -r "$LOG" ]] || { echo "Cannot read slow log: $LOG" >&2; exit 1; }

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Parse: accumulate each Query_time + normalised fingerprint, then aggregate.
awk -v min="$MIN_SECONDS" '
    /^# Query_time:/ { qt = $3 }
    /^use |^SET timestamp=|^# / { next }
    NF == 0 { next }
    {
        q = $0
        # Fingerprint: collapse string/number literals and IN-lists.
        gsub(/\x27[^\x27]*\x27/, "\x27?\x27", q)   # quoted strings
        gsub(/"[^"]*"/, "\"?\"", q)                 # double-quoted strings
        # Bare numbers (mawk-safe: no \b word boundaries).
        q = " " q " "
        while (match(q, /[^0-9A-Za-z_.][0-9]+/))
            q = substr(q, 1, RSTART) "?" substr(q, RSTART + RLENGTH)
        sub(/^ /, "", q); sub(/ $/, "", q)
        gsub(/\?([[:space:]]*,[[:space:]]*\?)+/, "?...", q)  # IN (?, ?, ?)
        gsub(/[[:space:]]+/, " ", q)               # squash whitespace
        if (qt + 0 >= min + 0) {
            total[q] += qt
            count[q]++
            if (qt > max[q]) max[q] = qt
        }
    }
    END {
        for (q in total)
            printf "%.6f\t%d\t%.6f\t%s\n", total[q], count[q], max[q], q
    }
' "$LOG" | sort -rn | head -n "$TOP" > "$TMP"

printf '%-12s %-8s %-10s  %s\n' "TOTAL_SECS" "COUNT" "MAX_SECS" "QUERY FINGERPRINT"
printf '%-12s %-8s %-10s  %s\n' "----------" "-----" "--------" "-----------------"
while IFS=$'\t' read -r total count maxq query; do
    printf '%-12.3f %-8d %-10.3f  %.100s\n' "$total" "$count" "$maxq" "$query"
done < "$TMP"

echo
echo "Tip: run EXPLAIN on the worst offenders, then add a covering index."
