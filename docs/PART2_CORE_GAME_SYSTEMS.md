# POCKET DETECTIVE — Core Game Systems Design

**Version:** 1.0
**Date:** 2026-02-23

---

## 1. VIRTUAL PHONE INTERFACE

### 1.1 Home Screen

The entire game is presented as a simulated smartphone. The home screen is the player's hub.

```
┌─────────────────────────┐
│  ■ 4G    12:47    🔋 87%│  ← Status bar (cosmetic, shows in-game time)
├─────────────────────────┤
│                         │
│  ┌─────┐  ┌─────┐      │
│  │ 📱  │  │ 📷  │      │
│  │ Msg  │  │Photo│      │
│  └─────┘  └─────┘      │
│  ┌─────┐  ┌─────┐      │
│  │ 📞  │  │ 👤  │      │
│  │Calls│  │Cntct│      │
│  └─────┘  └─────┘      │
│  ┌─────┐  ┌─────┐      │
│  │ 📋  │  │ 🔍  │      │
│  │Board│  │Notes│      │
│  └─────┘  └─────┘      │
│  ┌─────┐  ┌─────┐      │
│  │ 📅  │  │ ⚙️  │      │
│  │Daily│  │ Set │      │
│  └─────┘  └─────┘      │
│                         │
│  ════════════════════   │
│  "Case #004 — Active"   │
└─────────────────────────┘
```

### 1.2 App List

| App | Icon | Function |
|---|---|---|
| **Messages** | Chat bubble | Read text conversations between suspects/victim |
| **Photos** | Camera | Inspect photos with zoom and clue discovery |
| **Calls** | Phone | View call log with timestamps, read transcripts |
| **Contacts** | Person | View suspect profiles, relationships |
| **Evidence Board** | Pin board | Connect clues, build theory |
| **Notes** | Notepad | Player's personal notes (free text) |
| **Daily Puzzle** | Calendar | Daily mini-game |
| **Case File** | Folder | Case overview, objectives, progress |
| **Settings** | Gear | Audio, hints, language |

### 1.3 Notification System

- When the player discovers evidence or completes an action, in-game "notifications" appear at the top of the phone screen.
- Notifications can unlock new content:
  - "New message from Sophie Martin" → unlocks a chat thread
  - "Missed call from Unknown" → unlocks a call transcript
  - "Photo received" → unlocks a photo in the gallery

Notifications are triggered by the case state machine (see Part 3).

### 1.4 Navigation

- **Tap app icon** → Opens app full screen with back button
- **Swipe left** → Return to home screen (or back button)
- **Status bar** → Always visible, shows current in-game time
- **Bottom nav** → Quick access to Evidence Board (always accessible)

---

## 2. MESSAGING SYSTEM

### 2.1 Design

The messaging app replicates a real chat interface (like WhatsApp/iMessage).

```
┌─────────────────────────┐
│  ← Messages             │
├─────────────────────────┤
│                         │
│  Sophie Martin      ●   │  ← Unread indicator
│  "I didn't see him a..."│
│  Yesterday 22:14        │
│─────────────────────────│
│  Marc Duval             │
│  "The meeting was can..."│
│  Yesterday 18:30        │
│─────────────────────────│
│  Unknown Number         │
│  "You're looking in t..."│
│  Today 09:15            │
│─────────────────────────│
│                         │
└─────────────────────────┘
```

### 2.2 Chat Thread View

```
┌─────────────────────────┐
│  ← Sophie Martin        │
├─────────────────────────┤
│                         │
│        ┌───────────┐    │
│        │ Hey, are   │    │  ← Victim's message (left aligned)
│        │ you coming │    │
│        │ tonight?   │    │
│        └───────────┘    │
│        21:30            │
│                         │
│  ┌───────────┐          │
│  │ I'll be    │          │  ← Sophie's reply (right aligned)
│  │ there at   │          │
│  │ 22:00      │          │
│  └───────────┘          │
│          21:32          │
│                         │
│  ┌──────────────────┐   │
│  │ 🔍 TAP TO INSPECT│   │  ← Discoverable clue highlight
│  │ "22:00" conflicts │   │
│  │ with GPS data     │   │
│  └──────────────────┘   │
│                         │
└─────────────────────────┘
```

### 2.3 Clue Discovery in Messages

- Certain messages contain **highlighted words or timestamps** that can be tapped.
- Tapping a highlighted element triggers a popup: "Add to Evidence Board?"
- The player decides what is relevant — not everything highlighted is useful (red herrings).
- Discovered clues are marked with a small pin icon in the message.

### 2.4 Message Data Structure

Messages are loaded from the case JSON. Each conversation has:
- `thread_id`: unique ID
- `participants`: array of contact IDs
- `messages`: array of `{sender, text, timestamp, clue_id (optional)}`

---

## 3. PHOTO INSPECTION SYSTEM

### 3.1 Gallery View

Photos are displayed in a grid (2-3 columns). Each photo has:
- Thumbnail preview
- Timestamp
- Location tag (optional)

### 3.2 Inspection Mode

When the player taps a photo, it opens in full-screen inspection mode.

