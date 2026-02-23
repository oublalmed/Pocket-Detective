# POCKET DETECTIVE — Monetization Design

**Version:** 1.0
**Date:** 2026-02-23

---

## 1. MONETIZATION PHILOSOPHY

### Core Principles

1. **Fun first, money second.** The game must be enjoyable for free players. Paying only removes friction, never gates core content.
2. **No pay-to-win.** Hints help, but the player must still solve the case. You can't buy the answer.
3. **Respect the player.** No dark patterns, no FOMO pressure, no loot boxes. Clear value for clear money.
4. **Generous free tier.** A free player should be able to complete 3-5 cases before hitting any paywall.

### Revenue Model: Hybrid Free-to-Play

```
Revenue Mix Target:
├── Premium Unlock (one-time purchase): 50% of revenue
├── Case Packs (IAP):                   30% of revenue
└── Rewarded Ads:                       20% of revenue
```

---

## 2. PREMIUM UNLOCK — "DETECTIVE PASS"

### 2.1 What It Is

A single one-time purchase that removes all free-to-play friction.

**Price:** $4.99 / 4.99€ (one-time, not subscription)

### 2.2 What You Get

| Feature | Free | Detective Pass |
|---|---|---|
| Tutorial case | Yes | Yes |
| First 3 cases | Yes | Yes |
| Cases 4+ | Energy-gated | Unlimited |
| Energy system | 5 units, regen | Removed entirely |
| Ads | Rewarded (optional) | No ads at all |
| Hint coins | Earn or watch ads | Earn + bonus 50 coins |
| Daily puzzle | Yes | Yes + 2x rewards |
| Cosmetics | Basic | 3 exclusive wallpapers |
| Badge | None | "Supporter" badge |

### 2.3 Conversion Strategy

```
Free Player Journey:
Case 1-2:    Pure fun, no friction → Player falls in love with gameplay
Case 3:      First "energy depleted" moment → Soft upsell: "Want unlimited? $4.99"
Case 4-5:    Occasional energy waits → Gentle reminders
Case 6+:     "You've played 6 cases! Unlock unlimited for $4.99"
```

**Key rule:** Never interrupt gameplay to upsell. Only show purchase options in natural break points (between cases, energy screen, settings).

---

## 3. CASE PACKS — IN-APP PURCHASES

### 3.1 Pack Structure

Cases beyond the free bundle are sold in themed packs.

| Pack | Cases | Price | Theme |
|---|---|---|---|
| Starter Bundle | Cases 1-3 | Free | Tutorial + Easy |
| Dark Secrets | Cases 4-6 | $1.99 | Medium difficulty |
| Cold Cases | Cases 7-9 | $2.99 | Hard difficulty |
| Master Detective | Cases 10-12 | $2.99 | Expert difficulty |
| Season Pass | All current + future | $9.99 | Everything |

### 3.2 Individual Cases

Players can also buy individual cases: **$0.99 each**

### 3.3 Detective Pass Holders

Detective Pass holders get a **30% discount** on all case packs:
- Dark Secrets: $1.39 instead of $1.99
- Cold Cases: $2.09 instead of $2.99
- Season Pass: $6.99 instead of $9.99

---

## 4. REWARDED ADS

### 4.1 Philosophy

Ads are **always optional** and **always rewarded**. The player chooses to watch.

### 4.2 Ad Placement

| Placement | Reward | Max/Day | Context |
|---|---|---|---|
| Energy refill | +1 energy | 3 | Energy screen, when depleted |
| Hint coins | +1 coin | 5 | Hint screen, when out of coins |
| Case completion bonus | +2 coins | Unlimited | After case completion |
| Daily puzzle bonus | +1 coin | 1 | After daily puzzle |

### 4.3 Ad Rules

- **No banner ads.** Ever. They ruin immersion.
- **No interstitial ads.** Never interrupt the player.
- **No forced ads.** Every ad is opt-in.
- **No ads for Detective Pass holders.** The pass removes all ad prompts.
- **Ad cooldown:** Minimum 3 minutes between ad prompts to prevent fatigue.

### 4.4 Ad Integration (Technical)

