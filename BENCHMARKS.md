# Benchmarks

Performance comparison of Minitwin against the libraries it is most directly
comparable to: Disposable (twin layer), Representable (serializer) and Reform
(form/validation). Numbers are machine-specific; reproduce them yourself with
the command below.

## Environment

- Ruby: `ruby 4.0.2 (2026-03-17 revision d3da9fec82) +PRISM [x86_64-linux]`
- OS: `Linux 6.8.0-124-generic x86_64`
- minitwin `1.0.0`, disposable `0.6.3`, representable `3.2.0`, reform `2.6.2`, reform-rails `0.3.1`, benchmark-ips `2.15.1`, benchmark-memory `0.2.0`

## How to reproduce

```bash
bundle install
bundle exec rake benchmark   # writes benchmark/results/latest.txt
```

## What is compared where

Each operation is benchmarked only against libraries that perform the same
operation natively. No faked bars: where a library does not support an
operation, it is marked N/A.

| Operation | minitwin | disposable | representable | reform |
|---|---|---|---|---|
| Construct | `from_hash` + `from_object` ×4 backing types | `.new(model)` ×4 | N/A | — |
| Read | ✓ | ✓ | N/A (render/parse layer) | — |
| Serialize | `to_hash` / `to_json` | N/A | `to_hash` / `to_json` | — |
| Mutate | assign + `sync` | assign + `sync` | N/A | — |
| Validate | `valid?` | — | — | `validate(params)` |

Notes on fairness:

- Disposable and Minitwin both wrap a domain model. Minitwin additionally
  supports `from_hash` (no backing object), shown as its own bar.
- Representable is a render/parse layer — N/A for Read/Mutate. Its nested
  `from_hash` parse also raises on Ruby 4.0 (representable 3.2.0), so Construct
  is N/A; it is benchmarked for render (Serialize) only.
- Disposable's `to_nested_hash` raises `NameError: uninitialized constant
  Disposable::Rescheme` on disposable 0.6.3 / Ruby 4.0, so it is N/A for
  Serialize.
- The backing-object type barely affects either library, so it is varied only
  in Construct (and as the mutate model).
- Reform validates via the same ActiveModel backend Minitwin uses (via
  `reform-rails`). But Reform has **no validate-only call**: `validate(params)`
  also *populates* the form (deserializing params through Representable), so its
  bar includes population, whereas `minitwin valid?` runs on an already-built
  twin and measures validation only. Read the Validate section with that in mind.

## Construct (iterations/sec — higher is better)

| Variant | i/s | Allocated |
|---|---|---|
| disposable new(PlainClass) | 77,416 | 2,240 B |
| disposable new(Data) | 75,736 | 2,240 B |
| disposable new(Struct) | 74,155 | 2,240 B |
| disposable new(OpenStruct) | 73,309 | 2,240 B |
| minitwin from_hash | 48,851 | 2,520 B |
| minitwin from_object(PlainClass) | 37,168 | 3,480 B |
| minitwin from_object(Struct) | 36,995 | 3,480 B |
| minitwin from_object(OpenStruct) | 36,989 | 3,480 B |
| minitwin from_object(Data) | 36,977 | 3,480 B |
| representable | N/A (nested parse raises on Ruby 4.0) | — |

Disposable constructs ~1.5–2× faster than Minitwin and allocates a bit less.
The backing object type is not a meaningful lever for either library. Minitwin's
object-free `from_hash` is its fastest construction path.

## Read (iterations/sec)

Reads a flat field, a nested field, and iterates the collection.

| Variant | i/s | Allocated |
|---|---|---|
| disposable read | 1,622,772 | 160 B |
| minitwin read | 914,041 | 0 B |
| representable | N/A (render/parse layer) | — |

Both are sub-microsecond. Disposable reads ~1.8× faster; Minitwin allocates
nothing on read, Disposable allocates a little per access.

## Serialize (iterations/sec)

| Variant | i/s | Allocated |
|---|---|---|
| minitwin to_hash | 124,208 | 360 B |
| representable to_hash | 40,633 | 3,400 B |
| minitwin to_json | 102,861 | 888 B |
| representable to_json | 31,262 | 4,160 B |
| disposable | N/A (to_nested_hash raises on Ruby 4.0) | — |

Minitwin's `to_hash` is ~3.1× faster than Representable's with ~9× less memory;
for JSON it is ~3.3× faster with ~4.7× less memory, and JSON is built in.
Serialization is Minitwin's strongest area.

## Mutate (iterations/sec)

Assign a field, then push it back to the model in place. Disposable's `sync`
never validates, so the like-for-like bar is `minitwin sync(validate: false)`;
the default minitwin bar additionally runs a full `valid?` pass. (Reform is
omitted — its `sync` *is* Disposable's; Reform only extends it.)

| Variant | i/s | Allocated |
|---|---|---|
| minitwin assign+sync (validate: false) | 96,705 | 640 B |
| disposable assign+sync | 63,386 | 2,600 B |
| minitwin assign+sync (default, validates) | 40,485 | 1,160 B |
| representable | N/A | — |

For the same operation — write the twin's values back to the model — Minitwin is
~1.5× **faster** than Disposable and allocates ~4× less. Minitwin's *default*
`sync` is slower only because it also validates (Disposable's never does); that
validation pass is the entire difference.

## Validate (iterations/sec)

| Variant | valid i/s | invalid i/s |
|---|---|---|
| minitwin valid? | 120,804 | 104,738 |
| reform validate | 6,274 | 1,163 |

**Read with the fairness note above.** `minitwin valid?` validates an
already-built twin. `reform validate(params)` is Reform's only validation entry
point and *also* populates the form (params → Representable deserialization →
nested forms) before validating, which dominates its cost — hence ~19× (valid)
and ~90× (invalid) slower here. For the "validate an in-memory object" use case
Minitwin is far lighter; for Reform's params-driven form workflow the number
reflects the whole populate-and-validate cycle.

## Takeaways

- **Read:** Minitwin is the fastest here (~1.6× over Disposable, zero
  allocation) — plain getters compile to `attr_reader`.
- **Serialize:** Minitwin renders ~3× faster than Representable with far fewer
  allocations for both hash and JSON, and ships native JSON.
- **Construct:** Disposable is ~1.4–1.8× faster; Minitwin's overhead is
  ActiveModel + coercion + the nested twin. Minitwin allocates less than
  Disposable on `from_hash` (1,960 vs 2,240 B).
- **Mutate:** for the same write-back, Minitwin's `sync(validate: false)` is
  ~1.5× faster than Disposable and allocates ~4× less. Minitwin's *default*
  `sync` is slower only because it validates, which Disposable never does.
- **Validate:** for validating an in-memory object Minitwin is dramatically
  lighter than Reform, which couples population and validation in one call.
- **Backing object type is not a meaningful performance lever** for Minitwin
  `from_object` or Disposable — OpenStruct/Data/Struct/plain class all land in
  the same band.
