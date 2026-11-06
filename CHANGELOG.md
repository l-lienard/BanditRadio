# Changelog

## 2.0.0
- New event engine: contact, A->B trips with ETA, arrival, camp, rest, looting, gunshots, fights with zombies, overrun, faction clashes, hunting / closing in on players, losses, wiped out, gone silent, reinforcements, gatherings, ambient chatter
- Information reliability: Complete / Realistic / Rumors only, plus optional false rumors
- Weak signal downgrades full intel to partial info
- World map + minimap overlay: blurry zones coloured by faction, dotted trip paths, live ETA countdown, legend, auto-expiry
- Map ON/OFF button in the radio window (saved)
- All messages moved to editable templates (BR_Messages.lua)
- Public API: addTown, addPlace, addClanName, setFactionColor, addMessages, addDetector, onReport
- Sandbox: reliability, false rumors, ambient, per-category event toggles, map zones and lifetime

## 1.2.0
- Positions are now always vague: nearest town + building type (gas station, police station, farm...)
- Removed the exact coordinates option
- Clean, translated faction names (`12_Militia` -> Militia / Milice)
- AUTO / FR / EN language button in the radio window (saved between sessions)
- Log entries are re-rendered in the selected language

## 1.1.0
- Two modes: radio ON shows live messages above the player; radio OFF (carried) saves them as [missed] in the log
- New context entry "Open radio log" with unread counter
- Sandbox options: Overhead, LogWhenOff

## 1.0.0
- Bandit Radio item (bandit drop + world loot)
- Movement intercepts: town (with ETA), player tracking, direction, holding position
- Event reports: new contact, losses, group gone silent
- Factions tab: members, groups, weapons, last position, activity, hostility, losses
- Battery system, listening range, distance-based static
- Sandbox options, FR/EN, singleplayer + multiplayer
