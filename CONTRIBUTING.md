# Contributing to Bandit Radio

Thanks for helping! / Merci de contribuer !

## Quick rules
- One feature or fix per pull request.
- Test in-game (solo at least) with the latest **Bandits NPC** before opening a PR. Say which B42 version you tested on.
- Never copy code from Bandits into this repo. Call it through `BR_Adapter.lua`.
- Keep `BR_Intel.lua` free of game API calls so it stays testable outside the game.
- New event types: prefer `BanditRadio.API.addDetector` + `addMessages` (see README).

## Good first contributions
- **Messages:** add variants or new lines in `shared/BanditRadio/BR_Messages.lua` (lists = random variants).
- **Towns:** fix or add entries in `BanditRadio.Locations` (`shared/BanditRadio/BR_Config.lua`). Get the coordinates with debug mode or the in-game map.
- **Translations:** add a block in `BanditRadio.Strings` and the matching `Translate/<LANG>/` files.
- **Activities:** map more Bandits program names in `ACTIVITY` (`client/BanditRadio/BR_Window.lua`).

## Testing the logic outside the game
`tests/test_intel.py` runs `BR_Intel.lua` in an embedded Lua 5.1 (`pip install lupa`):
```
python3 tests/test_intel.py
```

## Bug reports
Open an issue with: B42 version, Bandits version, other mods, and the error from `Zomboid/console.txt` (look for `[BanditRadio]`).
