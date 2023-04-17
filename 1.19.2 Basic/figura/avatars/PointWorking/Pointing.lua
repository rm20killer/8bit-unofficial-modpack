--[[

# Pointing.lua
by Tanner Limes

This script lets your avatar point at blocks and entities in the world. If you
point at a player that is also pointing at you, you will instead hold hands.

## Setup

tldr: 
- Duplicate your avatar's arms in Blockbench and put each into a new group.
- Configure the `limbs` table below with the names of your pointing arm groups.
- Also add the names of the groups you want to hide when you're pointing.
- Add the example action (at the bottom of this readme) to your action wheel. 

### Blockbench Setup:
This script works by hiding your normal arms and controlling separate pointing
arms. Because of this you'll need to duplicate your current arms in Blockbench
and put them into a new group that this script can take control of.  

For example: the vanilla avatar has this structure:
```
> Head
v Body
  - Body
  - Jacket
v RightArm
  - RightArm
  - RightSleeve
> LeftArm
> RightLeg
> LeftLeg
```

You will need to create this structure:
```
> Head
v Body
  v PointingRightArm    <-- 
    - RightArm
    - RightSleeve
  > PointingLeftArm     <--
  - Body
  - Jacket
v RightArm
  - RightArm
  - RightSleeve
> LeftArm
> RightLeg
> LeftLeg
```

Here's some extra notes
- Put your PointingArm groups inside the Body group so that they move when you
  crouch, swim, or sit.
- Set up pointing groups for your left and right arms. This script will point 
  with the arm that is closest to the target.
- The script assumes that the arm model points downwards like the vanilla model.
  if your character is in a t-pose it won't work correctly
- Make sure to adjust the pivot point of the pointing arm. The vanilla model
  rotates a little funny by default, but it's a bit cleaner if you _move the
  pivot point from x=5 to x=6_. (the middle of the arm)
- Set the visibility of the Pointing groups to "false" in Blockbench. This way, 
  if the lua script fails, only the real arms should™ be visible.



### `limbs` Table Setup:
Once you've prepared the model, you'll need to configure the `limbs` table.
The `limbs` table is a list of tables. Each of these internal tables 
represents a limb that the script can point with. There are 3 fields:

- `pointing_limb` is the modelPart that this script can control freely. This 
  script will control this part's rotation and visibility.
  - you can't list multiple modelParts for `pointing_limb`. If your arm has 
    more than one part, make sure to put them all into one group and use that. 

- `limbs_to_hide` is a list of limbs that will be hidden when the
  avatar is pointing with `pointing_limb`. These can be modelParts or 
  VanillaModelParts
  - This list can also be empty if you want to manually control the visibility 
    of the "real" limbs elsewhere. A limb is pointing if limb.point_target is
    not nil. `get_busy_hands()` and `get_free_hands()` will return a lists of
    limbs that are or are not pointing right now. (though not directly. They
    wrap the limb in another table to keep track of its index in the limbs 
    table. Use `get_busy_hands()[YourIndex].limb.pointing_limb` to get the
    model part of the limbs that currently have targets. 

- `length` is the distance from the pivot point and the end of the arm in 
  meters. This number is used when trying to hold the hand of another avatar. 
  - Note: that __`length` is measured in meters__, but by default, Blockbench 
    uses pixels. To convert from BB pixels to meters, divide BB's units by 16.
  - On the default vanilla avatar, `length` is about _0.610_. The right arm is
    12 pixels tall, and 12 pixels off the ground. The arm's pivot point is 22 
    pixels off the ground. So the length from the pivot point to the bottom of
    the arm is 10 pixels. divide by 16 to get 0.6_25_ meters. Drop this down to
    0.610 to fake the position of the palm. 

note: the first limb of this table will be preferred. If you're avatar is left 
handed, put the left arm first. 

Example limbs table setup:

```lua
local model = models["MyAvatarModelFileName"]
local limbs = {
	{
		["pointing_limb"] = model.Body.PointingArmRight,
		["limbs_to_hide"] = {
			model.RightArm, 
			vanilla_model.RIGHT_ARM, 
			vanilla_model.RIGHT_SLEEVE,
			vanilla_model.RIGHT_ITEM
		}, 
		["length"] = 0.610
	},{
		["pointing_limb"] = model.Body.PointingArmLeft,
		["limbs_to_hide"] = {
			model.LeftArm, 
			vanilla_model.LEFT_ARM, 
			vanilla_model.LEFT_SLEEVE,
			vanilla_model.LEFT_ITEM
		}, 
		["length"] = 0.610
	}
}
```

### Action Wheel Setup
Once the model and the script are configured, you'll need to add an action to
your Action Wheel. 

The important functions are 
- `add_point_target`. Which adds whatever the avatar is looking at to a list of 
  point targets. (Entities take priority over blocks. Range of 20 meters.)
- `stop_pointing`: Clears the point targets list and stops pointing.

However, in order for other users to know your avatar started to point at 
something, you'll need to wrap these functions inside ping functions.

If you don't already have an action wheel, Here's a sample one to get you 
started. Create a file called `Action Wheel.lua` in your avatar folder and 
copy this code block into it: 

```lua
-- ping functions
function pings.add_point_target_ping()
	add_point_target()
	pointing_action:toggled(true)
end

function pings.stop_pointing_ping()
	stop_pointing()
	pointing_action:toggled(false)
end

-- Building the action
pointing_action = action_wheel:newAction()
	:title("Point")
	:toggleTitle("Stop Pointing\nRight click to point more than once.")
	:item("minecraft:spyglass")
	:onToggle(pings.add_point_target_ping)
	:onUntoggle(pings.stop_pointing_ping)
	:onRightClick(pings.add_point_target_ping)

-- Create action wheel page. Skip if you've already got one. 
-- Just be sure to add pointing_action to your wheel 
my_action_wheel_page = action_wheel:newPage()
action_wheel:setPage(my_action_wheel_page)

my_action_wheel_page:setAction(-1, pointing_action)


-- add_point_target now supports special cases. Currently it only recognizes
-- "ahead", but this script can be modded in the future with more cases.
function pings.point_ahead_ping()
	add_point_target("ahead")
	pointing_action:toggled(true)
end

point_ahead_action = action_wheel:newAction()
	:title("Point Ahead")
	:item("minecraft:spyglass")
	:onLeftClick(pings.point_ahead)
my_action_wheel_page:setAction(-1, point_ahead_action)

``` 

One more thing: Because add_point_target() works on where the clients think 
your avatar is, and not where _you_ think the avatar is, there's a chance that
what your avatar is pointing at gets de-synchronized with other players. To fix 
this, just clear your point targets and point again. This would mostly be a 
problem if either you or your target is moving very fast. (I haven't actually 
tested how bad this desync is. It might be pretty minimal.)




Now that that's all out of the way, you should be good to go! Happy pointing!
--]]


-- Start of user data section --------------------------------------------------

-- Shortcut to your model
local model = models["MyAvatar"]

-- List of limbs your character can point with
local limbs = {
	{
		["pointing_limb"] = model.Body.PointingRightArm,
		["limbs_to_hide"] = {
			vanilla_model.RIGHT_ARM, 
			vanilla_model.RIGHT_SLEEVE,
			vanilla_model.RIGHT_ITEM
		}, 
		["length"] = 0.610
	},{
		["pointing_limb"] = model.Body.PointingLeftArm,
		["limbs_to_hide"] = {
			vanilla_model.LEFT_ARM, 
			vanilla_model.LEFT_SLEEVE,
			vanilla_model.LEFT_ITEM
		}, 
		["length"] = 0.610
	}
}

-- End of user data section ----------------------------------------------------

-- inits and public FNs
local script_version = "0.1.1_limes"
-- in later versions of this script, we can test against version to see what 
-- the other avatar's script_version to see what that avatar's pointing
-- preferences are. 
-- This is only important for find_optimal_position_to_hold_hands(), where 2
-- avatars have to agree on a target position.

events.ENTITY_INIT:register(function()
	-- Validate limbs table. Warn the user if something looks wrong before 
	-- Lua throws any input-data related "tried to index nil" errors.
	if validate_limbs_table() then
		-- print("Limbs valid")
		-- process how to share data and add internal elements of limbs table.
		avatar:store("limes_pointing__version", script_version)
		share_limb_data()
	end
    --current_body_yaw = player:getBodyYaw()
--    previous_body_yaw = current_body_yaw
end)

-- Used to counteract the snappy body turn mid-tick (TODO)
--local previous_body_yaw = 0
--local current_body_yaw = 0

-- There are extra fields in limbs that aren't explicitly defined in the 
-- limbs table. (It makes the table appear cleaner when the user is inputing 
-- their data.) Here are the other fields:
-- - limbs[i].point_target: stores the target that a limb is pointing at. It
--   can be any Entity, a BlockState, or a string. Stings are used in special
--   cases. This is chiefly managed by `recalculate_target_limb_pairs()`
-- - limbs[i].previous_rot and current_rot: The rotation of the limb for the 
--   previous and current tick. This is used to smooth the animation of the
--   arm over time.  

local limbs_table_valid = nil	-- Will be true or false after validation
function validate_limbs_table() 
	local error_messages = {}
	
	if type(limbs) ~= "table" then 
		limbs_table_valid = false
		table.insert(error_messages, 
			string.format("limbs is a %s."
					.."\n  (Should be a table)"
				, i, type(limb)
			)
		)
	else
		if #limbs < 1 then
			limbs_table_valid = false
			table.insert(error_messages, "limbs is empty."
					.."\n  (There should be at least 1)"
			)
		else
			for i, limb in pairs(limbs) do
				if type(limb) ~= "table" then
					limbs_table_valid = false
					table.insert(error_messages, string.format(
						"limbs[%s] is a %s."
							.."\n  (Should be a table)"
						, i, type(limb)
					)	)
				else
				
					if type(limb.pointing_limb) ~= "ModelPart" then
						limbs_table_valid = false
						table.insert(error_messages, string.format(
							"limbs[%s].pointing_limb is a %s."
								.."\n  (Should be a ModelPart)"
							, i, type(limb.pointing_limb)
						)	)
					end
					
					if type(limb.limbs_to_hide) ~= "table" then
						limbs_table_valid = false
						table.insert(error_messages, string.format(
							"limbs[%s].limbs_to_hide is a %s."
								.."\n  (Should be a table. (can be empty.))"
							, i, type(limb.limbs_to_hide)
						)	)
					else
						for j, original_limb in pairs(limb.limbs_to_hide) do
							if	    (type(original_limb) ~= "ModelPart") 
								and (type(original_limb) ~= "VanillaModelPart") 
							then
								limbs_table_valid = false
								table.insert(error_messages, string.format(
									"limbs[%s].limbs_to_hide[%s] is a %s."
										.."\n  (Should be a ModelPart "
										.."or a VanillaModelPart.)"
									, i, j, type(original_limb)
								)	)
							end
						end
					end
					
					if type(limb.length) ~= "number" then
						limbs_table_valid = false
						table.insert(error_messages, string.format(
							"limbs[%s].length is a %s."
								.."\n  (Should be a number.)"
							, i, type(limb.length)
						)	)
					end
				end
			end
		end
	end
	
	if limbs_table_valid == false then
		print(
			string.format("!! !!"
					.."\nErrors found while validating the `limbs` table:"
					.."\n-----------\n- %s\n-----------"
				, table.concat(error_messages, "\n- ")
			)
		)
	else
		limbs_table_valid = true
	end
	return limbs_table_valid
end

function add_point_target(special_target)
	local free_hands = get_free_hands()
	if #free_hands <= 0 then
		print("No free hands to point with.")
		return
	end	

	local target = special_target
		-- Hi visitor! If you're looking to add your own special case, you need
		-- to see the `get_target_position()` function. That's where you can
		-- convert your special case string into a position vector.
    if type(target) ~= "string" then
        target = user:getTargetedEntity()
    end
	if target == nil then
		target = user:getTargetedBlock(true)
	end

    -- don't point at the same target twice.
	for i, hand in pairs(get_busy_hands()) do
		if  (   type(target) ~= "BlockState" and
                hand.limb.point_target == target
            ) or (
                -- If you target 2 different blocks that happen to
                -- be the same type, `point_target == target`
                -- returns "true." We don't want this. But a block
                -- target will be the same as another block target
                -- if they have the same position. 
                type(target) == "BlockState" 
                and type(hand.limb.point_target) == "BlockState"
                and hand.limb.point_target:getPos() == target:getPos()
            )
		then
			print("Already pointing at target:", target)
			return 
		end
	end
	
	free_hands[1].limb.point_target = target
	print("Pointing at", target)	 
	
	recalculate_target_limb_pairs()
end

function stop_pointing()
	print("Clearing pointing targets")
	clear_point_targets()
end

function share_limb_data()
	-- avatar:store() stores by reference and will stay in sync with the real
	-- limbs table. So we should only need to run this on avatar init.
	-- Store is for passing data between avatars. But pings are for passing
	-- info between clients. (Client B won't know that client A did an 
	-- action wheel action unless A pings B that they did it.)
	-- So long as the pings get to client B, everything should stay in sync.
	-- (and if not, just do a quick "clear targets" and repoint.)
	avatar:store("limes_pointing__limbs", limbs)
end

-- Getters 

-- get_free_hands does _not_ return a table limbs directly, but returns a meta
-- table. free_hands()[i].limb is the actual limb. free_hands()[i].index
-- is the index of that limb in the limbs table. 
function get_free_hands()
	local free_hands = {}
	for i, limb in pairs(limbs) do
		if type(limb.point_target) == "nil" then
			table.insert(free_hands, {index = i, limb = limb})
		end
	end 
	return free_hands
end

function limb_is_busy(limb) 
    if type(limb.point_target) ~= "nil"

            -- a hand can still by busy even if it has no target, we might be
            -- animating it back to the rest position. We are done when a limb
            -- has no targets, and when rotations have reset to 0. 
        or (    type(limb.previous_rot) ~= "nil"
                and limb.previous_rot ~= vectors.vec3(0,0,0)
        ) or (  type(limb.current_rot) ~= "nil" 
                and limb.current_rot ~= vectors.vec3(0,0,0)
        )
    then 
        return true 
    else 
        return false 
    end
end

function get_busy_hands()
	local busy_hands = {}
	for i, limb in pairs(limbs) do
		if limb_is_busy(limb) 
        then
			table.insert(busy_hands, {index = i, limb = limb})
		end
	end
	return busy_hands
end

function get_point_targets()
	local point_targets = {}
	for _, limb in pairs(limbs) do
		if limb.point_target ~= nil then
			table.insert(point_targets, limb.point_target)
		end
	end
	return point_targets
end

function get_limb_pivot_point(limb)
	return get_model_part_pivot_point(limb.pointing_limb)
end

function get_model_part_pivot_point(model_part) 
	return vectors.vec3(
		model_part:partToWorldMatrix()[4][1],
		model_part:partToWorldMatrix()[4][2],
		model_part:partToWorldMatrix()[4][3]
	)
end

function get_target_limbs(target)
	-- look into world.avatarVars and see if my target has 
	-- linked their limbs table there.
	if type(target) ~= "PlayerAPI" then return nil end
	-- check avatar store, look for this player.
	local target_avatar_vars = world.avatarVars()[target:getUUID()]
	if target_avatar_vars == nil then return nil end
	if target_avatar_vars.limes_pointing__limbs == nil then return nil end
	
	for _, limb in pairs(target_avatar_vars.limes_pointing__limbs) do 
		if (limb == nil) 
			or (type(limb.pointing_limb) ~= "ModelPart")
		then return nil end
	end
	
	return target_avatar_vars.limes_pointing__limbs
end

function is_targeting_us(target)
	local target_limbs = get_target_limbs(target)
	if target_limbs == nil then return false end
	for _, limb in pairs(target_limbs) do
		if (type(limb.point_target) == "PlayerAPI") 
			and (limb.point_target:getUUID() == player:getUUID())
		then
			return true, target_limbs
		end
	end	
	return false
end

function distance(point_a, point_b)
	return math.sqrt(
		  ( point_a.x - point_b.x )^2
		+ ( point_a.y - point_b.y )^2
		+ ( point_a.z - point_b.z )^2
	)
end

-- Main logic stuffs -----------------------------------------------------------
function clear_point_targets() 
	for i, limb in pairs(limbs) do
		limb.point_target = nil
	end
end

function update_visibility()
	for _, limb in pairs(limbs) do
		local is_pointing = limb_is_busy(limb) 
		limb.pointing_limb:setVisible(is_pointing)
		for _, original_limb in pairs(limb.limbs_to_hide) do
			original_limb:setVisible(not is_pointing)
		end
	end
end

function get_target_position(target)
	-- Converts a limb's target to a position vector that we can point at.
	if type(target) == "BlockState" then
		return target:getPos() + vectors.vec3( 0.5, 0.5, 0.5 )
	 
	elseif type(target) == "PlayerAPI" and is_targeting_us(target) then
		local out = find_optimal_position_to_hold_hands(target)
		return out
	
	elseif type(target) == "EntityAPI" 
		or type(target) == "LivingEntityAPI" 
		or type(target) == "PlayerAPI"	-- Player isn't pointing at us here
	then
		-- Give center-ish of entity Bounding box
		return target:getPos() 
			+ vectors.vec3( 0, (target:getBoundingBox().y * 0.70), 0)
    
    elseif type(target) == "string" then
        -- check special cases. 
        if target == "ahead" then
            -- Aim towards player's look direction. 
            local point_ahead_of_player = player:getPos()
                + vectors.vec3( 0, (player:getBoundingBox().y * 0.70), 0)
                + (player:getLookDir() * 10) 
            return point_ahead_of_player 
			
		-- Additional special cases can be added here withan  elseif --

        else
	        print("!! get_target_position() !!"
        		.."\nUnrecognized special target: '"..target.."'" )
            return vectors.vec3(0, 0, 0)
        end

    end

	print("!! get_target_position() !!"
		.."\nUnexpected target type:", type(target)
	)
	return vectors.vec3( 0, 0, 0 )
end

function recalculate_target_limb_pairs()
	-- Get the distance of every target-limb pairing. Find the pair with the 
	-- minimum distance, pair them in the limbs table, and remove them from 
	-- the next search. Loop until every target has a limb.
	
	local targets = get_point_targets()
	local num_targets = #targets
	clear_point_targets()
	
	local search_cycles = math.min(num_targets, #limbs) 
		-- num_targets should never be > than #limbs. But let's just be safe.
	for i=1,search_cycles do
		-- print("Search loop", i, "of", num_targets)
		local best_pair = {}
		local best_distance = math.huge
		local current_dist = math.huge
		for t, target in pairs(targets) do
			if target ~= nil then
				for l, free_hand in pairs( get_free_hands() ) do
					limb = limbs[free_hand.index]
					
					local target_is_targeting_us, target_limbs 
						= is_targeting_us(target)
					
					if target_is_targeting_us then
						-- We're holding hands.
						-- We'll need to loop through all of target's limbs
						
						-- !! Caution !! 
						-- don't run get_target_position() in this `if` block. 
						-- it will runs find_optimal_position_to_hold_hands()
						-- Use get_limb_pivot_point() instead to get distance 
						-- to their shoulder.
						-- (the correct solution would be to run it here and 
						-- store the result hand_position with the target)
						for tl, target_limb in pairs(target_limbs) do
							current_dist = distance(
								get_limb_pivot_point(limb), 
								get_limb_pivot_point(target_limb)
							) - 500 -- prioritize hand holding before pointing
							
							-- Skip heuristics and just use minimum distance.
							if current_dist < best_distance then
								best_distance = current_dist 
								best_pair.target = target
								best_pair.target_index = t
								best_pair.limb = free_hand.limb
								best_pair.limb_index = free_hand.index
							end
						end
					else -- target isn't pointing at us. 
						current_dist = distance(
							get_limb_pivot_point(limb), 
							get_target_position(target)
						)
						
						-- Do fancy heuristics here?? 
						-- todo: Discourage arms from pointing through body?
						if l == 1 then
							-- prioritize limbs higher in the limbs table.
							-- Simulates Handedness.
							-- Also prevents rapidly jumping between limbs when 
							-- target is almost equidistant from all limbs
							current_dist = current_dist - 0.10
						end
                        if type(target) == "string" then 
                            -- special weights for special cases
                            if target == "ahead" then
                                -- Significantly de-prioritize pointing ahead.
                                -- We can do this action with any arm. 
                                current_dist = current_dist + 500
                            end
                        end
						
						if current_dist < best_distance then
							best_distance = current_dist 
							best_pair.target = target
							best_pair.target_index = t
							best_pair.limb = free_hand.limb
							best_pair.limb_index = free_hand.index
						end
					end
				end	
			end
		end
		
		limbs[best_pair.limb_index].point_target = best_pair.target
		targets[best_pair.target_index] = nil
	end
end

function find_optimal_position_to_hold_hands(target)
	-- By the time this function runs, its should be safe to assume that. 
	-- recalculate_target_limb_pairs() ran recently. So we should know which
	-- limb we should point with and what limb they should point with. 
	-- But they might note have updated their pairs yet. (Or maybe they
	-- have a more optimal target to point at.) So instead, use our arm to 
	-- point at the hand that is pointing at us.
	
	-- This function works by transforming the system of 2 points into 2D,
	-- finding the intersection of 2 2D circles, picking the point with the
	-- smallest Y, then un-transform the system back to 3D. 
	
	-- Step 0: "Ooops, I didn't tell the function which limbs are pointing!"
	local my_limb = nil
	local their_limb = nil
	for _, limb in pairs(limbs) do
		if limb.point_target == target then
			my_limb = limb
			break
		end
	end
	
	for _, limb in pairs( get_target_limbs(target) ) do
		if (type(limb.point_target) == "PlayerAPI") 
			and (limb.point_target:getUUID() == player:getUUID())
		then
			their_limb = limb
		end
	end
	
	if (my_limb == nil) or (their_limb == nil) then
		print("!! find_optimal_position_to_hold_hands !!\nfunction was called,"
			.." but one of the avatars is not pointing at the other."
		)
		return vectors.vec3( 0, 0, 0 )
	end
	
	-- Step 1: Check if circle intersection will have 0 results. 
	local my_pos = get_limb_pivot_point(my_limb)
	local their_pos = get_limb_pivot_point(their_limb)
	local m_t_dist = distance(my_pos, their_pos) 
	
	-- 1.1 Are hands too far away to intersect?
	if m_t_dist > (my_limb.length + their_limb.length) then
		-- If too far away for hands to point, point to their shoulder. it will
		-- look the same as if they were reaching for the other's hand.
		return their_pos
	end
	 
	local small_limb, long_limb  = their_limb, my_limb
	if long_limb.length < small_limb.length then
		small_limb, long_limb = long_limb, small_limb 
	end
	
	-- 1.2: Is small limb entirely inside long limb's range?
	if  m_t_dist + small_limb.length <= long_limb.length
	 	or my_pos == their_pos
	then
		-- the range of the smaller arm is completely inside the larger radius.
		return get_limb_pivot_point(small_limb) 
			- vectors.vec3( 0, small_limb.length, 0)
	end
	
	-- Step 2: Transform into 2D
	-- 2.1: resolve ties if limbs are the same length
	if long_limb.length == small_limb.length then
		if my_pos.x ~= their_pos.x then
			if my_pos.x > their_pos.x then
				small_limb, long_limb = their_limb, my_limb
			else
				small_limb, long_limb = my_limb, their_limb
			end
		elseif my_pos.y ~= their_pos.y then
			if my_pos.y > their_pos.y then
				small_limb, long_limb = their_limb, my_limb
			else
				small_limb, long_limb = my_limb, their_limb
			end
		else 
			-- we already did a pos == pos check. 
			-- Z will be different if we get this far.  
			if my_pos.z > their_pos.z then
				small_limb, long_limb = their_limb, my_limb
			else
				small_limb, long_limb = my_limb, their_limb
			end
		end
	end
	-- 2.2: Move everything to origin.
	-- use "small limb" so that my avatar and their avatar use the same math
	local origin_pos = vectors.vec3(0, 0, 0) 
		-- == (small_limb_pos - small_limb_pos)
	local long_pos_t = get_limb_pivot_point(long_limb) 
					- get_limb_pivot_point(small_limb) 
	
	-- 2.3: find rotation angle (unless already on the z plane)
	local long_pos_r_angle = 0
	if long_pos_t.z ~= 0 then
		local right_angle_pos = vectors.vec3(long_pos_t.x, long_pos_t.y, 0)
		long_pos_r_angle = math.asin( 
				  distance(right_angle_pos, long_pos_t)
				/ distance(origin_pos, long_pos_t) 
		)
		-- correct backwards angles
		if long_pos_t.z < 0 then
			long_pos_r_angle = long_pos_r_angle *-1
		end
	end
	
	-- 2.4: Rotate long_pos_t to Z = 0
	function rotate(position, angle, axis)
		if axis == nil or axis == "y" then
			return vectors.vec3(
				  position.x * math.cos(angle) + position.z * math.sin(angle)
				, position.y
				, position.z * math.cos(angle) - position.x * math.sin(angle)
			)
		end
		return nil
	end
	
	local long_pos_t_r = rotate(long_pos_t, long_pos_r_angle, "y")
	
	-- Step 3: Find the intersections of 2 circles
	-- see also: https://stackoverflow.com/questions/33520698
	-- 		small_pos == C2 | long_pos == C1
	local hand_target_t_r = vectors.vec3( 0, 0, 0 ) 
	do
		-- m_t_dist is still the same as origin to long_pos_t_r
		local gamma = math.acos(
			  (small_limb.length^2 + m_t_dist^2 - long_limb.length^2) 
			/ (2*small_limb.length*m_t_dist)
		)	-- see also: https://en.wikipedia.org/wiki/Law_of_cosines
		local dist_ll_to_pbi = math.cos(gamma) * long_limb.length
		local dist_pbi_to_intersection = math.sin(gamma) * long_limb.length	
		local point_between_intersections = vectors.vec3(
			  long_pos_t_r.x + (origin_pos.x - long_pos_t_r.x) 
			  		/ m_t_dist * dist_ll_to_pbi 
			, long_pos_t_r.y + (origin_pos.y - long_pos_t_r.y) 
					/ m_t_dist * dist_ll_to_pbi
			, 0
		) 
		local intersection_lower = vectors.vec3(
			  point_between_intersections.x 
			  		+ ( - (origin_pos.y - long_pos_t_r.y) )
			  		/ m_t_dist * dist_pbi_to_intersection
			, point_between_intersections.y 
					+ ( origin_pos.x - long_pos_t_r.x )
					/ m_t_dist * dist_pbi_to_intersection
			, 0
		) 
		
		hand_target_t_r = intersection_lower
	end
	
	-- 3.2: make sure target isn't inside either avatar's body.
	if hand_target_t_r.x < 0 then
		hand_target_t_r.x = 0
		hand_target_t_r.y = origin_pos.y - small_limb.length
	elseif hand_target_t_r.x > long_pos_t_r.x then
		hand_target_t_r.x = long_pos_t_r.x
		hand_target_t_r.y = long_pos_t_r.y - long_limb.length
	end
	
	-- Step 4: undo rotation and translation on hand_target
	-- TODO: any arm swing physics should happen now by rotating on the x axis
	
	local hand_target_t = rotate(hand_target_t_r, -1 * long_pos_r_angle, "y")
	local hand_target = hand_target_t + get_limb_pivot_point(small_limb) 
	
	return hand_target
end

function get_limb_rotation_to_target(limb)
    if type(limb.point_target) == "nil" then
        return vectors.vec3(0, 0, 0)
    end
	 
	local arm_pos = get_model_part_pivot_point(limb.pointing_limb)
	point_target = get_target_position(limb.point_target)
	
	-- This dodges a div by zero error when target is directly above or below.
	-- (It doesn't actually crash, but instead dumps NaNs into the Limbs
	-- table causing a crash in other parts of the script.)
	if (arm_pos.x == point_target.x) and (arm_pos.z == point_target.z) then
		if point_target.y >= arm_pos.y then 
			return vectors.vec3( 0, 180, 0)
		else
			return vectors.vec3( 0, 0, 0)
		end
	end
 
	-- Calculate pointing angle.
	-- It's trig time
	
	-- Triangle 1 -- test x and z (finding "yaw")
	-- This triangle assumes the right angle and target point are at the same 
	-- height as the player. This is fine since it doesn't control the pitch
	-- component. 
	local triangle1_angle_a_t = 0
	do 
		local triangle1_ax = arm_pos.x
		local triangle1_az = arm_pos.z
		local triangle1_tx = point_target.x
		local triangle1_tz = point_target.z
		local triangle1_rx = arm_pos.x
		local triangle1_rz = point_target.z
		
		local triangle1_dist_a_r = math.sqrt( 	-- Adjacent
			(triangle1_rx - triangle1_ax)^2
			+ (triangle1_rz - triangle1_az)^2
		)
		local triangle1_dist_a_t = math.sqrt( 	-- Hypotenuse
			(triangle1_tx - triangle1_ax)^2
			+ (triangle1_tz - triangle1_az)^2
		)
		
		triangle1_angle_a_t = math.deg(
			math.acos( triangle1_dist_a_r/triangle1_dist_a_t )
		)
		
		if arm_pos.x > point_target.x then 
			triangle1_angle_a_t = triangle1_angle_a_t *-1
		end
		if arm_pos.z > point_target.z then 
			triangle1_angle_a_t = 90+ ( -1 * (triangle1_angle_a_t-90))
		end
	end
	
	-- Triangle 2 -- x and y (or z and y) (find "pitch")
	-- Triangle 2's hypotenuse is the same as the distance from the arm to the 
	-- target. It assumes the right angle is at the same height as target, and
	-- below the arm. 
	local triangle2_angle_a_t
	do
		local triangle2_axz = arm_pos.x
		local triangle2_ay = arm_pos.y
		local triangle2_txz = point_target.x
		local triangle2_ty = point_target.y
		local triangle2_rxz = arm_pos.x
		local triangle2_ry = point_target.y

		-- the x, y comparison fails when passing near the target's z coord. 
		-- the z, y comparison fails when passing near the target's x coord.
		-- switch the comparison at the halfway point.
		if     (triangle1_angle_a_t > -45 and triangle1_angle_a_t < 45) 
			or (triangle1_angle_a_t > 135 and triangle1_angle_a_t < 225)
		then
			-- print("flip")
			triangle2_axz = arm_pos.z
			triangle2_txz = point_target.z
			triangle2_rxz = arm_pos.z
		end

		local triangle2_dist_a_r = math.sqrt( 	-- Adjacent
			(triangle2_rxz - triangle2_axz)^2
			+ (triangle2_ry - triangle2_ay)^2
		)
		local triangle2_dist_a_t = math.sqrt( 	-- Hypotenuse
			(triangle2_txz - triangle2_axz)^2
			+ (triangle2_ty - triangle2_ay)^2
		)

		triangle2_angle_a_t = math.deg(
			math.acos( triangle2_dist_a_r/triangle2_dist_a_t )
		)

		if arm_pos.y < point_target.y then 
			triangle2_angle_a_t = 90+ ( -1 * (triangle2_angle_a_t-90))
		end
	end

	target_arm_rotation = vectors.vec3(
		triangle2_angle_a_t, 
		triangle1_angle_a_t + player:getBodyYaw()%360,
		0
	)
	
	-- TODO: twist the arm as it points backwards so that the "outside"
	-- stays on the outside

    return target_arm_rotation
end

-- Tick ------------------------------------------------------------------------
events.TICK:register(function()
	if not player:isLoaded() then return end
	
	recalculate_target_limb_pairs() 
	update_visibility()
	
	for _, hand in pairs(get_busy_hands()) do
        local target_rot = get_limb_rotation_to_target(hand.limb)
        hand.limb.previous_rot = hand.limb.current_rot
        hand.limb.current_rot = target_rot
--        print(hand.limb.previous_rot, hand.limb.current_rot)
	end

--    previous_body_yaw = current_body_yaw
--    current_body_yaw = player:getBodyYaw()
end)

-- Render ----------------------------------------------------------------------
events.RENDER:register(function(delta)
	if not player:isLoaded() then return end

	for _, hand in pairs(get_busy_hands()) do
        if hand.limb.current_rot == nil then 
            hand.limb.current_rot = vectors.vec3(0, 0, 0)
        end
        if hand.limb.previous_rot == nil then 
            hand.limb.previous_rot = vectors.vec3(0, 0, 0)
        end 

        -- Don't try to move the hand if it doesn't need to move. 
        -- (leads to wacky glitchy movements when standing still sometimes

        -- Due to a presision error (?), directly comparing current_rot to 
        -- previous_rot almost always returns false. Floor the vecs to remove
        -- the of the noise. Scale by a big number first to keep some presision
        if     hand.limb.current_rot:copy():scale(10000):floor() 
            == hand.limb.previous_rot:copy():scale(10000):floor()
        then
            hand.limb.pointing_limb:setRot(hand.limb.current_rot)
        else 
            -- TODO: counteract rotating body during a tick
			-- local change_in_body_yaw = 
			-- 		player:getBodyYaw() - previous_body_yaw

            hand.limb.pointing_limb:setRot(vectors.vec3(
                math.lerpAngle(
                    hand.limb.previous_rot.x, 
                    hand.limb.current_rot.x, 
                    delta
                ),
                math.lerpAngle(
                    hand.limb.previous_rot.y,-- + change_in_body_yaw, 
                    hand.limb.current_rot.y, 
                    delta
                ),
                math.lerpAngle(
                    hand.limb.previous_rot.z, 
                    hand.limb.current_rot.z, 
                    delta
                )
            )
        )
    	end
	end
end)

-- debug -----------------------------------------------------------------------
function spawn_debug_particle(pos, r, g, b)
	particles:newParticle("glow",pos.x, pos.y, pos.z):color(r, g, b)
end

-- End -------------------------------------------------------------------------
