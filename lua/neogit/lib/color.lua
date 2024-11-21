local util = require("neogit.lib.util")
local M = {}

--#region TYPES

---@class RGBA
---@field red number Float [0,1]
---@field green number Float [0,1]
---@field blue number Float [0,1]
---@field alpha number Float [0,1]

---@class HSV
---@field hue number Float [0,360)
---@field saturation number Float [0,1]
---@field value number Float [0,1]

---@class HSL
---@field hue number Float [0,360)
---@field saturation number Float [0,1]
---@field lightness number Float [0,1]

--#endregion

---@class Color
---@field red number
---@field green number
---@field blue number
---@field alpha number
---@field hue number
---@field saturation number
---@field value number
---@field lightness number
local Color = setmetatable({}, {})

function Color:init(r, g, b, a)
  self:set_red(r)
  self:set_green(g)
  self:set_blue(b)
  self:set_alpha(a)
end

---@param c Color
---@return Color
function Color.from_color(c)
  return Color(c.red, c.green, c.blue, c.alpha)
end

---@param h number Hue. Float [0,360)
---@param s number Saturation. Float [0,1]
---@param v number Value. Float [0,1]
---@param a number|nil (Optional) Alpha. Float [0,1]
---@return Color
function Color.from_hsv(h, s, v, a)
  h = h % 360
  s = util.clamp(s, 0, 1)
  v = util.clamp(v, 0, 1)
  a = util.clamp(a or 1, 0, 1)

  local function f(n)
    local k = (n + h / 60) % 6
    return v - v * s * math.max(math.min(k, 4 - k, 1), 0)
  end

  return Color(f(5), f(3), f(1), a)
end

---@param h number Hue. Float [0,360)
---@param s number Saturation. Float [0,1]
---@param l number Lightness. Float [0,1]
---@param a number|nil (Optional) Alpha. Float [0,1]
---@return Color
function Color.from_hsl(h, s, l, a)
  h = h % 360
  s = util.clamp(s, 0, 1)
  l = util.clamp(l, 0, 1)
  a = util.clamp(a or 1, 0, 1)
  local _a = s * math.min(l, 1 - l)

  local function f(n)
    local k = (n + h / 30) % 12
    return l - _a * math.max(math.min(k - 3, 9 - k, 1), -1)
  end

  return Color(f(0), f(8), f(4), a)
end

---Create a color from a hex number.
---@param c number|string Either a literal number or a css-style hex string (`#RRGGBB[AA]`).
---@return Color
function Color.from_hex(c)
  local n = c
  if type(c) == "string" then
    local s = c:lower():match("#?([a-f0-9]+)")
    n = tonumber(s, 16)
    if #s <= 6 then
      n = bit.lshift(n, 8) + 0xff
    end
  end

  assert(type(n) == "number", "must be a number")

  return Color(
    bit.rshift(n, 24) / 0xff,
    bit.band(bit.rshift(n, 16), 0xff) / 0xff,
    bit.band(bit.rshift(n, 8), 0xff) / 0xff,
    bit.band(n, 0xff) / 0xff
  )
end

---Returns a new shaded color.
---@param f number Amount. Float [-1,1].
---@return Color
function Color:shade(f)
  local t = f < 0 and 0 or 1.0
  local p = f < 0 and f * -1.0 or f

  return Color(
    (t - self.red) * p + self.red,
    (t - self.green) * p + self.green,
    (t - self.blue) * p + self.blue,
    self.alpha
  )
end

function Color.test_shade()
  print("-- SHADE TEST -- ")
  local c = Color.from_hex("#98c379")

  for i = 0, 10 do
    local f = (1 / 5) * i - 1
    print(string.format("%-8.1f%s", f, c:shade(f):to_css()))
  end
end

---Convert the color to HSV.
---@return HSV
function Color:to_hsv()
  local r = self.red
  local g = self.green
  local b = self.blue
  local max = math.max(r, g, b)
  local min = math.min(r, g, b)
  local delta = max - min
  local h = 0
  local s = 0
  local v = max

  if max == min then
    h = 0
  elseif max == r then
    h = 60 * ((g - b) / delta)
  elseif max == g then
    h = 60 * ((b - r) / delta + 2)
  elseif max == b then
    h = 60 * ((r - g) / delta + 4)
  end

  if h < 0 then
    h = h + 360
  end
  if max ~= 0 then
    s = (max - min) / max
  end

  return { hue = h, saturation = s, value = v }
end

