# Districts: Afterlight — Vertical Slice (Phase 0 + 1)

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

## Controls

| Input | Action |
|-------|--------|
| WASD + Space | Walk/jump |
| E (near prompt) | Take contract / Pick up package / Open shop or home console / Talk |
| WASD while seated | Drive van (arrow keys/WASD, Space to brake) |
| DELIVER PACKAGE button | Deliver when at the target beacon |

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
                               -- MissionService, ShopService, VehicleService
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

## Known first-run notes

- Van steering sign is one line in each van's `DriveController` script if it
  feels reversed (Studio iteration).
- Furniture spawns into a shared showcase home (prototype simplification).
- DataStores only persist in published experiences with API access enabled.

## Roadmap (blueprint phases 2-8, not yet built)

Phase 2 outbreak campaign → Phase 3 heroes/combat → Phase 4 settlement +
production → Phase 5 clans/missions → Phase 6 territory/alliances →
Phase 7 live ops → Phase 8 monetization. The service skeleton (Net registry,
campaign flags, mission tracker) is designed to absorb these without rewrites.