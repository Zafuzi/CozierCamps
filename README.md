# CozyCamps

Transform your Classic WoW experience into a survival adventure.

CozyCamps adds immersive survival mechanics that make campfires, inns, and the wilderness feel meaningful again. Rest by the fire to recover, manage your hunger in the wilds, brave harsh temperatures, and feel the weight of your journey through exhaustion and anguish.

## Features

### Survival Systems

**Exhaustion** — Your character grows tired as you travel. Movement builds exhaustion over time, while resting near campfires or in inns allows you to recover. Watch your energy and plan your routes accordingly.

**Anguish** — Taking damage leaves a lasting mark. Anguish builds as you're hurt in combat and only fades slowly while resting. Seek out innkeepers for relief, or endure the lingering pain of battle. Multiple difficulty scales available.

**Hunger** — The wilderness makes you hungry. Your hunger grows as you move and exert yourself, amplified by harsh temperatures and exhaustion. Eating food provides relief, with better recovery when resting safely. A subtle screen vignette darkens as hunger sets in.

**Temperature** — The world has hot and cold zones. Freezing peaks and scorching deserts affect your survival. Weather conditions like rain, snow, and dust storms intensify the effects. A manual weather toggle is included since Classic WoW cannot detect weather automatically.

**Constitution** — When running multiple survival systems together, Constitution tracks your overall resilience. This meta-meter reflects your combined survival state and unlocks when two or more systems are active.

### Campfire & Rest Mechanics

- **Automatic fire detection** — CozyCamps detects nearby campfires and rest points automatically
- **Manual rest mode** — Prefer more control? Use `/rest` to manually activate rest state
- **Action bar restrictions** — Optionally hide your action bars unless you're near a fire or in a safe area (requires level 6+)
- **Map restrictions** — Block access to the world map unless resting, adding strategic depth to navigation
- **Rest sound** — Optional audio cue when you enter campfire range

### World Map Integration

Enable survival icons on your world map to see:
- Known campfire locations in your current zone
- Inn locations
- First aid trainer locations

Plan your routes with survival in mind.

### Presets

- **Adventure** — The full survival experience with all systems enabled and restrictions active
- **Lite** — Minimal footprint with just exhaustion tracking—no restrictions, no extra meters

## About Fire Detection — Omissions

CozyCamps maintains a curated database of campfire locations. Some fires have been intentionally omitted:

- **Spooky/Plague fires Omitted** — Plaguelands bonfires, Silithus blue flames, and other "corrupted" fire sources are excluded. These aren't the kind of fires you'd want to cozy up to.
- **Most braziers Omitted** — Decorative braziers that line roads, buildings, and dungeons are generally ignored.
- **Uldaman exterior Omitted** — Too many overlapping fire sources in a small area created detection issues.
- **Maraudon entrance Omitted** — Braziers here caused significant overlap problems.

Generally, if I found a zone to be way overpopulated with fires, I was pickier about braziers and things. If zones seemed sparse with fires, I was more liberal about enabling them as CC campfires.

Want to check if a fire is recognized? Enable map indicators in the settings to see which fires CozyCamps knows about in your current zone.

Found a missing fire? Please submit it! I've certainly missed some, and contributions help make the addon better for everyone.

## Performance Notes

CozyCamps is more resource-intensive than typical addons. The nature of survival mechanics requires frequent checks—position tracking, health monitoring, zone detection, and movement calculations all happen regularly to provide a smooth experience.

In my testing, CozyCamps uses roughly twice the CPU resources of popular addons like RestedXP, WeakAuras, or Questie. On a mid-to-high-end gaming PC, I haven't noticed any adverse effects during normal gameplay.

If you're running on older hardware, I'd recommend either skipping this addon or using the Lite preset, which disables most systems and significantly reduces overhead.

## Alcohol and Disconnections

There is a known WoW client issue where alcohol consumption can cause disconnects at high FPS (144Hz+). This appears tied to drunk chat message spam, not CozyCamps itself. If you hit this, try capping FPS to 120. CozyCamps warmth from alcohol is safe and not the cause; results may vary.

### A note for UHC users

If you're using Ultra Hardcore, there are 2 settings you need to disable for CozyCamps to work: "Route Planner", "Hide Action Bars when not resting". Failure to do so will result in the addons fighting and UI/Visual issues.

## Recommended Console Settings

For the best immersive experience, try these console commands:

```
/console WeatherDensity 3
/console ActionCam full
```

## Commands

Open the settings panel:
```
/cozycamps
/cozy
```

Toggle manual rest mode (when using Manual Rest Mode detection):
```
/rest
```

Enable debug (play around with sliders and see values):
```
/cozy debug
```

## Feedback & Support

Found a bug? Have a suggestion? Missing a campfire location? Let me know!
