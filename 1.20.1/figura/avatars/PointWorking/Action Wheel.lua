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
