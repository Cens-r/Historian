local REQUIRED_MODULE = require(script.Packages.Historian)
export type Replay<T, Snapshot> = REQUIRED_MODULE.Replay<T, Snapshot>
export type SnapshotReverter<T, Snapshot> = REQUIRED_MODULE.SnapshotReverter<T, Snapshot>
export type LerpOptions = REQUIRED_MODULE.LerpOptions 
export type SnapshotRecorder<T, Snapshot> = REQUIRED_MODULE.SnapshotRecorder<T, Snapshot>
export type HistoryOptions<T, Snapshot> = REQUIRED_MODULE.HistoryOptions<T, Snapshot>
export type Historian<T, Snapshot> = REQUIRED_MODULE.Historian<T, Snapshot>
return REQUIRED_MODULE
