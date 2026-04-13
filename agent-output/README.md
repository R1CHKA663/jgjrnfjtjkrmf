# NeonVault Casino

A Stake-style mini-games casino MVP with a modern neon UI and a PHP/MySQL backend.

**Status (2026-04-13):** backend schema + core classes in progress; marketing docs added for GTM, content, and press.

## What’s in this repo
- `casino/` — static frontend prototype (HTML/CSS)
- `classes/` — PHP backend classes (DB, User, Wallet/RTP, etc.)
- `sql/` and `casino/sql/` — database schema (MySQL)
- `docs/` and `research/` — architecture + research notes
- `MARKETING/` — GTM plan, content calendar, press kit

## Quick start (local)
1) Copy env:
- `cp .env.example .env`

2) Create DB and import schema (choose one):
- `mysql -u root -p < sql/schema.sql`
- or `mysql -u root -p < casino/sql/full_schema.sql`

3) Configure `.env` with your DB credentials.

4) Serve locally (example):
- `php -S localhost:8080 -t casino`

> Note: API endpoints may be added in a separate `api/` folder depending on the backend routing approach.

## MVP scope
Games recommended for MVP:
- Dice, Limbo, Mines, Plinko, Crash

Core systems:
- Auth, wallet/ledger, provably-fair, RTP tracking, promotions/VIP (phased)

## License
Proprietary (internal MVP).