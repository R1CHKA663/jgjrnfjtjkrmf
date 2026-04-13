# NeonVault Casino (PHP/MySQL)

Backend-first casino platform skeleton with MySQL schema, user model, and RTP/accounting design docs.

## What’s in this repo
- `classes/Database.php` — PDO singleton
- `classes/User.php` — user CRUD + auth helpers
- `sql/schema.sql` — core schema (MySQL 8+)
- `casino/sql/full_schema.sql` — expanded schema draft
- `docs/rtp-architecture-and-metrics.md` — RTP + ledger architecture (2026-04-13)
- `docs/game-portfolio-recommendations-2026.md` — recommended first mini-games (2026-04-13)
- `casino/index.html` — landing page mock

## Quick start (local)
1) Create a `.env` from `.env.example`.
2) Create DB + tables:
   - Run `sql/schema.sql` (or `casino/sql/full_schema.sql` if you want the expanded draft).
3) Point your PHP runtime to the project root and ensure `$_ENV` is loaded (e.g., via `vlucas/phpdotenv` in your bootstrap).

## Next engineering steps
- Implement wallet ledger + idempotent game settlement endpoints (see `docs/rtp-architecture-and-metrics.md`).
- Add `classes/RTP.php` + game engines (Dice/Limbo/Mines/Plinko/Crash) with provably-fair seeds.
- Add API endpoints: register/login/balance/transactions + first game endpoint.

## License
Proprietary (internal).