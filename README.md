# hulaㅤ/ˈhuːlə/
a table of roblox-luau convenience modules

## about

|ico.svg|lore|
|-|-|
|<img src="./hula-ico.svg" width="96"/>|a table of roblox-luau convenience modules with no external or cross-dependencies. designed to be copy-pasted at the function/pseudo-type -level as part of a "only import what's needed" rule|

## gotchas

1. code in this repo is always being cycled in and out on a per-need basis
2. [net.luau](./hula/net/init.luau) must be required on the server for its `send()`, `recv()`, `s()`, and `ms()` functions to work

## modules

|module|bases covered|
|-|-|
|[hula](./hula/init.luau)|table|
|-|-|
|[color3.luau](./hula/color3/init.luau)|`Color3`, `ColorSequence` library extension|
|[gui.luau](./hula/gui/init.luau)|`UDim`, `UDim2`, `Vector2` library extensions, ui helper functions|
|[inputs.luau](./hula/inputs/init.luau)|`UserInputService`, `GamepadService` wrapper|
|[instance.luau](./hula/instance/init.luau)|`Instance` library extension|
|[math.luau](./hula/math/init.luau)|`math`, `NumberRange`, `NumberSequence` library extension|
|[net.luau](./hula/net/init.luau)|buffer-based remote interface, oopless signals, server-authoritative unix time (`DateTime.now()`)|
|[patronage.luau](./hula/patronage/init.luau)|player patronage (devproducts, gamepasses, premium, group membership, etc)|
|[types.luau](./hula/types/init.luau)|primitive type functions|
|[vector3.luau](./hula/vector3/init.luau)|`Vector3` library extension|

## design language

```lua
--- directives

--- RobloxType
--- luautype
--- hulatype

--- namingconflict .. "h" (color3h, mathh)
--- attribute flag prefix "h_"
--- --- sideline commentary

--- ### filename.luau /ipa/
---
--- description
local t = {}

--- description, return types, and nil-fallbacks, separated by line breaks \
function t.incr(x: number, y: number)
	--- ...

	return x + y
end

--- ... runtime-dependent work
return t
```

---

ㅐ hula by 00826 / overflowed