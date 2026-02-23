# POCKET DETECTIVE — Game Design Document (GDD)

**Version:** 1.0
**Date:** 2026-02-23
**Platform:** Android (Google Play)
**Genre:** Narrative Investigation / Puzzle
**Orientation:** Portrait
**Connectivity:** 100% Offline

---

## 1. EXECUTIVE SUMMARY

Pocket Detective is a mobile investigation game where the player uses a simulated smartphone to solve crime cases. The player receives cases from a mysterious contact, then explores digital evidence — messages, calls, photos, GPS data, and contacts — to identify the culprit through deductive reasoning.

The experience combines the binge-worthy tension of a Netflix crime thriller with the satisfying logic of a puzzle game. Each case is self-contained, data-driven, and loaded from JSON files, enabling unlimited content expansion without code changes.

---

## 2. CORE GAMEPLAY LOOP

```
┌─────────────────────────────────────────────┐
│           RECEIVE NEW CASE                   │
│  (notification on simulated phone)           │
└──────────────────┬──────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│         EXPLORE DIGITAL EVIDENCE             │
│  • Read messages & chat threads              │
│  • Listen to call transcripts                │
│  • Inspect photos (zoom, discover clues)     │
│  • Check GPS locations & timestamps          │
│  • Review contacts & relationships           │
└──────────────────┬──────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│         ANALYZE & CONNECT                    │
│  • Pin clues to evidence board               │
│  • Draw connections between evidence         │
│  • Identify contradictions                   │
│  • Build timeline of events                  │
└──────────────────┬──────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│         INTERROGATE SUSPECTS                 │
│  • Choose questions strategically            │
│  • Present evidence to challenge alibis      │
│  • Unlock new dialogue branches              │
│  • Detect lies through contradictions        │
└──────────────────┬──────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│         ACCUSE & RESOLVE                     │
│  • Select culprit                            │
│  • Present evidence chain                    │
│  • Receive rating (1-3 stars)                │
│  • Unlock next case                          │
└─────────────────────────────────────────────┘
```

**Micro-loop (within each case):**
1. Discover a clue → 2. Pin it to the board → 3. Connect it to another clue → 4. Unlock a new interrogation question → 5. Get closer to the truth

This micro-loop fires every 30-90 seconds, creating a constant drip of dopamine.

---

## 3. PLAYER MOTIVATIONS & PSYCHOLOGY

### Primary Motivations (Bartle's Taxonomy adapted)

| Motivation | How We Serve It |
|---|---|
| **Curiosity** | Layered evidence that unfolds gradually. "What does this photo hide?" |
| **Mastery** | Logic puzzles that reward careful analysis. Stars for perfect deductions. |
| **Narrative** | Emotionally rich characters with believable motives. |
| **Completion** | Case files, evidence collections, detective rank progression. |

### Psychological Hooks

1. **Zeigarnik Effect** — Unfinished cases create mental tension. The player *needs* to know who did it.
2. **Variable Reward** — Each clue may or may not be relevant. The uncertainty drives engagement.
3. **Aha! Moment** — Connecting two seemingly unrelated clues triggers a powerful satisfaction spike.
4. **Investment Loop** — As the player pins clues and builds connections, their sunk investment keeps them engaged.
5. **Social Identity** — The detective rank system gives the player an identity ("Senior Detective", "Inspector").

### Emotional Arc Per Case

```
Intrigue → Confusion → Suspicion → Doubt → Revelation → Satisfaction
```

Each case is designed to hit all 6 beats in 20-40 minutes of play.

---

## 4. RETENTION MECHANICS

### Session-Level Retention
- **Cliffhanger Unlocks:** At key evidence milestones, tease the next revelation ("New message from unknown number...")
- **Auto-save:** The game saves on every significant action. Players can leave and return seamlessly.
- **Quick Resume:** Opening the app drops you exactly where you left off — mid-conversation, mid-investigation.

### Day-Level Retention
- **Daily Case File:** A small daily mini-puzzle (spot the contradiction, match the alibi) that awards hint coins.
- **Case Countdown Timer:** Next premium case unlocks with a countdown, creating anticipation.
- **Detective Journal:** Daily log entries from the detective persona, building world continuity.

### Week-Level Retention
- **Case Series:** Cases are grouped in story arcs (3-5 cases linked by a recurring antagonist or theme).
- **Weekly Challenge:** "Solve 3 cases this week" for bonus rewards.
- **Detective Rank:** Slow progression that resets weekly challenges.

