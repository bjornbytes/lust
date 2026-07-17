-- lust v0.2.0 - Lua test framework
-- https://github.com/bjornbytes/lust
-- MIT LICENSE

local lust = {}
lust.level = 0
lust.passes = 0
lust.errors = 0
lust.befores = {}
lust.afters = {}

local red = string.char(27) .. '[31m'
local green = string.char(27) .. '[32m'
local normal = string.char(27) .. '[0m'
local function indent(level) return string.rep('\t', level or lust.level) end

function lust.nocolor()
  red, green, normal = '', '', ''
  return lust
end

function lust.describe(name, fn)
  print(indent() .. name)
  lust.level = lust.level + 1
  fn()
  lust.befores[lust.level] = {}
  lust.afters[lust.level] = {}
  lust.level = lust.level - 1
end

function lust.it(name, fn)
  for level = 1, lust.level do
    if lust.befores[level] then
      for i = 1, #lust.befores[level] do
        lust.befores[level][i](name)
      end
    end
  end

  local success, err = pcall(fn)
  if success then lust.passes = lust.passes + 1
  else lust.errors = lust.errors + 1 end
  local color = success and green or red
  local label = success and 'PASS' or 'FAIL'
  print(indent() .. color .. label .. normal .. ' ' .. name)
  if err then
    print(indent(lust.level + 1) .. red .. tostring(err) .. normal)
  end

  for level = 1, lust.level do
    if lust.afters[level] then
      for i = 1, #lust.afters[level] do
        lust.afters[level][i](name)
      end
    end
  end
end

function lust.before(fn)
  lust.befores[lust.level] = lust.befores[lust.level] or {}
  table.insert(lust.befores[lust.level], fn)
end

function lust.after(fn)
  lust.afters[lust.level] = lust.afters[lust.level] or {}
  table.insert(lust.afters[lust.level], fn)
end

-- Assertions
local function isa(v, x)
  if type(x) == 'string' then
    return type(v[1]) == x, 'expected ' .. tostring(v[1]) .. ' to be a ' .. x
  elseif type(x) == 'table' then
    if type(v[1]) ~= 'table' then
      return false, 'expected ' .. tostring(v[1]) .. ' to be a ' .. tostring(x)
    end

    local seen = {}
    local meta = v[1]
    while meta and not seen[meta] do
      if meta == x then return true end
      seen[meta] = true
      meta = getmetatable(meta) and getmetatable(meta).__index
    end

    return false, 'expected ' .. tostring(v[1]) .. ' to be a ' .. tostring(x)
  end

  error('invalid type ' .. tostring(x))
end

local function has(t, x)
  for k, v in pairs(t) do
    if v == x then return true end
  end
  return false
end

local function eq(t1, t2, eps)
  if type(t1) ~= type(t2) then return false end
  if type(t1) == 'number' then return math.abs(t1 - t2) <= (eps or 0) end
  if type(t1) ~= 'table' then return t1 == t2 end
  for k, _ in pairs(t1) do
    if not eq(t1[k], t2[k], eps) then return false end
  end
  for k, _ in pairs(t2) do
    if not eq(t2[k], t1[k], eps) then return false end
  end
  return true
end

