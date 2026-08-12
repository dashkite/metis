import * as Val from "@dashkite/joy/value"

# OOP-friendly negate
negate = ( predicate ) -> 
  ( args... ) ->
    result = predicate.apply @, args
    if result?.then?
      result.then (resolvedValue) -> !resolvedValue
    else
      !result

# destructive cat
cat = ( array, value ) -> array.push value...

# destructive assign
assign = ( target, value ) -> Object.assign target, value

# predicate to check for tuples of a given length
tuple = ( size ) -> ( value ) -> value?.length == size

hasEvaluator = ( value ) -> value?.constructor == Object && value.evaluator?
isSync = ( value ) -> value?.constructor == Object && value.mode in [ "sync", "synchronous" ]
isAsync = ( value ) -> value?.constructor == Object && (!value.mode? || value.mode in [ "async", "asynchronous" ])

isIterable = ( value ) -> value?[Symbol.iterator]? || value?[Symbol.asyncIterator]?

export { negate, cat, assign, tuple, hasEvaluator, isSync, isAsync, isIterable }
