import * as Val from "@dashkite/joy/value"

arity = ( size, fn ) ->
  Object.defineProperty fn, "length", value: size, configurable: true

# deferrable combinator for functions that may return thenables
deferrable = ( fn ) ->
  arity ( fn.length + 1 ), ( args..., handler ) ->
    result = fn.apply @, args
    if result?.then?
      result.then ( resolved ) => handler.call @, resolved
    else
      handler.call @, result

# OOP-friendly negate
negate = ( predicate ) -> 
  wrapped = deferrable predicate
  ( args... ) ->
    wrapped.call @, args..., ( result ) -> !result

# destructive cat
cat = ( array, value ) -> array.push value...

# destructive assign
assign = ( target, value ) -> Object.assign target, value

# predicate to check for tuples of a given length
tuple = ( size ) -> ( value ) -> value?.length == size

hasEvaluator = ( value ) ->
  value?.constructor == Object && value.evaluator?

isSync = ( value ) ->
  value?.constructor == Object && value.mode in [ "sync", "synchronous" ]

isAsync = ( value ) ->
  isObject = ( value?.constructor == Object )
  isAsyncMode = (! value.mode? || value.mode in [ "async", "asynchronous" ])
  isObject && isAsyncMode

isIterable = ( value ) ->
  value?[Symbol.iterator]? || value?[Symbol.asyncIterator]?

export {
  arity
  deferrable
  negate
  cat
  assign
  tuple
  hasEvaluator
  isSync
  isAsync
  isIterable
}
