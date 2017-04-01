--[[
Minetest Mod Storage Drawers - A Mod adding storage drawers

Copyright (C) 2017 LNJ <git@lnj.li>

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

core.register_entity("drawers:visual", {
	initial_properties = {
		hp_max = 1,
		physical = false,
		collide_with_objects = false,
		collisionbox = {-0.4374, -0.4374, 0,  0.4374, 0.4374, 0}, -- for param2 0, 2
		visual = "upright_sprite", -- "wielditem" for items without inv img?
		visual_size = {x = 0.6, y = 0.6},
		textures = {"drawers_empty.png"},
		spritediv = {x = 1, y = 1},
		initial_sprite_basepos = {x = 0, y = 0},
		is_visible = true,
	},

	get_staticdata = function(self)
		return core.serialize({
			drawer_posx = self.drawer_pos.x,
			drawer_posy = self.drawer_pos.y,
			drawer_posz = self.drawer_pos.z,
			texture = self.texture
		})
	end,

	on_activate = function(self, staticdata, dtime_s)
		-- Restore data
		data = core.deserialize(staticdata)
		if data then
			self.drawer_pos = {
				x = data.drawer_posx,
				y = data.drawer_posy,
				z = data.drawer_posz,
			}
			self.texture = data.texture
		else
			self.drawer_pos = drawers.last_drawer_pos
			self.texture = drawers.last_texture or "drawers_empty.png"
		end


		local node = core.get_node(self.drawer_pos)

		-- collisionbox
		local colbox = {-0.4374, -0.4374, 0,  0.4374, 0.4374, 0} -- for param2 = 0 or 2
		if node.param2 == 1 or node.param2 == 3 then
			colbox = {0, -0.4374, -0.4374,  0, 0.4374, 0.4374}
		end


		-- infotext
		local meta = core.get_meta(self.drawer_pos)
		local infotext = meta:get_string("entity_infotext") .. "\n\n\n\n\n"

		self.object:set_properties({
			collisionbox = colbox,
			infotext = infotext,
			textures = {self.texture}
		})

		-- make entity undestroyable
		self.object:set_armor_groups({immortal = 1})
	end,

	on_rightclick = function(self, clicker)
		local node = core.get_node(self.drawer_pos)
		local itemstack = clicker:get_wielded_item()
		local add_count = itemstack:get_count()
		local add_name = itemstack:get_name()

		local meta = core.get_meta(self.drawer_pos)
		local name = meta:get_string("name")
		local count = meta:get_int("count")
		local max_count = meta:get_int("max_count")

		local base_stack_max = meta:get_int("base_stack_max")
		local stack_max_factor = meta:get_int("stack_max_factor")

		-- if nothing to be added, return
		if add_count <= 0 then return end
		-- if no itemstring, return
		if item_name == "" then return end

		-- only add one, if player holding sneak key
		if clicker:get_player_control().sneak then
			add_count = 1
		end

		-- if current itemstring is not empty
		if name ~= "" then
			-- check if same item
			if add_name ~= name then return end
		else -- is empty
			name = add_name
			count = 0

			-- get new stack max
			base_stack_max = ItemStack(name):get_stack_max()
			max_count = base_stack_max * stack_max_factor

			-- Don't add items stackable only to 1
			if base_stack_max == 1 then
				return
			end

			meta:set_string("name", name)
			meta:set_int("base_stack_max", base_stack_max)
			meta:set_int("max_count", max_count)
		end

		-- set new counts:
		-- if new count is more than max_count
		if (count + add_count) > max_count then
			count = max_count
			itemstack:set_count((count + add_count) - max_count)
		else -- new count fits
			count = count + add_count
			itemstack:set_count(itemstack:get_count() - add_count)
		end
		-- set new drawer count
		meta:set_int("count", count)

		-- update infotext
		local infotext = drawers.gen_info_text(core.registered_items[name].description,
			count, stack_max_factor, base_stack_max)
		meta:set_string("entity_infotext", infotext)

		-- texture
		self.texture = drawers.get_inv_image(name)

		self.object:set_properties({
			infotext = infotext .. "\n\n\n\n\n",
			textures = {self.texture}
		})

		clicker:set_wielded_item(itemstack)
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		local meta = core.get_meta(self.drawer_pos)
		local count = meta:get_int("count")

		if count <= 0 then
			return
		end
		local name = meta:get_string("name")

		local remove_count = 1
		if not puncher:get_player_control().sneak then
			remove_count = ItemStack(name):get_stack_max()
		end
		if remove_count > count then remove_count = count end

		local stack = ItemStack(name)
		stack:set_count(remove_count)

		local inv = puncher:get_inventory()
		if not inv:room_for_item("main", stack) then
			return
		end

		inv:add_item("main", stack)
		count = count - remove_count
		meta:set_int("count", count)

		-- update infotext
		local stack_max_factor = meta:get_int("stack_max_factor")
		local base_stack_max = meta:get_int("base_stack_max")
		local item_description = ""
		if core.registered_items[name] then
			item_description = core.registered_items[name].description
		end

		if count <= 0 then
			meta:set_string("name", "")
			self.texture = "drawers_empty.png"
			item_description = "Empty"
		end

		local infotext = drawers.gen_info_text(item_description,
			count, stack_max_factor, base_stack_max)
		meta:set_string("entity_infotext", infotext)

		self.object:set_properties({
			infotext = infotext .. "\n\n\n\n\n",
			textures = {self.texture}
		})
	end
})

core.register_lbm({
	name = "drawers:restore_visual",
	nodenames = {"group:drawer"},
	run_at_every_load = true,
	action  = function(pos, node)
		local objs = core.get_objects_inside_radius(pos, 0.5)
		if objs then
			for _, obj in pairs(objs) do
				if obj and obj:get_luaentity() and
						obj:get_luaentity().name == "drawers:visual" then
					return
				end
			end
		end

		-- no visual found, create a new one
		drawers.spawn_visual(pos)
	end
})