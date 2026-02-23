# POCKET DETECTIVE — Production Roadmap

**Version:** 1.0
**Date:** 2026-02-23
**Developer:** Solo Indie Developer
**Target Launch:** Google Play (Android)

---

## 1. DEVELOPMENT PHASES OVERVIEW

```
PHASE 1: Foundation         [Weeks 1-4]    Core engine, data loader, save system
PHASE 2: Phone UI           [Weeks 5-8]    Phone frame, apps, navigation
PHASE 3: Investigation      [Weeks 9-12]   Evidence, board, interrogation
PHASE 4: First Case         [Weeks 13-16]  Tutorial case, end-to-end flow
PHASE 5: Polish & Content   [Weeks 17-20]  2 more cases, sound, animations
PHASE 6: Monetization       [Weeks 21-22]  Ads, IAP, energy system
PHASE 7: Testing & Launch   [Weeks 23-26]  Testing, store listing, launch
```

**Total: ~6 months** for a solo developer working part-time (15-20 hrs/week)
**Or ~3-4 months** full-time (40 hrs/week)

---

## 2. PHASE 1 — FOUNDATION (Weeks 1-4)

### Goal: Core systems working, can load and parse a case JSON

| Week | Tasks | Deliverable |
|---|---|---|
| 1 | Set up Godot project, folder structure, project settings | Empty project with correct structure |
| 1 | Implement EventBus singleton | Signal-based communication working |
| 2 | Implement SaveManager | Can save/load JSON to user:// |
| 2 | Implement StateManager | Holds game state, connects to SaveManager |
| 3 | Implement CaseLoader | Can discover and parse case.json files |
| 3 | Create case JSON schema | Complete schema with example data |
| 4 | Implement HintManager | Hint economy logic working |
| 4 | Create first case.json (tutorial) | Complete data for Case #001 |

### Milestone: Load case.json → data in memory → save/load progress → all passing

---

## 3. PHASE 2 — PHONE UI (Weeks 5-8)

### Goal: Functional phone interface with all app shells

| Week | Tasks | Deliverable |
|---|---|---|
| 5 | PhoneFrame scene + StatusBar | Phone frame renders, status bar shows |
| 5 | HomeScreen with app grid | Tappable icons, grid layout |
| 6 | Screen manager (open app, go back, history) | Navigation working |
| 6 | MessagesApp — thread list + chat view | Can display messages from JSON |
| 7 | PhotosApp — gallery + inspection mode | Can display photos, zoom works |
| 7 | CallsApp — call log + transcript view | Call list and transcripts display |
| 8 | ContactsApp — suspect profiles | Profile cards with portraits |
| 8 | NotesApp — free text notes | Player can type and save notes |
| 8 | CaseFileApp — case overview | Shows case meta, objectives, progress |

### Milestone: Full phone UI navigable, all apps display data from case.json

---

## 4. PHASE 3 — INVESTIGATION SYSTEMS (Weeks 9-12)

### Goal: Core investigation mechanics working

| Week | Tasks | Deliverable |
|---|---|---|
| 9 | Clue discovery system (tap to find, add to board) | Clues discoverable in messages, photos, calls |
| 9 | Notification system (trigger, display, unlock) | In-game notifications working |
| 10 | Evidence Board — pin clues, drag, arrange | Board UI with pinned clues |
| 10 | Evidence Board — connection drawing + validation | Can draw lines, system validates |
| 11 | Interrogation screen — portrait, dialogue, choices | Full interrogation UI |
| 11 | DialogueManager — tree traversal, evidence gating | Dialogue logic working |
| 12 | Accusation screen — select suspect + evidence | Accusation UI |
| 12 | AccusationSystem — validation, stars, resolution | Full end-game flow |

### Milestone: Can play a case from start to accusation, all systems integrated

---

## 5. PHASE 4 — FIRST CASE END-TO-END (Weeks 13-16)

### Goal: One complete, polished, playable case

| Week | Tasks | Deliverable |
|---|---|---|
| 13 | Create all art assets for Case #001 | Portraits (5 emotions × 2 suspects), photos, icons |
| 13 | Write complete dialogue trees | All interrogation paths written |
| 14 | Full playtest of Case #001 | Play through, note issues |
| 14 | Fix bugs, adjust difficulty, refine flow | Smooth first experience |
| 15 | Tutorial overlay system | First-time player guidance |
| 15 | Tutorial triggers for Case #001 | Guided hints for tutorial case |
| 16 | Resolution screen + stats display | Case completion experience |
| 16 | Case selection screen | List available cases, show status |

### Milestone: A friend can install the APK and solve Case #001 from scratch

---

## 6. PHASE 5 — POLISH & CONTENT (Weeks 17-20)

### Goal: 3 total cases, audio, animations, visual polish

