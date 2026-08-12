import Generic from "@dashkite/generic"
import { cat, assign, negate, tuple } from "./helpers.js"

class Conditions

  constructor: ( @parent = null ) ->
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

  parseName: ( name ) ->
    if ( name.startsWith "!" )
      { truename: name[ 1.. ], negated: true }
    else
      { truename: name, negated: false }

  lookup: ( name ) ->
    { truename, negated } = ( @parseName name )

    if ( entry = @registry[ truename ] )?
      predicate = if negated then ( negate entry.run ) else entry.run
      { name, truename, negated, predicate, scope: "target", when: entry.when }
    else if ( parentCondition = @parent?.lookup truename )?
      predicate = if negated then ( negate parentCondition.predicate ) else parentCondition.predicate
      { name, truename, negated, predicate, scope: "parent", when: parentCondition.when }
    else
      throw new Error "unknown condition: #{ truename }"

  closure: ( conditions = [], seen = new Set ) ->
    result = []
    for name in ( conditions ? [] )
      { truename } = ( @parseName name )

      if ( entry = @registry[ truename ] )?
        condition = ( @lookup name )
        if ( ! ( seen.has condition.truename ) )
          seen.add condition.truename
          if ( entry.when?.length > 0 )
            cat result, ( @closure entry.when, seen )
          if ( ! ( @in condition, result ) )
            result.push condition

      else if @parent?
        parentClosure = @parent.closure [ name ], seen
        for parentCondition in parentClosure
          if ( ! ( seen.has parentCondition.truename ) )
            seen.add parentCondition.truename
            if ( ! ( @in parentCondition, result ) )
              result.push parentCondition

      else
        throw new Error "unknown condition: #{ truename }"
    result

  in: ( condition, list ) ->
    list.some ( item ) -> ( item.name == condition.name ) || ( item.truename == condition.truename )

export default Conditions
