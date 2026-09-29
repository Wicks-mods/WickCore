-- WickCore
-- Chrome.lua — the Wick visual system, built once.
--
-- Locked palette, flat panels, single 1px muted-purple border, fel-green
-- L-bracket corners with 10px arms 2px thick flush to the corners. Products
-- call Chrome:NewPanel and get all of it; they never draw their own frame.

local ADDON = ...
local Core = LibStub("WickCore-1.0", true)
if not Core or Core._sourceAddon ~= ADDON then return end

local Chrome = {}
Core.Chrome = Chrome

-- ============================================================
-- Palette (locked, do not drift)
-- Fel #4FC778 · Void #0D0A14 · Shadow #171124 · Border #383058 · Text #D4C8A1
-- ============================================================
Chrome.Colors = {
    fel      = { 0.310, 0.780, 0.471, 1 },
    void     = { 0.051, 0.039, 0.078, 1 },
    voidBG   = { 0.051, 0.039, 0.078, 0.97 },
    shadow   = { 0.090, 0.067, 0.141, 1 },
    border   = { 0.220, 0.188, 0.345, 1 },
    text     = { 0.831, 0.784, 0.631, 1 },
    muted    = { 0.560, 0.530, 0.440, 1 },
    white    = { 1, 1, 1, 1 },
}
Chrome.Hex = {
    fel    = "4FC778",
    void   = "0D0A14",
    shadow = "171124",
    border = "383058",
    text   = "D4C8A1",
}

Chrome.BRACKET  = 10
Chrome.HEADER_H = 22
Chrome.FONT     = "Fonts\\FRIZQT__.TTF"

local C = Chrome.Colors

-- ============================================================
-- Palette registry
-- ============================================================
-- Every region Chrome paints with a palette token is remembered (weakly)
-- with the token's name, so a theme switch can re-tint it in place. A
-- color table that is not one of the tokens is a one-off and is left alone.
local TOKEN_OF = {}
for name, tbl in pairs(Chrome.Colors) do TOKEN_OF[tbl] = name end
local tinted = setmetatable({}, { __mode = "k" })

-- Register a region a product painted itself. kind: "texture" or "text".
function Chrome:Register(region, token, kind, alpha)
    if type(token) == "table" then
        -- A derived table keeps its own alpha; a token's alpha is part
        -- of the token.
        if alpha == nil and TOKEN_OF[token] and token[4] ~= (C[TOKEN_OF[token]] or {})[4] then
            alpha = token[4]
        end
        token = TOKEN_OF[token]
    end
    if not token or not C[token] then return region end
    tinted[region] = { token = token, kind = kind or "texture", alpha = alpha }
    return region
end

-- A colour derived from a token at another alpha: a hover wash, a
-- selection fill. Kept and refreshed on a theme change, and treated as a
-- token by Register, so a product paints with it exactly as it would
-- paint with Chrome.Colors.fel.
local derived = {}
function Chrome:Wash(token, alpha)
    if type(token) == "table" then token = TOKEN_OF[token] end
    local src = token and C[token]
    if not src then return { 0, 0, 0, alpha or 1 } end
    local t = { src[1], src[2], src[3], alpha or 1 }
    derived[#derived + 1] = { color = t, token = token }
    TOKEN_OF[t] = token
    return t
end

function Chrome:Retint()
    -- The derived tables first, so a region registered with one is
    -- repainted from numbers that are already current.
    for _, d in ipairs(derived) do
        local src = C[d.token]
        if src then
            d.color[1], d.color[2], d.color[3] = src[1], src[2], src[3]
        end
    end
    for region, info in pairs(tinted) do
        local c = C[info.token]
        if c then
            local a = info.alpha or c[4] or 1
            if info.kind == "text" then
                if region.SetTextColor then region:SetTextColor(c[1], c[2], c[3], a) end
            elseif info.kind == "vertex" then
                if region.SetVertexColor then region:SetVertexColor(c[1], c[2], c[3], a) end
            elseif region.SetColorTexture then
                region:SetColorTexture(c[1], c[2], c[3], a)
            end
        end
    end
end

-- ============================================================
-- Styles
-- ============================================================
-- The shape the chrome is drawn in, separate from its colours (Theme.lua).
-- A style is a description, not code: every drawing call below reads the
-- current one, so a new look is a new entry here and the whole suite
-- follows it. Each belongs to one of two families, which is what the
-- drawing code branches on (Chrome:Modern()):
--
--   modern  textured panels: 9-sliced glass on a soft lift, no border
--           line, a ring that stands in for a coloured border
--   og      flat panels: a solid fill, a 1px border, corner marks
--
-- and then says how it differs from its family's base:
--
--   media        textures: panel (rounded), ring, the tile and tileRing
--                small frames draw in instead (64 px or less; the panel
--                shape where a look has no tile of its own), the lift (shadow), the
--                mask for rounded corners (roundmask, the minimap too) and
--                the one for icons (iconmask)
--   slice        the 9-slice margin of panel and ring
--   glass        how solid panels are, times the family's own alpha
--   lift         the lift's colour token (nil for black) and alpha
--   ringRest     a ring shown at rest in the border's place: token, alpha
--   corners      og: "brackets" or "none"
--   edge         og: the black pixel outside the border
--   font         the Chrome font; uiFont, when set, is also what Wick's
--                UI's "Wick" font draws in, uiBump added to its sizes
--   headingFont  headings and titles, headingBump added to their size
--   bump         added to font sizes (faces that run small)
--   textShadow   a firm drop shadow on text
--   upper        headings in capitals
--   plate        headings on a plate in the accent
--   dash         a short line in the accent before each heading
--   borderPx     og: border thickness
--   hardShadow   og: a solid offset shadow under panels { x, y, alpha }
--   stripe       an accent stripe down the left edge of panels
--   palette      the theme the look comes with, chosen with it
--   sheen        a gradient laid over panels (not tiles): the accent at
--                { top } alpha along the top, black at { bottom } alpha
--                along the bottom, so a window is lit from above
--   edgeInset    how far in from a panel's edge it reads as solid (a wash
--                that fades out at its sides): things set against the
--                edge, like a window's side tabs, move in by this much
--   iconTab      icons start this far below their tile's top, so the
--                tile's shaped top shows above them as a tab (Arena's
--                folders: its 6 px notch and 1 px under it)
--   health       unit health bars in the look's colours instead of by
--                class: { friend = token or hex, enemy = token or hex }
--   statusbar    the bar texture the look draws in, where the player has
--                left the bar texture on the default
--
-- The choice is account-wide, read from the saved variable directly (as
-- the theme is), and changing it takes a reload: panels are built once.
local MEDIA = "Interface\\AddOns\\WickCore\\Media\\"
local TEX = MEDIA .. "Textures\\"
local FONTS = MEDIA .. "Fonts\\"
local PT_SANS = FONTS .. "PT_Sans-Narrow-Web-Bold.ttf"
local FRIZ = "Fonts\\FRIZQT__.TTF"
local ARIALN = "Fonts\\ARIALN.TTF"
local MORPHEUS = "Fonts\\MORPHEUS.TTF"