local function stringify(...)
  local values = {}
  for i = 1, select('#', ...) do
    local value = select(i, ...)
    if type(value) == 'string' then
      table.insert(values, "'" .. tostring(value) .. "'")
    elseif type(value) ~= 'table' or getmetatable(value) and getmetatable(value).__tostring then
      table.insert(values, tostring(value))
    else
      local entries = {}
      for i, v in ipairs(value) do
        entries[#entries + 1] = stringify(v)
      end
      for k, v in pairs(value) do
        if type(k) ~= 'number' or k > #value or k < 1 then
          entries[#entries + 1] = ('[%s] = %s'):format(stringify(k), stringify(v))
        end
      end
      table.insert(values, '{ ' .. table.concat(entries, ', ') .. ' }')
    end
  end
  return table.concat(values, ', ')
end

local function all(t, fn, ...)
  for i = 1, t.n or #t do
    if not fn(t[i], i, ...) then return false end
  end
  return true
end

local function any(t, fn, ...)
  for i, v in ipairs(t) do
    if fn(v, i, ...) then return true end
  end
  return false
end

local function concat(t, s)
  local strings = {}
  for i = 1, t.n or #t do
    table.insert(strings, tostring(t[i]))
  end
  return table.concat(strings, s)
end

local unpack = _G.unpack or table.unpack
local function istable(x) return type(x) == 'table' end

local paths = {
  [''] = { 'to', 'to_not' },
  to = { 'have', 'equal', 'be', 'exist', 'fail', 'match', 'approximately' },
  to_not = {
    'have', 'equal', 'be', 'exist', 'fail', 'match', 'approximately',
    chain = function(a) a.negate = not a.negate end
  },
  a = { test = isa },
  an = { test = isa },
  be = { 'a', 'an', 'truthy', 'falsy',
    test = function(v, ...)
      local same = v.n == select('#', ...) and all(v, function(x, i, ...) return x == select(i, ...) end, ...)
      return same, 'expected ' .. concat(v, ', ') .. ' and ' .. concat({ n = select('#', ...), ... }, ', ') .. ' to be the same'
    end
  },
  exist = {
    test = function(v)
      return v.n > 0 and all(v, function(x) return x ~= nil end), 'expected ' .. concat(v, ', ') .. ' to exist'
    end
  },
  truthy = {
    test = function(v)
      return v.n > 0 and all(v, function(x) return x end), 'expected ' .. concat(v, ', ') .. ' to be truthy'
    end
  },
  falsy = {
    test = function(v)
      return all(v, function(x) return not x end), 'expected ' .. concat(v, ', ') .. ' to be falsy'
    end
  },
  equal = {
    test = function(v, ...)
      local equal = true

      equal = equal and v.n == select('#', ...)
      equal = equal and all(v, function(x, i, ...) return eq(x, select(i, ...), v.epsilon) end, ...)

      local comparison = ''
      if any(v, istable) or any({ ... }, istable) then
        comparison = comparison .. '\n' .. indent(lust.level + 1) .. 'LHS: ' .. stringify(unpack(v))
        comparison = comparison .. '\n' .. indent(lust.level + 1) .. 'RHS: ' .. stringify(...)
      end

      return equal, 'expected ' .. concat(v, ', ') .. ' and ' .. concat({ n = select('#', ...), ... }, ', ') .. ' to be equal' .. comparison
    end
  },
  have = {
    test = function(v, x)
      if type(v[1]) ~= 'table' then
        error('expected ' .. tostring(v[1]) .. ' to be a table')
      end

      return has(v[1], x), 'expected ' .. tostring(v[1]) .. ' to contain ' .. tostring(x)
    end
  },
  fail = { 'with',
    test = function(v, pattern)
      local ok, err = pcall(unpack(v))

      if pattern then
        return not ok and string.find(err, pattern), 'expected ' .. tostring(v[1]) .. ' to fail with error matching "' .. pattern .. '"'
      else
        return not ok, 'expected ' .. tostring(v[1]) .. ' to fail'
      end
    end
  },
  with = {
    test = function(v, pattern)
      local ok, message = pcall(unpack(v))
      return not ok and message:match(pattern), 'expected ' .. tostring(v[1]) .. ' to fail with error matching "' .. pattern .. '"'
    end
  },
  match = {
    test = function(v, pattern)
      local value = tostring(v[1])
      local result = string.find(value, pattern)
      return result ~= nil, 'expected ' .. value .. ' to match pattern [[' .. pattern .. ']]'
    end
  },
  approximately = { 'be', 'equal',
    chain = function(a, x) a.epsilon = x or 1e-3 end
  }
}

function lust.expect(...)
  local assertion = { action = '', negate = false, epsilon = 0, n = select('#', ...), ... }

  setmetatable(assertion, {
    __index = function(t, k)
      if has(paths[rawget(t, 'action')], k) then
        rawset(t, 'action', k)
        local chain = paths[rawget(t, 'action')].chain
        if chain then chain(t) end
        return t
      end
      return rawget(t, k)
    end,
    __call = function(t, ...)
      if paths[t.action].test then
        local res, err = paths[t.action].test(t, ...)
        if assertion.negate then
          res = not res
          err = err:gsub(' to ', ' to not ', 1)
        end
        if not res then
          error(err or 'unknown failure', 2)
        end
      elseif paths[t.action].chain then
        paths[t.action].chain(t, ...)
        return t
      end
    end
  })

  return assertion
end

function lust.spy(target, name, run)
  local spy = {}
  local subject

  local function capture(...)
    table.insert(spy, {...})
    return subject(...)
  end

  if type(target) == 'table' then
    subject = target[name]
    target[name] = capture
  else
    run = name
    subject = target or function() end
  end

  setmetatable(spy, {__call = function(_, ...) return capture(...) end})

  if run then run() end

  return spy
end

lust.test = lust.it
lust.paths = paths

return lust
