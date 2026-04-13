# RTP + accounting architecture (for PHP/MySQL backend)

Date: 2026-04-13

This doc complements the existing backend work (see: `sql/schema.sql`, `classes/User.php`, `classes/RTP.php` WIP). Goal: lock RTP/accounting data model and metrics **before** adding many games/bonuses, so we don’t refactor after first tests.

---

## 1) Core principle: separate **game outcomes** from **money movements**

### Why
RTP, fraud checks, bonuses, cashback, VIP, and reconciliations all break when you only store “final balance” or store a single `bets` table without a proper ledger.

### Recommendation
Use **double-entry-style ledger** (or at minimum an append-only wallet transactions table) + game rounds. Every balance change is an immutable transaction with a reference.

**Must-have invariants**
- A user’s balance = sum(all wallet ledger rows) for that currency.
- Each game round has idempotent settlement: cannot pay twice.
- Every bet and payout points to: game, round, user, and provably-fair seed snapshot.

---

## 2) RTP: two-loop model (mandatory)

### A) Theoretical RTP (target, per game variant)
**Definition:** computed from paytable/probabilities for a given configuration.

Store as a “game passport”:
- `game_id`, `variant_id` (e.g., Mines 5x5/3 mines vs 10 mines)
- `target_rtp` (e.g., 0.985)
- `house_edge` (= 1 - target_rtp)
- `max_win_multiplier`, `volatility_class`
- configuration JSON (rows/cols, risk level, payout curve)

This is **static** and used for:
- UI disclosure
- risk limits
- sanity checking actual RTP drift

### B) Actual RTP (observed, accounting-based)
**Definition:** from real money movement.

For a time window (hour/day/week) and dimension (game/variant/currency/region), compute:
- `total_wagered` = sum(bet amounts)
- `total_paid` = sum(payout amounts)
- `actual_rtp = total_paid / total_wagered`
- `ggr = total_wagered - total_paid` (gross gaming revenue)

**Important:** Use ledger movements tied to `round_id` to avoid missing/duplicate counts.

---

## 3) Minimal data model additions (to extend existing `sql/schema.sql`)

> Dev Lead already created base schema. Below are **tables/fields we should add** (or ensure exist), not PHP code.

### 3.1 Wallet ledger (append-only)
Table: `wallet_tx`
- `id` (PK)
- `user_id`
- `currency` (or `wallet_id`)
- `direction` ENUM('debit','credit')
- `amount` DECIMAL(18,8)
- `type` ENUM(
  'deposit','withdrawal','bet','payout','rollback',
  'bonus_grant','bonus_wager','bonus_convert',
  'cashback_grant','referral_bonus','vip_reward','adjustment'
)
- `game_id` NULL
- `round_id` NULL
- `bet_id` NULL
- `bonus_id` NULL
- `referral_event_id` NULL
- `provider_tx_id` (idempotency key)
- `created_at`

Indexes:
- (`user_id`,`created_at`)
- (`round_id`)
- unique (`provider_tx_id`)

### 3.2 Game rounds (settlement unit)
Table: `game_rounds`
- `id` (PK)
- `user_id`
- `game_id`, `variant_id`
- `currency`
- `status` ENUM('created','bet_placed','settled','rolled_back')
- `bet_amount`
- `payout_amount`
- `profit` (= bet - payout)
- `started_at`, `settled_at`
- `server_seed_hash`, `server_seed_revealed` (nullable)
- `client_seed`
- `nonce`
- `result_json` (final outcome)

Indexes:
- (`game_id`,`settled_at`)
- (`user_id`,`settled_at`)
- unique (`user_id`,`game_id`,`nonce`) (optional)

### 3.3 Bets vs. rounds
For simple games 1 bet = 1 round. For multi-step games (Mines) we still settle once; store intermediate steps in:

Table: `game_round_events`
- `id`
- `round_id`
- `event_type` (e.g., 'pick','cashout','auto')
- `event_json`
- `created_at`

### 3.4 Bonuses with wagering (to avoid abuse)
Table: `bonuses`
- `id`
- `user_id`
- `bonus_type` ENUM('deposit_match','freebet','freespins','cashback','manual')
- `currency`
- `amount_granted`
- `wagering_multiplier` (e.g., 30x)
- `wagering_required` (= amount_granted * multiplier)
- `wagering_completed`
- `status` ENUM('active','completed','expired','cancelled')
- `eligible_games_json`
- `created_at`, `expires_at`

