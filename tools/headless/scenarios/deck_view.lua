-- #12: the Full Deck screen, with Steamodded's own View Deck when it is loaded.
-- The cards get the whole width under the deck's counts, and nothing leaves the
-- screen.

local SEED = os.getenv('BPM_HL_SEED') or 'BPMTEST1'
G.FUNCS.start_run(nil, {stake = 1, seed = SEED})
wait_state('BLIND_SELECT', 30)
wait_until(function() dismiss_popups() return find({button = 'select_blind'}) end, 20, 'blind choices')
wait(1)

G.FUNCS.deck_info()
wait_until(function() return G.OVERLAY_MENU and input_ready() end, 10, 'deck screen')
wait(1.5)
shot('deck_view')

local W = love.graphics.getWidth()
local areas = {}
local function walk(node)
    local obj = node.UIT == G.UIT.O and node.config.object
    if obj and obj.is and obj:is(CardArea) then areas[#areas + 1] = obj end
    if obj and obj.UIRoot then walk(obj.UIRoot) end
    for _, c in ipairs(node.children or {}) do walk(c) end
end
walk(G.OVERLAY_MENU.UIRoot)
check(#areas >= 4, 'the deck screen has a row of cards per suit (' .. #areas .. ')')
local s = G.TILESCALE * G.TILESIZE
for i, a in ipairs(areas) do
    local x0, x1 = (a.T.x + G.ROOM.T.x) * s, (a.T.x + a.T.w + G.ROOM.T.x) * s
    check(x0 >= -1 and x1 <= W + 1, string.format('row %d of cards is on the screen (%.0f..%.0f of %d)', i, x0, x1, W))
    if i == 1 then
        log(string.format('cards row width %.0f px of %d', x1 - x0, W))
        -- On a phone the width is what limits the cards; a nearly square fold or a
        -- tablet runs out of height first.
        if W < 500 then
            check(x1 - x0 > W * 0.75, string.format('the cards get most of the width (%.0f of %d px)', x1 - x0, W))
        end
    end
end
layout_report('deck_view')
