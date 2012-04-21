
load("./lib/module.jl")

# Adapted from: https://github.com/visionmedia/mocha/blob/master/lib/reporters/base.js
test_colors = {
  "pass" => 90
  "fail" => 31
  "bright pass" => 92
  "bright fail" => 91
  "bright yellow" => 93
  "pending" => 36
  "suite" => 0
  "error title" => 0
  "error message" => 31
  "error stack" => 90
  "checkmark" => 32
  "fast" => 90
  "medium" => 33
  "slow" => 31
  "green" => 32
  "light" => 90
  "diff gutter" => 90
  "diff added" => 42
  "diff removed" => 41
}
color(s, c) = strcat("\033[", test_colors[c], "m", s, "\033[0m")

type TestGroupResult
  completed::Int
  total::Int
  
  TestGroupResult() = new(0, 0)
end

global test_groups = HashTable{Any,TestGroupResult}()
global current_test_group = false

function test_group(name)
  if has(test_groups, name)
    end_test_group(name)
  else
    println("$name:")
    global current_test_group
    test_groups[name] = TestGroupResult()
    current_test_group = name
  end
end
function end_test_group(name)
  println(string(test_groups[name].completed), "/", string(test_groups[name].total), " passed")
  println("")
  current_test_group = false
end
end_test_group() = end_test_group(current_test_group)


function time_test_expr(expr)
  local s = time()
  local v
  try
    v = eval(expr)
  catch
    v = false
  end
  (time() - s, v)
end
macro test_true(name, expr)
  t, v = time_test_expr(expr)
  ms = int(t * 1000)
  global current_test_group
  if current_test_group != false
    test_groups[current_test_group].total += 1
  end
  if v == true
    if current_test_group != false
      test_groups[current_test_group].completed += 1
    end
    println("  ", color("✔", "bright pass"), color("  $name ($ms ms)", "pass"))
  else
    println("  ", color("✖", "bright fail"), color("  $name ($ms ms)", "fail"))
  end
  nothing
end
function test_true(name, v)
  global current_test_group
  if current_test_group != false
    test_groups[current_test_group].total += 1
  end
  if v == true
    if current_test_group != false
      test_groups[current_test_group].completed += 1
    end
    println("  ", color("✔", "bright pass"), color("  $name", "pass"))
  else
    println("  ", color("✖", "bright fail"), color("  $name", "fail"))
  end
end


test_group("Module")

@module_begin Test
@test_true "Module exists in _modules" has(_modules, :Test)
# test_true("Module exists in _modules", has(_modules, :Test))

@module_add Test function func(n)
  return n
end
@test_true "Function 'func' exists in _modules" has(_modules[:Test], "func")
@test_true "Function 'func' behaves as expected in _modules" _modules[:Test]["func"]("test") == "test"

@module_add Test val = 1
@test_true "Value 'val' exists in _modules" has(_modules[:Test], "val")
@test_true "Value 'val' is expected value in _modules" _modules[:Test]["val"] == 1

@module_end Test
@test_true "Module still exists in _modules" has(_modules, :Test)

@test_true "Module type exists" Test == Test
@test_true "Function 'func' behaves as expected in type" Test.func("test") == "test"
@test_true "Value 'val' is expected value in type" Test.val == 1

end_test_group()
