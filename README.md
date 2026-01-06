# SpaceDust

SpaceDust is a comprehensive astrodynamics library for Elixir, providing tools for satellite tracking, orbital mechanics, coordinate transformations, and ground-based observation calculations.

## Features

- Time system conversions (UTC, TAI, TT, Julian Date, GPS)
- Coordinate frame transformations (ECI J2000, TEME, ECEF, Geodetic)
- Orbital element conversions (Cartesian to/from Keplerian)
- TLE parsing and SGP4 propagation
- Earth Orientation Parameters (EOP) with prediction support
- Celestial body position calculations (Sun, Moon)
- Ground-based observation calculations (Azimuth/Elevation, Right Ascension/Declination)
- High-performance numerical operations via Nx tensors

## Installation

Add `space_dust` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:space_dust, "~> 0.2.0"}
  ]
end
```

## Quick Start

### Satellite Tracking Example

Track a geostationary satellite from a ground station:

```elixir
alias SpaceDust.Ingest.Celestrak
alias SpaceDust.Utils.Tle
alias SpaceDust.State.{TEMEState, GeodeticState}
alias SpaceDust.State.Transforms
alias SpaceDust.Observations

# Fetch latest TLE for a satellite (NORAD catalog number)
{:ok, tle} = Celestrak.pullLatestTLE("40425")  # GALAXY-16

# Define ground observer location (Denver, CO)
observer = GeodeticState.new(39.7392, -104.9903, 1.6)  # lat, lon, alt (km)

# Propagate satellite to current time
epoch = DateTime.utc_now()
{position, velocity} = Tle.getRVatTime(tle, epoch)

# Convert from TEME to ECI J2000
teme_state = TEMEState.new(epoch, position, velocity)
eci_state = Transforms.teme_to_eci(teme_state)

# Calculate observation angles from ground station
az_el = Observations.compute_az_el(observer, eci_state)

IO.puts("Azimuth: #{az_el.azimuth * 180 / :math.pi()}")
IO.puts("Elevation: #{az_el.elevation * 180 / :math.pi()}")
IO.puts("Range: #{az_el.range} km")
IO.puts("Above Horizon: #{Observations.AzEl.above_horizon?(az_el)}")
```

## Modules

### SpaceDust.Time

Time system representations and conversions between different astronomical time scales.

| Module | Description |
|--------|-------------|
| `SpaceDust.Time.UTC` | Coordinated Universal Time (civil time standard) |
| `SpaceDust.Time.TAI` | International Atomic Time (continuous, no leap seconds) |
| `SpaceDust.Time.TT` | Terrestrial Time (modern astronomical standard) |
| `SpaceDust.Time.JulianDate` | Julian Date and Modified Julian Date |
| `SpaceDust.Time.GMST` | Greenwich Mean Sidereal Time |
| `SpaceDust.Time.GPS` | GPS Time |
| `SpaceDust.Time.Transforms` | Conversions between time systems |

#### Example: Time Conversions

```elixir
alias SpaceDust.Time.{UTC, Transforms, JulianDate}

# Create UTC time from ISO8601 string
utc = UTC.from_iso8601!("2026-01-06T12:00:00Z")

# Convert to other time systems
tai = Transforms.utc_to_tai(utc)
tt = Transforms.utc_to_tt(utc)
jd = Transforms.utc_to_jd(utc)

# Get Modified Julian Date
mjd = UTC.to_mjd(utc)

# Calculate Julian centuries since J2000.0
centuries = JulianDate.julian_centuries_j2000(jd)
```

### SpaceDust.State

State vector representations in various coordinate frames.

| Module | Description |
|--------|-------------|
| `SpaceDust.State.ECIState` | Earth-Centered Inertial J2000 frame |
| `SpaceDust.State.TEMEState` | True Equator Mean Equinox frame (SGP4 output) |
| `SpaceDust.State.ECEFState` | Earth-Centered Earth-Fixed frame |
| `SpaceDust.State.GeodeticState` | Geodetic coordinates (lat/lon/alt on WGS84) |
| `SpaceDust.State.KeplerianElements` | Classical orbital elements |
| `SpaceDust.State.Transforms` | Coordinate frame transformations |

#### Example: Coordinate Transformations

```elixir
alias SpaceDust.State.{ECIState, TEMEState, KeplerianElements, Transforms}

# Create an ECI state vector
eci = ECIState.new(
  ~U[2026-01-06 12:00:00Z],
  {7000.0, 0.0, 0.0},      # position [km]
  {0.0, 7.5, 0.0}          # velocity [km/s]
)

# Convert to Keplerian elements
kepler = Transforms.eci_to_keplerian(eci)
IO.puts("Semi-major axis: #{kepler.semi_major_axis} km")
IO.puts("Eccentricity: #{kepler.eccentricity}")
IO.puts("Orbital period: #{KeplerianElements.period(kepler)} seconds")

# Convert to ECEF (rotating frame)
ecef = Transforms.eci_to_ecef(eci)
```

### SpaceDust.Observations

Angular observation calculations for ground-based tracking.

| Module | Description |
|--------|-------------|
| `SpaceDust.Observations` | Main observation computation functions |
| `SpaceDust.Observations.RaDec` | Right Ascension / Declination observations |
| `SpaceDust.Observations.AzEl` | Azimuth / Elevation observations |

#### Example: Observation Calculations

```elixir
alias SpaceDust.State.{ECIState, GeodeticState}
alias SpaceDust.Observations

