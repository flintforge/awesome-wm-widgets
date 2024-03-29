-----------------------------------------------------
-- Sct Widget for Awesome Window Manager
-- [2021-02-25 Thu]
-- @author: Phil Estival (pe [@t] 7d.nz)
-- https://github.com/flintforge/awesome-wm-widgets

-- - Set screen color temperature.
-- - Requires sct.
-- - Mouse wheel (or left and right mouse clicks)
--   to adjust the temperature,
--   middle click recalls the defaut value at 6500K

-----------------------------------------------------

local awful = require("awful")
local spawn = require("awful.spawn")
local wibox = require("wibox")

local function worker(...)

   local arg = {n=select('#',...),...}
   local default_temp = arg[1]
   if (default_temp == nil) then
      default_temp = 6400
   end
   local temperature = default_temp -- kelvins

   local text = wibox.widget {
      id = "txt",
      font   = "Inconsolata Medium 13",
      widget = wibox.widget.textbox
   }

   local sct = wibox.widget {
      forced_height = 32,
      forced_width = 44,
      bg = "#000",
      paddings = 0,
      widget = wibox.widget.textbox,
   }

   local function get_temperature()
      sct.markup = string.format(" <b>%.1fK</b>",temperature/1000)
   end

   get_temperature()

   local update_graphic = function(widget, stdout, _, _, _)
      widget.colors = { colors.B }
   end

   local function updateTemperature(tpr)
      temperature = temperature + tpr
      if(temperature<1000) then temperature = 1000 end
      if(temperature>10000) then temperature = 10000 end
      awful.spawn("sct " .. temperature,false)
      get_temperature()
   end

   local function defaultTemperature()
      temperature = default_temp
      awful.spawn("sct", false)
      get_temperature()
   end

   local function setTemperature(t)
      temperature = t
      awful.spawn("sct", false)
      get_temperature()
   end

   sct:connect_signal(
      "button::press",
      function(_, _, _, button)
         if (button == 3 or button==5) then
            updateTemperature( -500 )
         elseif (button == 1 or button==4) then
            updateTemperature(  500 )
         elseif (button == 2) then
            defaultTemperature()
         end
   end)

   local Sct = {
      widget = sct,
      update = updateTemperature,
      set = setTemperature,
      defaultTemperature = defaultTemperature
   }
   return Sct
end

local sct_widget = {}
return setmetatable(
   sct_widget, {
      __call = function(_, ...) return worker(...) end
               }
)
