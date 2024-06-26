---------------------------------------------------
-- Xrandr Widget for Awesome Window Manager

-- @author Phil Estival
-- https://github.com/flintforge/awesome-wm-widgets
---------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local spawn = require("awful.spawn")
local naughty = require("naughty")
local gears = require("gears")
local beautiful = require("beautiful")

local HOME_DIR = os.getenv("HOME")
local WIDGETS_DIR = HOME_DIR .. '/.config/awesome/awesome-wm-widgets/'
local WIDGET_DIR = WIDGETS_DIR .. ''
local ICONS_DIR = WIDGETS_DIR ..'/icons/'
local ICON = 'video-display.svg'
local MONITORS =[[sh -c "xrandr | cut -d' ' -f1,2 | tail -n +2 |  sed -r '/^\s*$/d'"]]
local ACTIVE_MONITORS =[[sh -c "xrandr --listactivemonitors |tail -n+2 | cut -d' ' -f3 | sed 's/\+//'" ]]
local MARGINS = 4
local SPACINGS = 4
local HEIGHT = 15
local actives = {}

--- To show a warning messages
local function message(message)
	 naughty.notify{
			bg = "#CCCCCC",
			fg = "#000000",
			title = 'notice',
			text = message}
end

-- only left rotation
local function rotate_screen(output, rotate)
   spawn.easy_async("xrandr --output " .. output .. " --rotate " ..(rotate and "left" or "normal"))
end

local function turn_screen(output, on)
   spawn.easy_async("xrandr --output " .. output .. " " ..(on and "--auto" or "--off"))
end

function in_table ( t, e )
	 for _,v in pairs(t) do
			if (v==e) then return true end
	 end
	 return false
end

local wibox_popup = wibox {
	 ontop = true,
	 visible = false,
	 shape = gears.shape.rounded_rect,
	 border_width = 1,
	 border_color = beautiful.bg_focus,
	 max_widget_size = 500,
	 height = 100,
	 width = 150,
	 bg = "#666"
}

local xrandr_widget = wibox.widget {
	 {
			{
				 id = 'icon',
				 widget = wibox.widget.imagebox
			},
			margins = 4,
			layout = wibox.container.margin
	 },
	 layout = wibox.layout.fixed.horizontal,
	 set_icon = function(self, new_icon)
			self:get_children_by_id("icon")[1].image = new_icon
	 end
}

local function worker(user_args)

	 local args = user_args or {}
	 local icon = args.icon or ICONS_DIR .. ICON

	 xrandr_widget:set_icon(icon)

	 local pointer = 0
	 local min_widgets = 5
	 local carousel = false

	 local function rebuild_widget(containers, errors, _, _)

			if errors ~= '' then
				 message(errors)
				 return
			end

			local rows = wibox.layout.fixed.vertical()

			local i = 0

			n_actives= 0
			for li in active_monitors:gmatch("[^\r\n]+") do
				 actives[li] = true
				 n_actives = n_actives + 1
			end

			for line in containers:gmatch("[^\r\n]+") do
				 --for screen,state in containers:match("(.*)%s(.*)%s") do
				 local screen, state = line:match("(.*)%s(.*)")
				 if screen ~= nil and state == "connected"
				 then
						i = i + 1
						local row = wibox.widget {
							 { { { {
													 id							= 'checkbox',
													 checked				= actives[screen],
													 color					= beautiful.bg_normal,
													 paddings				= 2,
													 --shape					= gears.shape.rectangle,
													 check_color		=  n_actives> 1 and beautiful.fg_normal
															or beautiful.bg_urgent,
													 forced_width		= 15,
													 forced_height	= HEIGHT,
													 border_color		= n_actives> 1 and beautiful.border_focus
															or beautiful.bg_urgent,
													 border_width		= 1,
													 widget					= wibox.widget.checkbox
										 },
												valign						= 'center',
												layout						= wibox.container.place,
									 },
										 {  {
													 id = 'name',
													 markup = screen,
													 widget = wibox.widget.textbox
												},
												halign = 'left',
												layout = wibox.container.place
										 },
										 spacing = SPACING,
										 layout = wibox.layout.fixed.horizontal
								 },
									margins = MARGINS,
									layout = wibox.container.margin
							 },
							 id = 'row',
							 bg = beautiful.bg_normal,
							 widget = wibox.container.background,
							 activate_screen = function(self, checked,_,button)
									local a = self:get_children_by_id('checkbox')[1]
										 turn_screen(screen, not a.checked)
										 a:set_checked(not a.checked)
										 n = a.checked and -1 or 1
										 --if not a.checked
										 n_actives = n_actives + n
							 end,
							 screen_rotation = function(self, checked,_,button)
									local a = self:get_children_by_id('checkbox')[1]
									rotate_screen(screen, not(a.check_shape == gears.shape.losange))
									if not (a.check_shape == gears.shape.losange) then
										 a:set_check_shape(gears.shape.losange)
									else
										 a:set_check_shape(gears.shape.square)
									end
							 end,
						}

						row:connect_signal("mouse::enter", function(c)
																	c:set_bg(beautiful.bg_focus)
						end)
						row:connect_signal("mouse::leave", function(c)
																	c:set_bg(beautiful.bg_normal)
						end)

						row:connect_signal(
							 "button::press", function(c, _,_,button)
									if button==1 then
										 c:activate_screen()
									elseif button==3 then
										 c:screen_rotation()
									end
						end )

						rows:add(row)
				 end
			end

			wibox_popup:setup {
				 rows,
				 layout = wibox.layout.fixed.vertical,
			}

			wibox_popup.height = (  HEIGHT + MARGINS + SPACINGS) * (i)

	 end

	 xrandr_widget:buttons(
			awful.util.table.join(
				 awful.button({}, 1, function()
							 if wibox_popup.visible then
									wibox_popup.visible = not wibox_popup.visible
							 else

									spawn.easy_async(
										 ACTIVE_MONITORS,
										 function(out, err)
												active_monitors = out
												spawn.easy_async(
													 MONITORS,
													 function(stdout, stderr)
															rebuild_widget(stdout, stderr)
															wibox_popup.visible = true
															awful.placement.top(
																 wibox_popup,
																 { margins = { top = 20 },
																	 parent = mouse})
												end)
									end)
							 end
	 end) ) )

	 return xrandr_widget
end

return setmetatable(
   xrandr_widget,
   { __call = function(_, ...) return worker(...) end })
