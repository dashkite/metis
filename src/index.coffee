import * as Val from "@dashkite/joy/value"
import Generic from "@dashkite/generic"

# OOP-friendly negate
negate = ( predicate ) -> 
  ( value ) -> !( predicate.call @, value )

# destructive cat
cat = ( array, value ) -> array.push value...

# destructive assign
assign = ( target, value ) -> Object.assign target, value

# predicate to check for tuples of a given length
tuple = ( k ) -> ( value ) -> value?.length == k

Rules =

  defaults:
    equal: Val.equal
    initialize: ( x ) -> x
    clone: structuredClone

  make: ( options ) ->
    { 
      Rules.defaults...
      options...
      rules: {}
      conditions: {}
      actions: {}
    }

  register: ( engine, rules ) ->
    do ({ name, conditions, action, predicate } = {}) ->
      for name, conditions of rules
        engine.rules[ name ] = 
          if ( action = engine.actions[ name ])?
            { name, conditions, action }
          else if ( condition = engine.conditions[ name ])?
            { name, conditions, condition }
          else
            throw new Error "unknown action: #{ name }"
    
  run: ( engine, state ) ->
    state = engine.initialize state
    do ({ rules, rule, saved, changed, result } = {}) ->
      loop
        rules = Object.values engine.rules
          .filter ( rule ) ->
            rule.action? && do ->
              conditions = Conditions.closure engine, rule.conditions
              conditions.every ( condition ) -> 
                Conditions
                  .lookup engine, condition
                  .call state
        saved = state
        state = engine.clone state
        for rule in rules
          yield { name: "rule", rule: rule.name, state }
          await rule.action.call state
        changed = !( engine.equal saved, state )
        if changed
          yield { name: "change", state }
        else
          break
      yield { name: "done", state }
      state

Conditions =

  register: ( engine, conditions ) ->
    assign engine.conditions, conditions

  normalize: ( engine, name ) ->
    do ({ truename, negated, condition } = {}) ->
      if ( name.startsWith "!" )
        truename = name[1..]
        negated = true
      else
        truename = name
      if ( condition = engine.conditions[ truename ])?
        condition = negate condition if negated
        { name, truename, negated, condition }
      else
        throw new Error "unknown condition: #{ truename }"

  lookup: ( engine, condition ) ->
    ( Conditions.normalize engine, condition ).condition
  
  closure: ( engine, conditions, seen = new Set ) ->
    result = []
    for name in conditions
      condition = Conditions.normalize engine, name
      unless seen.has condition.truename
        seen.add condition.truename
        if ( _condition = engine.rules[ condition.truename ])?
          cat result,
            Conditions.closure engine, 
              _condition.conditions,
              seen
        if !( Conditions.in condition, result )
          result.push condition.name
    result

  in: ({ name, truename }, list ) ->
    ( name in list ) ||
      (( name != truename ) && ( truename in list ))

Actions =
  
  register: ( engine, actions ) ->
    assign engine.actions, actions

class Athena

  @make: ( options ) -> 
    Object.assign ( new @ ), 
      engine: Rules.make options

  conditions: ( dictionary ) ->
    Conditions.register @engine, dictionary

  condition: do ->

    ( Generic.make "Athena::condition" )
    
      .define [ Object ], ( specifier ) ->
        @conditions [ specifier.name ]: specifier.run
        if specifier.when?
          @rules [ specifier.name ]: specifier.when
        @

      .define [ tuple 2 ], ([ name, run ]) ->
        @condition { name, run }

      .define [ tuple 3 ], ([ name, conditions, run ]) ->
        @condition { name, run, when: conditions }

  actions: ( dictionary ) ->
    Actions.register @engine, dictionary

  action: do ->

    ( Generic.make "Athena::action" )

      .define [ Object ], ( specifier ) ->
        @actions [ specifier.name ]: specifier.run
        if specifier.when?
          @rules [ specifier.name ]: specifier.when
        @

      .define [ tuple 2 ], ([ name, run ]) ->
        @action { name, run }

      .define [ tuple 3 ], ([ name, conditions, run ]) ->
        @action { name, run, when: conditions }

  rules: ( dictionary ) ->
    Rules.register @engine, dictionary

  apply: ( state, args ) ->
    # this is for composition
    # TODO explain
    if args?[0]?
      Object.assign state,
        ( await yield from args[0])
    yield from Rules.run @engine, state

export default Athena
export { Rules, Conditions, Actions, Athena }