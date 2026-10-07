# MySQL Slow Log Analyzer

Rank the worst queries in your MySQL/MariaDB slow query log — no `pt-query-digest` needed, just `awk` and `sort`.

Queries are grouped by a **normalised fingerprint** (literals collapsed to `?`, `IN (…)` lists collapsed to `...`), then ranked by **total execution time**, so the queries hurting you most come first.

## What's inside

| File | What it does |
|---|---|
| `analyze-slow-log.sh` | Parses a slow query log and prints a Top-N table: total time, count, max time, fingerprint |

## Usage

```bash
chmod +x analyze-slow-log.sh

# Top 20 worst queries in the default slow log
sudo ./analyze-slow-log.sh

# Custom log, top 10, ignore anything under 1 second
./analyze-slow-log.sh --log /var/log/mysql/mysql-slow.log --top 10 --min-seconds 1
```

Example output:

```
TOTAL_SECS   COUNT    MAX_SECS    QUERY FINGERPRINT
12.842       34       1.204       SELECT * FROM wp_posts WHERE post_status = '?' AND ...
 7.531        9       2.010       SELECT * FROM wp_options WHERE option_name = '?' ...
```

Enable the slow log in MySQL/MariaDB if it isn't on yet:

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
```

Work through the top rows with `EXPLAIN`, add covering indexes, and watch the totals drop.

MIT licensed. Contributions welcome.