### Long-Term Retention
- **Branching Reputation:** Choices in interrogations affect future case introductions (cosmetic, not blocking).
- **Collector System:** Evidence gallery, suspect profiles, case trophies.
- **Community Cases:** (Future) Allow user-generated cases loaded from JSON.

---

## 5. PROGRESSION SYSTEM

### Detective Rank

| Rank | Cases Required | Unlock |
|---|---|---|
| Rookie Detective | 0 | Tutorial case |
| Junior Detective | 1 | Standard cases |
| Detective | 3 | Medium difficulty cases |
| Senior Detective | 6 | Hard cases + interrogation pressure |
| Inspector | 10 | Expert cases + time pressure |
| Chief Inspector | 15 | Bonus story arc |
| Legendary Detective | 20+ | Prestige badge + all hints free |

### Star Rating Per Case

| Stars | Condition |
|---|---|
| ★☆☆ | Correct culprit, used 3+ hints |
| ★★☆ | Correct culprit, used 1-2 hints |
| ★★★ | Correct culprit, 0 hints, all evidence found |

### Unlockables
- Phone wallpapers (cosmetic)
- Detective office themes (cosmetic)
- Bonus case files (narrative)
- Interrogation styles (dialogue flavor variants)

---

## 6. DIFFICULTY CURVE

```
Case 1 (Tutorial):    ████░░░░░░  Guided, 3 suspects, obvious clues
Cases 2-3 (Easy):     █████░░░░░  Light guidance, 3 suspects, 1 red herring
Cases 4-6 (Medium):   ██████░░░░  No guidance, 3-4 suspects, 2 red herrings
Cases 7-9 (Hard):     ████████░░  Timeline pressure, 4 suspects, complex alibis
Cases 10+ (Expert):   ██████████  Multiple evidence chains, hidden connections
```

### Difficulty Levers (per case, set in JSON)

| Lever | Easy | Medium | Hard | Expert |
|---|---|---|---|---|
| Number of suspects | 3 | 3 | 4 | 4 |
| Red herrings | 0-1 | 1-2 | 2-3 | 3+ |
| Evidence pieces | 5 | 6-7 | 7-8 | 8-10 |
| Required connections | 2 | 3-4 | 5-6 | 7+ |
| Interrogation complexity | Linear | Branching | Branching + pressure | Multi-layer |
| Hint availability | Generous | Moderate | Limited | Minimal |

---

## 7. REWARD SYSTEM

### Immediate Rewards
- **Clue Discovery:** Satisfying animation + sound. "Evidence added to board!"
- **Connection Made:** Visual spark between two connected evidence nodes.
- **Interrogation Breakthrough:** Suspect's expression changes. New dialogue unlocked.

### Delayed Rewards
- **Case Completion:** Full debrief with star rating, time taken, evidence found percentage.
- **Rank Promotion:** Celebratory screen with new title and badge.
- **Story Arc Completion:** Narrative epilogue revealing overarching story threads.

### Currency: Hint Coins
- Earned: 5 per case completion, 2 per daily puzzle, bonus for 3-star cases.
- Spent: 1 coin per hint (3 hint levels per clue).
- Can be earned via rewarded ads (1 coin per ad).
- Cannot be lost. Only spent voluntarily.

---

## 8. DAILY ENGAGEMENT DESIGN

### Daily Login Flow

```
Open App
  → Daily Puzzle Available?
    → YES → Show notification badge on "Daily" app
    → Complete puzzle → Earn 2 hint coins
  → Active Case?
    → YES → Resume exactly where you left off
    → NO → Show "New Case Available" or "Daily Puzzle"
  → Check Detective Journal (optional)
```

### Daily Puzzle Types
1. **Spot the Lie:** Two witness statements, find the contradiction (30 seconds).
2. **Timeline Order:** Arrange 4 events in correct order (30 seconds).
3. **Evidence Match:** Match 3 clues to the correct suspect (45 seconds).
4. **Photo Detail:** Find the hidden clue in a photo (20 seconds).

These are lightweight, take <1 minute, and keep the player in the detective mindset.

---

## 9. TARGET METRICS

| Metric | Target |
|---|---|
| Average Session Length | 15-25 minutes |
| Sessions Per Day | 1.5-2 |
| Day 1 Retention | 45%+ |
| Day 7 Retention | 25%+ |
| Day 30 Retention | 12%+ |
| Average Case Duration | 25-40 minutes |
| Star Rating (avg) | 2.1 stars |
| Monetization | Rewarded ads + premium unlock |

---

*This GDD is a living document. Update it as development progresses and playtest data arrives.*