Table: `bonus_ledger`
- `id`, `bonus_id`, `round_id`, `amount_wagered`, `created_at`

### 3.5 Referral (event-based + anti-abuse)
Table: `referral_codes`
- `id`, `owner_user_id`, `code`, `created_at`

Table: `referral_attributions`
- `id`, `referred_user_id`, `referrer_user_id`, `code_id`, `attributed_at`,
- `source` (utm/campaign), `ip_hash`, `device_hash`

Table: `referral_events`
- `id`, `referrer_user_id`, `referred_user_id`,
- `event_type` ENUM('signup','first_deposit','wager_milestone'),
- `amount`, `currency`, `created_at`

**Rule:** pay referral only after `first_deposit` clears + basic fraud checks.

### 3.6 VIP & cashback
Table: `vip_levels`
- `level`, `name`, `benefits_json`, `monthly_wager_requirement`

Table: `vip_user_status`
- `user_id`, `level`, `period_start`, `period_end`, `updated_at`

Table: `cashback_rules`
- `id`, `period` ('daily','weekly'), `rate`, `min_loss`, `eligible_games_json`

Table: `cashback_runs`
- `id`, `period_start`, `period_end`, `status`, `created_at`

Cashback is computed from **net losses** (bet - payout) per game set, then granted as `wallet_tx type='cashback_grant'`.

---

## 4) Metrics we need from day 1 (admin dashboard + alerts)

### Financial
- GGR by game/variant/currency/day
- Net revenue after bonuses/cashback/referrals
- Bonus cost ratio = (bonus + cashback + referral payouts) / wagered

### Game health
- Actual RTP vs Target RTP (daily + rolling 7d)
- Volatility proxy: stddev of profit per round; max drawdown
- Large win concentration (% of payouts to top 1% winners)

### User health
- ARPU, retention D1/D7/D30
- Deposit conversion, KYC/withdrawal funnels (if applicable)

### Risk & abuse
- Bonus abuse: high wagering with zero deposits, multi-account patterns
- Referral abuse: shared device/IP clusters
- Rapid bet loops / bot-like patterns

---

## 5) Game portfolio: what to implement first (mini-games)

Prioritization criteria: fast rounds, easy RTP control, provably-fair friendly, low implementation risk.

**Tier 1 (MVP, highest ROI / easiest)**
1. Dice (1-100 roll-under) — simple math, adjustable house edge.
2. Limbo — multiplier target, also very simple.
3. Crash — popular, but needs strong fairness + anti-manipulation controls.
4. Mines — engaging, multi-step; store events.
5. Plinko — good retention; needs correct discrete distribution.

**Tier 2**
- Blackjack (requires rules clarity, shoe/reshuffle policy)
- Roulette (European vs American; careful with 0/00)

Slots are content-heavy (art/paytables). Consider adding later or using a single simple slot prototype.

---

## 6) Provably fair: what to store
Per round store:
- `server_seed_hash` at bet time
- `client_seed`, `nonce`
- `server_seed_revealed` at settle time
- `result_json` with enough detail to reproduce

Also store a server-seed rotation table:
Table: `pf_seed_batches`
- `id`, `user_id`, `server_seed`, `server_seed_hash`, `created_at`, `revealed_at`

---

## 7) House edge defaults (starting points)
These are product defaults (can tune later):
- Dice/Limbo: 1.0% house edge
- Mines: 1.0–2.0% depending on risk profile
- Plinko: 1.0–3.0%
- Crash: 1.0% (typical) with cap controls

---

## 8) Implementation notes for Dev Lead (to avoid refactors)
- Make **one** settlement endpoint per game that:
  1) creates round
  2) debits bet via `wallet_tx`
  3) computes result using provably fair
  4) credits payout via `wallet_tx`
  5) marks round settled
- Use DB transaction + idempotency key.
- Never update balances directly; only via ledger append.

---

## 9) Acceptance checklist
- Can recompute balances from ledger for any user.
- Can recompute actual RTP for any game/time window from DB.
- Any round can be reproduced from seeds.
- Bonuses/referrals/cashback are ledger-backed and auditable.
