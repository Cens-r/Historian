--!strict

local CensorUtils = require(script.Parent.CensorUtils)
type Table<K, V> = CensorUtils.Table<K, V>

local Queue = CensorUtils.Queue
type Queue<T> = CensorUtils.Queue<T>

local Array = CensorUtils.Array
type Array<T> = CensorUtils.Array<T>

local Replay = require(script.Replay)
type TimeContext<T> = Replay.TimeContext<T>
export type Replay<T, Snapshot> = Replay.Replay<T, Snapshot>
export type SnapshotReverter<T, Snapshot> = Replay.SnapshotReverter<T, Snapshot>

local GenericLerp = require(script.GenericLerp)
export type LerpOptions = GenericLerp.LerpOptions

export type SnapshotRecorder<T, Snapshot> = (T) -> Snapshot?
export type HistoryOptions<T, Snapshot> = {
  size: number?,
  LerpOptions: LerpOptions?,
  Recorder: SnapshotRecorder<T, Snapshot>,
  Reverter: SnapshotReverter<T, Snapshot>
}

type HistorianStruct<T, Snapshot> = {
  __type: any,
  __cleanup: Table<any, any>,
  __queue: Queue<TimeContext<Snapshot>>,
  
  __object: T,
  __options: LerpOptions?,
  
  __recorder: SnapshotRecorder<T, Snapshot>,
  __reverter: SnapshotReverter<T, Snapshot>
}

local Methods = {}
local Historian = setmetatable({}, { __index = Methods })
export type Historian<T, Snapshot> = typeof(setmetatable({} :: HistorianStruct<T, Snapshot>, { __index = Methods }))

Historian.Type = setmetatable({}, {
  __tostring = function ()
    return "History"
  end
})

function Historian.new<T, Snapshot>(object: T, options: HistoryOptions<T, Snapshot>): Historian<T, Snapshot>
  local cleanup = {}
  local struct: HistorianStruct<T, Snapshot> = {
    __type = Historian.Type,
    __cleanup = cleanup,
    __queue = Queue.new(options.size),

    __object = object,
    __options = options.LerpOptions,
    
    __recorder = options.Recorder,
    __reverter = options.Reverter
  }
  return setmetatable(struct, { __index = Methods })
end

function Methods.Save<T, Snapshot>(self: Historian<T, Snapshot>, seconds: number): Replay<T, Snapshot>
  local content = self.__queue:get()
  local size = #content
  if size == 0 then
    error("History.Save() - No content to save!")
  end

  local offset = nil
  if seconds then
    local oldestSnapshot = content[1]
    local newestSnapshot = content[size]

    local goalTime = math.max(newestSnapshot.time - seconds, oldestSnapshot.time)

    local closestIndex = 1

    -- Abusing this method to binary search
    Array.find(content, goalTime, function (goal: number, snapshot: TimeContext<Snapshot>, index: number)
      local value = snapshot.time
      if goal == value then
        closestIndex = index
        return Array.BinaryResult.Equal
      elseif goal > value then
        closestIndex = index
        return Array.BinaryResult.Greater
      else
        -- Don't set closestSnapshot here
        -- The 'value' is higher, we only want closest lowest
        return Array.BinaryResult.Less
      end
    end)

    local closestSnapshot = content[closestIndex]
    local length = newestSnapshot.time - closestSnapshot.time
    offset = length - seconds

    content = table.move(content, closestIndex, size, 1, {})
  end

  local data: Replay.ReplayData<T, Snapshot> = {
    offset = offset,
    content = content,
    options = self.__options,
    Reverter = self.__reverter
  }
  return Replay.new(self.__object, data)
end

function Methods.Restore<T, Snapshot>(self: Historian<T, Snapshot>, replay: Replay<T, Snapshot>)
  local private = replay :: Replay.ReplayPrivate<T, Snapshot>
  if self.__object ~= private.__object then
    error("'Replay.__object' does not match 'History.__object'!")
  end
  local current = self.__queue:get()
  local content = Array.extend(current, private.__array)
  self.__queue:set(content)
end

function Methods.Capture<T, Snapshot>(self: Historian<T, Snapshot>): Snapshot?
  return self.__recorder(self.__object)
end

local DEFAULT_THROTTLE = 1/60

type RecordDisconnect = () -> ()
function Methods.Record<T, Snapshot>(self: Historian<T, Snapshot>, event: RBXScriptSignal<number, number?>, throttle: number?): RecordDisconnect?
  if self.__cleanup.Recording then
    return warn("History.Record() - Recording already in progress!")
  end

  throttle = throttle or DEFAULT_THROTTLE

  local count = 0
  local conn = event:Connect(function (a, b)
    local dt = if b then b else a
    
    count += dt
    if count < (throttle :: number) then return end
    count %= (throttle :: number)

    local snapshot = self:Capture()
    if snapshot then
      self.__queue:push({
        data = snapshot,
        time = os.clock()
      })
    end
  end)

  local disconnect = function ()
    conn:Disconnect()
  end
  self.__cleanup.Recording = disconnect
  return disconnect
end

return Historian
