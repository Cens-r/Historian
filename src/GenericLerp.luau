--!strict
--!native

type Native = CFrame | Vector3 | Vector2 | Color3 | UDim2
type Lerp<T> = (T, T, number) -> T

local NativeLerp: Lerp<Native> = function (self, goal, alpha)
  return (self :: any):Lerp(goal, alpha)
end
local NumericLerp: Lerp<number> = function (self, goal, alpha)
  return self + (goal - self) * alpha
end

local MethodMap = {
  -- Native:
  CFrame = NativeLerp,
  Vector3 = NativeLerp,
  Vector2 = NativeLerp,
  Color3 = NativeLerp,
  UDim2 = NativeLerp,

  -- Numeric:
  number = NumericLerp
}

export type LerpOptions = {
  GetType: (any) -> string,
  Methods: {[string]: Lerp<any>}
}

local function GenericLerp<T>(value: T, goal: T, alpha: number, options: LerpOptions?): T
  if options then
    local optype = options.GetType(value)
    local custom = options.Methods[optype]
    if custom then
      return custom(value, goal, alpha)
    end
  end

  local method = MethodMap[typeof(value)]
  if method then
    return method(value, goal, alpha)
  end
  return if alpha < 0.5 then value else goal
end

return function <T>(value: T, goal: T, alpha: number, options: LerpOptions?): T
  if goal == nil then return value end
  local valueType = typeof(value)
  if valueType == "table" then
    local new = {} :: any
    for key, child in value :: any do
      new[key] = GenericLerp(child, (goal :: any)[key], alpha, options)
    end
    return new
  end
  return GenericLerp(value, goal, alpha, options)
end
