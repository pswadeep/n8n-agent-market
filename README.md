# n8n Market-Update Agent → Telegram

| Workflow file | Schedule (IST) | What it sends |
|---|---|---|
| `workflows/india-market-oi-hourly.json` | `0 9-15 * * 1-5` (hourly 9:00–15:00, Mon–Fri) | Nifty & BankNifty: spot, call/put OI, OI change, PCR, max-OI strikes. Sensex: index level only |
| `workflows/global-market-news-3h.json` | `0 */3 * * *` (every 3 h) | 12 market stories per run: 5 international (Trump / stock exchanges / big money flows) + India and general markets, from Yahoo Finance RSS, Google News RSS and the Finnhub market-news API. Each story = headline, summary, source hyperlink, image |

Each workflow also has a **Manual Test** trigger so you can run it any time.

## 1. Telegram bot (2 minutes)
1. In Telegram, message **@BotFather** → `/newbot` → copy the token.
2. Send any message to your new bot, then open
   `https://api.telegram.org/bot<TOKEN>/getUpdates` and copy `message.chat.id`.

## 1b. Finnhub API key (free, 1 minute)
Sign up at finnhub.io, copy the API key from the dashboard (free plan, 60 calls/min) and put it in `.env` as
`FINNHUB_API_KEY=...` (for GitHub Actions add it as a repo secret with the same name). Without a key the workflow
still works from Yahoo + Google News; the header line shows `Finnhub 0`.

**How the news message works:** each run sends a short header, then one Telegram message per story (about 12, one per
~1 second). Stories with an image (Finnhub, some Yahoo items) show it above the text; for the others Telegram shows the
article's own preview. The source name is the hyperlink. "New" = published in the last `NEWS_LOOKBACK_HOURS` (default 6)
and not already sent by this n8n instance; if fewer than 10 qualify, older stories fill up to 10. Tunables are at the
top of the *Build Digest* node (`INTL_COUNT`, `OTHER_COUNT`, `MIN_TOTAL`, theme keywords); feeds are in *Feed List*.
Google News links open Google's redirect page, and Google RSS items have no images.

## 2. Test on your PC (Docker Desktop required)
```bash
cp .env.example .env          # paste TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID
docker compose up -d
# open http://localhost:5678 → create the owner account
./scripts/import.sh           # Windows: run in WSL/Git Bash, or import the two JSON files via UI menu → Import from file
```
In the UI open each workflow → **Execute workflow** (manual trigger) → message should arrive in Telegram →
toggle **Active** (top right). The schedules then run by themselves while Docker is running.

Add/change things: edit in the UI (add a feed, a symbol, a node), then `./scripts/export.sh` to write it back
to `workflows/`. Quick edits without the UI: feeds are in the **Feed List** node, symbols in **Prepare Requests**,
region mapping and headline count at the top of **Format Message**.

## 3. Free hosting with 4 automatic runs a day: GitHub Actions (recommended)
No server at all. GitHub starts a free VM on a schedule, loads **every workflow in `./workflows`** into a throw-away
n8n container, runs them one after another, sends the Telegram messages and shuts down.

1. Create a **private** GitHub repo and push this folder (the `.github/workflows/n8n-scheduled.yml` path must stay as is).
2. Repo -> Settings -> Secrets and variables -> Actions -> add `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` and `FINNHUB_API_KEY`.
3. Actions tab -> "n8n scheduled runs" -> **Run workflow** to test (leave the box empty to run all, or type
   `india` / `news` to run only matching files).
4. Done. Runs Mon-Fri at IST 09:30, 13:30, 15:15 and 19:30 (UTC `cron:` lines in the YAML; edit to change).

* New workflow? Drop its `.json` into `workflows/` and it runs automatically. Files starting with `telegram-hi-` or `_`
  are skipped (they need an always-on n8n); change the `case` line in the YAML to skip others.
* If one workflow fails the others still run, and the job is marked failed so GitHub emails you.
* Every run sends both the India and the global message, so the 19:30 run shows India closing data. Remove a run time
  or move a workflow into a skipped name if you don't want that. `NEWS_LOOKBACK_HOURS` (6) sets how far back news goes.

Cost: $0. Public repos get unlimited free minutes; private repos get 2,000 min/month on the Free plan
(~4 runs x ~3 min x ~22 days = ~270 min/month). GitHub cron is best-effort and can start a few minutes late. Scheduled
workflows in *public* repos are disabled after 60 days without repo activity (not an issue for private repos).
GitHub's runners are in US datacenters, so **NSE will probably block the India workflow** there; the message then
says "NSE data unavailable". To fix: install a GitHub *self-hosted runner* on your own PC (free, home IP; PC must be on)
and change `runs-on: ubuntu-latest` to `runs-on: self-hosted`.

## 3c. Reply to "hi" on Telegram (on-demand updates)
Send **hi** (or hello / hey / update / /start) to your bot and it replies within seconds with the latest India
(Nifty, BankNifty, Sensex) update and the global news. Only messages from your own `TELEGRAM_CHAT_ID` are answered.
This needs n8n running all the time (Option B, your PC with Docker). It cannot run on GitHub Actions, because
Actions only runs on a timer and cannot sit and wait for a message.

**`workflows/telegram-hi-reply-polling.json` (use this one)** checks Telegram every 15 seconds. It needs no public
URL and no extra credentials, so it works on localhost. Import it, then switch it **Active**
(test by activating it and sending "hi"; manual runs don't remember which messages were already handled).
The bot must not have a webhook set (it won't, unless you used the other file).
Change the trigger words in the `TRIGGER` line of the *Get New Messages* node. Successful polls are not saved in the
execution list, to avoid thousands of empty entries; failures still are.

**`workflows/telegram-hi-reply-webhook.json`** uses n8n's Telegram Trigger node (instant). Telegram only delivers
to a public HTTPS address, so on localhost you need a tunnel, e.g. `cloudflared tunnel --url http://localhost:5678`,
then put the https URL in `.env` as `WEBHOOK_URL=` (with trailing slash), run `docker compose up -d` again, create
a Telegram credential in n8n (bot token), select it in the trigger node and activate. Free tunnel URLs change on
every restart, so polling is the easier choice. Use one of the two files, not both.

## 4. Known limits
* **NSE blocks bots.** The option-chain endpoint is unofficial and often rejects datacenter IPs (GitHub's included).
  If it fails, the message says "NSE data unavailable". Run the India workflow from your own PC (Option B) or use a broker API.
* **Sensex OI** is not included (no free public feed); Sensex shows the index level.
* Exchange holidays are not filtered. Check each site's terms before scraping; RSS URLs can change.
