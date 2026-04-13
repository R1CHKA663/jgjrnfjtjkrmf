# Mini-games to build first (2026) + RTP/edge controls

Date: 2026-04-13

Goal: recommend a high-velocity mini-game set that is (1) provably-fair compatible, (2) low dev complexity, (3) easy to tune for stable RTP, and (4) supports VIP/bonus mechanics.

## Summary recommendation (MVP)
1) **Dice** (roll-under)
2) **Limbo** (target multiplier)
3) **Mines** (grid picks + cashout)
4) **Plinko** (discrete bins)
5) **Crash** (multiplier growth + bust)

Add later: Roulette, Blackjack. Slots last (content-heavy).

---

## 1) Dice
**Why:** simplest to implement, transparent math, excellent for testing wallet/ledger/RTP pipelines.

**Control knobs**
- House edge (e.g., 1%) applied to payout formula.

**Telemetry**
- wagered, paid, rtp, distribution of chosen win-chances.

---

## 2) Limbo
**Why:** same benefits as dice, but “multiplier chase” UX.

**Control knobs**
- House edge (1%)
- Max multiplier cap

**Abuse considerations**
- Very high multipliers can create PR wins; cap per user tier.

---

## 3) Mines
**Why:** sticky gameplay, good session time.

**Implementation detail**
- Treat as 1 round with multiple events.
- Store `game_round_events` for picks/cashout.

**Control knobs**
- Payout curve per mines count and picks
- House edge baked into multipliers

---

## 4) Plinko
**Why:** high engagement; easy A/B with risk levels.

**Implementation detail**
- Use a deterministic mapping from RNG to path/bucket.
- Predefine bin multipliers (risk profiles).

**Control knobs**
- Multipliers table per risk
- Bet limits

---

## 5) Crash
**Why:** very popular, social; but more sensitive reputationally.

**Implementation detail**
- Pre-commit server seed hash.
- Compute crash point deterministically.
- Allow cashout before bust.

**Control knobs**
- House edge (e.g., 1%)
- Max crash cap
- Rate limiting / anti-bot

**Risk**
- Needs clear fairness verification UI.

---

## Default house-edge starting points
- Dice/Limbo: 1.0%
- Mines/Plinko: 1.0–2.0%
- Crash: 1.0%

---

## Data needed per game (non-negotiable)
- Round id
- Bet amount + payout amount
- Server seed hash at bet time
- Client seed + nonce
- Server seed reveal at settle
- Result JSON sufficient to reproduce

This aligns with `docs/rtp-architecture-and-metrics.md`.