local BASE_MEDIA = {
    rounded   = TEX .. "rounded.png",
    ring      = TEX .. "ring.png",
    shadow    = TEX .. "shadow.png",
    roundmask = TEX .. "roundmask.png",
    iconmask  = TEX .. "roundmask.png",
    font      = PT_SANS,
    slice     = 8,
}

local function modernBump(size) return size + (size <= 11 and 2 or 1) end

-- The open-licensed faces the looks draw in (SIL OFL 1.1, each licence
-- beside its font in Media/Fonts).
local F = {
    rajdhani     = FONTS .. "Rajdhani-SemiBold.ttf",
    rajdhaniBold = FONTS .. "Rajdhani-Bold.ttf",
    anton        = FONTS .. "Anton-Regular.ttf",
    archivo      = FONTS .. "ArchivoNarrow-Bold.ttf",
    cormorant    = FONTS .. "CormorantGaramond-SemiBold.ttf",
    cormorantSC  = FONTS .. "CormorantSC-SemiBold.ttf",
    barlow       = FONTS .. "BarlowCondensed-SemiBold.ttf",
    barlowBold   = FONTS .. "BarlowCondensed-Bold.ttf",
    jost         = FONTS .. "Jost-Medium.ttf",
    jostBold     = FONTS .. "Jost-SemiBold.ttf",
    michroma     = FONTS .. "Michroma-Regular.ttf",
    saira        = FONTS .. "SairaSemiCondensed-Medium.ttf",
    sairaBold    = FONTS .. "SairaSemiCondensed-SemiBold.ttf",
    -- Bundled for what comes next; any Wick's UI font list offers them.
    tektur       = FONTS .. "Tektur-Medium.ttf",
    tekturBold   = FONTS .. "Tektur-SemiBold.ttf",
    italiana     = FONTS .. "Italiana-Regular.ttf",
    exo          = FONTS .. "Exo2-Medium.ttf",
    exoBold      = FONTS .. "Exo2-SemiBold.ttf",
}
Chrome.Fonts = F
local function up(n) return function(size) return size + n end end

