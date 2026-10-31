"""Tests for the Export Model to Speckle measure (no network needed).

Run with:  python -m pytest tests   (needs the `openstudio` Python package;
the bundle test is skipped unless specklepy[bundle] >= 2026.9 is importable).
"""

import json
import os
import sys
from pathlib import Path

import openstudio
import pytest

CURRENT_DIR_PATH = Path(__file__).parent.absolute()
sys.path.insert(0, str(CURRENT_DIR_PATH.parent))
from measure import ExportModelToSpeckle  # noqa: E402

sys.path.remove(str(CURRENT_DIR_PATH.parent))
del sys.modules["measure"]
sys.path.insert(0, str(CURRENT_DIR_PATH.parent / "resources"))

import os_speckle_extract  # noqa: E402  (resources/ is on sys.path via measure.py)
import speckle_publisher  # noqa: E402


def _run(measure, model, args, workdir):
    osw = openstudio.WorkflowJSON()
    runner = openstudio.measure.OSRunner(osw)
    arguments = measure.arguments(model)
    argument_map = openstudio.measure.convertOSArgumentVectorToMap(arguments)
    for arg in arguments:
        if arg.name() in args:
            a = arg.clone()
            assert a.setValue(args[arg.name()])
            argument_map[arg.name()] = a
    cwd = os.getcwd()
    os.chdir(workdir)
    try:
        measure.run(model, runner, argument_map)
    finally:
        os.chdir(cwd)
    return runner.result()


def _example_model():
    return openstudio.model.exampleModel()


def test_arguments():
    names = [a.name() for a in ExportModelToSpeckle().arguments(openstudio.model.Model())]
    assert names[:3] == ["speckle_project", "speckle_model_name", "speckle_server"]
    assert "dry_run" in names and "color_by" in names


def test_requires_project_unless_dry_run(tmp_path):
    result = _run(ExportModelToSpeckle(), _example_model(), {}, tmp_path)
    assert result.value().valueName() == "Fail"


def test_dry_run_writes_payload(tmp_path):
    model = _example_model()
    result = _run(ExportModelToSpeckle(), model,
                  {"dry_run": True, "python_packages_path": str(tmp_path / "none")}, tmp_path)
    assert result.value().valueName() == "Success"
    payload = json.loads((tmp_path / "speckle_payload.json").read_text())
    counts = os_speckle_extract.summarize(payload)
    assert counts["Surface"] == len(model.getSurfaces())
    assert counts["SubSurface"] == len(model.getSubSurfaces())
    assert counts["Space"] == len(model.getSpaces())
    surf = next(o for o in payload["objects"] if o["category"] == "Surface")
    assert surf["mesh"]["faces"][0] == 3
    assert "Construction" in surf["properties"]
    # measure must not modify the model
    assert len(model.getSurfaces()) == 24


def test_mesh_area_matches_net_area():
    model = _example_model()
    payload = os_speckle_extract.extract_payload(model)
    for o in payload["objects"]:
        if o["category"] != "Surface":
            continue
        v, f = o["mesh"]["vertices"], o["mesh"]["faces"]
        area = 0.0
        for i in range(0, len(f), 4):
            a, b, c = (v[3 * f[i + 1]:3 * f[i + 1] + 3], v[3 * f[i + 2]:3 * f[i + 2] + 3],
                       v[3 * f[i + 3]:3 * f[i + 3] + 3])
            u = [b[k] - a[k] for k in range(3)]
            w = [c[k] - a[k] for k in range(3)]
            cr = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]]
            area += 0.5 * sum(x * x for x in cr) ** 0.5
        assert abs(area - o["properties"]["Surface"]["Net Area"]["value"]) < 1e-3


def test_parse_target():
    assert speckle_publisher.parse_target("", "abc", "M") == (
        "https://app.speckle.systems", "abc", None, "M")
    assert speckle_publisher.parse_target(
        "", "https://app.speckle.systems/projects/p1/models/m1@v9", None) == (
        "https://app.speckle.systems", "p1", "m1", None)


def test_bundle_builds(tmp_path):
    try:
        speckle_publisher._check_specklepy_version()
    except Exception:
        pytest.skip("specklepy[bundle] >= 2026.9 not installed")
    payload = os_speckle_extract.extract_payload(_example_model())
    res = speckle_publisher.build_local(payload, str(tmp_path / "bundle"))
    assert res["ok"] and res["object_count"] == len(payload["objects"])
