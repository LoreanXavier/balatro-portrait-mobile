-- The black ellipse: on a GPU that runs the CRT shader's noise at half precision
-- the seed overflows wherever tc.x * tc.y > 0.16, and that area comes out black.
-- A desktop GPU never does, so the shader is told to go black where a half float
-- would have overflowed. The unfixed seed has to draw the ellipse, or this check
-- proves nothing; the seed the game ships must not.
local UNSAFE = '* time * 1000.0;'
local SAFE = '* mod(time, 32.0) * 1000.0;'

local function with_half_overflow(source)
    local seed_end = source:find('1000.0;', 1, true) + #'1000.0;'
    return source:sub(1, seed_end - 1)
        .. '\n    if (x >= 65504.0) { return vec4(0.0, 0.0, 0.0, 1.0); }\n'
        .. source:sub(seed_end)
end

-- Share of pixels that are pure black, over the screen and in the corner the
-- ellipse grows from. Sampled, not counted: this is a yes or no.
local function black_share()
    local data
    love.graphics.captureScreenshot(function(img) data = img end)
    repeat coroutine.yield() until data
    local w, h = data:getDimensions()
    local function share(x0, y0, x1, y1)
        local black, total = 0, 0
        for y = math.floor(y0 * h), math.floor(y1 * h) - 1, 4 do
            for x = math.floor(x0 * w), math.floor(x1 * w) - 1, 4 do
                local r, g, b = data:getPixel(x, y)
                total = total + 1
                if r + g + b < 0.02 then black = black + 1 end
            end
        end
        return black / total
    end
    return share(0, 0, 1, 1), share(0.5, 0.5, 0.97, 0.97)
end

local function use(source)
    G.SHADERS['CRT'] = love.graphics.newShader(with_half_overflow(source))
    frames(4)
end

wait_title()
wait(1)
G.SETTINGS.GRAPHICS.crt = 70

-- The Zygisk build keeps the app's own shader and patches it as it loads.
local shipped = love.filesystem.read('resources/shaders/CRT.fs')
local has_rules, rules = pcall(require, 'portrait_shaders')
if has_rules and type(rules) == 'table' and rules.patches then
    for _, rule in ipairs(rules.patches['CRT.fs'] or {}) do
        local first, last = shipped:find(rule.find, 1, true)
        if first then shipped = shipped:sub(1, first - 1) .. rule.replace .. shipped:sub(last + 1) end
    end
end
check(shipped:find(SAFE, 1, true) ~= nil, 'CRT noise seed wraps time')
check(shipped:find(UNSAFE, 1, true) == nil, 'CRT noise seed is not the one that overflows')

local at = shipped:find(SAFE, 1, true)
if at then
    use(shipped:sub(1, at - 1) .. UNSAFE .. shipped:sub(at + #SAFE))
    local all, corner = black_share()
    shot('crt_unfixed_on_half_precision')
    log('unfixed black share', all, corner)
    check(corner > 0.9, 'half precision emulation reproduces the ellipse')

    use(shipped)
    all, corner = black_share()
    shot('crt_fixed_on_half_precision')
    log('fixed black share', all, corner)
    check(corner < 0.01, 'no ellipse with the shipped shader')
end
