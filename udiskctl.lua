-------------------------------------------------
-- Usb disks control for Awesome Window Manager

-- @author Phil Estival pe [@t] 7d.nz
-- https://github.com/flintforge/awesome-wm-widgets

-- handles powering drives
-- requires udisksctl
----------------------------------------------------

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

local DRIVES = "for drives in $(lsblk -do name,tran | awk '$2==\"usb\"{print $1}'); do  lsblk /dev/$drives -o name,mountpoint | awk 'NR!=1' ; done"
---> sdb1/WDntfs
local poweroff="udisksctl power-off -b "
local MARGINS = 4
local SPACINGS = 4
local HEIGHT = 15

-- local DISKS = [[ sh -c "lsblk -o name,mountpoint | /bin/grep media |tr -d '  ' | cut -d '/' -f1,4 | sed -e 's/├─//'" ]]
-- local USBDEV = "lsblk -do name,tran | awk '$2==\"usb\"{print $1}'"
-- local function get_drives (dev, callback)
--    spawn.easy_async_with_shell(
--       "lsblk /dev/" .. dev .." -o name,mountpoint | awk 'NR!=1'",
--       callback)
-- end


--- Utility function to show warning messages
local function show_warning(message)
   naughty.notify{
      preset = naughty.config.presets.critical,
      title = 'Error',
      text = message}
end

local function mount(part)
   show_warning(part)
   spawn.easy_async("mount /dev/" .. part,
		    function(stdout,stderr)
		       show_warning(stderr)
		    end
   )
end
local function umount(part)
   spawn.easy_async_with_shell( "umount /dev/" .. part,
				function(stdout,stderr)
				   show_warning(stderr)
                                end
   )				  
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
   width = 250,
   bg = "#666"
   --beautiful.bg_normal
   -- opacity = 1,
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


local function makebox(label,checked, click)
   return wibox.widget {
      {{
	    { {
		  id = 'checkbox',
		  checked       = checked, --mtpt and true or false,--actives[screen],
		  color         = beautiful.bg_normal,
		  paddings      = 2,
		  shape         = gears.shape.square,
		  check_color   = beautiful.fg_normal,
		  forced_width  = 15,
		  forced_height = HEIGHT,
		  border_color  = beautiful.border_focus,
		  border_width  = 1,
		  widget        = wibox.widget.checkbox
	      },
	       valign = 'center',
	       layout = wibox.container.place,
	    },
	    spacing = SPACING,
	    {  {
		  id = 'name',
		  --markup = '<b>' .. package['name'] .. '</b>',
		  markup = label, -- mtpt and disk .. "/" .. mtpt or disk,
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
      click = click      
   }
end


local function worker(user_args)

   local args = user_args or {}
   local icon = args.icon or ICONS_DIR .. ICON
   -- todo: make it an other if there's no disk to mount or poweroff (black)

   udiskswidget:set_icon(icon)

   local min_widgets = 5
   local carousel = false
   
   local function rebuild_widget(ddrives, errors, _, _)
      
      if errors ~= '' then
	 show_warning(errors)
	 return
      end
      
      local rows = wibox.layout.fixed.vertical()
      local i=0
      
      -- {disk = d, parts = {}}     
      local parts={}
      local drives = {}
      local disk
      for line in ddrives:gmatch("[^\r\n]+") do
	 --local disk, mtpt = line:match("(.*)/(.*)")1
	 print(line)
	 local part,mtpt = line:match("├─(.*)%s(.*)") 
	 if part == nil
	 then --attemp 2 (lua has no multistring match)
	    part,mtpt = line:match("└─(.*)%s(.*)") 
	 end
	 
	 if part == nil
	 then
	    drives[line] = {}
	    disk = line
	 else 
	    print(part, mtpt)
	    table.insert(drives[disk], {part=part, mtpt=mtpt})
	 end
      end

      print("[",ddrives,"]")
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
      end
      
      for d,parts in pairs(drives) do
	 
	 local row = makebox(
	    d, true, -- poweredoff disk would be undetected
	    function(self, checked)
	       local a = self:get_children_by_id('checkbox')[1]
	       -- turn_screen(screen, not a.checked)
	       a:set_checked(not a.checked)
	       --n = a.checked and -1 or 1
	       if parts
	       then 
		  if not a.checked
		  then
		     poweroff(d)
		  else
		     mount(d)
		  end
	       end
	       --n_actives = n_actives + n
	       --show_warning( "".. n_actives )
	 end)
	 
	 row:connect_signal("mouse::enter", function(c)
			       c:set_bg(beautiful.bg_focus)
	 end)
	 row:connect_signal("mouse::leave", function(c)
			       c:set_bg(beautiful.bg_normal)
	 end)		  
	 row:connect_signal("button::press", function(c, _, _, button)
			       if button == 1 then c:click() end
	 end)
	 rows:add(row)
	 i = i+1

	 --show_warning(d)
	 for k,part in ipairs(parts) do
	    print(" ".. part.part .. " : " .. (part.mtpt or '') )
	    local row = makebox(
	       "   " .. part.part .. " ", part.mtpt,
	       function(self, checked)
		  local a = self:get_children_by_id('checkbox')[1]
		  -- turn_screen(screen, not a.checked)
		  a:set_checked(not a.checked)
		  --n = a.checked and -1 or 1
		  if not a.checked
		  then
		     umount(part.part)
		  else
		     mount(part.part)
		  end
		  --n_actives = n_actives + n
		  --show_warning( "".. n_actives )
	    end)
	    
	    row:connect_signal("mouse::enter", function(c)
				  c:set_bg(beautiful.bg_focus)
	    end)
	    row:connect_signal("mouse::leave", function(c)
				  c:set_bg(beautiful.bg_normal)
	    end)		  
	    row:connect_signal("button::press", function(c, _, _, button)
				  if button == 1 then c:click() end
	    end)
	    rows:add(row)
	    i = i+1
	 end
	 
      end

      
      wibox_popup:setup {
	 rows,
	 layout = wibox.layout.fixed.vertical,
      }
      
      wibox_popup.height = (  HEIGHT + MARGINS + SPACINGS) * (i)
      
   end

   udiskswidget:buttons(
      awful.util.table.join(
	 awful.button({}, 1, function()
	       if wibox_popup.visible then
		  wibox_popup.visible = not wibox_popup.visible
	       else
		  spawn.easy_async_with_shell(
		     DRIVES,
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
