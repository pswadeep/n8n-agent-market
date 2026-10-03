# n8n Market-Update Agent → Telegram

| Workflow file | Schedule (IST) | What it sends |
|---|---|---|
| `workflows/india-market-oi-hourly.json` | `0 9-15 * * 1-5` (hourly 9:00–15:00, Mon–Fri) | Nifty & BankNifty: spot, call/put OI, OI change, PCR, max-OI strikes. Sensex: index level only |
| `workflows/global-market-news-3h.json` | `0 */3 * * *` (every 3 h) | Latest headlines for US, London/Europe, Asia (RSS) |

Each workflow also has a **Manual Test** trigger so you can run it any time.

## 1. Telegram bot (2 minutes)
1. In Telegram, message **@BotFather** → `/newbot` → copy the token.
2. Send any message to your new bot, then open
   `https://api.telegram.org/bot<TOKEN>/getUpdates` and copy `message.chat.id`.

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
No server at all. GitHub starts a free VM on a schedule, runs your workflow inside a throw-away n8n container,
sends the Telegram message and shuts down. Your workflow JSON files stay the single source of truth.

1. Create a **private** GitHub repo and push this folder (the `.github/workflows/n8n-scheduled.yml` path must stay as is).
2. Repo -> Settings -> Secrets and variables -> Actions -> add `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`.
3. Actions tab -> "n8n scheduled runs" -> **Run workflow** (pick `global`, then `india`) to test.
4. Done. Schedules (UTC cron in the YAML): India IST 09:30 / 11:30 / 13:30 / 15:00 Mon-Fri, Global IST 06:30 / 13:30 / 19:30 / 02:00.
   Edit the `cron:` lines to change times; `NEWS_LOOKBACK_HOURS` (8) controls how far back the news window looks.

Cost: $0. Public repos get unlimited free minutes; private repos get 2,000 min/month on the Free plan
(~8 runs/day x ~2 min = ~500 min/month). GitHub cron is best-effort and can start a few minutes late. Scheduled
workflows in *public* repos are disabled after 60 days without repo activity (not an issue for private repos).
The `n8n execute` CLI is used; if a future n8n version changes it, pin `N8N_VERSION` in the YAML.
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
