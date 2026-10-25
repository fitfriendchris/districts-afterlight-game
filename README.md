# Districts: Afterlight — Meridian Open-World Slice (Phases 0–4)

Roblox open-world roleplay / zombie-survival game, built from the complete
design blueprint. This repo currently implements **Phase 0 (foundation) and
Phase 1 (the peaceful city prototype)** with a server-authoritative
architecture, packaged as a single `.rbxlx` file that opens directly in
Roblox Studio — no Rojo required.

## Quick start

1. `build/DistrictsAfterlight.rbxlx` — double-click (open in Roblox Studio) or
   File > Open from File.
2. Press **Play** (F5). Walk up to NPCs and prompts; press **E** to interact.
3. To publish later: File > Publish to Roblox.

Note: Studio needs your Roblox account; the place starts with API services
disabled (DataStores require publishing — first-run saves are in-memory and
warn in the output).

## What's inside (playable vertical slice)

- **Meridian Heights district** — procedural city blockout: road grid,
  buildings, plaza (fountain, news screen, Marcus), job board, courier depot,
  outfitter kiosk, delivery addresses.
- **Save system** — versioned DataStore profiles (`DistrictsAfterlight_Profiles_v1`),
  autosave every 90s, UpdateAsync writes, BindToClose flush, rejoin-safe.
- **Server-authoritative economy** — all cash/XP flows through
  `EconomyService.award`; oversized grants rejected; clients may only ask.
- **Curbside Delivery job loop** — Take Contract (job board) → Pick Up Package
  (depot prompt) → Deliver (server distance-validated). Repeatable with cooldown.
- **Campaign flags + intro mission** — "Getting on Your Feet": talk to Marcus →
  2 deliveries → visit home console → buy furniture → done. Idempotent,
  persisted in the profile; rejoining resumes mid-mission.
- **Home** — Apartment 3B with a home console; furniture purchases spawn
  decor parts that persist.
- **Shop (Meridian Outfitters)** — cash cosmetics: van wraps + jacket colors.
  No gacha, no gamepasses (per blueprint §10F).
- **Van** — 2 drivable vans (hinge-constraint chassis + per-van drive
  controller). Sit to claim; hop to release. Wraps paint your claimed van.
- **HUD** — cash, level/XP bar, objective tracker, toasts, deliver button.
- **Dialogue** — Marcus trees incl. foreshadowing ("harbor facility outage").
- **Phase 2 core: survival systems** — scavenge rubble piles (1–3 scrap/fabric
  per scavenge, 60s per-pile cooldown), crowbar combat, and hostiles: three
  server-built infected rigs chase within 55 studs and attack (12 dmg on a 1.2s
  cooldown); defeating one pays cash/XP and can drop medical supplies.
- **Phase 2 core: the fall begins** — chapter 2 of the intro campaign
  (scavenge ×3 → defeat an infected → barricade Apartment 3B with 4 scrap).
  Entering chapter 2 fires the EMERGENCY BROADCAST world reaction: the news
  headline swaps, night falls (ClockTime 19.8) and fog closes in.
- **Inventory** — scrap/fabric/medical counts persist in the profile and show
  in the HUD (server-awarded only).

## Heroes Hall (Phase 3)
A kiosk by the plaza (`HERO_KIOSK` in WorldLayout, press **E**) opens the Heroes Hall. **8 hand-authored survivors** across 4 rarities — RIN (Runner·Common), MOSS (Courier·Common), SABLE (Medic·Rare), DORAN (Warden·Rare), LYS (Arc·Epic), VEL (Quartermistress·Epic), KANE (Sentinel·Legendary), IVEY (Overseer·Legendary).

- **Recruit** (server-validated): Common $200·2 Scrap → Rare $480 (3S·2F) → Epic $950 (4S·3F·1 Med) → Legendary $1800 (6S·5F·3 Med)
- **Star-up** ★1–★5: Medical {1,2,4,6,9} + cash {150→2400}; every ★ = +14% damage, +250 HP; ★5 unlocks the Spec (Vanguard/Guardian/Meditech)
- **Gear**: Weapon 6 Scrap (dmg ×1.15), Armor 5S·2F (HP ×1.5)
- **Deploy**: up to 2 armed allies fight alongside you server-side (`InfectedService` ally registry), respawn after 12s if dropped; Meditech Spec adds +20% medical drops from infected
- Everything mutates `data.Heroes` via the Data service — recruits, stars and gear persist

