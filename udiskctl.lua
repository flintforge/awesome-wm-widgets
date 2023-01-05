---------------------------------------------------
-- Usb disks controls for Awesome Window Manager

-- @author Phil Estival ©2021
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
local ICON = 'usb-tree.svg'

local status_cmd = "lsblk -Pmino name,label,mountpoint,size,state,vendor,model "
local usb_drives_cmd = 'for drive in $(lsblk -do name,tran | awk \'$2=="usb"{print $1}\'); do '..
   status_cmd..' /dev/$drive ; done'
-- using series of spawn_easy_async is too hairy without a queue
local poweroff_cmd = "udisksctl power-off -b "
local mount_cmd    = "udisksctl mount -b "
local unmount_cmd  = "udisksctl unmount -b "
local open_cmd     = "xdg-open "

local MARGINS = 4
local VSPACE = 4
local HEIGHT = 15

--- show warning messages
local function notify(message)
   naughty.notify{
      preset = naughty.config.presets.low,
      title = 'Error',
      text = message}
end

local function spawncmd(cmd)
   spawn.easy_async(
      cmd,
      function(stdout,stderr)
	 notify(stderr)
      end
   )
end

local function mount(part)
   spawncmd( mount_cmd.."/dev/"..part.name ) end

local function umount(part)
   spawncmd( unmount_cmd.."/dev/"..part.name ) end
local function poweroff(drive)
   notify("ok powering off")
   --spawn(power_off_cmd)
end

local function open(path)
   spawncmd( open_cmd..path ) end

local function confirm(text,next)
   -- I need to get a pure wibox confirmation dialog
   awful.prompt.run {
      prompt       = text.."(type 'y' to confirm)? ",
      textbox      = awful.screen.focused().mypromptbox.widget,
      exe_callback = function (t)
         if string.lower(t) == "y" then
            next()
         end
      end,
      -- completion_callback = function (t, p, n)
      --    return awful.completion.generic(t, p, n, {"no", "NO", "yes", "YES"})
      -- end
   }
end

function in_table ( t, e )
   for _,v in pairs(t) do
      if (v==e) then return true end
   end
   return false
end

local function ellipsize(text, length)
   return (text:len() > length and length > 0)
      and text:sub(0, length - 3) .. '...'
      or text
end


local wibox_popup = wibox {
   ontop = true,
   visible = false,
   shape = gears.shape.rounded_rect,
   --shape = function(cr, width, height)
   --   gears.shape.rounded_rect(cr, width, height, 4)
   --end,
   border_width = 1,
   border_color = beautiful.bg_focus,
   max_widget_size = 500,
   height = 100,
   width = 450,
   bg = "#555"
}

