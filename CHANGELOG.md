# WickCore - Changelog

## 0.11.1 (unreleased)

### Fixed

- Picking Wick Modern or Wick OG keeps the theme you have. It had been
  switching you to your class theme, so on TBC a try of Wick Modern and a
  return to Wick OG left you on your class colour instead of Fel. Coming
  back from a look with its own colours (Rebel, Crisp and the rest) gives
  you the Wick theme you had before that look.

## 0.11.0 (2026-10-03)

### Added

- TBC Classic Anniversary. WickCore loads on 2.5.6 as well as Forever,
  from one folder and one version. The client is the same engine
  generation as Forever with the Classic interface on top, so the
  modern dialect, the Settings panel and Edit Mode are all there; what
  it lacks is read off at load as capability flags (`Client.hasEditMode`,
  `hasSettings`, `hasAuraContainer`, `hasPing`, `hasBossFrames`,
  `hasObjectiveTracker`), which products branch on instead of the
  flavour.
- A TBC-shaped stub client for the offline harness
  (`run.py --tbc`, `--all` for every shape).
- Movable frames. A product registers a bar, button or counter the
  player can drag (`Chrome:RegisterMovable`, or `A:RegisterMovable` on
  its addon object), with where it sits as the default. A UI with
  movers of its own (Wick's UI) lists it with everything else and
  takes over its place, telling the product to stand its own drag
  down; without one nothing changes. `Chrome:RestorePosition` leaves
  a claimed frame alone.

### Changed

- On TBC a character starts on Wick OG in fel green, the look every TBC
  addon has always had, so an update changes nothing a player did not
  ask for. Modern and the class colours are one click away in
  /wickcore options. Forever still starts on Wick Modern.
- Combat is combat on every client: `Restrict:IsCombat()` reads combat
  lockdown as well as the restriction state, the regen events are
  watched everywhere, and one Combat notification fires per change of
  state whichever event carried it. TBC has the restriction API and
  never restricts anything.
- The macro settings store only arms on Forever, the client it was
  written for. Elsewhere it says it is not needed and never offers.
- The line naming a blocked or forbidden call now prints only with
  /wickcore debug on. The record is kept either way for /wickcore
  refused.
- The options root no longer names a client.

### Fixed

- Opening a Custom colour picker switched the theme to Custom before
  anything was picked, and Cancel put the colours back but not the
  theme.
- `Dialect.IsSpellKnown(id, true)` passed a boolean where
  `C_SpellBook.IsSpellKnown` wants a spell bank, so every pet spell
  read as unknown.

## 0.10.1 (2026-10-01)

### Added

- Crisp, a ninth look. Clean cut: see-through dark grey panels, one
  black pixel round everything, square corners, no shadows or glows,
  and your class colour as the accent. Pick it under /wickcore options,
  or in the first-run setup of Wick's UI.

### Changed

- A look's palette can take your class colour as its accent, in the
  class colour set you chose. Crisp is the first look to do it.
- Flat panels, the ones Wick OG and its family draw, take a look's
  glass, so a look can make them see-through.
- /wickcore theme no longer prints the saved-variable traces. The
  client hands settings back at load again, so they had nothing left
  to show.

### Fixed

- /wickcore addons and the version broadcast said 0.9.0 all through
  the 0.10.0 release. They give the real number now.

## 0.10.0 (2026-09-30)

### Added

- Looks. Every Wick addon is drawn in one of eight: Wick Modern (rounded
  glass, the default), Wick OG (flat panels with the fel corners),
  Hologram, Rebel, Gilded, Arena, Foundry and Frost. Each brings its own
  shapes, fonts and colours. Pick one under /wickcore options, or in the
  first-run setup of Wick's UI.
- The look and the colours are each character's own. A new character
  starts on Wick Modern in its class colours; the class colour set and
  custom colours stay account-wide.
- Profiles can be one per account, starting from the profile the
  character is on.
- A reload prompt for the times the game refuses an addon's reload: its
  Reload now is the game's own /reload, so it always goes through. Out of
  combat only, and it closes itself as a fight starts.
- /wickcore refused names any call the client turned down.

### Changed

- One Appearance section holds the look, the theme and the class colours.
- Theme swatches wrap to the width of the settings page.
- The minimap button sits inside the edge of a square map.

### Fixed

- A character that logs in before the client knows its name no longer
  files its settings under "Unknown", where the next new character would
  have found them. Old "Unknown" entries are cleared.
- A weapon's coating is read from the weapon's own tooltip, in every
  shape the client reports it.

## 0.9.3 — 2026-09-24

### Changed

- The client keeps settings itself again, as of its 24 September patch.
  The macro store was standing in for a client that wrote saved
  variables and never read them back; it checks at every login, and it
  has stood itself down. It now says so once at login while the WickCfg
  macros it made are still there, and points at `/wickcore store off`
  to clear them and get the macro slots back.
- Nothing is lost by clearing them. The client always wrote saved
  variables correctly during the beta, it only failed to read them, so
  every addon has a current file of its own.

## 0.9.2 — 2026-09-24

### Changed

- The cooldown bar tracks rather than casts. It was built out of secure
  cast buttons, which cannot be changed during a fight, which is when a
  cooldown tracker is worth having. Clicking an icon no longer casts.
- The bar has a scale and a row width, and anything on cooldown dims,
  so it answers at a glance the question it exists for.
- A checklist row can say it does not apply to this character, instead
  of sitting grey forever next to something you will never have.

### Fixed

- Settings changed outside the options page are kept. Picking a theme
  or dragging a window wrote the setting and never told the part of
  WickCore that survives a restart, so your theme came back to the old
  one at the next login.
- A window sized in code opens at the size the code says. A size saved
  under an older layout was being restored over it.
- The version handler no longer compares a chat payload the client has
  marked unreadable.

## 0.9.1

### Your theme stops resetting

A login that read the theme before the settings had arrived fell back to
Fel and then saved Fel over your real choice, so one early read lost the
setting for good. On this client the settings come from the macro store,
which can land after login, so reading nothing at login is normal and
has to be harmless. It only writes back a choice it actually read now.

## 0.9.0

One version across the suite for the Forever beta. Every addon carried a
number of its own that said nothing about how finished it was, so they are
aligned here and the suite goes to 1.0.0 together at launch.

## 0.4.0 - 2026-09-21

### Settings that survive this client

The Forever beta writes saved variables at logout and hands nothing back at
load. Macros are the one thing an addon can write that provably comes back,
so every Wick saved variable is now kept in account macros named WickCfg01
onward as well: dictionary-coded, base64, 240 characters a macro, 60 macros
at most. Restored as each addon enables, before its OnEnable, so no product
applies defaults it did not choose. Written ten seconds after an options
change, once a minute if anything differs, and at logout.

- Core.Store: Encode/Decode, Read/Write/Clear, RestoreFor, Save, Dirty.
  Deterministic encoding, so "changed" is a string compare
- DBProto:RebindTo(table), which Rebind now uses; db.handedOver records
  whether the client itself supplied the table (a WicksProfile bake does
  not count)
- Runs only when the client handed WickCoreDB over as nil. If saved
  variables start loading, it stays out of the way and says so
- /wickcore store [save|clear]
- Addons declare cache paths with storeExclude (Bags: global.alts, the
  alt inventory snapshot) and those are left out of the store, so a cache
  cannot grow past the budget and take an addon's settings down with it
- Bodies are escaped rather than base64: settings are printable text, and
  base64 made every one a third bigger. Fifty-four macros became about
  twenty. Anything the base64 version wrote still reads back

## 0.3.0 - 2026-09-17

### Themes

The chrome keeps its shape and swaps its five colors. Fel stays the brand
default; the other eight themes are one per Forever class.

- Chrome.Themes: Fel (the brand, and the warlock theme) plus one theme per
  other class. Class themes take their accent from the client's class color
  table and derive void, shadow, border and text from it, so they match the
  colors the game itself uses for each class
- Chrome:SetTheme(id) mutates Chrome.Colors in place and re-tints every
  region Chrome painted with a palette token, live, no reload
- "auto" follows the player's class; the choice is saved account-wide in WickCoreDB
- Theme picker with swatches on the Wick's Mods options page; /wickcore theme
- Chrome:Register(region, token, kind) for regions products paint themselves
- Chat prefix and two-tone title colors follow the theme

## 0.1.0 - 2026-09-17

### Scaffold

Built the day the Forever beta opened, against the first two probe runs on
client 1.60.1.69893 (interface 16001) and the `forever` branch of Blizzard's UI
source.

- LibStub-versioned library `WickCore-1.0`, loadable standalone or embedded
- Addon objects: `WickCore:NewAddon`, event bus, slash registration, lifecycle
- Client detection by interface number, since Forever reports itself as Mainline
- Restriction guard: `ADDON_RESTRICTION_STATE_CHANGED`, secret-value checks,
  aura access guard that survives the in-combat throw
- Dialect shim over items, spells, cooldowns, containers, auras, quest log,
  group, money, addon messages, professions, totems, talents
- Brand chrome: palette tokens, panel builder, brackets, buttons, checks
- Profiles keyed by character, spec, class or game mode, with export/import strings
- One "Wick's Mods" options category with a page per product
- Launcher: LibDataBroker object per product, minimap button and hub fallback
- Localization tables with key fallback
- Version broadcast on the WICK prefix, guarded by the chat restriction
