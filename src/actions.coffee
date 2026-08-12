import { assign } from "./helpers.js"

Actions =
  
  register: ( engine, actions ) ->
    assign engine.actions, actions
    engine

export default Actions
