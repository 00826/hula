# hulaㅤ/ˈhuːlə/
a table of roblox-luau convenience modules

## about

|ico.svg|lore|
|-|-|
|<img src="./hula-ico.svg" width="96"/>|a table of roblox-luau convenience modules with no external or cross-dependencies. designed to be copy-pasted at the function/pseudo-type -level as part of a "only import what's needed" rule|

## gotchas

1. code in this repo is always being cycled in and out on a per-need basis
2. [net.luau](./hula/net/init.luau) must be required on the server for its `port()`, `s()`, and `ms()` functions to work

## modules

|module|bases covered|
|-|-|
|[hula](./hula/init.luau)|table|
|-|-|
|[bufferh.luau](./hula/bufferh/init.luau)|`buffer` library extension|
|[color3h.luau](./hula/color3h/init.luau)|`Color3` library extension|
|[gui.luau](./hula/gui/init.luau)|gui helper functions and instantiators|
|[inputs.luau](./hula/inputs/init.luau)|`UserInputService`, `GamepadService` wrapper|
|[instanceh.luau](./hula/instanceh/init.luau)|`Instance` library extension|
|[mathh.luau](./hula/mathh/init.luau)|`math`, `NumberRange`, `NumberSequence` library extension|
|[net.luau](./hula/net/init.luau)|`client<->server` & `vm₁<->vm₁` networking, server-authoritative `DateTime.now().UnixTimestampMillis`, miscellaneous time functions|
|[patronage.luau](./hula/patronage/init.luau)|aio devproducts, gamepasses, premium, group membership, etc|
|[stringh.luau](./hula/stringh/init.luau)|`string` library extension|
|[tableh.luau](./hula/tableh/init.luau)|`table` library extension|
|[vector3h.luau](./hula/vector3h/init.luau)|`Vector3` library extension|

## design language

```lua
--- library naming conflicts suffixed with "h" (color3h, mathh)
--- attributes prefixed with "h_"

--- services
--- variables
--- private functions
--- types
--- module

--- ### filename.luau
---
--- description
local t = {}

--- description
function t.sum(x: number, y: number)
	--- ...

	return x + y
end

--- ... runtime-dependent work
return t
```

---

ㅐ hula by 00826 / overflowed