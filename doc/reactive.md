# Package reactive

## Introduction to reactive

The `reactive` package gives Maxima first-class **signals**. A signal is a named, bounded, mutable numeric value that appears in expressions as a noun form printed `signal(name)`. Maxima keeps the noun form symbolic through simplification, `diff`, `integrate`, `limit`, `solve` and `subst`, so an expression built from signals keeps its dependency on them. The noun's argument is a symbol from a private Lisp package, so a user variable with the same name as a signal never captures it.

Downstream packages such as `ax-plots` walk an expression with `collect_signals`, emit a UI control for each signal, and call `resolve_signals` to substitute current values before sampling. When a control moves, the host calls `signal_set` and re-evaluates the view.

To use the package:

```
load("reactive");
```

### Quick start

```maxima
(%i1) load("reactive")$
(%i2) k : widget_slider("frequency", 0.1, 5);
(%o2)                    signal(frequency)
(%i3) expr : sin(k*x);
(%o3)                 sin(signal(frequency) x)
(%i4) diff(expr, x);
(%o4)        signal(frequency) cos(signal(frequency) x)
(%i5) resolve_signals(expr);
(%o5)                       sin(0.1 x)
(%i6) signal_set("frequency", 2.5)$
(%i7) resolve_signals(expr);
(%o7)                       sin(2.5 x)
```

### Names

A signal name is a string of 1 to 128 ASCII letters, digits or underscores. The constructors reject anything else, because the aximar host applies the same rule when a slider moves. Names are case-sensitive: `"freq"` and `"Freq"` are different signals.

### Registry

Each signal lives in a per-session registry keyed by name. An entry is a list of `key = value` equations:

```maxima
[name = "freq", kind = slider, lo = 0.1, hi = 5.0, value = 0.1]
```

- `lo`, `hi` and `value` are floats.
- `kind` is one of `slider`, `number`, `checkbox`, `dropdown`.
- Dropdowns add `choices = [...]`.

Read fields with `signal_field`, `signal_value` or `signal_kind` rather than by position. New widget kinds will add fields.

Calling a `widget_*` constructor with an existing name replaces that entry. Re-running a notebook cell therefore resets the signal to its initial value.

### Limitations

- Numeric evaluation does not resolve signals automatically. Call `resolve_signals` before `float`, plotting or sampling. (`ax-plots` does this for you.)
- `signal_set` does not clamp slider or number values to `[lo, hi]`. The caller (normally the renderer) enforces the range.
- The package has no event-bound widgets yet (buttons, click or drag on a plot).

## Definitions for reactive

### Function: widget_slider (name, lo, hi)

Registers a slider signal called `name` on the range `[lo, hi]` and returns its noun form. The initial value is `lo`. `name` must be a valid signal name, and `lo` must be less than `hi`.

```maxima
(%i1) k : widget_slider("freq", 0.1, 5);
(%o1)                      signal(freq)
(%i2) signal_value(k);
(%o2)                           0.1
```

### Function: widget_number (name, lo, hi, initial)

Registers a signal that the renderer shows as a numeric text input instead of a drag track. `initial` must lie in `[lo, hi]`.

```maxima
(%i1) n : widget_number("threshold", 0, 100, 42)$
(%i2) signal_value(n);
(%o2)                          42.0
```

### Function: widget_checkbox (name, initial)

Registers a boolean signal stored as `0.0` or `1.0`. `initial` may be `true`, `false`, `0` or `1`. Multiply by the signal to switch a term on and off.

```maxima
(%i1) damped : widget_checkbox("damped", true)$
(%i2) resolve_signals(exp(-damped*t) * sin(t));
                                - 1.0 t
(%o2)                         %e        sin(t)
```

### Function: widget_dropdown (name, choices)

Registers a signal whose value must be one of the numbers in the non-empty list `choices`. The initial value is the first choice, and `lo`/`hi` are the smallest and largest choices.

```maxima
(%i1) m : widget_dropdown("mode", [1, 2, 4, 8])$
(%i2) signal_meta(m);
(%o2) [name = mode, kind = dropdown, lo = 1.0, hi = 8.0, value = 1.0, 
                                                choices = [1.0, 2.0, 4.0, 8.0]]
```

### Function: signal (name)

Returns the noun form for the registered signal `name`. Use it to refer to a signal by name in an expression you type by hand. Signals an error if no signal has that name.

```maxima
(%i1) widget_slider("freq", 0.1, 5)$
(%i2) resolve_signals(sin(signal("freq") * x));
(%o2)                       sin(0.1 x)
```

### Function: signal_p (x)

Returns `true` if `x` is a signal noun form and `false` otherwise.

### Function: signal_name (x)

Returns the name string from the signal noun form `x`. Signals an error if `x` is not a signal.

### Function: signal_value (target)

Returns the current value of a signal as a float. `target` may be a signal noun form or a name string. Signals an error if no signal has that name.

### Function: signal_kind (target)

Returns the widget kind of `target`: `slider`, `number`, `checkbox` or `dropdown`.

### Function: signal_field (target, key)

Returns the value of field `key` in the registry entry for `target`, or `false` if the entry has no such field.

```maxima
(%i1) widget_slider("freq", 0.1, 5)$
(%i2) signal_field("freq", hi);
(%o2)                           5.0
(%i3) signal_field("freq", choices);
(%o3)                          false
```

### Function: signal_meta (target)

Returns the full registry entry for `target` as a list of `key = value` equations. UI builders use this to choose and configure a control.

### Function: signal_list ()

Returns the names of every registered signal, sorted.

### Function: signal_set (target, value)

Sets the current value of a signal and returns the new value as a float. `target` may be a signal noun form or a name string.

- For a checkbox, `value` may be `true`, `false`, `0` or `1`. Anything else is an error.
- For a dropdown, `value` must be one of the registered choices.
- For a slider or number, any number is accepted and not clamped.

```maxima
(%i1) widget_slider("freq", 0.1, 5)$
(%i2) signal_set("freq", 2.5);
(%o2)                           2.5
```

### Function: collect_signals (expr)

Returns the names of the signals that appear in `expr`, each once, in the order a depth-first walk of the simplified expression first meets them. Maxima may reorder terms during simplification, so the order can differ from the order in your input.

```maxima
(%i1) a : widget_slider("a", 0, 1)$
(%i2) b : widget_slider("b", 0, 1)$
(%i3) collect_signals(a*x + b*sin(a*x));
(%o3)                         [b, a]
```

### Function: resolve_signals (expr)

Returns `expr` with every signal replaced by its current value. Returns `expr` unchanged if it has no signals. Signals an error if `expr` names a signal that is no longer registered.

### Function: reactive_reset ()

Clears the registry. Noun forms created before the reset still exist, but `signal_value` and `resolve_signals` fail on them until you register the names again. Tests and notebook restarts use this.