Chrome.Styles = {
    { id = "modern", name = "Wick Modern", family = "modern",
      blurb = "Rounded glass on a soft shadow, the Wick font, no border lines.",
      font = PT_SANS, bump = modernBump, textShadow = true },
    { id = "og", name = "Wick OG", family = "og",
      blurb = "The original: flat panels, a single-pixel border, fel corners.",
      font = FRIZ, corners = "brackets", edge = true },
    { id = "hologram", name = "Hologram", family = "modern", palette = "hologram",
      blurb = "A projected display: faint glass, cut corners, a cyan outline and glow, clean geometric type with capital headings.",
      font = F.jost, headingFont = F.jostBold, uiFont = F.jost, bump = up(1), uiBump = 1,
      textShadow = true, upper = true,
      media = { rounded = TEX .. "panel-chamfer.png", ring = TEX .. "ring-chamfer.png",
                roundmask = TEX .. "mask-chamfer.png", iconmask = TEX .. "mask-chamfer.png" },
      glass = 0.55, lift = { token = "fel", alpha = 0.3 }, ringRest = { token = "fel", alpha = 0.6 },
      health = { friend = "fel", enemy = "FF3F6C" } },
    { id = "rebel", name = "Rebel", family = "og", palette = "rebel",
      blurb = "Loud and graphic: black slabs, thick grey outlines, hard shadows, headings on red tags.",
      font = F.archivo, headingFont = F.anton, uiFont = F.archivo, bump = up(1), headingBump = 2, uiBump = 1,
      textShadow = true, upper = true, plate = true,
      corners = "none", edge = false, borderPx = 2, hardShadow = { x = 3, y = -3, alpha = 1 },
      health = { friend = "border", enemy = "fel" } },
    { id = "gilded", name = "Gilded", family = "modern", palette = "gilded",
      blurb = "Almost no chrome: a dark wash between thin gold rules, serif small capitals, round action buttons.",
      font = F.cormorant, headingFont = F.cormorantSC, uiFont = F.cormorant, bump = up(3), headingBump = 1, uiBump = 3,
      textShadow = true,
      media = { rounded = TEX .. "panel-wash.png", ring = TEX .. "ring-rules.png",
                iconmask = TEX .. "mask-circle.png", slice = 16 },
      glass = 0.9, lift = { alpha = 0 }, ringRest = { token = "fel", alpha = 0.5 }, edgeInset = 12,
      health = { friend = "A6282B", enemy = "fel" } },
    { id = "arena", name = "Arena", family = "modern", palette = "arena",
      blurb = "Esports flat: hard panels with one notched corner, an edge stripe, bold condensed capitals.",
      font = F.barlow, headingFont = F.barlowBold, uiFont = F.barlow, bump = up(2), uiBump = 2,
      textShadow = true, upper = true, stripe = true, iconTab = 7, health = { friend = "text", enemy = "fel" },
      media = { rounded = TEX .. "panel-notch.png", ring = TEX .. "ring-notch.png",
                roundmask = TEX .. "mask-square.png", iconmask = TEX .. "mask-square.png", slice = 8 },
      glass = 1.25, lift = { alpha = 0.7 }, ringRest = { token = "text", alpha = 0.16 },
      statusbar = TEX .. "bar-edge.png" },
    { id = "frost", name = "Frost", family = "modern", palette = "frost",
      blurb = "Cold and sparse: see-through panels, hairlines in the icy accent, stark wide capitals over a narrow face.",
      font = F.saira, headingFont = F.michroma, uiFont = F.saira, bump = up(1), headingBump = -2, uiBump = 1,
      textShadow = true, upper = true,
      media = { rounded = TEX .. "panel-square.png", ring = TEX .. "ring-hair.png",
                roundmask = TEX .. "mask-square.png", iconmask = TEX .. "mask-square.png", slice = 4 },
      glass = 0.55, lift = { alpha = 0 }, ringRest = { token = "fel", alpha = 0.3 },
      health = { friend = "fel", enemy = "FFB36B" }, statusbar = TEX .. "bar-glass.png", dash = true,
      sheen = { top = 0.32, bottom = 0.35 } },
}
Chrome.StyleByID = {}
for _, st in ipairs(Chrome.Styles) do Chrome.StyleByID[st.id] = st end

local function styleStore()
    local sv = rawget(_G, "WickCoreDB")
    return type(sv) == "table" and type(sv.global) == "table" and sv.global or nil
end

-- The style in use, its whole description.
function Chrome:StyleDef()
    local g = styleStore()
    return self.StyleByID[g and g.style or "modern"] or self.StyleByID.modern
end

function Chrome:StyleID() return self:StyleDef().id end

-- The family: "modern" or "og". What the drawing code branches on.
function Chrome:Style() return self:StyleDef().family end

function Chrome:Modern() return self:Style() == "modern" end

function Chrome:SetStyle(style)
    local sv = rawget(_G, "WickCoreDB")
    if type(sv) ~= "table" then return end
    sv.global = sv.global or {}
    sv.global.style = self.StyleByID[style] and style or "modern"
    -- A look comes with its own colours; they are chosen with it, and can
    -- be changed afterwards like any theme. Wick Modern and Wick OG keep
    -- whatever theme is in use.
    local st = self.StyleByID[style]
    if st and st.palette and self.SetTheme and self.ThemeByID and self.ThemeByID[st.palette] then
        self:SetTheme(st.palette)
    end
    if Core.Store then Core.Store:Dirty() end
end

-- Media for the style in use: its own textures where it has them, the
-- base set where it does not. Read at draw time, never cached.
Chrome.Media = setmetatable({}, { __index = function(_, k)
    local own = Chrome:StyleDef().media
    if own and own[k] ~= nil then return own[k] end
    return BASE_MEDIA[k]
end })

function Chrome:Glyph(name) return TEX .. "glyph-" .. name .. ".png" end

-- The panel and ring textures for a frame: small ones (slots, buttons,
-- tiles) take the look's tile shape where it has one, since a square icon
-- inside a shaped tile shows past the shape. A frame not sized yet counts
-- as a panel.
function Chrome:IsTile(f)
    local w, h = f and f.GetSize and f:GetSize()
    return w and h and w > 0 and h > 0 and w <= 64 and h <= 64
end
function Chrome:PanelTex(f)
    return (self:IsTile(f) and self.Media.tile) or self.Media.rounded
end
function Chrome:RingTex(f)
    return (self:IsTile(f) and self.Media.tileRing) or self.Media.ring
end

-- An icon of the suite's own in a look with an icon tab: its top edge is
-- moved down to the tab, its sides and bottom kept, so the whole picture is
-- drawn a little shorter below the tile's shaped top. Returns true when it
-- did, and the icon's mask then covers all of it.
function Chrome:TabIcon(icon, tile)
    local tab = self:Modern() and self:StyleDef().iconTab
    if not (tab and icon and tile and icon.GetNumPoints) then return false end
    local l, r, b = 0, 0, 0
    for i = 1, icon:GetNumPoints() do
        local p, _, _, x, y = icon:GetPoint(i)
        if p == "TOPLEFT" then l = x or 0
        elseif p == "BOTTOMRIGHT" then r, b = x or 0, y or 0 end
    end
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", tile, "TOPLEFT", l, -tab)
    icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", r, b)
    return true