```
┌─────────────────────────┐
│  ← Photo #3   🔍 Zoom   │
├─────────────────────────┤
│                         │
│  ┌───────────────────┐  │
│  │                   │  │
│  │    [PHOTO]        │  │
│  │                   │  │
│  │      ● ← hidden  │  │  ← Discoverable hotspot
│  │        clue       │  │
│  │                   │  │
│  └───────────────────┘  │
│                         │
│  Pinch to zoom          │
│  Tap hotspots to        │
│  discover clues         │
│                         │
│  📍 Paris, Café Luna    │
│  📅 March 12, 21:45     │
│                         │
└─────────────────────────┘
```

### 3.3 Hotspot System

- Each photo has **invisible hotspot zones** defined in the case JSON.
- Hotspots are rectangles defined by `{x, y, width, height}` as percentages of the image.
- When the player zooms in and taps within a hotspot, the clue is revealed.
- A subtle visual pulse can hint at hotspot areas (optional, difficulty-dependent).
- Discovered hotspots show a magnifying glass icon overlay.

### 3.4 Photo Clue Types

| Type | Example |
|---|---|
| **Object** | A receipt visible on a table in the background |
| **Timestamp** | The clock on the wall shows 19:30, contradicting the alibi |
| **Person** | A reflection in a mirror shows someone who shouldn't be there |
| **Location** | A street sign visible through a window identifies the real location |
| **Document** | A partially visible text on a laptop screen |

---

## 4. SUSPECT INTERROGATION SYSTEM

### 4.1 Interrogation Flow

```
┌─────────────────────────┐
│  INTERROGATION          │
│  Sophie Martin          │
├─────────────────────────┤
│                         │
│  ┌───────────────────┐  │
│  │   [SUSPECT         │  │
│  │    PORTRAIT]       │  │
│  │                    │  │
│  │  😐 → Neutral     │  │  ← Expression changes based on pressure
│  └───────────────────┘  │
│                         │
│  "I was at home all     │
│   evening. I didn't     │
│   go anywhere."         │
│                         │
│  ┌───────────────────┐  │
│  │ Ask about alibi    │  │  ← Question option A
│  ├───────────────────┤  │
│  │ Show GPS evidence  │  │  ← Question option B (requires evidence)
│  ├───────────────────┤  │
│  │ Ask about victim   │  │  ← Question option C
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

### 4.2 Question Types

| Type | Mechanic |
|---|---|
| **Open Question** | Always available. Gets a standard response. |
| **Evidence Question** | Requires specific evidence. Unlocks when player has the clue. |
| **Pressure Question** | Available after catching a contradiction. Forces suspect to reveal more. |
| **Bluff Question** | Player can bluff having evidence. Risky — may shut down dialogue. |

### 4.3 Dialogue State Machine

Each interrogation is a tree with nodes:

```
[Start]
  ├── Q1: "Where were you?" → Response A
  │     ├── Q1a: "Can anyone confirm?" → Response B
  │     └── Q1b: [Show phone GPS] → Response C (caught in lie!)
  │           └── Q1b-i: "Why did you lie?" → Response D (new clue!)
  ├── Q2: "Did you know the victim?" → Response E
  └── Q3: [Locked until evidence found]
```

### 4.4 Suspect Reactions

Suspects have emotional states that change during interrogation:

| State | Visual | Trigger |
|---|---|---|
| Calm | 😐 Neutral face | Default |
| Nervous | 😰 Sweating | Evidence presented |
| Angry | 😡 Flushed | Caught in contradiction |
| Defensive | 🙄 Arms crossed | Accused directly |
| Broken | 😢 Tearful | Full evidence chain presented |

These are represented as different portrait images per suspect per emotional state.

---

## 5. EVIDENCE LINKING BOARD

### 5.1 Overview

The evidence board is the player's investigation workspace. It functions as a cork board where clues are pinned and connected with strings.

```
┌─────────────────────────────────────┐
│  EVIDENCE BOARD          Case #004  │
├─────────────────────────────────────┤
│                                     │
│   ┌────┐         ┌────┐            │
│   │MSG │─────────│GPS │            │
│   │#01 │         │#03 │            │
│   └────┘         └────┘            │
│      │              │               │
│      │         ┌────┐              │
│      └─────────│PHOTO│             │
│                │#02  │             │
│                └────┘              │
│                   │                 │
│              ┌────┐                │
│              │ALIBI│               │
│              │#05  │               │
│              └────┘                │
│                                     │
│  [Pin Clue]  [Connect]  [Clear]    │
│                                     │
│  Connections: 3/5  Evidence: 6/8   │
└─────────────────────────────────────┘
```

### 5.2 Board Mechanics

1. **Pin Clue:** Drag a discovered clue from inventory onto the board.
2. **Connect:** Draw a line between two pinned clues to create a connection.
3. **Validate Connection:** The system checks if the connection is valid (defined in case JSON).
4. **Remove:** Long-press to remove a clue or connection.
5. **Auto-arrange:** Button to neatly organize pinned clues.

### 5.3 Connection Feedback

| Result | Feedback |
|---|---|
| **Correct connection** | Green line + sparkle animation. "Connection confirmed!" |
| **Incorrect connection** | Red line that fades. "These don't seem related." (No penalty) |
| **Key connection** | Gold line + sound. "Breakthrough! This changes everything." Triggers new content. |

### 5.4 Board Progress

- The board tracks: `connections_found / connections_required`
- When all required connections are made, the **Accusation** phase unlocks.
- Bonus connections (not required but insightful) award extra hint coins.

---

## 6. ACCUSATION & VERIFICATION LOGIC

### 6.1 Accusation Flow

```
Player completes required evidence connections
  → "Accusation" button appears on board
  → Player selects suspect
  → Player selects 3 key evidence pieces that prove guilt
  → System validates:
      ✓ Correct suspect?
      ✓ Correct evidence chain?
      ✓ Calculate star rating
  → Show resolution scene
