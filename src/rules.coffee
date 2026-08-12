import * as Val from "@dashkite/joy/value"

Rules =

  defaults:
    equal: Val.equal
    initialize: ( state ) -> state
    clone: structuredClone

  make: ( options ) ->
    { 
      Rules.defaults...
      options...
      rules: {}
      actions: {}
    }

  register: ( engine, rules ) ->
    do ({ name, whenConditions, action, condition } = {}) ->
      for name, whenConditions of rules
        engine.rules[ name ] = 
          if ( action = engine.actions[ name ] )?
            { name, when: whenConditions, run: action }
          else if ( condition = ( engine.conditions.lookup name ) )?
            { name, when: whenConditions, predicate: condition.predicate }
          else
            throw new Error "unknown action: #{ name }"
      return # avoid returning comprehension
    engine

export default Rules
