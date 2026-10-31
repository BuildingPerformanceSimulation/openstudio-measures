# Export Model to Speckle (OpenStudio ModelMeasure, Python)

Publishes an OpenStudio model to a [Speckle](https://speckle.systems) project as a new
model version: geometry plus the energy-model inputs, so the model can be viewed in the
Speckle web viewer, filtered by property, compared version-to-version and pulled into
Power BI / Databricks / Snowflake through Speckle's connectors. The OpenStudio model
is **not** modified, so the measure can sit anywhere in a workflow.

## What gets sent

| Speckle object | From | Key properties |
|---|---|---|
| Surface (mesh) | `OS:Surface` (windows cut out) | type, boundary condition (+ adjacent surface), sun/wind exposure, gross/net area, azimuth, tilt, WWR, construction, layers, U-factor, R-value |
| Sub Surface (mesh) | `OS:SubSurface` | type, parent surface (Speckle *host*), multiplier, area, construction, U-factor, SHGC, VT |
| Shading (mesh) | `OS:ShadingSurface` | site / building / space, group, transmittance schedule |
| Interior partition (mesh) | `OS:InteriorPartitionSurface` | group, area, internal-mass flag |
| Space (no geometry) | `OS:Space` | space type + standards tags, story, zone, floor area, volume, people / LPD / EPD / gas, infiltration, outdoor air |

Every surface also carries its space, thermal zone (multiplier, air loops, zone equipment,
thermostat schedules) and story data, so you can filter or colour any element by those
fields. Speckle relations: Building > Story > Space collection tree, **levels** (stories),
**rooms** (spaces), **hosts** (window → wall), **groups** (thermal zones), **systems**
(air loops). Scene views: by story/space (default), thermal zone, surface type, boundary
condition, construction. Model-level properties: building, site, weather file, climate
zone, OpenStudio version.

Geometry is in metres, site coordinates (north axis applied), triangulated with
OpenStudio's own triangulation. Values are SI.

## One-time setup

1. **Speckle token**: in app.speckle.systems, open your account settings and create a
   personal access token (under the developer / access tokens section) with read and
   write access to projects (`streams:read`, `streams:write`) plus `profile:read`. Then either:
   - set `SPECKLE_TOKEN` in the environment that launches OpenStudio (best for CLI /
     batch runs), or
   - paste it into the measure's *token* argument (saved in plain text in the .osw), or
   - leave both blank if you are signed in with a Speckle desktop connector.
2. **specklepy for OpenStudio's Python.** OpenStudio 3.11 embeds Python 3.12, so install
   the 3.12 wheels into a folder the measure looks in by default:

   ```bash
   python3 -m pip install --target ~/OpenStudio/python_packages \
       --python-version 3.12 --only-binary=:all: \
       --platform macosx_11_0_arm64 "specklepy[bundle]>=2026.9.1"
   ```

   (Any pip works — `--python-version`/`--platform` pick the right wheels. On Windows use
   `--platform win_amd64`; on Linux `--platform manylinux_2_28_x86_64`. ~185 MB, mostly
   pyarrow.) Use the *python_packages_path* argument for a different folder.

   *Fallback:* if that import fails, set *external_python* to any Python ≥ 3.11 that has
   `specklepy[bundle]` installed; the measure hands the payload to it.

3. **Corporate network (Netskope etc.).** If publishing fails with
   `CERTIFICATE_VERIFY_FAILED ... self-signed certificate in certificate chain`, a
   TLS-inspecting proxy is re-signing HTTPS. The measure automatically uses Netskope's
   `nscacert_combined.pem` when it exists, or `SSL_CERT_FILE` if set. Otherwise build a
   bundle from the macOS keychains and pass it as the *ca_bundle* argument:

   ```bash
   security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain \
       /Library/Keychains/System.keychain ~/Library/Keychains/login.keychain-db \
       > ~/OpenStudio/speckle_ca.pem
   ```

   Alternatively, `pip install truststore` into the same `python_packages` folder. The
   measure then uses the OS trust store.

## Arguments

| Argument | Default | Notes |
|---|---|---|
| Speckle project | — | Project ID, project URL, or model URL (required unless dry run) |
| Speckle model name | building name | Found by name or created; ignored for a model URL |
| Speckle server | `https://app.speckle.systems` | |
| Token | blank | See setup |
| Version message | "Published from OpenStudio" | |
| Colour surfaces by | Surface Type | or Boundary Condition, Thermal Zone, Space Type, Construction (uses OS rendering colours) |
| Include shading / partitions / space objects | on | |
| Dry run | off | Writes `speckle_payload.json` (+ the parquet bundle if specklepy is available) and stops |
| python_packages_path / external_python | blank | See setup |
| Fail the workflow if publishing fails | off | Off = warning only, so a network hiccup doesn't kill a simulation |

Outputs (registered values): `speckle_url`, `speckle_version_id`, `speckle_model_id`,
object counts. `speckle_payload.json` and `speckle_result.json` are written to the
measure's run folder.

## Run it

* **OpenStudio Application / PAT:** copy this folder into `~/OpenStudio/Measures`, add
  it as a model measure, fill in the project link.
* **CLI:**

  ```json
  { "seed_file": "my_building.osm",
    "steps": [{ "measure_dir_name": "export_model_to_speckle",
                "arguments": { "speckle_project": "https://app.speckle.systems/projects/<id>" } }] }
  ```

  `SPECKLE_TOKEN=... openstudio run -m -w workflow.osw` (`-m` = measures only, skip the
  simulation).

## Files

* `measure.py` — measure wrapper / arguments / fallback logic
* `resources/os_speckle_extract.py` — OpenStudio → JSON payload (openstudio only)
* `resources/speckle_publisher.py` — payload → Speckle bundle → upload; also a
  standalone CLI (`python speckle_publisher.py payload.json --project ... --dry-run`)
* `tests/` — `python -m pytest tests` (offline)

## Known limits / next steps

* One-way (OpenStudio → Speckle). Each run creates a new version; the free *Explore*
  plan caps a workspace at 100 versions.
* Uses the specklepy 2026.9 bundle API, which is new; pin `specklepy` if Speckle
  changes it.
* Simulation results aren't included yet. A reporting-measure variant could add zone
  loads / EUI from `eplusout.sql` as extra properties on the same objects.
* No HVAC equipment geometry. Air loops show up only as Speckle systems and properties.
