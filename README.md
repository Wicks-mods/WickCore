<p align="center"><img src="images/wick-thumb-core.png" alt="WickCore"></p>
# WickCore

<!-- wick:badges:start -->
[![Downloads](https://img.shields.io/curseforge/dt/1708157?style=flat-square&labelColor=171124&label=downloads&color=4FC778)](https://www.curseforge.com/wow/addons/wickcore)
![TBC Anniversary](https://img.shields.io/badge/client-TBC%20Anniversary-383058?style=flat-square&labelColor=171124)
![Forever](https://img.shields.io/badge/client-Forever-383058?style=flat-square&labelColor=171124)
[![License](https://img.shields.io/badge/license-MIT%20%2B%20trademark-383058?style=flat-square&labelColor=171124)](LICENSE)
[![Discord](https://img.shields.io/badge/discord-join-4FC778?style=flat-square&labelColor=171124)](https://discord.gg/GWGTMhYBZY)
<!-- wick:badges:end -->

> The shared platform under every Wick addon for World of Warcraft: Forever.

Part of the **[Wick suite](https://github.com/Wicks-mods/WickSuite)**. WickCore is
a library, not a player-facing addon. It carries the brand chrome and every
table-stakes capability so no product builds its own: profiles, one options
panel, import and export strings, a launcher, localization, version broadcast,
and a shim that speaks the client's API dialect.

## Why it exists

Forever runs retail's engine at level 60 (interface `16001`, `WOW_PROJECT_ID`
is Mainline) with Midnight's addon restrictions. Against the TBC Anniversary
suite that meant:

- `GetItemInfo`, `GetSpellInfo`, `GetSpellCooldown`, `UnitAura` and the
  container globals are gone. 73 of the suite's 219 bare globals are nil.
- The player's own health and power are secret at all times. Ratings, totems
  and cooldowns go secret in combat. Aura queries in combat throw.
- Talents are the retail trait system, with native loadouts and import strings.

WickCore absorbs all of that once.

## Using it from a product

```lua
local A = WickCore:NewAddon("WicksBags", {
    title    = "Wick's Bags",
    version  = "1.0.0",
    savedVar = "WicksBagsDB",
    defaults = { profile = { locked = false, window = {} } },
})

function A:OnInitialize()
    self.panel = WickCore.Chrome:NewPanel("WicksBagsFrame", {
        title = self.title, width = 420, height = 320,
        resizable = true, db = self.db.profile.window,
    })
    self:RegisterSlash(function(_, msg) self.panel:Toggle() end, "/wbags", "/wb")
    self:RegisterOptions(function(page)
        local O = WickCore.Options
        local y = O:Heading(page, "General", 0)
        y = O:Check(page, "Lock window", function() return self.db.profile.locked end,
                    function(v) self.db.profile.locked = v end, y)
        y = O:ProfileSection(page, self, y - 8)
    end)
    self:RegisterLauncher({ onClick = function() self.panel:Toggle() end })
end

function A:OnEnable()
    local D = WickCore.Dialect
    local item = D.GetItemInfo(6948)          -- same table on Forever and TBC
    for aura in D.IterateAuras("player") do   -- yields nothing while blocked
        -- ...
    end
    WickCore.Restrict:OnChange(function(kind, active)
        if kind == "Combat" then self:Refresh() end
    end)
end
```

## Modules

| Module | Entry points |
|---|---|
| `Core` | `NewAddon`, `safe`, `pack`, `applyDefaults`, `compareVersions`, `Print` |
| `Client` | `isForever`, `isModern`, `hasSecrets`, `hasTraits`, `GameMode()`, `IsHardcore()` |
| `Restrict` | `IsActive(kind)`, `AurasBlocked()`, `CooldownsSecret()`, `ChatBlocked()`, `IsSecret(v)`, `Guard(fn)`, `OnChange(fn)` |
| `Dialect` | item, spell, cooldown, container, aura, quest, group, coin, addon message, profession, totem, talent config |
| `Chrome` | `NewPanel`, `AddBorder`, `AddBrackets`, `Button`, `Check`, `Heading`, `TitleMarkup`, position save/restore |
| `Profiles` | `A.db.profile/global/char`, `SetProfile`, `CopyProfile`, `ResetProfile`, `SetKeyMode`, `Export`, `Import` |
| `Options` | `Register`, `Open`, `Heading`, `Check`, `Button`, `Note`, `ProfileSection`, `ShowExport` |
| `Launcher` | `Register`, minimap button, hub |
| `Locale` | `A:NewLocale(locale, isDefault)`, `A.L` |
| `Version` | automatic; `Register` is called on enable |

`/wickcore` prints the client report and restriction state. `/wickcore dialect`
shows which path each shimmed call resolved to.

## Embedding

Copy the folder to `Libs/WickCore/` in a product and list its files in the
product's TOC after `LibStub.lua`. The newest copy wins at runtime. Add
`WickCoreDB` to the product's `SavedVariables` if you want the minimap position
to persist without the standalone addon installed.

## Offline test

```
python WickSuite/tools/core-harness/run.py            # Forever-shaped stub client
python WickSuite/tools/core-harness/run.py --legacy   # TBC-shaped stub client
```

## More from Wick

<!-- wick:suite-table:start -->
| Addon | GitHub | CurseForge |
|---|---|---|
| **Wick's TBC BIS Tracker** | [repo](https://github.com/Wicks-mods/WickidsTBCBISTracker) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-tbc-bis-tracker) |
| **Wick's CD Tracker** | [repo](https://github.com/Wicks-mods/WicksCDTracker) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-cd-tracker) |
| **Wick's Trade Hall** | [repo](https://github.com/Wicks-mods/WicksTradeHall) | [CurseForge](https://www.curseforge.com/wow/addons/trade-hall) |
| **Wick's Macro Builder** | [repo](https://github.com/Wicks-mods/WicksMacroBuilder) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-macro-builder) |
| **Wick's Combat Log** | [repo](https://github.com/Wicks-mods/WicksCombatLog) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-combat-log) |
| **Wick's Stats** | [repo](https://github.com/Wicks-mods/WicksStats) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-stats) |
| **Wick's Quest Key** | [repo](https://github.com/Wicks-mods/WicksQuestKey) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-quest-key) |
| **Wick's Totems and Things** | [repo](https://github.com/Wicks-mods/WicksTotemsAndThings) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-totems-and-things) |
| **Wick's Bags** | [repo](https://github.com/Wicks-mods/WicksBags) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-bags) |
| **Wick's Travel Form** | [repo](https://github.com/Wicks-mods/WicksTravelForm) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-travel-form) |
| **Wick's Ledger** | [repo](https://github.com/Wicks-mods/WicksLedger) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-ledger) |
| **Wick's Wardrobe** | [repo](https://github.com/Wicks-mods/WicksWardrobe) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-wardrobe) |
| **Wick's Survivors** | [repo](https://github.com/Wicks-mods/WicksSurvivors) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-survivors) |
| **WickCore** | [repo](https://github.com/Wicks-mods/WickCore) | [CurseForge](https://www.curseforge.com/wow/addons/wickcore) |
| **Wick's Comforts** | [repo](https://github.com/Wicks-mods/WicksComforts) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-comforts) |
| **Wick's Beasts and Things** | [repo](https://github.com/Wicks-mods/WicksBeastsAndThings) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-beasts-and-things) |
| **Wick's Stances and Things** | [repo](https://github.com/Wicks-mods/WicksStancesAndThings) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-stances-and-things) |
| **Wick's Seals and Things** | [repo](https://github.com/Wicks-mods/WicksSealsAndThings) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-seals-and-things) |
| **Wick's Conjures and Things** | [repo](https://github.com/Wicks-mods/WicksConjuresAndThings) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-conjures-and-things) |
| **Wick's Poisons and Things** | [repo](https://github.com/Wicks-mods/WicksPoisonsAndThings) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-poisons-and-things) |
| **Wick's Demons and Things** | [repo](https://github.com/Wicks-mods/WicksDemonsAndThings) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-demons-and-things) |
| **Wick's Gear** | [repo](https://github.com/Wicks-mods/WicksGear) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-gear) |
| **Wick's UI** | [repo](https://github.com/Wicks-mods/WicksUIForever) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-ui) |
| **Wick's Reminders** | [repo](https://github.com/Wicks-mods/WicksReminders) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-reminders) |
| **Wick's Map** | [repo](https://github.com/Wicks-mods/WicksMap) | [CurseForge](https://www.curseforge.com/wow/addons/wicks-map) |

**Community:** [Discord](https://discord.gg/GWGTMhYBZY)
<!-- wick:suite-table:end -->

## License

MIT with a trademark carve-out for the Wick name, logomark and visual system.
LibStub is public domain. Full policy:
[WickSuite/TRADEMARK.md](https://github.com/Wicks-mods/WickSuite/blob/main/TRADEMARK.md).
