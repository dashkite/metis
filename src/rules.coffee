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
    do ({ name, conditions, action, condition } = {}) ->
      for name, conditions of rules
        engine.rules[ name ] = 
          if ( action = engine.actions[ name ])?
            { name, when: conditions, run: action }
          else if ( condition = ( engine.conditions.lookup name ))?
            { name, when: conditions, predicate: condition.predicate }
          else
            throw new Error "unknown action: #{ name }"
      return
    engine

export default Rules
