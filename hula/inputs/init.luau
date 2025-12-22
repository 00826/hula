--!strict

local RunService = game:GetService("RunService")

local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")
local UserInputService = game:GetService("UserInputService")

--- ### inputs.luau
---
--- input service wrapper
local inputs = {
	--- interally-resolved preferred input based on recency
	preferredinput = Enum.PreferredInput.KeyboardAndMouse;
	preferredinputflag = "h_preferredinput";

	--- used by `inputs.keybindof()` \
	--- to convert mouse clicks (`Enum.UserInputType`) to their `Enum.KeyCode` equivalent
	inputtypestokeycodes = {
		[Enum.UserInputType.MouseButton1] = Enum.KeyCode.MouseLeftButton;
		[Enum.UserInputType.MouseButton2] = Enum.KeyCode.MouseRightButton;
		[Enum.UserInputType.MouseButton3] = Enum.KeyCode.MouseMiddleButton;
	};

	--- `Enum.UserInputType -> Enum.PreferredInput` conversion table \
	--- `Enum.UserInputType.TextInput` is omitted and should be accounted for externally
	inputtypestopreferredinputs = {
		[Enum.UserInputType.None] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.Focus] = Enum.PreferredInput.KeyboardAndMouse;

		[Enum.UserInputType.MouseButton1] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseButton2] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseButton3] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseWheel] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseMovement] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.Keyboard] = Enum.PreferredInput.KeyboardAndMouse;
		
		[Enum.UserInputType.Touch] = Enum.PreferredInput.Touch;
		[Enum.UserInputType.Accelerometer] = Enum.PreferredInput.Touch;
		[Enum.UserInputType.Gyro] = Enum.PreferredInput.Touch;

		[Enum.UserInputType.Gamepad1] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad2] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad3] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad4] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad5] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad6] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad7] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad8] = Enum.PreferredInput.Gamepad;
	};

	GamepadService = GamepadService;
	GuiService = GuiService;
	UserInputService = UserInputService;
}

--- returns index-value pair of key bound to `inputs.inputtypestokeycodes[inputobject.UserInputType]` or `inputObject.KeyCode` \
--- `Enum.KeyCode.Unknown` returns `nil, nil`
function inputs.keybindof<T>(inputobject: InputObject, keybinds: {{ keys: {Enum.KeyCode} }} & T): (number?, any?)
	local keycode = inputs.inputtypestokeycodes[inputobject.UserInputType] or inputobject.KeyCode

	if keycode == Enum.KeyCode.Unknown then
		return nil, nil
	else
		for i, bind in ipairs(keybinds) do
			if table.find(bind.keys, keycode) then
				return i, bind
			end
		end
	end

	return nil, nil
end

--- returns `UserInputService.InputBegan`
function inputs.began()
	return UserInputService.InputBegan
end

--- returns `UserInputService.InputChanged`
function inputs.changed()
	return UserInputService.InputChanged
end

--- returns `UserInputService.InputEnded`
function inputs.ended()
	return UserInputService.InputEnded
end

--- returns `UserInputService.LasInputTypeChanged`
function inputs.lastinputtypechanged()
	return UserInputService.LastInputTypeChanged
end

--- returns internally-resolved `UserInputService.PreferredInput` signal based on recency
function inputs.preferredinputchanged()
	return script:GetAttributeChangedSignal(inputs.preferredinputflag)
end

--- returns `UserInputService:GetMouseLocation()`
function inputs.mouselocation()
	return UserInputService:GetMouseLocation()
end

--- returns `UserInputService.MouseBehavior`
function inputs.mousebehavior()
	return UserInputService.MouseBehavior
end

--- equivalent to `UserInputService.MouseBehavior = mousebehavior`
function inputs.setmousebehavior(mousebehavior: Enum.MouseBehavior)
	UserInputService.MouseBehavior = mousebehavior
end

--- returns `UserInputService.MouseIcon`
function inputs.mouseicon()
	return UserInputService.MouseIcon
end

--- equivalent to `UserInputService.MouseIcon = icon or ""`
function inputs.setmouseicon(icon: string?)
	UserInputService.MouseIcon = icon or ""
end

--- returns `UserInputService.MouseIconEnabled`
function inputs.mouseiconenabled()
	return UserInputService.MouseIconEnabled
end

--- equivalent to `UserInputService.MouseIconEnabled = enabled`
function inputs.setmouseiconenabled(enabled: boolean)
	UserInputService.MouseIconEnabled = enabled
end

--- returns `UserInputService.TouchTapInWorld`
function inputs.touchtapinworld()
	return UserInputService.TouchTapInWorld
end

--- returns `UserInputService.TouchEnabled`
function inputs.touchenabled()
	return UserInputService.TouchEnabled
end

--- calls `GamepadService:EnableGamepadCursor(target)` or `GamepadService:DisableGamepadCursor()` depending on state
function inputs.setgamepadcursorstate(state: boolean, target: GuiObject?)
	if state == true then
		GamepadService:EnableGamepadCursor(target)
	else
		GamepadService:DisableGamepadCursor()
	end
end

--- returns `GamepadService.GamepadCursorEnabled`
function inputs.gamepadcursorenabled()
	return GamepadService.GamepadCursorEnabled
end

--- returns `GamepadService:GetPropertyChangedSignal("GamepadCursorEnabled")`
function inputs.gamepadcursorstatechanged()
	return GamepadService:GetPropertyChangedSignal("GamepadCursorEnabled")
end

--- returns `GuiService.MenuOpened`
function inputs.menuopened()
	return GuiService.MenuOpened
end

--- returns `GuiService.MenuClosed`
function inputs.menuclosed()
	return GuiService.MenuClosed
end

--- returns position, direction, and raycastresult of `camera:ScreenPointToRay`
function inputs.screenpointraycast(camera: Camera, screenposition: Vector2, raycastparams: RaycastParams, length: number)
	local unitray = camera:ScreenPointToRay(screenposition.X, screenposition.Y)
	local origin, direction = unitray.Origin, unitray.Direction

	return origin, direction, workspace:Raycast(origin, direction * length, raycastparams)
end

if RunService:IsClient() then
	local function updatepreferredinput(userinputtype: Enum.UserInputType)
		local thispreferredinput = inputs.inputtypestopreferredinputs[userinputtype]
		if thispreferredinput == nil then return end
		if inputs.preferredinput ~= thispreferredinput then
			inputs.preferredinput = thispreferredinput

			script:SetAttribute(inputs.preferredinputflag, inputs.preferredinput.Value)
		end
	end

	UserInputService.LastInputTypeChanged:Connect(updatepreferredinput)
	updatepreferredinput(UserInputService:GetLastInputType())
end

return inputs