local udiskswidget = wibox.widget {
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


local function make_checkbox(partition, active, phy, drive)
   local shape
   local width
   if phy then -- physical drives dispay a rounded CB
      width = 15
      shape = gears.shape.rounded_bar
   else -- their partitions a square one
      witdh = 25
      shape = gears.shape.square
   end

   local cb = wibox.widget {
      widget        = wibox.widget.checkbox,
      checked       = active,
      id = 'checkbox',
      color         = beautiful.bg_normal,
      paddings      = 2,
      shape         = shape,
      check_color   = "#0A0", -- beautiful.fg_normal,
      forced_width  = width,
      forced_height = HEIGHT,
      border_color  = beautiful.border_focus,
      border_width  = 1,
      click = function(self, checked)

	 if phy and active
	 then
	    local poff = function()
	       poweroff(d)
	       self:set_checked(not self.checked)
	    end
	    confirm("unmount paritions and power off drive ? ", poff)
	    -- then refresh display / rebuild widget ?
	 else
	    if drive
	    then
	       if active
	       then
		  print("unmount"..partition.mountpoint)
		  umount(partition)
		  self:set_checked(not self.checked)
		  --worker() TODO : refresh state
	       else
		  print("mount "..partition.name)
		  mount(partition)
		  self:set_checked(not self.checked)
	       end
	    end
	 end
      end
   }

   cb:connect_signal(
      "button::press", function(c, _, _, button)
	 if button == 1 then c:click() end end)
   return cb
end


local function make_path(partition)
   local path = wibox.widget {
      widget = wibox.widget.textbox,
      text = partition.mountpoint,
      forced_width = 10,
      click = function(self)
	 if (not(partition.mountpoint=="")) then
	    open(partition.mountpoint)
	 end
      end
   }

   path:connect_signal(
      "button::press", function(c, _, _, button)
	 if button == 1 then c:click() end end)
   return path
end

local function makerow(partition, active, phy, drive)
   return wibox.widget
      {
	 make_checkbox(partition,active,phy, drive),
	 {
	    text = partition.name,
	    forced_width = 10,
	    widget = wibox.widget.textbox
	 },
	 {
	    text = partition.label,
	    forced_width = 10,
	    widget = wibox.widget.textbox
	 },
	 make_path(partition),
	 layout = wibox.layout.ratio.horizontal
      }
end

function values(t)
   local i = 0
   return function() i = i + 1; return t[i] end
end


function lpad(str, len, char)
    if char == nil then char = ' ' end
    return str .. string.rep(char, len - #str)
end


local function worker(user_args)

   local args = user_args or {}
   local icon = args.icon or ICONS_DIR..ICON

   local min_widgets = 5
   local carousel = false

   udiskswidget:set_icon(icon)

   spawn.easy_async_with_shell(
      usb_drives_cmd,
      function(stdout, stderr)
	 -- todo: make it an other if there's no disk to mount or poweroff (black)
	 drives=stdout
	 notify(drives)
	 --udiskswidget:set_icon(icon_cold)
	 --udiskswidget:set_icon(icon_error)
      end
   )

   local n=0

   local function partitions(dr)
      local drives= {}
      local match = 'NAME="(.*)" '
	 ..'LABEL="(.*)" MOUNTPOINT="(.*)" '
	 ..'SIZE="(.*)" STATE="(.*)" '
	 ..'VENDOR="(.*)" MODEL="(.*)"'

      n=0
      print(dr)
      for li in dr:gmatch("[^\r\n]+") do
	 --print(li)
	 local name,label,mountpoint,size,state,vendor,model = li:match(match)
	 --print(name,label,mountpoint)
	 drives[n] = {name=name, label=label, mountpoint=mountpoint,
		      size=size, state=state, vendor=vendor, model=model}
	 --print(drives[i].name)
	 n = n+1
      end
      return drives
   end


   local function rebuild_widget(ddrives, errors, _, _)

      -- notify(ddrives)
      if errors ~= '' then
	 notify(errors)
	 return
      end

--       confirmQuitmenu = awful.menu(
-- 	 { items = {
-- 	      { "Cancel", function() do end end },
      -- 	      { "Quit", function() awesome.quit() end }}}
      -- ..
--     awful.key({ modkey, "Shift"   }, "q", function () confirmQuitmenu:show() end,
--               {description = "Confirm Awesome wm exit", group = "awesome"}),

      local rows = wibox.layout.fixed.vertical()


      if ddrives == '' then
	 local row = wibox.widget {
	    {{
		  id = 'name',
		  markup = "no drive connected",
		  widget = wibox.widget.textbox
	     },
	       halign = 'left',
	       layout = wibox.container.place
	 }}
	 rows:add(row)

      else
	 local drives = partitions(ddrives)
	 for i=0,n-1 do
	    local parts = drives[i]
	    -- print(parts.name)
	    -- print(parts.state)
	    -- print(parts.mountpoint)
	    -- print("---")
    	    -- print(not(parts.mountpoint==""))
	    -- print(not(parts.vendor==""))
	    -- print("----")

	    local active = false
	    local phy = false
	    local drive = false
	    if (not(parts.vendor=="")) then -- a physical drive
	       phy = true
	       active = parts.state=="running"
	       label = lpad(parts.name, 5)..'\t'.. parts.label..'\t'
		  ..parts.vendor.." ".. parts.model.. parts.size
	    else
	       drive = true
	       active = not(parts.mountpoint=="")
	       label = lpad(parts.name, 5)..' '.. parts.label..'\t'..parts.mountpoint
	    end


	       -- id = 'row',
	       -- bg = beautiful.bg_normal,
	       -- halign='left',
	       -- widget = wibox.container.background,

	    local row=makerow(parts,active,phy,drive)
	    row:ajust_ratio(2, 0.1, 0.2, 0.7)

	    local line = wibox.widget(
	    {
	       row,
	       id = 'row',
	       bg = beautiful.bg_normal,
	       halign='left',
	       widget = wibox.container.background,
	    })
	    line:connect_signal(
	       "mouse::enter", function(c) c:set_bg(beautiful.bg_focus) end)
	    line:connect_signal(
	       "mouse::leave", function(c) c:set_bg(beautiful.bg_normal) end)
	    -- row:connect_signal(
	    --    "button::press", function(c, _, _, button)
	    -- 	  if button == 1 then c:click() end end)
	    rows:add(line)
	 end
      end

      wibox_popup:setup {
	 rows,
	 margins = 30,
	 layout = wibox.layout.fixed.vertical,
	 padding = 10,
	 border_width = 10,
      }
      wibox_popup.height = (  HEIGHT + MARGINS + VSPACE +1 ) * (n-1)
   end


   udiskswidget:buttons(
      awful.util.table.join(
	 awful.button({}, 1, function()
	       if wibox_popup.visible then
		  wibox_popup.visible = not wibox_popup.visible
	       else
		  spawn.easy_async_with_shell(
		     usb_drives_cmd,
		     function(stdout, stderr)
			rebuild_widget(stdout or ' ', stderr or ' ')
			wibox_popup.visible = true
			awful.placement.top(
			   wibox_popup,
			   { margins = { top = 20 },
			     parent = mouse})
		  end)
	       end
   end) ) )

   return udiskswidget
end

return setmetatable(
   udiskswidget,
   { __call = function(_, ...) return worker(...) end })