```gdscript
# AdManager.gd (wrapper for ad SDK)
var ads_enabled: bool = true
var ad_cooldown_timer: float = 0.0
const AD_COOLDOWN = 180.0  # 3 minutes

func can_show_ad() -> bool:
    if not ads_enabled:
        return false
    if StateManager.has_detective_pass():
        return false
    if ad_cooldown_timer > 0:
        return false
    return true

func show_rewarded_ad(reward_type: String) -> void:
    if not can_show_ad():
        return
    # Show ad via SDK
    # On completion:
    _on_ad_completed(reward_type)

func _on_ad_completed(reward_type: String) -> void:
    ad_cooldown_timer = AD_COOLDOWN
    match reward_type:
        "energy":
            StateManager.add_energy(1)
        "hint_coin":
            StateManager.add_coins(1)
        "bonus_coins":
            StateManager.add_coins(2)

func _process(delta):
    if ad_cooldown_timer > 0:
        ad_cooldown_timer -= delta
```

---

## 5. HINT COIN ECONOMY

### 5.1 Earning

| Source | Coins | Frequency |
|---|---|---|
| Case completion | +5 | Per case |
| 3-star bonus | +3 | Per perfect case |
| Daily puzzle | +2 | Daily |
| Rewarded ad | +1 | Up to 5/day |
| First launch | +10 | One-time |
| Detective Pass | +50 | One-time bonus |

### 5.2 Spending

| Hint Level | Cost |
|---|---|
| Nudge | 1 coin |
| Push | 2 coins |
| Reveal | 3 coins |

### 5.3 Economy Balance

```
Average case: Player earns 5 coins, could spend 6-18 coins on hints
Expected spend per case: 2-4 coins (most players use 1-2 hints)
Net per case: +1 to +3 coins

This means a moderately skilled player slowly accumulates coins,
while a struggling player slowly depletes them → drives ad views or
encourages improvement.
```

### 5.4 No Coin Purchase

Hint coins cannot be bought directly with real money. This prevents pay-to-win.
The only paths to coins: play the game, watch ads, or buy Detective Pass.

---

## 6. PRICING PSYCHOLOGY

### 6.1 Anchor Pricing

The Season Pass ($9.99) makes individual packs look like great value.

```
"Buy 3 packs separately: $7.97"
"Or get everything forever: $9.99"
→ Most will buy the Season Pass
```

### 6.2 First Purchase Discount

First-time buyers see a one-time offer:
- Detective Pass: ~~$4.99~~ → **$2.99** (first 48 hours after first case completion)
- This converts the highest-intent players at their peak engagement moment.

### 6.3 No Artificial Scarcity

- No limited-time offers (except first purchase discount)
- No countdown timers
- No "only X left" messaging
- Prices are fair and permanent

---

## 7. GOOGLE PLAY STORE OPTIMIZATION

### 7.1 Store Listing

```
Title: Pocket Detective — Crime Puzzles
Short Description: Investigate crimes. Find clues. Solve cases. No wifi needed.
Category: Puzzle
Content Rating: Teen (crime themes, no violence shown)
```

### 7.2 Keywords

Primary: detective game, crime puzzle, investigation, offline game
Secondary: mystery, evidence, clue, suspect, interrogation
Long-tail: offline detective puzzle, crime investigation game, mystery solving

### 7.3 Monetization Disclosure

- "Contains ads" (rewarded only)
- "In-app purchases: $0.99 - $9.99"
- "Optional purchases, fully playable for free"

---

## 8. REVENUE PROJECTIONS (Conservative)

### 8.1 Assumptions

| Metric | Value |
|---|---|
| Monthly installs | 5,000 (organic + minimal ASO) |
| Day 30 retention | 12% |
| Conversion to premium | 3% of retained players |
| Average ad views/user/month | 8 |
| eCPM (rewarded) | $10 |

### 8.2 Monthly Revenue Estimate

```
Premium: 5000 × 0.12 × 0.03 × $4.99     = $89.82
IAP:     5000 × 0.12 × 0.02 × $3.50      = $42.00
Ads:     5000 × 0.12 × 8 × $10/1000       = $48.00
                                    Total ≈ $180/month

After 6 months with growth: ~$500-800/month
After 12 months with 10+ cases: ~$1000-2000/month
```

These are conservative solo indie estimates. Viral moments or featuring can 10x these numbers.

---

## 9. ETHICAL GUARDRAILS

| We DO | We DON'T |
|---|---|
| Offer clear value for purchases | Create artificial urgency |
| Let free players complete cases | Gate story endings behind paywalls |
| Show ads only when requested | Interrupt gameplay with ads |
| Give generous free content | Withhold content to force purchases |
| Respect player time | Create wait-to-play mechanics beyond gentle energy |
| Price fairly and transparently | Use psychological manipulation |