---Convert the color to HSL.
---@return HSL
function Color:to_hsl()
  local r = self.red
  local g = self.green
  local b = self.blue
  local max = math.max(r, g, b)
  local min = math.min(r, g, b)
  local delta = max - min
  local h = 0
  local s = 0
  local l = (max + min) / 2

  if max == min then
    h = 0
  elseif max == r then
    h = 60 * ((g - b) / delta)
  elseif max == g then
    h = 60 * ((b - r) / delta + 2)
  elseif max == b then
    h = 60 * ((r - g) / delta + 4)
  end

  if h < 0 then
    h = h + 360
  end
  if max ~= 0 and min ~= 1 then
    s = (max - l) / math.min(l, 1 - l)
  end

  return { hue = h, saturation = s, lightness = l }
end

---Convert the color to a hex number representation (`0xRRGGBB[AA]`).
---@param with_alpha boolean|nil Include the alpha component.
---@return integer
function Color:to_hex(with_alpha)
  with_alpha = with_alpha or false

  local n = bit.bor(
    bit.bor((self.blue * 0xff), bit.lshift((self.green * 0xff), 8)),
    bit.lshift((self.red * 0xff), 16)
  )
  return with_alpha and bit.lshift(n, 8) + (self.alpha * 0xff) or n
end

---Convert the color to a css hex color (`#RRGGBB[AA]`).
---@param with_alpha boolean|nil Include the alpha component.
---@return string
function Color:to_css(with_alpha)
  local n = self:to_hex(with_alpha)
  local l = with_alpha and 8 or 6
  return string.format("#%0" .. l .. "x", n)
end

---@param v number Float [0,1].
function Color:set_red(v)
  self._red = util.clamp(v or 1.0, 0, 1)
  return self
end

---@param v number Float [0,1].
function Color:set_green(v)
  self._green = util.clamp(v or 1.0, 0, 1)
  return self
end

---@param v number Float [0,1].
function Color:set_blue(v)
  self._blue = util.clamp(v or 1.0, 0, 1)
  return self
end

---@param v number Float [0,1].
function Color:set_alpha(v)
  self._alpha = util.clamp(v or 1.0, 0, 1)
  return self
end

---@param v number Hue. Float [0,360).
function Color:set_hue(v)
  local hsv = self:to_hsv()
  hsv.hue = v % 360
  local c = Color.from_hsv(hsv.hue, hsv.saturation, hsv.value)
  self._red = c.red
  self._green = c.green
  self._blue = c.blue
  return self
end

---@param v number Float [0,1].
function Color:set_saturation(v)
  local hsv = self:to_hsv()
  hsv.saturation = util.clamp(v, 0, 1)
  local c = Color.from_hsv(hsv.hue, hsv.saturation, hsv.value)
  self._red = c.red
  self._green = c.green
  self._blue = c.blue
  return self
end

---@param v number Float [0,1].
function Color:set_value(v)
  local hsv = self:to_hsv()
  hsv.value = util.clamp(v, 0, 1)
  local c = Color.from_hsv(hsv.hue, hsv.saturation, hsv.value)
  self._red = c.red
  self._green = c.green
  self._blue = c.blue
  return self
end

---@param v number Float [0,1].
function Color:set_lightness(v)
  local hsl = self:to_hsl()
  hsl.lightness = util.clamp(v, 0, 1)
  local c = Color.from_hsl(hsl.hue, hsl.saturation, hsl.lightness)
  self._red = c.red
  self._green = c.green
  self._blue = c.blue
  return self
end

do
  local getters = {
    red = function(self)
      return self._red
    end,

    green = function(self)
      return self._green
    end,

    blue = function(self)
      return self._blue
    end,

    alpha = function(self)
      return self._alpha
    end,

    hue = function(self)
      return self:to_hsv().hue
    end,

    saturation = function(self)
      return self:to_hsv().saturation
    end,

    value = function(self)
      return self:to_hsv().value
    end,

    lightness = function(self)
      return self:to_hsl().lightness
    end,
  }

  local setters = {
    red = function(self, v)
      self:set_red(v)
    end,

    green = function(self, v)
      self:set_green(v)
    end,

    blue = function(self, v)
      self:set_blue(v)
    end,

    alpha = function(self, v)
      self:set_alpha(v)
    end,

    hue = function(self, v)
      self:set_hue(v)
    end,

    saturation = function(self, v)
      self:set_saturation(v)
    end,

    value = function(self, v)
      self:set_value(v)
    end,

    lightness = function(self, v)
      self:set_lightness(v)
    end,
  }

  function Color.__index(self, k)
    if getters[k] then
      return getters[k](self)
    end
    return Color[k]
  end

  function Color.__newindex(self, k, v)
    if setters[k] then
      setters[k](self, v)
    else
      rawset(self, k, v)
    end
  end

  local mt = getmetatable(Color)
  function mt.__call(_, ...)
    local this = setmetatable({}, Color)
    this:init(...)
    return this
  end
end

M.Color = Color

return M