end

-- Where an icon's mask sits: over the whole icon, or, in a look with an
-- icon tab, over all of it but the top few pixels. This is for icons that
-- are Blizzard's, which are not moved: the picture is cut, keeping its
-- width, and the tile's shaped top shows above it. The suite's own icons
-- are drawn shorter instead (TabIcon). inset: how far the icon already
-- sits inside its tile's top.
function Chrome:PlaceIconMask(m, icon, inset)
    m:ClearAllPoints()
    local tab = self:Modern() and self:StyleDef().iconTab
    if tab then
        m:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, -math.max(0, tab - (inset or 0)))
        m:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    else
        m:SetAllPoints(icon)
    end
end

Chrome.FONT_OG = FRIZ

-- The font every Chrome text uses. Chrome.FONT is kept current for
-- products that read it directly.
function Chrome:Font() return self:StyleDef().font or PT_SANS end
function Chrome:HeadingFont() local st = self:StyleDef(); return st.headingFont or st.font or PT_SANS end

-- How solid a panel of the family's alpha is in this style.
function Chrome:GlassAlpha(a) return math.min(1, (a or 1) * (self:StyleDef().glass or 1)) end

-- The corner marks an og-family panel wears.
function Chrome:Corners() return self:StyleDef().corners or "none" end

local function slice(tex, m)
    if tex.SetTextureSliceMargins then
        tex:SetTextureSliceMargins(m, m, m, m)
        if tex.SetTextureSliceMode then pcall(tex.SetTextureSliceMode, tex, 0) end
    end
end

-- A rounded glass texture in a palette colour, re-tinted with the theme.
function Chrome:Glass(parent, layer, color, alpha, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    t:SetTexture(self:PanelTex(parent))
    slice(t, self.Media.slice)
    color = color or C.void
    local a = self:GlassAlpha(alpha or color[4] or 1)
    t:SetVertexColor(color[1], color[2], color[3], a)
    Chrome:Register(t, color, "vertex", a)
    return t
end

-- The soft lift under a modern panel, reaching past its edges.
function Chrome:Lift(f)
    local s = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    s:SetTexture(self.Media.shadow)
    slice(s, 28)
    s:SetPoint("TOPLEFT", f, "TOPLEFT", -12, 10)
    s:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 12, -14)
    local lift = self:StyleDef().lift or {}
    local c = lift.token and C[lift.token] or { 0, 0, 0 }
    s:SetVertexColor(c[1], c[2], c[3], lift.alpha or 0.6)
    if lift.token then Chrome:Register(s, c, "vertex", lift.alpha or 0.6) end
    return s
end

