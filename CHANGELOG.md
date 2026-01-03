# Changelog

## [4.0.1]
### Bug Fixes
- Rogue Combo Frame Floating: Fixed combo point frames remaining visible when target frame is hidden by Adventure Mode. ComboFrame, ComboPointPlayerFrame, and ComboPoint1-5 textures now hide correctly.
- Hunger Tooltip Values Inverted: Fixed bar mode hunger tooltip showing wrong checkpoint values; now matches bar display.
- Instance Pause Behavior: Adventure Mode restrictions no longer apply during instances when constitution is paused. Target frame, nameplates, combo points, map, and action bars restore properly; heartbeat sound no longer plays.
- Flight Pause Behavior: Map, bags, and action bars now work correctly during taxi flights. Anguish and exhaustion no longer recover while flying over rested areas.
- Instance Reload State Loss: Anguish and exhaustion now persist across UI reloads inside dungeons/raids and restore on exit.

### UI Improvements
- Thirst Vial Asset: Updated thirst vial to use the dedicated `thirstpotion.png` asset.

### Documentation
- Alcohol Disconnection Note: Added note about a known WoW client issue with alcohol consumption at high FPS causing disconnections.

## [4.0.0]
### New Features
- Mana Potion Thirst Quenching: Mana potions now slowly restore thirst over 2 minutes, down to the 50% hydration checkpoint.
- Dynamic Constitution Weights: Constitution tooltip now shows accurate percentages based on which meters are enabled.
- Well-Fed Tooltip Enhancement: Status icon tooltip now shows "Healing hunger" when actively recovering vs "Hunger paused" when at checkpoint.
- Status Icons System: Dynamic icon row above meters showing active effects with smooth fades, spinning glows, and tooltips with details and remaining durations.
- Status Icons Temperature-Only Mode: Status icons now position directly above temperature bar when no vials are present in vial mode.
- Mana Potion Icon Visibility: Now shows when thirst or temperature is enabled.
- Mana Potion Tooltip: Shows both cooling and quenching timers when both systems are active.

### Bug Fixes
- Constitution Not Appearing: Fixed constitution meter not showing when only 2 meters enabled (thirstEnabled was missing from ShouldShowConstitution count).
- Constitution Checkbox Disabled: Fixed settings panel hook order for temperature checkbox initialization.
- Anguish Checkpoint Bypass: Prevent bandages/potions from passing checkpoints when exactly at 75%/50%/25%.
- Anguish Rested Recovery: Re-enabled slow anguish recovery while resting (0.5%/sec down to 25%).
- Vial Visibility Bugs: Added explicit Show()/Hide() calls in vial mode to prevent vials appearing/disappearing incorrectly.
- Bar Percentage Rounding: Fixed 74% showing instead of 75% by using proper rounding instead of floor().
- Water Icon Too Large: Scaled down thirst icon in bar mode.