## Settlement (Phase 4)
Foundation pads sit in the yard behind Apartment 3B (a **Settlement Board**, press **E**, opens the panel; the rig prompts on built structures work too).

| Structure | Cost | Produces | Interval |
|---|---|---|---|
| Workbench | 8 Scrap · 4 Fabric | 2 Scrap | 120s |
| Loom | 6 Scrap · 8 Fabric | 2 Fabric | 150s |
| Generator | 12 Scrap | $30 | 90s |
| Med Station | 8 Scrap · 5 Fabric · 1 Med | 1 Medical | 240s |
| Storage Crate | 5 Scrap | +1 interval to every bank cap | passive |

- **Levels 1–3**: upgrade costs 2×/3× the base cost; yields ×1.0/×1.6/×2.4
- **Banks accrue offline** (capped at 3 intervals, or more with Storage crates) and collect on demand — XP for build/collect/upgrade is server-awarded
- **Demolish refunds 30%** of base cost. All placement/cost/production math is server-side; builds persist in the profile and respawn on rejoin

## Controls

| Input | Action |
|-------|--------|
| WASD + Space | Walk/jump |
| E (near prompt) | Take contract / Pick up package / Open shop or home console / Talk |
| WASD while seated | Drive van (arrow keys/WASD, Space to brake) |
| DELIVER PACKAGE button | Deliver when at the target beacon |
| Click (Crowbar equipped) | Swing at infected (8-stud range, must face target) |

## Repo layout

```
src/
  ReplicatedStorage/
    Net.lua                    -- central remote registry (8 remotes)
    Shared/WorldLayout.lua     -- GENERATED interaction coordinates (do not hand-edit)
    Shared/Configs/            -- EconomyConfig, ProgressionConfig
    Shared/Definitions/        -- ItemDefinitions, HomeDefinitions, MissionDefinitions
    Shared/Util/Signal.lua
  ServerScriptService/
    Bootstrap.server.lua       -- service boot order + golden-hour lighting
    Services/                  -- DataService, EconomyService, CampaignService,
                               -- ContractService, DialogueService, HomeService,
                               -- MissionService, ShopService, VehicleService,
                               -- SurvivalService, InfectedService
  StarterPlayer/StarterPlayerScripts/  -- UIKit + HUD/dialogue/shop/home clients
build_place.py                -- packs src/ -> build/DistrictsAfterlight.rbxlx
```

## Rebuild

```bash
python3 build_place.py
```

Regenerates `src/ReplicatedStorage/Shared/WorldLayout.lua` (single source of
truth for coordinates) and repacks the `.rbxlx`. Services read coordinates
from WorldLayout, so world and gameplay can never drift.

Static checks (run locally): `luau-analyze *.lua` with Roblox type definitions.

## Completion tests (blueprint acceptance)

- **Phase 0**: earn test cash → leave → rejoin → balance still correct. (Requires
  published place; in Studio, saving warns about API services.)
- **Phase 1**: new player earns cash, completes a contract, customizes
  something (jacket/wrap/furniture), rejoin keeps progress. Intro mission
  walk-through ends with the news screen flipping to the outage headline.
- **Phase 2**: finish chapter 1 → emergency broadcast + darkness → scavenge
  3 piles → crowbar-kill an infected → barricade Apartment 3B → chapter 2
  complete toast. Materials persist through rejoin.
- **Phase 3**: press **E** at the Heroes Hall kiosk → recruit a hero (cash +
  materials leave the profile) → gear them → deploy → ally shoots infected →
  recall → rejoin keeps roster, stars and gear. Spec locks at ★5.
- **Phase 4**: read the Settlement Board in the yard behind Apartment 3B →
  build a Workbench on pad 1 with scavenge materials → wait ~2 min → collect 2
  scrap → upgrade it → rejoin: structures, levels and banks persist. Chapter-3
  mission advances on build + collect and the rebuild headline breaks.

## Known first-run notes

- Van steering sign is one line in each van's `DriveController` script if it
  feels reversed (Studio iteration).
- Furniture spawns into a shared showcase home (prototype simplification).
- DataStores only persist in published experiences with API access enabled.

## Roadmap (remaining phases)

Phase 4 settlement is shipped (see above) → Phase 5 clans/group missions →
Phase 6 territory/alliances → Phase 7 live ops → Phase 8 monetization. The
service skeleton
(Net registry, campaign flags, mission tracker) is designed to absorb these
without rewrites.