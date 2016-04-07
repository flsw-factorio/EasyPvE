require( "defines" )

local function player( idx )
	return game.players[ idx ]
end

-------------------------------
-- Tables to keep track of data
-------------------------------
local gui_prefix = "easypve_"
local open_menu, menu_button, update_gui

local hide_enemy_force = true
local hide_neutral_force = true
-------------------------------
-- Helper functions
-------------------------------

local function get_main_menu( ply )
	return ply.gui.left[gui_prefix .. "main_menu_base"]
end

local function get_force_checkboxes( ply )
	local main_menu = get_main_menu( ply )

	if main_menu and main_menu.valid then
		local checkboxes = {}
		local flow = main_menu[gui_prefix .. "join_force_flow"]

		for force_name,force in pairs( game.forces ) do
			if hide_enemy_force and force_name == "enemy" then
				-- do nothing
			elseif hide_neutral_force and force_name == "neutral" then
				-- do nothing
			else
				local checkbox_container = flow[gui_prefix .. "forcelist_flow_" .. force_name]
				local checkbox = checkbox_container[gui_prefix .. "forcelist_checkbox_" .. force_name]

				checkboxes[#checkboxes+1] = checkbox
			end
		end

		return checkboxes
	end

	return {}
end

local function print_all( text )
	for k,v in pairs( game.players ) do
		v.print( text )
	end
end

local function get_force_by_name( name )
	for k,v in pairs( game.forces ) do
		if v.name == name then
			return v
		end
	end
end

local function get_selected_force( ply )
	for k,v in pairs( get_force_checkboxes( ply ) ) do
		if v and v.valid and v.state == true then
			return get_force_by_name( v.caption )
		end
	end
end


-------------------------------
-- Button callbacks
-------------------------------
local function new_force( ply, event )
	local main_menu = get_main_menu( ply )
	local text = main_menu[gui_prefix .. "new_force_flow"][gui_prefix .. "new_force_text"].text
	if text == "" then
		ply.print( "Can't create a force with no name!" )
		return
	end

	if game.forces[text] then
		ply.print( "A force with that name already exists!" )
		return
	end

	print_all( "New force '" .. text .. "' created by player '" .. ply.name .. "'." )

	ply.force = game.create_force( text )
	-- Enforce Peace
	for name, force in pairs(game.forces) do
		if name ~= 'enemy' and name ~= 'neutral' and name ~= text then
			game.player.print("Setting ceasefire between " .. name .. " and " .. ply.force.name )
			force.set_cease_fire(ply.force.name, true)
		end
	end
	update_gui()
end


local function join_force( ply, event )
	local selected_force = get_selected_force( ply )

	if selected_force then
		ply.force = selected_force
		update_gui()
		print_all( "Player '" .. ply.name .. "' joined force '" .. selected_force.name .. "'." )
		return
	end

	ply.print( "Unable to find selected force! Perhaps it was deleted?" )
end

local first_selected_force = {}
local merge_note
local function select_force( ply, event )
	local first_selected = first_selected_force[ply.index]
	if first_selected ~= nil then
		local selected = get_force_by_name( event.element.caption )

		local forcename = first_selected.name

		if selected.name == forcename then
			ply.print( "You can't select the same force! Try again." )
			return
		end

		game.merge_forces( first_selected.name, selected.name )
		if merge_note.valid then merge_note.destroy() end

		for k,v in pairs( get_force_checkboxes( ply ) ) do
			if v and v.valid then
				v.state = (v.caption == forcename)
			end
		end

		first_selected_force[ply.index] = nil
		update_gui()

		print_all( "Force '" .. forcename .. "' was merged into '" .. forcename .."'." )
	else
		for k,v in pairs( get_force_checkboxes( ply ) ) do
			if v and v.valid and v ~= event.element then
				v.state = false
			end
		end
	end
end

local function cancel_merge( ply, event )
	first_selected_force[ply.index] = nil
	if merge_note.valid then merge_note.destroy() end
end

local function merge_force( ply, event )
	local selected_force = get_selected_force( ply )
	if selected_force.name == "enemy" or
		selected_force.name == "neutral" or
		selected_force.name == "player" then
		ply.print( "You can't merge one of the default forces!" )
		return
	end

	first_selected_force[ply.index] = selected_force

	merge_note = ply.gui.center.add({
		type = "label",
		caption = "Select another force to merge this force into. Click here to cancel.",
		name = gui_prefix .. "mergeforce_info",
	})
end

-------------------------------
-- Update gui
-------------------------------
function update_gui()
	for k,v in pairs( game.players ) do
		local menu = get_main_menu( v )
		if menu and menu.valid then
			local force_table = menu[gui_prefix .. "join_force_flow"]
			if force_table and force_table.valid then
				for _,name in pairs( force_table.children_names ) do
					force_table[name].destroy()
				end

				local current_force_name = v.force.name
				for force_name,force in pairs( game.forces ) do
					if hide_enemy_force and force_name == "enemy" then
						-- do nothing
					elseif hide_neutral_force and force_name == "neutral" then
						-- do nothing
					else

						local flow = force_table.add({
							type = "flow",
							direction = "horizontal",
							name = gui_prefix .. "forcelist_flow_" .. force_name
						})

						local checkbox = flow.add({
							type="checkbox",
							caption=force_name,
							state=(force_name == current_force_name),
							name = gui_prefix .. "forcelist_checkbox_" .. force_name
						})

						local playernames = {}
						for _,ply in pairs( force.players ) do
							playernames[#playernames+1] = ply.name
						end

						flow.add({
							type = "label",
							caption = "   " .. table.concat( playernames, ", " ),
							name = gui_prefix .. "forcelist_player_names_" .. force_name
						})
					end
				end
			end
		end
	end
end

-------------------------------
-- Main menu
-------------------------------

-- menu creation
function open_menu( ply )
	local frame = ply.gui.left.add({
		type = "frame",
		caption = "EasyPvE",
		direction = "vertical",
		name = gui_prefix .. "main_menu_base"
	})

	-- New force
	local new_force_flow = frame.add({
		type = "flow",
		direction = "horizontal",
		name = gui_prefix .. "new_force_flow"
	})
	local new_force_text = new_force_flow.add({
		type = "textfield",
		name = gui_prefix .. "new_force_text"
	})
	new_force_flow.add({
		type = "button",
		caption = "New force",
		name = gui_prefix .. "new_force_button",
	})

	-- Join force
	frame.add({
		type = "label",
		caption = "Join force:                                                                       ",
		name = gui_prefix .. "join_force_label"
	})

	local tab = frame.add({
		type = "flow",
		direction = "vertical",
		name = gui_prefix .. "join_force_flow",
	})

	-- divider
	frame.add({
		type = "label",
		caption = "                                                                                 ",
		name = gui_prefix .. "divider1",
	})

	-- Join / delete buttons
	local horizontal_frame = frame.add({
		type = "flow",
		direction = "horizontal",
		name = gui_prefix .. "horizontal_frame",
	})

	horizontal_frame.add({
		type = "button",
		caption = "Join",
		name = gui_prefix .. "join_force_button",
	})

	horizontal_frame.add({
		type = "button",
		caption = "Merge",
		name = gui_prefix .. "merge_force_button",
	})

	update_gui()
end


-- open menu button

local function open_menu_callback( ply, event )
	if event.element.caption == "EasyPvE" then
		event.element.caption = "Close"
		open_menu( ply )
	else
		event.element.caption = "EasyPvE"

		local main_menu = get_main_menu( ply )

		if main_menu and main_menu.valid then
			main_menu.destroy()
		end
	end
end

function menu_button( ply )
	ply.gui.left.add({
		type = "button",
		caption = "EasyPvE",
		name = "easypve_open_menu_button"
	})
end

-------------------------------
-- Events
-------------------------------

script.on_event( defines.events.on_player_created, function( event )
	local ply = player( event.player_index )

	menu_button( ply )
end)

local gui_element_callbacks = {
	mergeforce_info = cancel_merge,
	forcelist_checkbox = select_force,
	new_force_button = new_force,
	join_force_button = join_force,
	merge_force_button = merge_force,
	open_menu_button = open_menu_callback,
}


-- Handle callbacks
script.on_event(defines.events.on_gui_click,function(event)
	local ply = player( event.player_index )
	local element_name = event.element.name

	local callback
	for k,v in pairs( gui_element_callbacks ) do
		if string.find( element_name, k ) then
			v( ply, event )
			break
		end
	end
end)

remote.add_interface("pvp", {
init = function(player) menu_button(player) end
})
