# Casino website design benchmarks (as of 2026-04-13)

## What we’re trying to copy (structure & patterns, not brands)
A modern casino site typically optimizes for:
- **Fast path to play**: search + category filters + large game grid, above-the-fold CTAs.
- **Conversion**: bonus offer, trust signals, payments, license/responsible gambling.
- **Retention**: personalized recommendations, recently played, jackpots/VIP.

## Reference patterns to replicate
### 1) Homepage / Landing
**Common sections**
1. **Hero**: headline + primary CTA ("Play Now"/"Join"), secondary CTA ("View Games"), bonus strip.
2. **Popular games carousel**: horizontal scroll, 5–8 cards visible desktop.
3. **Category shortcuts**: Slots, Live Casino, Table Games, Jackpots, New.
4. **Top promos**: 2–4 tiles (Welcome Bonus, Free Spins, Cashback, Tournaments).
5. **Jackpots band**: 3–5 jackpot cards with animated counters.
6. **Payments & trust**: Visa/Mastercard/Apple Pay/crypto icons, SSL, licensing.
7. **Responsible gambling + age gate**: 18+/21+ badges, links to help organizations.

**Visual style trends**
- Dark UI with neon gradients, gold accents for "premium".
- Large rounded cards, soft shadows, blurred glows.
- Motion: subtle hover tilt, animated jackpot counters, shimmer on CTA.

### 2) Game Lobby / Catalog
**Key components**
- Sticky top bar: logo, search, login/signup, wallet.
- Filter row: category chips + provider + volatility/feature toggles.
- Game grid: 4–6 columns desktop, 2 columns mobile.
- "Recently played" and "Recommended" rails.
- Game cards: thumbnail, provider badge, RTP tooltip, quick "Play" overlay.

### 3) Promo pages
- Promo card list w/ expiry, wagering requirements link.
- Clear T&Cs accordion.

### 4) VIP page
- Tier ladder, benefits table, progress bar.

### 5) Footer (must-have)
- Licensing disclaimer placeholder.
- Responsible gambling links.
- KYC/AML note.
- Payment icons.

## Content/IA suggestion for our build
- `/` Home
- `/games` Lobby
- `/promotions`
- `/vip`
- `/support` FAQ + contact
- `/terms`, `/privacy`, `/responsible-gaming`

## Compliance & UX notes (non-legal advice)
- Show **age restriction** and **responsible gambling** in header/footer.
- Avoid implying guaranteed winnings.
- Make bonus terms accessible (not hidden).

## Next actions for Dev Lead (implementation hints)
- Create shared components: header, footer, game card, promo card.
- Implement responsive grid + chip filters (static first).
- Add design tokens: colors, spacing, typography.

---
*Note:* This doc captures best-practice patterns. We should not copy brand assets, trademarks, or exact layouts from competitors; replicate structure and UI patterns instead.