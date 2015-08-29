Lust
===

Lust is a small library that tests Lua code.

Usage
---

Copy the `lust.lua` file to a project directory and require it, which returns a table that includes all of the functionality.

```Lua
local lust = require 'lust'

lust.describe('my project', function()
  lust.describe('module1', function() -- Can be nested
    lust.it('feature1', function()
      lust.expect(1).to.be.a('number') -- Pass
      lust.expect('astring').to.equal('astring') -- Pass
    end)

    lust.it('feature2', function()
      lust.expect(nil).to.exist() -- Fail
    end)
  end)
end)
```

Documentation
---

`lust.describe(name, func)`

Used to declare a group of tests.  `name` is a string used to describe the group, and `func` is a function containing all tests and `describe` blocks in the group.  Groups created using `describe` can be nested.

`lust.it(name, func)`

Used to declare a test, which consists of a set of assertions.  `name` is a string used to describe the test, and `func` is a function containing the assertions.

### Assertions

Lust uses "expect style" assertions.  An assertion begins with `lust.expect(value)` and other modifiers can be chained after that:

`lust.expect(x).to.exist()`

Fails only if `x` is `nil`.

`lust.expect(x).to.have(y)`

If `x` is a table, ensures that at least one of its keys contains the value `y` using the `==` operator.  If `x` is not a table, this assertion fails.

`lust.expect(x).to.equal(y)`

Performs a strict equality test, failing if x and y have different types or values.  Tables are tested by recursively ensuring that both tables contain the same set of keys and values.  Metatables are not taken into consideration.

`lust.expect(x).to.be(y)`

Performs an equality test using the `==` operator.  Fails if `x ~= y`.

`lust.expect(x).to.be.truthy()` and `lust.expect(x).to.be.falsy()`

Truthy fails if `x` is `nil` or `false`.  Falsy fails if `x` is not `nil` or `false`.

`lust.expect(x).to.be.a(y)`

Fails if `type(x)` is not equal to `type(y)`.

### Befores and Afters

You can define functions that are called before and after every call to `lust.it`:

`lust.before(fn)`

Set a function that is called before every test, or `nil` to clear the function.  `fn` will be passed a single string containing the name of the test about to be run.

`lust.after(fn)`

Set a function that is called after every test, or `nil` to clear the function.  `fn` will be passed a single string containing the name of the test that was finished.

### Output Options

Coming soon.

License
---

MIT, see LICENSE for details.