# Ground observer
observer = GeodeticState.new(40.0, -105.0, 1.6)  # Denver, CO

# Satellite position in ECI
satellite = ECIState.new(
  ~U[2026-01-06 12:00:00Z],
  {-41851.0, -5169.0, 11.7},
  {0.377, -3.066, 0.0}
)

# Compute topocentric observation angles
az_el = Observations.compute_az_el(observer, satellite)
ra_dec = Observations.compute_ra_dec(observer, satellite)

# Check visibility
if Observations.AzEl.above_horizon?(az_el) do
  IO.puts("Satellite is visible!")
  IO.puts("Look direction: #{Observations.AzEl.compass_direction(az_el)}")
end

# With angular rates
az_el_rates = Observations.compute_az_el(observer, satellite, include_rates: true)
```

### SpaceDust.Bodies

Celestial body parameters and position calculations.

| Module | Description |
|--------|-------------|
| `SpaceDust.Bodies.Earth` | Earth parameters, precession, nutation |
| `SpaceDust.Bodies.Sun` | Solar position in ECI frame |
| `SpaceDust.Bodies.Moon` | Lunar position in ECI frame |
| `SpaceDust.Bodies.Barycenter` | Earth-Moon barycenter calculations |

#### Example: Celestial Body Positions

```elixir
alias SpaceDust.Bodies.{Sun, Moon}

epoch = ~U[2026-01-06 12:00:00Z]

# Get Sun position in ECI (meters)
sun_pos = Sun.eci_position(epoch)

# Get Moon position in ECI (meters)
moon_pos = Moon.eci_position(epoch)

# Check if satellite is in Earth's shadow
satellite_eci = ECIState.new(epoch, {7000.0, 0.0, 0.0}, {0.0, 7.5, 0.0})
in_shadow = Sun.in_earth_shadow?(epoch, satellite_eci)
```

### SpaceDust.Data

Reference data tables and Earth Orientation Parameters.

| Module | Description |
|--------|-------------|
| `SpaceDust.Data.EOP` | Earth Orientation Parameters retrieval |
| `SpaceDust.Data.EOPCache` | High-performance EOP cache with interpolation |
| `SpaceDust.Data.IAU1980` | IAU 1980 nutation coefficients |
| `SpaceDust.Data.LeapSecond` | Leap second table |

The EOP data is sourced from IERS finals.all and includes predictions extending approximately one year into the future, ensuring continuous operation without warnings for near-future propagations.

### SpaceDust.Ingest

API clients for external data sources.

| Module | Description |
|--------|-------------|
| `SpaceDust.Ingest.Celestrak` | Celestrak TLE retrieval |

#### Example: Fetching TLEs

```elixir
alias SpaceDust.Ingest.Celestrak

# Fetch by NORAD catalog number
{:ok, tle} = Celestrak.pullLatestTLE("25544")  # ISS
IO.puts("Epoch: #{tle.epoch}")
IO.puts("Inclination: #{tle.inclinationDeg}")
IO.puts("Mean Motion: #{tle.meanMotion} rev/day")
```

### SpaceDust.Utils

Utility functions and constants.

| Module | Description |
|--------|-------------|
| `SpaceDust.Utils.Constants` | Physical and mathematical constants |
| `SpaceDust.Utils.Tle` | TLE parsing and SGP4 propagation |
| `SpaceDust.Utils.TwoLineElementSet` | TLE data structure |

#### Example: TLE Propagation

```elixir
alias SpaceDust.Utils.Tle
alias SpaceDust.State.TEMEState

# Parse TLE lines directly
line1 = "1 25544U 98067A   26006.50000000  .00016717  00000-0  10270-3 0  9002"
line2 = "2 25544  51.6400 208.1200 0001234  85.0000 275.0000 15.48919100123456"

{:ok, tle} = Tle.parseTLE(line1, line2)

# Propagate to a specific time
epoch = ~U[2026-01-06 18:00:00Z]
{position, velocity} = Tle.getRVatTime(tle, epoch)

# Create TEME state for further transformations
teme = TEMEState.new(epoch, position, velocity)
```

### SpaceDust.Math

Mathematical operations optimized for astrodynamics calculations.

| Module | Description |
|--------|-------------|
| `SpaceDust.Math.Vector` | 3D vector operations |
| `SpaceDust.Math.Matrix` | 3x3 matrix operations |
| `SpaceDust.Math.Functions` | Polynomial evaluation, angle utilities |

## Performance

SpaceDust uses several optimizations for high-performance calculations:

- **Nx Tensors**: Numerical operations leverage Nx for potential GPU/TPU acceleration
- **ETS Caching**: Earth Orientation Parameters are cached in ETS with binary search for O(log n) lookups
- **NIF-based SGP4**: Satellite propagation uses the sgp4_ex library with native C++ implementation

## Data Sources

- **Earth Orientation Parameters**: IERS finals.all (includes historical data and approximately 1 year of predictions)
- **TLE Data**: Celestrak GP catalog
- **Nutation Coefficients**: IAU 1980 theory

## License

MIT License - see LICENSE for details.

## Contributing

Contributions are welcome. Please open an issue or submit a pull request on GitHub.

## Links

- [GitHub Repository](https://github.com/Stratogen-Applied-Research/space_dust)
- [Hex Package](https://hex.pm/packages/space_dust)
- [Documentation](https://hexdocs.pm/space_dust)