-- An item button in the modern style, drawn like the action buttons: the
-- icon trimmed to the rounded shape on a glass tile, and the quality shown
-- as a rounded ring in its colour. Returns the function that sets that
-- ring (colour table in, the resting border colour puts it away), or nil
-- in the original style, when the product keeps its own square edges.
function Chrome:ModernSlot(b, icon)
    if not self:Modern() or not b then return nil end
    if b.ItemSlotBackground then b.ItemSlotBackground:SetAlpha(0) end
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetTexture(self.Media.tile or self.Media.rounded)
    slice(bg, self.Media.slice)
    bg:SetAllPoints()
    -- The shadow colour, a step off the panel, so an empty slot (the Free
    -- tile) still reads as a tile.
    bg:SetVertexColor(C.shadow[1], C.shadow[2], C.shadow[3], 0.95)
    Chrome:Register(bg, C.shadow, "vertex", 0.95)
    if icon and icon.AddMaskTexture and b.CreateMaskTexture then
        local m = b:CreateMaskTexture()
        m:SetTexture(self.Media.iconmask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        self:TabIcon(icon, b)
        m:SetAllPoints(icon)
        icon:AddMaskTexture(m)
    end
    local ring = b:CreateTexture(nil, "OVERLAY", nil, 1)
    ring:SetTexture(self.Media.tileRing or self.Media.ring)
    slice(ring, self.Media.slice)
    ring:SetAllPoints()
    ring:Hide()
    local rest = C.border
    local ringRest = self:StyleDef().ringRest
    return function(c)
        -- The resting colour (the theme's border, or the brand purple a
        -- product passes for "no quality") puts the ring away.
        local function is(x) return math.abs(c[1] - x[1]) < 0.03 and math.abs(c[2] - x[2]) < 0.03 and math.abs(c[3] - x[3]) < 0.03 end
        if not c or is(rest) or is({ 0.20, 0.18, 0.34 }) then
            if ringRest then
                local rc = C[ringRest.token] or C.border
                ring:SetVertexColor(rc[1], rc[2], rc[3], ringRest.alpha)
                ring:Show()
            else
                ring:Hide()
            end
        else
            ring:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
            ring:Show()
        end
    end
end

-- The rounded ring a modern control shows for hover or selection.
function Chrome:Ring(parent, color, layer)
    local r = parent:CreateTexture(nil, layer or "BORDER", nil, 2)
    r:SetTexture(self:RingTex(parent))
    slice(r, self.Media.slice)
    r:SetAllPoints()
    color = color or C.fel
    r:SetVertexColor(color[1], color[2], color[3], 1)
    Chrome:Register(r, color, "vertex", 1)
    r:Hide()
    return r
end

-- ============================================================
-- Primitives
-- ============================================================

function Chrome:Texture(parent, layer, color)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    if color then
        t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        -- Through Register, so the rule about a derived colour
        -- keeping its own alpha is written once.
        Chrome:Register(t, color, "texture")
    end
    return t
end

-- A font string in the style's font. PT Sans Narrow runs small next to
-- Friz, so the modern style sets it a size or two up, with a firm shadow,
-- to read as clearly as Wick's UI. Products that make their own font
-- strings call this too.
function Chrome:SetFont(fs, size, flags, heading)
    size = size or 12
    local st = self:StyleDef()
    if st.bump then size = st.bump(size) end
    if heading and st.headingBump then size = size + st.headingBump end
    fs:SetFont(heading and self:HeadingFont() or self:Font(), size, flags or "")
    if st.textShadow then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    end
end

function Chrome:Text(parent, size, color, flags, heading)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    self:SetFont(fs, size or 12, flags, heading)
    color = color or C.text
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    Chrome:Register(fs, color, "text")
    return fs
end

-- Four 1px muted-purple edges.
--
-- In the modern style a border is not drawn. The frame's flat background
-- (a full-size texture Chrome painted with a palette colour) becomes rounded
-- glass, a panel-sized frame gets the soft lift, and the four edges become
-- stand-ins for one rounded ring: a product that recolours its border for
-- hover or selection (for _, t in pairs(f.border) do t:SetColorTexture(...))
-- lights the ring in that colour, and setting it back to the border colour
-- puts the ring away. So every product built on these primitives takes the
-- modern look without changing a line.
local function near(a, b) return math.abs(a - b) < 0.02 end

local function roundify(f)
    local fw, fh = f:GetSize()
    for _, r in ipairs({ f:GetRegions() }) do
        local info = r.GetObjectType and r:GetObjectType() == "Texture" and tinted[r]
        if info and info.kind == "texture" and r:GetDrawLayer() == "BACKGROUND" then
            local w, h = r:GetSize()
            local full = (r:GetNumPoints() >= 2) or (fw and w and fh and h and w >= fw - 2 and h >= fh - 2)
            if full then
                local c = C[info.token]
                local a = info.alpha or (c and c[4]) or 1
                r:SetTexture(Chrome:PanelTex(f))
                a = Chrome:GlassAlpha(a)
                if r.SetTextureSliceMargins then
                    local m = Chrome.Media.slice
                    r:SetTextureSliceMargins(m, m, m, m)
                    if r.SetTextureSliceMode then pcall(r.SetTextureSliceMode, r, 0) end
                end
                if c then r:SetVertexColor(c[1], c[2], c[3], a) end
                info.kind = "vertex"
                info.alpha = a
            end
        end
    end
end

local function ringProxy(ring, restColor)
    local proxy = {}
    local ringRest = Chrome:StyleDef().ringRest
    local function paint(_, r, g, b, a)
        if near(r, restColor[1]) and near(g, restColor[2]) and near(b, restColor[3]) then
            if ringRest then
                local rc = C[ringRest.token] or C.border
                ring:SetVertexColor(rc[1], rc[2], rc[3], ringRest.alpha)
                ring:Show()
            else
                ring:Hide()
            end
        else
            ring:SetVertexColor(r, g, b, a or 1)
            ring:Show()
        end
    end
    proxy.SetColorTexture = paint
    proxy.SetVertexColor = paint
    return setmetatable(proxy, { __index = function() return function() end end })
end

function Chrome:AddBorder(f, color)
    color = color or C.border
    if self:Modern() then
        roundify(f)
        local w, h = f:GetSize()
        if not f.lift and w and h and w >= 150 and h >= 100 then f.lift = self:Lift(f) end
        local ring = f:CreateTexture(nil, "BORDER", nil, 2)
        ring:SetTexture(self:RingTex(f))
        local m = self.Media.slice
        if ring.SetTextureSliceMargins then ring:SetTextureSliceMargins(m, m, m, m) end
        ring:SetAllPoints()
        ring:Hide()
        f.ring = f.ring or ring
        -- A border asked for in a colour other than the resting one is a
        -- signal (a bank section, a highlighted row): the ring shows it.
        local rest = C.border
        local proxy = ringProxy(ring, rest)
        -- Painted once now: a signal colour lights the ring, the resting
        -- one shows the style's ring at rest (or nothing).
        proxy:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        f.border = { top = proxy, bottom = proxy, left = proxy, right = proxy }
        return
    end
    local px = self:StyleDef().borderPx or 1
    local top    = self:Texture(f, "BORDER", color); top:SetPoint("TOPLEFT");    top:SetPoint("TOPRIGHT");    top:SetHeight(px)
    local bot    = self:Texture(f, "BORDER", color); bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(px)
    local left   = self:Texture(f, "BORDER", color); left:SetPoint("TOPLEFT");   left:SetPoint("BOTTOMLEFT"); left:SetWidth(px)
    local right  = self:Texture(f, "BORDER", color); right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(px)
    f.border = { top = top, bottom = bot, left = left, right = right }
end

-- Fel-green L-brackets. If a resizeButton is passed the BOTTOMRIGHT bracket
-- is parented to it so it doubles as the grip.
function Chrome:AddBrackets(parent, resizeButton, color)
    color = color or C.fel
    local B = self.BRACKET
    parent.brackets = {}
    -- No brackets in the modern style: the table is kept for products that
    -- walk it, and stays empty.
    if self:Modern() and not parent.wickPanel then return end
    local corners = self:Modern() and "brackets" or self:Corners()
    if corners == "none" then return end
    for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local host = (point == "BOTTOMRIGHT" and resizeButton) or parent
        local h = self:Texture(host, "OVERLAY", color)
        h:SetPoint(point, host, point, 0, 0)
        h:SetSize(B, 2)
        local v = self:Texture(host, "OVERLAY", color)
        v:SetPoint(point, host, point, 0, 0)
        v:SetSize(2, B)
        parent.brackets[point] = { h, v }
    end
end

-- Two-tone title: "Wick's" in text color, the noun in fel green.
function Chrome:TitleMarkup(title)
    local pre, noun = tostring(title):match("^(Wick'?s?)%s+(.+)$")
    if pre then
        return "|cff" .. self.Hex.text .. pre .. "|r |cff" .. self.Hex.fel .. noun .. "|r"
    end
    return "|cff" .. self.Hex.text .. tostring(title) .. "|r"
end

-- ============================================================
-- Dragging
-- ============================================================
-- One rule for every locked thing in the suite. A lock is there to stop
-- an accidental nudge while you are clicking the bar, not to stop you
-- moving it on purpose, and hunting for the unlock checkbox every time
-- is worse than the accident. Shift always moves the frame.
--
-- Anything with a lock asks this rather than testing the flag itself, so
-- the answer is the same everywhere and there is one place to change it.
function Chrome:DragAllowed(locked)
    if not locked then return true end
    local shift = rawget(_G, "IsShiftKeyDown")
    return (shift and shift()) and true or false
end

-- ============================================================
-- Panel
-- ============================================================
-- local panel = Chrome:NewPanel("WicksBagsFrame", {
--     title = "Wick's Bags", width = 400, height = 300,
--     resizable = true, minWidth = 260, minHeight = 120,
--     closable = true, strata = "MEDIUM", db = A.db.profile.window,
-- })
-- panel.content is the inset frame products draw into.

-- Register a named frame so Escape hides it before the game menu opens.
-- Only frames with a global name can be listed, and only once.
function Chrome:CloseOnEscape(frame)
    local name = frame and frame.GetName and frame:GetName()
    if not name then return false end
    local list = rawget(_G, "UISpecialFrames")
    if type(list) ~= "table" then return false end
    for _, n in ipairs(list) do if n == name then return true end end
    list[#list + 1] = name
    return true
end

function Chrome:NewPanel(name, o)
    o = o or {}
    local f = CreateFrame("Frame", name, o.parent or UIParent)
    f:SetSize(o.width or 400, o.height or 240)
    -- Whether the player can change the size, which is what decides
    -- whether a saved size is theirs or a stale copy of ours.
    f.wickResizable = o.resizable and true or false
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) s:StartMoving() end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        if s.db then Chrome:SavePosition(s, s.db) end
    end)
    if o.strata then f:SetFrameStrata(o.strata) end
    f:Hide()

    local modern = self:Modern()
    f.wickPanel = true
    local bg
    if modern then
        -- Rounded glass on a soft lift; the border is the ring stand-in.
        bg = self:Glass(f, "BACKGROUND", C.void, 0.95, -7)
        bg:SetAllPoints()
        f.lift = self:Lift(f)
        self:AddBorder(f)
    else
        bg = self:Texture(f, "BACKGROUND", C.voidBG); bg:SetAllPoints()
        self:AddBorder(f)
    end
    f.bg = bg
    Chrome:PanelExtras(f)

    -- Header strip: a band in the original style; in the modern one the
    -- title sits on the glass, with only a faint rule under it.
    local H = self.HEADER_H
    local header = self:Texture(f, "ARTWORK", C.shadow)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(H)
    -- The rule under the title: in the modern style the accent at half
    -- strength, inset a little, as the character sheet's headings draw it.
    local sep = self:Texture(f, "ARTWORK", modern and C.fel or C.border)
    sep:SetPoint("TOPLEFT", modern and 7 or 1, -H - 1)
    sep:SetPoint("TOPRIGHT", modern and -7 or -1, -H - 1)
    sep:SetHeight(1)
    if modern then header:Hide(); sep:SetAlpha(0.5) end
    f.header = header

    f.title = self:Text(f, 12, nil, nil, true)
    f.title:SetPoint("LEFT", f, "TOPLEFT", 10, -H / 2)
    f.title:SetText(self:TitleMarkup(o.title or name))

    -- Close glyph
    if o.closable ~= false then
        local close = CreateFrame("Button", nil, f)
        close:SetSize(H, H)
        close:SetPoint("TOPRIGHT", -1, -1)
        if modern then
            -- Our flat close mark; the accent copy shows on the highlight
            -- layer by itself.
            local x = close:CreateTexture(nil, "OVERLAY")
            x:SetSize(12, 12)
            x:SetPoint("CENTER")
            x:SetTexture(self:Glyph("close"))
            x:SetVertexColor(C.text[1], C.text[2], C.text[3], 1)
            Chrome:Register(x, C.text, "vertex", 1)
            local xh = close:CreateTexture(nil, "HIGHLIGHT")
            xh:SetAllPoints(x)
            xh:SetTexture(self:Glyph("close"))
            xh:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
            Chrome:Register(xh, C.fel, "vertex", 1)
        else
            local x = self:Text(close, 13)
            x:SetPoint("CENTER")
            x:SetText("x")
            close:SetScript("OnEnter", function() x:SetTextColor(C.fel[1], C.fel[2], C.fel[3], 1) end)
            close:SetScript("OnLeave", function() x:SetTextColor(C.text[1], C.text[2], C.text[3], 1) end)
        end
        close:SetScript("OnClick", function() f:Hide() end)
        f.close = close
        -- Escape closes it too, ahead of the game menu. UISpecialFrames is
        -- how every window in the game asks for that, and CloseSpecialWindows
        -- only ever hides what is listed, so nothing of theirs is touched.
        Chrome:CloseOnEscape(f)
    end

    -- Content inset
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 8, -H - 8)
    content:SetPoint("BOTTOMRIGHT", -8, 8)
    f.content = content

    -- Resize grip doubles as the BOTTOMRIGHT bracket
    local grip
    if o.resizable then
        f:SetResizable(true)
        local minW, minH = o.minWidth or 200, o.minHeight or 100
        if f.SetResizeBounds then f:SetResizeBounds(minW, minH)
        elseif f.SetMinResize then f:SetMinResize(minW, minH) end
        grip = CreateFrame("Button", nil, f)
        grip:SetSize(self.BRACKET + 2, self.BRACKET + 2)
        grip:SetPoint("BOTTOMRIGHT", 0, 0)
        grip:EnableMouse(true)
        grip:SetScript("OnMouseDown", function(_, btn)
            if btn == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end
        end)
        grip:SetScript("OnMouseUp", function()
            f:StopMovingOrSizing()
            if f.db then Chrome:SavePosition(f, f.db) end
            if f.OnResized then f.OnResized(f) end
        end)
        f.grip = grip
    end

    self:AddBrackets(f, grip)
    if modern then
        -- No brackets in the modern style; a resizable panel keeps a soft
        -- grip mark in its corner so the handle can still be found.
        for point, pair in pairs(f.brackets) do
            local keep = grip and point == "BOTTOMRIGHT"
            for _, t in ipairs(pair) do
                if keep then t:SetAlpha(0.45) else t:Hide() end
            end
        end
    end

    if o.db then
        f.db = o.db
        self:RestorePosition(f, o.db)
    end

    f.Toggle = function(s) if s:IsShown() then s:Hide() else s:Show() end end
    return f
