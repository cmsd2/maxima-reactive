# reactive

First-class **signals** for Maxima.  A signal is a named, bounded,
mutable numeric value with identity that survives normal symbolic
processing.  Downstream packages (notably `ax-plots`) can detect
signals in user expressions, emit UI controls bound to them, and
re-render when the controls fire.

This is paradigm-1 of the *reactive views* roadmap (see
[ax-plots/doc/design/reactive-views.md](../ax-plots/doc/design/reactive-views.md)) —
the bottom layer that everything above (widgets, views, streaming)
builds on.

## Install

```
mxpm install --path . --editable
```

## Quick tour

```maxima
load("reactive")$

k : widget_slider("frequency", 0.1, 5)$
/* k is the noun form signal("frequency"); its current value is 0.1 */

expr : sin(k*x)$
/* sin(signal("frequency") * x) — the signal stays symbolic */

diff(expr, x)$
/* signal("frequency") * cos(signal("frequency") * x)
 *   — symbolic differentiation works without resolving */

resolve_signals(expr)$            /* sin(0.1*x) */

signal_set("frequency", 2.5)$
resolve_signals(expr)$            /* sin(2.5*x) */
```

## API

| Function | Purpose |
| --- | --- |
| `widget_slider(name, lo, hi)` | register a slider-flavoured signal; returns a noun form `signal(name)` with initial value `lo` |
| `signal_p(x)` | `true` iff `x` is a signal noun form |
| `signal_name(x)` | extract the name from a signal noun form |
| `signal_value(target)` | current numeric value (accepts name string or noun form) |
| `signal_meta(target)` | full registry entry `[name, lo, hi, current, kind]` |
| `signal_list()` | sorted list of every registered signal name |
| `signal_set(target, v)` | update the current value; returns the new float |
| `collect_signals(expr)` | walk `expr`, return a list of unique signal names |
| `resolve_signals(expr)` | substitute every signal in `expr` with its current value |
| `reactive_reset()` | drop every registered signal (tests / notebook re-runs) |

## What v0 deliberately doesn't do

- **Automatic dependency tracking via a `meval` read hook.**  That
  needs a Maxima core patch; users must call `resolve_signals(expr)`
  explicitly before any numeric evaluation.  Sampling code in
  `ax-plots` does this for you.
- **Cross-cell widget identity.**  Each notebook cell that calls
  `widget_slider("freq", …)` registers/overwrites the same entry;
  there's no automatic re-binding when the cell re-runs.
- **Widget types beyond `widget_slider`.**  Button, dropdown,
  click-on-plot, drag point — all coming, all on the same scaffolding.
- **The renderer ↔ kernel bidirectional channel.**  That lives in
  `aximar` and the renderers, not in this Maxima package.  When
  the renderer pushes a slider event back to the kernel, the kernel
  side does `signal_set(name, v)` and re-evaluates whatever
  expression the view was built from.

## License

MIT
