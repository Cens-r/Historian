local REQUIRED_MODULE = require(script.Parent._Index["cens-r_censor-utils@0.2.3"]["censor-utils"])
export type Table<K, V> = REQUIRED_MODULE.Table<K, V>
export type Array<T> = REQUIRED_MODULE.Array<T>
export type Stack<T> = REQUIRED_MODULE.Stack<T>
export type Queue<T> = REQUIRED_MODULE.Queue<T>
return REQUIRED_MODULE