end

-- ============================================================
-- Position persistence
-- ============================================================

-- Where a window is put is the player's, always. How big it is only
-- belongs to them when they can drag it: a panel sized in code has to
-- come up at the size the code says, or changing a layout leaves every
-- existing player on the old dimensions with the new contents spilling
-- out. Wick's Gear grew a second column and opened at its old width
-- with the paperdoll running through the button below it.
function Chrome:SavePosition(f, db)
    local point, _, relPoint, x, y = f:GetPoint()
    db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
    if f.wickResizable then
        db.width, db.height = f:GetWidth(), f:GetHeight()
    else
        -- Stop old numbers sitting there waiting to be believed again.
        db.width, db.height = nil, nil
    end
    -- Same as a theme: where a window sits is a setting, and on this
    -- client a setting the store has not been told about is gone at the
    -- next login.
    if Core.Store then Core.Store:Dirty() end
end

function Chrome:RestorePosition(f, db)
    if f.wickResizable and db.width and db.height then
        f:SetSize(db.width, db.height)
    end
    if db.point then
        f:ClearAllPoints()
        f:SetPoint(db.point, UIParent, db.relPoint or db.point, db.x or 0, db.y or 0)
    end
end

-- ============================================================
-- Small widgets in the same voice
-- ============================================================