| Week | Tasks | Deliverable |
|---|---|---|
| 17 | Create Case #002 (easy/medium) content | Full JSON + assets |
| 17 | Create Case #003 (medium) content | Full JSON + assets |
| 18 | Sound effects — tap, notification, clue discover, connection | SFX integrated |
| 18 | Background ambient music (2-3 tracks) | Music system working |
| 19 | Animations — screen transitions, clue reveal, connection spark | Visual polish |
| 19 | Evidence Board — auto-arrange, zoom, pan | Board usability |
| 20 | Detective rank system | Rank progression working |
| 20 | Daily puzzle system (2-3 puzzle types) | Daily engagement loop |

### Milestone: 3 polished cases, audio/visual feedback, rank progression

---

## 7. PHASE 6 — MONETIZATION (Weeks 21-22)

### Goal: Revenue systems integrated

| Week | Tasks | Deliverable |
|---|---|---|
| 21 | Energy system implementation | Energy UI, regen, limits |
| 21 | Rewarded ad integration (AdMob) | Ad placements working |
| 22 | Detective Pass IAP (Google Play Billing) | One-time purchase working |
| 22 | Case pack IAP | Pack purchases working |
| 22 | Settings screen (audio, language, restore purchases) | Settings complete |

### Milestone: Can earn/spend coins, watch ads, buy premium, energy works

---

## 8. PHASE 7 — TESTING & LAUNCH (Weeks 23-26)

### Goal: Stable, tested, published on Google Play

| Week | Tasks | Deliverable |
|---|---|---|
| 23 | Device testing (3+ devices, different tiers) | Bug list |
| 23 | Performance profiling (memory, FPS, load times) | Performance report |
| 24 | Bug fixing sprint | All critical/major bugs fixed |
| 24 | Beta test (5-10 friends/family) | Feedback collected |
| 25 | Store listing (screenshots, description, icon, feature graphic) | Store assets ready |
| 25 | Privacy policy, content rating questionnaire | Legal requirements met |
| 26 | Google Play Console setup, closed testing track | APK uploaded |
| 26 | Open beta → public launch | App live! |

### Milestone: Pocket Detective live on Google Play

---

## 9. POST-LAUNCH ROADMAP

### Month 1-2: Stabilize
- Monitor crash reports (Firebase Crashlytics)
- Fix reported bugs
- Analyze retention and monetization metrics
- Respond to user reviews

### Month 3-4: Content
- Cases #004-006 (Dark Secrets pack)
- Seasonal daily puzzles
- New phone wallpaper cosmetics

### Month 5-6: Features
- Cases #007-009 (Cold Cases pack)
- Story arc connecting cases 1-9
- Player statistics screen
- Localization (French → English, Spanish)

### Month 7-12: Growth
- Cases #010-012 (Master Detective pack)
- Season Pass
- Community features (share completion stats)
- iOS port consideration
- User-generated cases exploration

---

## 10. RISK MITIGATION

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Scope creep | High | High | Stick to MVP. Cut features, not quality. |
| Art quality | Medium | High | Use AI-generated placeholder art. Hire artist for final. |
| Burnout (solo dev) | High | Critical | Time-box sessions. Ship MVP, iterate. |
| Low downloads | High | Medium | Focus on ASO. Quality > marketing budget. |
| Technical debt | Medium | Medium | Refactor in Phase 5, not before. |
| Monetization too aggressive | Low | High | Follow ethical guardrails (Part 6). |

---

## 11. MVP DEFINITION

### What IS in the MVP (launch)

- 3 complete cases (tutorial, easy, medium)
- Full phone interface (all apps)
- Evidence board with connections
- Interrogation system
- Accusation and resolution
- Hint system with coins
- Energy system
- Rewarded ads
- Detective Pass (premium)
- Save/load
- Sound effects
- Basic animations

### What is NOT in the MVP

- Multiple languages
- Daily puzzles (can launch in Month 2)
- Story arcs between cases
- Community features
- Player statistics screen
- Custom phone wallpapers
- iOS port

---

## 12. TOOLS & ASSET PIPELINE

| Need | Tool | Cost |
|---|---|---|
| Game engine | Godot 4.x | Free |
| Code editor | VS Code | Free |
| Art — portraits | Stable Diffusion / DALL-E | Free-$20/month |
| Art — UI icons | Figma + icon libraries | Free |
| Art — photos | Stock photos + editing | $10-20/month |
| Sound effects | Freesound.org + Audacity | Free |
| Music | AI music (Suno/Udio) or free loops | Free-$10/month |
| Version control | Git + GitHub | Free |
| CI/CD | GitHub Actions | Free tier |
| Store presence | Google Play Console | $25 one-time |
| Ad network | Google AdMob | Free (revenue share) |
| Analytics | Firebase Analytics | Free tier |
| Crash reporting | Firebase Crashlytics | Free |

**Total recurring cost: $0-50/month**
**Total one-time cost: $25 (Google Play)**
