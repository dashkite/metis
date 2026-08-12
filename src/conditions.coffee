import Generic from "@dashkite/generic"
import { cat, assign, negate, tuple } from "./helpers.js"

class Conditions

  constructor: ->
    @registry = {}

  register: ( dictionary ) ->
    for name, run of dictionary
      @condition [ name, run ]
    @

  condition: do ->
    ( Generic.make "Conditions::condition" )

      .define [ Object ], ( specifier ) ->
        @registry[ specifier.name ] =
          run: specifier.run
          when: specifier.when ? []
        @

      .define [ tuple 2 ], ([ name, run ]) ->
        @condition { name, run }

      .define [ tuple 3 ], ([ name, conditions, run ]) ->
        @condition { name, run, when: conditions }

  parse: ( name ) ->
    if ( name.startsWith "!" )
      { truename: name[ 1.. ], negated: true }
    else
      { truename: name, negated: false }

  lookup: ( name ) ->
    { truename, negated } = ( @parse name )

    if ( entry = @registry[ truename ])?
      predicate = if negated then ( negate entry.run ) else entry.run
      { name, truename, negated, predicate, when: entry.when }
    else
      null

  closure: ( conditions = [], seen = new Set ) ->
    result = []
    for name in ( conditions ? [])
      { truename } = ( @parse name )

      if ( entry = @registry[ truename ])?
        condition = ( @lookup name )
        if condition? && (!( seen.has condition.truename ))
          seen.add condition.truename
          if ( entry.when?.length > 0 )
            cat result, ( @closure entry.when, seen )
          exists =
            result.some ( item ) ->
              ( item.name == condition.name ) ||
                ( item.truename == condition.truename )
          if (! exists)
            result.push condition
    result

export default Conditions