function Chrome:Button(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 90, height or 22)
    if self:Modern() then
        -- A rounded tile; on hover the accent ring.
        local bg = self:Glass(b, "BACKGROUND", C.shadow, 0.92); bg:SetAllPoints()
        self:AddBorder(b)
        b.ring = self:Ring(b)
        b.label = self:Text(b, 11)
        b.label:SetPoint("CENTER")
        b.label:SetText(text)
        b:SetScript("OnEnter", function(s) s.ring:Show() end)
        b:SetScript("OnLeave", function(s) s.ring:Hide() end)
        return b
    end
    local bg = self:Texture(b, "BACKGROUND", C.shadow); bg:SetAllPoints()
    self:AddBorder(b)
    b.label = self:Text(b, 11)
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    b:SetScript("OnEnter", function(s)
        for _, t in pairs(s.border) do t:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 1) end
    end)
    b:SetScript("OnLeave", function(s)
        for _, t in pairs(s.border) do t:SetColorTexture(C.border[1], C.border[2], C.border[3], 1) end
    end)
    return b
end

-- Check box: 14px bordered square, fel fill when checked.
function Chrome:Check(parent, label, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(220, 18)
    local box = CreateFrame("Frame", nil, b)
    box:SetSize(14, 14)
    box:SetPoint("LEFT", 0, 0)
    local fill
    if self:Modern() then
        local bbg = self:Glass(box, "BACKGROUND", C.shadow, 0.92); bbg:SetAllPoints()
        self:AddBorder(box)
        fill = self:Glass(box, "ARTWORK", C.fel, 1)
    else
        local bbg = self:Texture(box, "BACKGROUND", C.void); bbg:SetAllPoints()
        self:AddBorder(box)
        fill = self:Texture(box, "ARTWORK", C.fel)
    end
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    b.fill = fill
    b.label = self:Text(b, 11)
    b.label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    b.label:SetText(label)
    local function refresh() if get() then fill:Show() else fill:Hide() end end
    b:SetScript("OnClick", function() set(not get()); refresh() end)
    b.Refresh = refresh
    refresh()
    return b
end

-- Stepper: a number you nudge, for the settings a check box cannot
-- carry. Same 220px width as Check so the two line up in a column.
--
-- No slider: a slider needs a drag region and a thumb texture to look
-- like anything, and every number the suite has wanted so far has a
-- sensible step and a small range.
function Chrome:Stepper(parent, label, get, set, opts)
    opts = opts or {}
    local step = opts.step or 1
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(220, 18)
    b.label = self:Text(b, 11)
    b.label:SetPoint("LEFT", 0, 0)
    b.label:SetText(label)

    local value = self:Text(b, 11, C.fel)
    local function refresh()
        local v = get()
        if v == nil then
            value:SetText("-")
        elseif opts.text then
            value:SetText(opts.text(v))
        else
            value:SetText((opts.format or "%d"):format(v))
        end
    end

    local minus = self:Button(b, "-", 18, 18)
    minus:SetPoint("RIGHT", b, "RIGHT", -62, 0)
    local plus = self:Button(b, "+", 18, 18)
    plus:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    value:SetPoint("CENTER", minus, "RIGHT", 22, 0)

    local function nudge(by)
        local v = tonumber(get())
        if not v then return end
        -- The setter clamps; this only asks.
        set(v + by)
        refresh()
    end
    minus:SetScript("OnClick", function() nudge(-step) end)
    plus:SetScript("OnClick", function() nudge(step) end)

    b.Refresh = refresh
    refresh()
    return b
end

function Chrome:Heading(parent, text)
    local fs = self:Text(parent, 12, C.fel, nil, true)
    self:SetHeadingText(fs, text)
    return fs
end

-- A heading's text in the look's voice: capitals where it writes them,
-- and on a plate in the accent where it draws one (then the text is the
-- panel colour, to read on the plate).
function Chrome:SetHeadingText(fs, text)
    local st = self:StyleDef()
    text = tostring(text or "")
    if st.upper and not text:find("|", 1, true) then text = text:upper() end
    if st.dash and text ~= "" then
        -- A 14 by 1 line in the accent, drawn into the text so it sits
        -- right wherever the heading is placed.
        local c = C.fel
        text = ("|TInterface\\Buttons\\WHITE8X8:1:14:0:0:8:8:0:8:0:8:%d:%d:%d|t   "):format(
            math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) .. text
    end
    fs:SetText(text)
    local parent = st.plate and not fs.wickPlate and fs.GetParent and fs:GetParent()
    if parent and parent.CreateTexture then
        local p = parent:CreateTexture(nil, "ARTWORK", nil, -1)
        p:SetPoint("TOPLEFT", fs, "TOPLEFT", -5, 2)
        p:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 5, -2)
        p:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(p, C.fel, "texture")
        fs.wickPlate = p
        fs:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        Chrome:Register(fs, C.text, "text")
    end