```

### 6.2 Accusation Screen

```
┌─────────────────────────┐
│  MAKE YOUR ACCUSATION   │
├─────────────────────────┤
│                         │
│  Who is guilty?         │
│                         │
│  ○ Sophie Martin        │
│  ● Marc Duval           │  ← Selected
│  ○ Lucas Bernard        │
│                         │
│  Select your evidence:  │
│  (choose 3 key pieces)  │
│                         │
│  ☑ GPS contradiction    │
│  ☑ Deleted message      │
│  ☑ Receipt timestamp    │
│  ☐ Witness photo        │
│                         │
│  ┌───────────────────┐  │
│  │  ACCUSE ▶         │  │
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

### 6.3 Verification Logic

```
if (selected_suspect == case.culprit):
    correct_evidence_count = count(selected_evidence ∩ case.required_evidence)

    if correct_evidence_count >= case.min_evidence:
        → CASE SOLVED
        → Stars based on hints_used and evidence_found
    else:
        → "Right suspect, but your evidence isn't convincing enough."
        → Player can retry (no penalty)
else:
    → "The evidence doesn't support this accusation."
    → Show gentle hint toward correct direction
    → Player can retry (counts as hint used, affects star rating)
```

### 6.4 Resolution Scene

After successful accusation:
1. **Arrest narrative** — Short story text explaining how the arrest goes down.
2. **Evidence recap** — Visual summary of the evidence chain.
3. **Star rating** — With breakdown (hints used, evidence found, wrong accusations).
4. **Case stats** — Time taken, clues discovered, connections made.
5. **Next case teaser** — Preview of the next investigation.

---

## 7. HINT SYSTEM

### 7.1 Three-Tier Hints

Each puzzle point (clue, connection, interrogation choice) has 3 hint levels:

| Level | Cost | Information |
|---|---|---|
| **Nudge** | 1 coin | Vague direction. "Look more carefully at the timestamps." |
| **Push** | 2 coins | Specific pointer. "Compare Sophie's message time with the GPS log." |
| **Reveal** | 3 coins | Direct answer. "Sophie's message says 22:00 but GPS shows her at the café at 21:45." |

### 7.2 Hint Access Points

- **Evidence Board:** "Need help connecting clues?" button.
- **Interrogation:** "Unsure what to ask?" button.
- **Photo Inspection:** "Can't find the clue?" button after 30 seconds of zooming.
- **Accusation:** "Need help choosing?" button.

### 7.3 Hint Economy

| Source | Coins |
|---|---|
| Case completion | +5 |
| 3-star completion | +3 bonus |
| Daily puzzle | +2 |
| Rewarded ad | +1 |
| Starter bonus | 10 free |

### 7.4 Anti-Frustration Design

- First hint in a case is **always free** (encourages usage, reduces churn).
- If a player is stuck for >3 minutes on the same screen, show a subtle "Need help?" prompt.
- Hints never fully solve the case — they guide toward the answer but the player must still make the final deduction.

---

## 8. STAMINA / ENERGY SYSTEM

### 8.1 Design Philosophy

The energy system should feel **generous**, not punishing. It exists to:
1. Create natural session breaks (healthy play patterns).
2. Provide a monetization touchpoint (rewarded ads to refill).
3. Not be the primary monetization — premium unlock removes it entirely.

### 8.2 Energy Mechanics

| Parameter | Value |
|---|---|
| Max energy | 5 units |
| Energy to start a case | 1 unit |
| Energy regeneration | 1 unit every 30 minutes |
| Full refill time | 2.5 hours |
| Rewarded ad refill | +1 unit per ad (max 3/day) |
| Premium upgrade | Unlimited energy |

### 8.3 Energy-Free Activities

The following never cost energy:
- Continuing an in-progress case
- Daily puzzles
- Viewing evidence board
- Re-reading solved case files
- Settings and cosmetics

### 8.4 Generous Boundaries

- **First 3 cases are energy-free** (onboarding, no friction).
- **Daily puzzle always available** (maintains engagement even at 0 energy).
- **Level-up refills energy** (rewards progression).
- **Energy regenerates while playing** (continuing a case doesn't pause regeneration).

This ensures a player can always play for at least 30-45 minutes in a single session, and casual players (1-2 cases/day) may never hit the energy wall at all.
