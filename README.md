Cutoff
==================

[![Gem Version](https://badge.fury.io/rb/cutoff.svg)](https://badge.fury.io/rb/cutoff)
[![CI](https://github.com/justinhoward/cutoff/workflows/CI/badge.svg)](https://github.com/justinhoward/cutoff/actions?query=workflow%3ACI+branch%3Amaster)
[![Code Quality](https://app.codacy.com/project/badge/Grade/2748da79ec294f909996a56f11caac4a)](https://www.codacy.com/gh/justinhoward/cutoff/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=justinhoward/cutoff&amp;utm_campaign=Badge_Grade)
[![Inline docs](http://inch-ci.org/github/justinhoward/cutoff.svg?branch=master)](http://inch-ci.org/github/justinhoward/cutoff)

A deadlines library for Ruby inspired by Shopify and
[Kir Shatrov's blog series][kir shatrov].


```ruby
Cutoff.wrap(5) do
  sleep(4)
  Cutoff.checkpoint! # still have time left
  sleep(2)
  Cutoff.checkpoint! # raises an error
end
```

It has a built-in patch for Mysql2 to auto-insert checkpoints and timeout query
hints.

```ruby
require 'cutoff/patch/mysql2'

client = Mysql2::Client.new
Cutoff.wrap(5) do
  client.query('SELECT * FROM dual WHERE sleep(2)')

  # Cutoff will automatically insert a /*+ MAX_EXECUTION_TIME(3000) */
  # hint so that MySQL will terminate the query after the time remaining
  #
  # Or if time already expired, this will raise an error and not be executed
  client.query('SELECT * FROM dual WHERE sleep(1)')
end
```

Why use deadlines?
------------------------

If you've already implemented timeouts for your networked dependencies, then you
can be sure that no single HTTP request or database query can take longer than
the time allotted to it.

For example, let's say you set a query timeout of 3 seconds. That means no
single query will take longer than 3 seconds. However, imagine a bad controller
action or background job executes 100 slow queries. In that case, the queries
add up to 300 seconds, much too long.

Deadlines keep track of the total elapsed time in a request of job and interrupt
it if it takes too long.

Installation
---------------

Add it to your `Gemfile`:

```ruby
gem 'cutoff'
```

Or install it manually:

```sh
gem install cutoff
```

API Documentation
------------------

API docs can be read [on rubydoc.info][api docs], inline in the source code, or
you can generate them yourself with Ruby `yard`:

```sh
bin/yardoc
```

Then open `doc/index.html` in your browser.

Usage
-----------

The simplest way to use Cutoff is to use its class methods, although it can be
used in an object-oriented manner as well.

### Wrapping a block

```ruby
Cutoff.wrap(3.5) do # number of allowed seconds for this block
  # Do something time-consuming here

  # At a good stopping point, call checkpoint!
  # If the allowed time is exceeded, this raises a Cutoff::CutoffExceededError
  # otherwise, it does nothing
  Cutoff.checkpoint!

  # Now continue executing
end
```

### Creating your own instance

```ruby
cutoff = Cutoff.new(6.4)
sleep(10)
cutoff.checkpoint! # Raises Cutoff::CutoffExceededError
```

### Getting cutoff details

Cutoff has some instance methods to get information about the time remaining,
etc.

```ruby
# If you're using Cutoff class methods, you can get the current instance
cutoff = Cutoff.current # careful, this will be nil if a cutoff isn't running
```

Once you have an instance, either by creating your own or from `.current`, you
have access to these methods.

```ruby
cutoff = Cutoff.current

# These return Floats
cutoff.allowed_seconds # Total seconds allowed (the seconds given when cutoff was started)
cutoff.seconds_remaining # Seconds left
cutoff.elapsed_seconds # Seconds since the cutoff was started
cutoff.ms_remaining # Milliseconds left

cutoff.exceeded? # True if the cutoff is expired
```

Patches
-------------

Cutoff is in early stages, but it aims to provide patches for common networked
dependencies. The first of these is the `mysql2` patch. It is not loaded by
default, so you need to require it manually.

```ruby
# In your Gemfile
gem 'cutoff', require: %w[cutoff cutoff/patch/mysql2]
```

```ruby
# Or manually
require 'cutoff'
require 'cutoff/patch/mysql2'
```

Once it is enabled, any `Mysql2::Client` object will respect the current cutoff
if one is set.

```ruby
client = Mysql2::Client.new
Cutoff.wrap(3) do
  sleep(4)

  # This query will not be executed because the time is already expired
  client.query('SELECT * FROM users')
end

Cutoff.wrap(3) do
  sleep(1)

  # There are 2 seconds left, so a MAX_EXECUTION_TIME query hint is added
  # to inform MySQL we only have 2 seconds to execute this query
  # The executed query will be "SELECT /*+ MAX_EXECUTION_TIME(2000) */ * FROM users"
  client.query('SELECT * FROM users')

  # MySQL only supports MAX_EXECUTION_TIME for SELECTs so no query hint here
  client.query("INSERT INTO users(first_name) VALUES('Joe')")

  sleep(3)

  # We don't even execute this query because time is already expired
  # This limit applies to all queries, including INSERTS, etc
  client.query('SELECT * FROM users')
end
```

Timing a Rails Controller
---------------------------

One use of a cutoff is to add a deadline to a Rails controller action.

```ruby
around_action { |_controller, action| Cutoff.wrap(2.5) { action.call } }
```

Now in your action, you can call `checkpoint!`, or if you're using the Mysql2
patch, checkpoints will be added automatically.

```ruby
def index
  # Do thing one
  Cutoff.checkpoint!

  # Do something else
end
```

Consider adding a global error handler for the `Cutoff::CutoffExceededError`

```ruby
class ApplicationController < ActionController::Base
  rescue_from Cutoff::CutoffExceededError, with: :handle_cutoff_exceeded

  def handle_cutoff_exceeded
    # Render a nice error page
  end
end
```

Multi-threading
-----------------

In multi-threaded environments, cutoff class methods are independent in each
thread. That means that if you start a cutoff in one thread then start a new
thread, the second thread _will not_ inherit the cutoff from its parent thread.

```ruby
Cutoff.wrap(6) do
  Thread.new do
    # This code can run as long as it wants because the class-level
    # cutoff is independent

    Cutoff.wrap(3) do
      # However, you can start a new cutoff inside the new thread and it
      # will not affect any other threads
    end
  end
end
```

The same rules apply to fibers. Each fiber has independent class-level cutoff
instances. This means you can use Cutoff in a multi-threaded web server or job
runner without worrying about thread conflicts.

If you want to use a single cutoff for multi-threading, you'll need to pass an
instance of a Cutoff.

```ruby
cutoff = Cutoff.new(6)
cutoff.checkpoint! # parent thread can call checkpoint!
Thread.new do
  # And the child thread can use the same cutoff
  cutoff.checkpoint!
end
end
```

However, because patches use the class-level Cutoff methods, this only works
when calling cutoff methods manually.

Nested Cutoffs
-----------------

When using the Cutoff class methods, it is possible to nest multiple Cutoff
contexts with `.wrap` or `.start`.

```ruby
Cutoff.wrap(10) do
  # This outer block has a timeout of 10 seconds
  Cutoff.wrap(3) do
    # But this inner block is only allowed to take 3 seconds
  end
end
```

A child cutoff can never be set for longer than the remaining time of its parent
cutoff. So if a child is created for longer than the remaining allowed time, it
will be reduced to the remaining time of the outer cutoff.

```ruby
Cutoff.wrap(5) do
  sleep(4)
  # There is only 1 second remaining in the parent
  Cutoff.wrap(3) do
    # So this inner block will only have 1 second to execute
  end
end
```

About the Timer
-------------------

Cutoff tries to use the best timer available on whatever platform it's running
on. If a monotonic clock is available, that will be used, or failing that, if
concurrent-ruby is loaded, that will be used. If neither is available,
`Time.now` is used.

This mean that Cutoff tries its best to prevent time from travelling backwards.
However, the clock uniformity, resolution, and stability is determined by the
system Cutoff is running on.

Manual start and stop
----------------------

If you find that `Cutoff.wrap` is too limiting for some integrations, Cutoff
also provides the `start` and `stop` methods. Extra care is required to use
these to prevent a cutoff from being leaked. Every `start` call must be
accompanied by a `stop` call, otherwise the cutoff will continue to run and
could affect a context other than the intended one.

```ruby
Cutoff.start(2.5)
begin
  # Execute code here
  Cutoff.checkpoint!
ensure
  # Always stop in an ensure statement to make sure an exception cannot leave
  # a cutoff running
  Cutoff.stop
end

# Nested cutoffs are still supported
outer = Cutoff.start(10)
begin
  # Outer 10s cutoff is used here
  Cutoff.checkpoint!

  inner = Cutoff.start(5)
  begin
    # Inner 5s cutoff is used here
    Cutoff.checkpoint!
  ensure
    # Stops the inner cutoff
    # We don't need to pass the instance here, but it does prevent some types of mistakes
    Cutoff.stop(inner)
  end
ensure
  # Stops the outer cutoff
  Cutoff.stop(outer)
end

Cutoff.start(10)
Cutoff.start(5)
begin
  # Code here
ensure
  # This stops all cutoffs
  Cutoff.clear_all
end
```

Be careful, you can easily make a mistake when using this API, so prefer `.wrap`
when possible.

Design Philosophy
-------------------

Cutoff is designed to only stop code execution at predictable points. It will
never interrupt a running program unless:

- `checkpoint!` is called
- a network timeout is exceeded

Patches such as the current Mysql2 patch are designed to ease the burden on
developers to manually call `checkpoint!` or configure network timeouts. The
ruby `Timeout` class is not used. See Julia Evans' post on [Why Ruby's Timeout
is dangerous][julia_evans].

Patches are only applied by explicit opt-in, and Cutoff can always be used as a
standalone library.

[julia_evans]: https://jvns.ca/blog/2015/11/27/why-rubys-timeout-is-dangerous-and-thread-dot-raise-is-terrifying/
[kir shatrov]: https://kirshatrov.com/posts/scaling-mysql-stack-part-2-deadlines/
[api docs]: https://www.rubydoc.info/github/justinhoward/cutoff/master
