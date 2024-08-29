--!strict

local RunService = game:GetService("RunService")
local Packages = script.Parent.Parent

local GenericLerp = require(script.Parent.GenericLerp)

local CensorUtils = require(Packages.CensorUtils)
type Table<K, V> = CensorUtils.Table<K, V>

local Array = CensorUtils.Array
type Array<T> = CensorUtils.Array<T>

local Signal = require(Packages.LemonSignal)
type Signal<T...> = Signal.Signal<T...>
type Connection<U...> = Signal.Connection<U...>

local NONE = {}
type None = typeof(NONE)

export type TimeContext<T> = {
  data: T,
  time: number
}

export type SnapshotReverter<T, Snapshot> = (T, Snapshot) -> ()
export type ReplayData<T, Snapshot> = {
  offset: number?,
  content: Array<TimeContext<Snapshot>>,
  options: GenericLerp.LerpOptions?,
  Reverter: SnapshotReverter<T, Snapshot>
}

type ReplayPrivateStruct<T, Snapshot> = {
  __type: any,
  __object: T,
  __array: Array<TimeContext<Snapshot>>,

  __offset: number,
  __playback: RBXScriptConnection | None,
  __reverter: SnapshotReverter<T, Snapshot>,

  __options: GenericLerp.LerpOptions?
}

type ReplayWriteStruct = {
  Looped: boolean,
  TimePosition: number
}
type ReplayReadStruct = {
  IsPlaying: boolean,
  Speed: number,
  Length: number,
  
  Ended: Signal<>,
  Stopped: Signal<>,
  DidLoop: Signal<>
}

local Methods = {}
local Replay = setmetatable({}, { __index = Methods })
export type Replay<T, Snapshot> = typeof(setmetatable({} :: ReplayReadStruct, { __index = Methods })) & ReplayWriteStruct
export type ReplayPrivate<T, Snapshot> = Replay<T, Snapshot> & ReplayPrivateStruct<T, Snapshot>

Replay.Type = setmetatable({}, {
  __tostring = function ()
    return "Replay"
  end
})

local function GetWriteableReplay<T, Snapshot>(replay: Replay<T, Snapshot> | ReplayPrivate<T, Snapshot>): Replay<T, Snapshot>
  return getmetatable(replay).__index
end

function Replay.new<T, Snapshot>(object: T, data: ReplayData<T, Snapshot>): Replay<T, Snapshot>
  local content = data.content
  local size = #content

  local offset = content[1].time
  
  local public: ReplayReadStruct = {
    IsPlaying = false,
    Speed = 1,
    Length = content[size].time - offset,

    Ended = Signal.new(),
    Stopped = Signal.new(),
    DidLoop = Signal.new()
  }
  setmetatable(public, { __index = Methods })

  local private: ReplayPrivateStruct<T, Snapshot> & ReplayWriteStruct = {
    __type = Replay.Type,
    __object = object,
    __array = content,
   
    __offset = offset,
    __playback = NONE,
    __reverter = data.Reverter,

    __options = data.options,

    Looped = false,
    TimePosition = 0
  }
  return (setmetatable(private, {
    __index = public,
    __newindex = function ()
      error("'Replay.__newindex' - Attempting to write to a read-only property!")
    end
  }) :: any) :: Replay<T, Snapshot>
end

function Methods.Step<T, Snapshot>(self: Replay<T, Snapshot>, delta: number): boolean
  local this = self :: ReplayPrivate<T, Snapshot> 
  local didLoop = false

  local content = this.__array
  local size = #content

  -- Edgecases: Improperly sized or Replay is over
  if size <= 1 then return didLoop end
  if (this.TimePosition >= this.Length) and (not this.Looped) then return didLoop end

  -- Shift TimePostion by delta and handle looping
  local shifted = self.TimePosition + delta
  if self.Looped and (shifted >= self.Length) then
    shifted %= this.Length
    didLoop = true
  else
    shifted = math.clamp(shifted, 0, this.Length)
  end
  this.TimePosition = shifted

   -- Case for where the shift ended the Replay
  local object = this.__object
  if shifted == this.Length then
    this.__reverter(object, content[size].data)
    return didLoop
  end

  local offset = this.__offset
  
  local closestIndex = 1
  Array.find(content, shifted + offset, function (goal: number, snapshot: TimeContext<Snapshot>, index: number)
    local value = snapshot.time
    if goal == value then
      closestIndex = index
      return Array.BinaryResult.Equal
    elseif goal > value then
      closestIndex = index
      return Array.BinaryResult.Greater
    else
      return Array.BinaryResult.Less
    end
  end) -- Note: Could optimize be updating search bounds

  local current, future = content[closestIndex], content[closestIndex + 1]
  local alpha = (shifted - (current.time - offset)) / (future.time - current.time)

  local value = GenericLerp(current.data, future.data, alpha, this.__options)
  this.__reverter(object, value)

  return didLoop
end

local function CleanupPlayback<T, Snapshot>(replay: ReplayPrivate<T, Snapshot>)
  local public = GetWriteableReplay(replay)
  public.IsPlaying = false
  if replay.__playback ~= NONE then
    (replay.__playback :: RBXScriptConnection):Disconnect()
    replay.__playback = NONE
  end
end

function Methods.Play<T, Snapshot>(self: Replay<T, Snapshot>, event: RBXScriptSignal<number, number?>?)
  local this = self :: ReplayPrivate<T, Snapshot>

  local content = this.__array
  if #content <= 1 then return end

  local public = GetWriteableReplay(this)
  public.IsPlaying = true

  local run: RBXScriptSignal<number, number?> = event or RunService.Heartbeat
  this.__playback = run:Connect(function (a, b)
    local delta = if b then b else a
    local looped = this:Step(delta * public.Speed)

    if this.Looped and looped then
      public.DidLoop:Fire()
    elseif this.TimePosition >= public.Length then
      CleanupPlayback(this)
      public.Ended:Fire()
    end
  end)
end

function Methods.Stop<T, Snapshot>(self: Replay<T, Snapshot>)
  local this = self :: ReplayPrivate<T, Snapshot>
  if not this.IsPlaying then return end
  CleanupPlayback(this)
  this.Stopped:Fire()
end

function Methods.AdjustSpeed<T, Snapshot>(self: Replay<T, Snapshot>, speed)
  local this = self :: ReplayPrivate<T, Snapshot>
  local public = GetWriteableReplay(this)
  public.Speed = speed
end

return Replay
