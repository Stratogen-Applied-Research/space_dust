# SpaceDust

Space Dust is an astrodynamics library written in elixir

## Installation

```elixir
def deps do
  [
    {:space_dust, "~> 0.1.0"}
  ]
end
```

## Functions

### `SpaceDust.Time`
Conversions between UTC and:
 - International Atomic Time (TAI)
 - Terrestrial Time (TT)
 - Julian Dates

### `SpaceDust.Math`
Operations on 3D vectors & 3x3 Matrices

### `SpaceDust.State`
State vector definitions & conversions between ECI J2000 and:
 - True Equator Mean Equinox (TEME)

### `SpaceDust.Propagator`
Functions for propagating state vectors, including:
 - Simplified General Perturbations 4 (SGP4) algorithm

### `SpaceDust.Data`
Data tables & retrieval utilities for:
 - Earth Orientation Parameters (EOP)
 - IAU1980 nutation data
 - Leap seconds

### `SpaceDust.Utils`
Utility functions, including:
 - Constants
 - Parsing of Two-Line Element sets (TLEs)

### `SpaceDust.Ingest`
API clients for:
 - Celestrak TLEs
