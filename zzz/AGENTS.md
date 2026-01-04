# AGENTS.md

## Project overview

CozierCamps is a World of Warcraft Retail addon that adds survival systems like exhaustion, anguish, hunger, thirst, and temperature, plus campfire and inn-based rest
mechanics.

## Survival systems behavior

- Anguish: builds from combat damage; critical hits and being dazed add more trauma; bandages and health potions recover down to checkpoints (75/50/25); resting in towns heals down
  to 25; innkeepers provide deeper relief; First Aid trainers fully recover; multiple difficulty scales available
- Exhaustion: movement builds exhaustion over time; resting near campfires or in inns restores it
- Hunger: grows with movement and exertion, amplified by temperature and exhaustion; eating recovers to checkpoints with better recovery near fires or in rested areas; Well Fed
  pauses hunger drain; vignette darkens as hunger rises; Cooking trainers fully restore satiation
- Thirst: builds with travel, faster in hot environments and combat; drinking recovers down to checkpoints; swimming and rain restore hydration slowly; mana potions cool and quench
  over 2 minutes
- Temperature: hot/cold zones affect survival; weather (rain, snow, dust) intensifies effects; swimming increases cold buildup; alcohol provides warmth; mana potions cool when
  overheated; manual weather toggle exists
- Constitution: active when 2+ systems are enabled; weighted contributions from each system always total 100%

## Checkpoint system

- Open world recovery to 75% (25% satiation/hydration)
- Near campfire recovery to 50%
- Rested area recovery to 25% (75% satiation/hydration)
- Trainers or innkeepers allow full recovery
- Exact checkpoint values require additional damage or drain before further recovery

## Status icons

- Left side (expand outward): Mana Potion, Health Potion, Bandage, Wet, Swimming
- Center (overlap): Cozy/Fire, Rested
- Right side (expand outward): Well Fed, Alcohol, Combat, Constitution Warning
- Icons use smooth fades, color-coded spinning glows, and tooltips with details and remaining durations

## Display modes

- Bar mode: horizontal stacked bars
- Vial mode: bottle vials with temperature as a bar below; constitution orb floats beside vials

## Campfire and rest mechanics

- Automatic fire detection
- Manual rest mode via `/rest`
- Action bar restrictions near fire or safe areas (level 6+)
- Bag restrictions when constitution is critically low
- Map restrictions unless resting
- Optional rest sound when entering campfire range

## Adventure mode (constitution effects)

- Below 75%: target frame and nameplates hidden
- Below 50%: player frame hidden
- Below 25%: action bars and map disabled; optional heartbeat sound

## World map integration

- Campfire, inn, First Aid trainer, and Cooking trainer icons
- Plan routes around survival support

## Presets

- Adventure: full survival systems and restrictions
- Lite: exhaustion only with no restrictions or extra meters

## Recovery sources

- Anguish: bandages and health potions to checkpoint; resting in town to 25%; innkeeper to 15%; First Aid trainer full
- Hunger: food to checkpoint; Cooking trainer full
- Thirst: drink to checkpoint; swimming and rain to checkpoint; mana potion to 50% over 2 min
- Temperature: campfire warms when cold; mana potion cools 20% over 2 min when hot; swimming or rain cools when hot
- Exhaustion: resting full recovery

## Fire detection omissions

- Spooky or plague fires (Plaguelands bonfires, Silithus blue flames, and other corrupted fires)
- Most decorative braziers across roads, buildings, and dungeons
- Uldaman exterior (too many overlapping sources)
- Maraudon entrance braziers (overlap issues)
- Zones with dense fire sources are curated more aggressively; sparse zones are more inclusive
- Use map indicators to see known fires in your current zone
- Missing fires should be submitted for inclusion

## Dungeon and raid behavior

- All survival systems pause inside dungeons and raids
- No accumulation or recovery while inside
- Values are saved on entry and restored on exit

## Performance notes

- More CPU-intensive than typical addons due to frequent position, health, zone, and movement checks
- Roughly 2x CPU usage versus common addons like RestedXP, WeakAuras, and Questie in testing
- Recommend the Lite preset on older hardware

## UHC compatibility

- Ultra Hardcore users must disable "Route Planner" and "Hide Action Bars when not resting" to avoid UI conflicts

## Alcohol and disconnections

- High FPS (144Hz+) can cause alcohol-related disconnects; appears to be a WoW client issue
- Capping FPS to 120 can help; issue relates to drunk chat message spam
- CozierCamps warmth from alcohol is safe and not the cause
- Personal note: the author rarely uses the drunk jacket buff to avoid capping FPS; results may vary

## Recommended console settings

- `/console WeatherDensity 3`
- `/console ActionCam full`

## Commands

- Open settings: `/CozierCamps` or `/cozy`
- Toggle manual rest mode when using Manual Rest Mode detection: `/rest`

## Multi-client support

- Maintain Classic, TBC Anniversary, and Retail versions
- TBC Anniversary uses Retail Edit Mode for action bar handling
- Keep feature parity across clients; diverge only when client-specific behavior requires it

## Key files

- Core.lua: addon bootstrap, shared helpers, default settings, shared constants
- Exhaustion.lua, Anguish.lua, Hunger.lua, Thirst.lua, Temperature.lua: survival systems
- Meters.lua: UI meters and rendering (heavy UI code)
- FireDB.lua: large static campfire location data
- MapOverlay.lua, MapBlock.lua: map icons and map blocking
- Settings.lua: options UI and saved variable wiring
- CozierCamps.toc: load order, metadata, and version
- assets/: textures and sounds

## Coding style and performance

- Lua 5.1; prefer `local` for hot paths and cache repeated lookups
- Avoid per-frame table or closure allocation in OnUpdate or frequent timers
- Reuse shared constants (colors, asset paths) instead of duplicating strings
- Keep CPU overhead in mind; CozierCamps is intentionally heavier than typical addons

## Data edits

- FireDB.lua is large; change it only when necessary and keep data formatting consistent
- Map and trainer lists should match existing conventions for coordinates and zone names

## Testing and validation

- In-game reload: `/reload`
- Open settings: `/cozy` or `/CozierCamps`
- Debug mode: `/cozy debug` to check meter values and sliders
- If touching map data, verify icons and map blocking in multiple zones

## Versioning and release hygiene

- Keep `Core.lua` `version` and `CozierCamps.toc` `## Version` in sync
- Update `CHANGELOG.md` for user-facing changes
- Add new Lua files to `CozierCamps.toc` in the intended load order

Refer to CHANGELOG.md for the most recent changes and context.
This project is also implemented in the TBC and Classic, and Retail Clients. Please make sure to maintain feature parity wherever possible. The others are located in D:/
CozierCamps and D:/ CozierCamps