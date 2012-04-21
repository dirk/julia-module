global _modules = HashTable{Symbol,Any}()
global _module_currently_defining = false

function _module_fix_module_name(q::QuoteNode)
  string(q.value)
end
function _module_fix_module_name(n::Any)
  string(n)
end
function _module_type_for_name(name::String)
  symbol("_module_meta_type_$name")
end
function symbol(s::Symbol)
  s
end

macro module_begin(module_name_expr)
  #module_name = string(module_name_expr)
  module_name = _module_fix_module_name(module_name_expr)
  _modules[symbol(module_name)] = HashTable{String,Any}()
  
  nothing
end

macro module_end(module_name_expr)
  # The name of the final module (eg. Test)
  module_name = _module_fix_module_name(module_name_expr)
  # Internal name for the module's type (eg. _module_meta_type_Test)
  typename = _module_type_for_name(module_name)
  
  # Get pairs (key, value) from the module hash
  pairs = { p | p = _modules[symbol(module_name)] }
  
  # Build an array of expressions for the type fields (eg. test::Int)
  block_exprs = {}
  for pair in pairs
    push(block_exprs, Expr(symbol("::"), {symbol(pair[1]), typeof(pair[2])}, Any))
  end
  
  # Build the type (with internal typename)
  eval(Expr(:type, {
    symbol(typename),
    Expr(:block, block_exprs, Any)
  }, Any))
  
  # Initialize an instance of the type with its memebers
  instance = eval(symbol(typename))({ p[2] | p = pairs}...)
  # Make the name of the module global
  eval(Expr(:global, {symbol(module_name)}, Any))
  # Assign the name of the module to the instance
  eval(Expr(symbol("="), {symbol(module_name), instance}, Any))
  
  nothing
end

# Given a name expression and body expression, add the body expression into
# the module defined by the name expression.
function _module_add_member(module_name_expr, expr)
  #module_name = string(module_name_expr)
  module_name = _module_fix_module_name(module_name_expr)
  name = false
  
  if expr.head == :function
    function_ptr = gensym()
    # Expression for the function name and signature (eg. testing(n))
    function_name_expr = expr.args[1]
    # old_function_name_symbol = function_name_expr.args[1]
    name = string(function_name_expr.args[1]) # Grab the original name of the function
    # Overwrite the function name to be a random symbol so the original
    # namespace won't be polluted with it.
    function_name_expr.args[1] = function_ptr
    
    eval(expr)
    _modules[symbol(module_name)][name] = eval(:($function_ptr))
    
  elseif expr.head == symbol("=")
    if isa(expr.args[1], Symbol)
      # lvalue = expr.args[1]
      name = string(expr.args[1])
      # Overwrite the lvalue so it doesn't pollute the original namespace.
      expr.args[1] = gensym()
      
      _modules[symbol(module_name)][name] = eval(expr.args[2])
    end
  end
  # TODO: Add tuple handling to enable multiple assignment like: a, b = 1, 2
  if name == false
    return :(error("cannot handle expression: ",$string(expr)))
  end
  
  nothing
end

macro module_add(module_name_expr, expr)
  _module_add_member(module_name_expr, expr)
end



  