end

-- A look's sheen over a panel (Frost): lit in the accent at the top, darker
-- at the bottom, drawn just above the panel's own fill. Small frames
-- (slots, buttons) are left plain. Repainted when the theme changes.
local sheens = setmetatable({}, { __mode = "k" })
local function paintSheen(t)
    local sh = Chrome:StyleDef().sheen
    if not (sh and t.SetGradient and CreateColor) then return end
    local c = C.fel
    pcall(t.SetGradient, t, "VERTICAL", CreateColor(0, 0, 0, sh.bottom or 0.3), CreateColor(c[1], c[2], c[3], sh.top or 0.15))
end
local sheenHooked = false
function Chrome:Sheen(f)
    local sh = self:StyleDef().sheen
    if not sh or not f or f.wickSheen or self:IsTile(f) then return end
    -- Theme.lua loads after this file; the repaint is hooked on first use.
    if not sheenHooked and self.OnThemeChanged then
        sheenHooked = true
        self:OnThemeChanged(function() for t in pairs(sheens) do paintSheen(t) end end)
    end
    local t = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    t:SetAllPoints()
    t:SetColorTexture(1, 1, 1, 1)
    paintSheen(t)
    sheens[t] = true
    f.wickSheen = t
    return t
end

-- What a look adds to a big panel: a solid offset shadow (Rebel) and an
-- accent stripe down its left edge (Arena).
function Chrome:PanelExtras(f)
    local st = self:StyleDef()
    self:Sheen(f)
    if st.hardShadow and not f.wickHardShadow then
        local h = st.hardShadow
        local sh = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        sh:SetPoint("TOPLEFT", f, "TOPLEFT", h.x, h.y)
        sh:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", h.x, h.y)
        sh:SetColorTexture(0, 0, 0, h.alpha or 1)
        f.wickHardShadow = sh
    end
    if st.stripe and not f.wickStripe then
        local s = f:CreateTexture(nil, "BORDER", nil, 3)
        s:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -1)
        s:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 1)
        s:SetWidth(3)
        s:SetColorTexture(C.text[1], C.text[2], C.text[3], 1)
        Chrome:Register(s, C.text, "texture")
        f.wickStripe = s
    end
end

-- A 1px rule. In the modern style it is the accent at half strength, the
-- rule the character sheet's headings and Wick's Bags draw.
function Chrome:Divider(parent)
    local modern = self:Modern()
    local t = self:Texture(parent, "ARTWORK", modern and C.fel or C.border)
    t:SetHeight(1)
    if modern then t:SetAlpha(0.5) end
    return t
end
