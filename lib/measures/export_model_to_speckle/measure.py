"""Export Model to Speckle — OpenStudio ModelMeasure (Python).

Publishes the OpenStudio model's geometry (surfaces, sub-surfaces, shading and
interior partitions) and energy-model inputs (constructions, U-values, space
types, loads, thermal zones, HVAC assignment, stories) to a Speckle project as a
new model version. The OpenStudio model itself is not changed.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import openstudio

_RESOURCES = Path(__file__).resolve().parent / "resources"
if str(_RESOURCES) not in sys.path:
    sys.path.insert(0, str(_RESOURCES))

import os_speckle_extract as extract  # noqa: E402

DEFAULT_PACKAGES_DIR = Path.home() / "OpenStudio" / "python_packages"
PAYLOAD_FILE = "speckle_payload.json"
RESULT_FILE = "speckle_result.json"


class ExportModelToSpeckle(openstudio.measure.ModelMeasure):
    def name(self):
        return "Export Model to Speckle"

    def description(self):
        return (
            "Publishes the model's geometry and energy-model inputs (constructions, "
            "U-values, space types, internal loads, thermal zones, HVAC assignment) "
            "to a Speckle project as a new version, so it can be viewed, compared and "
            "analysed alongside other design models. The OpenStudio model is not changed."
        )

    def modeler_description(self):
        return (
            "Surfaces, sub-surfaces, interior partitions and shading surfaces are "
            "triangulated in site coordinates (metres, north axis applied) and sent with "
            "the specklepy 2026.9+ bundle API (BundleBuilder + operations.send3). Objects "
            "are organised Building > Story > Space, linked to Speckle levels, rooms "
            "(spaces), hosts (sub-surface -> parent surface), groups (thermal zones) and "
            "systems (air loops). specklepy is loaded from the OpenStudio embedded Python "
            "(add its folder with the python_packages_path argument) or, failing that, an "
            "external Python 3.11+ interpreter given by external_python. A JSON payload "
            "of everything sent is always written to the run directory. The token is "
            "read from the speckle_token argument, else the SPECKLE_TOKEN environment "
            "variable, else a local Speckle desktop-connector account."
        )

    # ── arguments ──────────────────────────────────────────────────────────

    def arguments(self, model=None):
        args = openstudio.measure.OSArgumentVector()

        a = openstudio.measure.OSArgument.makeStringArgument("speckle_project", False)
        a.setDisplayName("Speckle project (ID, project URL or model URL)")
        a.setDescription(
            "Paste a project or model link from app.speckle.systems, or just the project "
            "ID. A model URL publishes to that exact model.")
        a.setDefaultValue("")
        args.append(a)

        a = openstudio.measure.OSArgument.makeStringArgument("speckle_model_name", False)
        a.setDisplayName("Speckle model name")
        a.setDescription(
            "Model inside the project to publish to; created if it does not exist. Blank "
            "= the OpenStudio building name. Ignored when a model URL is given.")
        a.setDefaultValue("")
        args.append(a)

        a = openstudio.measure.OSArgument.makeStringArgument("speckle_server", False)
        a.setDisplayName("Speckle server")
        a.setDefaultValue("https://app.speckle.systems")
        args.append(a)

        a = openstudio.measure.OSArgument.makeStringArgument("speckle_token", False)
        a.setDisplayName("Speckle personal access token (optional)")
        a.setDescription(
            "Leave blank to use the SPECKLE_TOKEN environment variable or a signed-in "
            "Speckle connector. A token entered here is saved in plain text in the "
            "workflow (.osw) file.")
        a.setDefaultValue("")
        args.append(a)

        a = openstudio.measure.OSArgument.makeStringArgument("version_message", False)
        a.setDisplayName("Version message")
        a.setDefaultValue("")
        args.append(a)

        a = openstudio.measure.OSArgument.makeChoiceArgument(
            "color_by", extract.COLOR_BY_CHOICES, True)
        a.setDisplayName("Colour surfaces by")
        a.setDefaultValue("Surface Type")
        args.append(a)

        a = openstudio.measure.OSArgument.makeBoolArgument("include_shading", True)
        a.setDisplayName("Include shading surfaces")
        a.setDefaultValue(True)
        args.append(a)

        a = openstudio.measure.OSArgument.makeBoolArgument("include_interior_partitions", True)
        a.setDisplayName("Include interior partition surfaces")
        a.setDefaultValue(True)
        args.append(a)

        a = openstudio.measure.OSArgument.makeBoolArgument("include_space_objects", True)
        a.setDisplayName("Include space objects (rooms with loads/zone data)")
        a.setDefaultValue(True)
        args.append(a)

        a = openstudio.measure.OSArgument.makeBoolArgument("dry_run", True)
        a.setDisplayName("Dry run (write payload/bundle locally, do not upload)")
        a.setDefaultValue(False)
        args.append(a)

        a = openstudio.measure.OSArgument.makeStringArgument("python_packages_path", False)
        a.setDisplayName("Folder with specklepy for the OpenStudio Python (optional)")
        a.setDescription(
            f"Added to sys.path before importing specklepy. Blank = {DEFAULT_PACKAGES_DIR} "
            "if it exists.")
        a.setDefaultValue("")
        args.append(a)

        a = openstudio.measure.OSArgument.makeStringArgument("external_python", False)
        a.setDisplayName("External Python with specklepy (optional fallback)")
        a.setDescription(
            "Path to a Python 3.11+ executable that has specklepy[bundle] installed; used "
            "if specklepy cannot be imported inside OpenStudio.")
        a.setDefaultValue("")
        args.append(a)

        a = openstudio.measure.OSArgument.makeStringArgument("ca_bundle", False)
        a.setDisplayName("CA certificate bundle (optional, for corporate proxies)")
        a.setDescription(
            "PEM file of trusted root certificates. Needed when a TLS-inspecting proxy "
            "(e.g. Netskope) causes CERTIFICATE_VERIFY_FAILED. Blank = auto-detect "
            "(SSL_CERT_FILE, the truststore package, or Netskope's bundle).")
        a.setDefaultValue("")
        args.append(a)

        a = openstudio.measure.OSArgument.makeBoolArgument("fail_on_publish_error", True)
        a.setDisplayName("Fail the workflow if publishing fails")
        a.setDescription("Off = log a warning and let the rest of the workflow continue.")
        a.setDefaultValue(False)
        args.append(a)
        return args

    # ── run ────────────────────────────────────────────────────────────────

    def run(self, model, runner, user_arguments):
        super().run(model, runner, user_arguments)
        if not runner.validateUserArguments(self.arguments(model), user_arguments):
            return False

        def s(name):
            return runner.getStringArgumentValue(name, user_arguments).strip()

        def b(name):
            return runner.getBoolArgumentValue(name, user_arguments)

        project = s("speckle_project")
        model_name = s("speckle_model_name")
        server = s("speckle_server") or "https://app.speckle.systems"
        token = s("speckle_token")
        message = s("version_message")
        color_by = runner.getStringArgumentValue("color_by", user_arguments)
        dry_run = b("dry_run")
        packages = s("python_packages_path")
        external = s("external_python")
        fail_hard = b("fail_on_publish_error")
        ca_bundle = s("ca_bundle")

        if not dry_run and not project:
            runner.registerError("Enter a Speckle project ID or URL (or turn on dry run).")
            return False

        # 1) extract ---------------------------------------------------------
        payload = extract.extract_payload(
            model, color_by=color_by,
            include_shading=b("include_shading"),
            include_partitions=b("include_interior_partitions"),
            include_spaces=b("include_space_objects"),
        )
        if model_name:
            payload["model_name"] = model_name
        for w in payload.get("warnings", []):
            runner.registerWarning(w)
        counts = extract.summarize(payload)
        runner.registerInitialCondition(
            "Model has " + ", ".join(f"{v} {k}" for k, v in sorted(counts.items())) + ".")
        for k, v in counts.items():
            runner.registerValue(f"speckle_{k.lower()}_count", v)

        run_dir = Path.cwd()
        payload_path = run_dir / PAYLOAD_FILE
        payload_path.write_text(json.dumps(payload), encoding="utf-8")
        runner.registerInfo(f"Wrote Speckle payload to {payload_path}")

        source_file = None
        seed = runner.workflow().seedFile()
        if seed.is_initialized():
            source_file = str(seed.get())

        # 2) publish (or build locally) ------------------------------------
        result = self._publish_in_process(runner, payload, packages, dry_run, run_dir,
                                          server, project, model_name, token, message,
                                          source_file, ca_bundle)
        if result is None and external:
            result = self._publish_external(runner, external, payload_path, dry_run, run_dir,
                                            server, project, model_name, token, message,
                                            source_file, ca_bundle)
        if result is None:
            if dry_run:
                runner.registerFinalCondition(
                    f"Dry run: payload written to {payload_path} (specklepy not available, "
                    "so no bundle was built).")
                return True
            return self._fail(runner, fail_hard,
                              "specklepy (>= 2026.9, with the 'bundle' extra) could not be "
                              "loaded. Set python_packages_path or external_python — see "
                              "the measure README.")

        (run_dir / RESULT_FILE).write_text(json.dumps(result, indent=2), encoding="utf-8")
        if not result.get("ok"):
            return self._fail(runner, fail_hard, f"Speckle publish failed: {result.get('error')}")

        if result.get("dry_run"):
            runner.registerFinalCondition(
                f"Dry run: built a {result['object_count']}-object Speckle bundle in "
                f"{result['bundle_dir']} (not uploaded).")
            return True

        runner.registerValue("speckle_version_id", result["version_id"])
        runner.registerValue("speckle_model_id", result["model_id"])
        runner.registerValue("speckle_url", result["url"])
        created = " (new model)" if result.get("model_created") else ""
        runner.registerFinalCondition(
            f"Published {result['object_count']} objects to Speckle model "
            f"'{result['model_name']}'{created}: {result['url']} . The version appears "
            "once Speckle finishes processing (usually seconds).")
        return True

    # ── helpers ────────────────────────────────────────────────────────────

    @staticmethod
    def _fail(runner, fail_hard, msg):
        if fail_hard:
            runner.registerError(msg)
            return False
        runner.registerWarning(msg)
        runner.registerFinalCondition("Model was not published to Speckle (see warnings).")
        return True

    @staticmethod
    def _publish_in_process(runner, payload, packages, dry_run, run_dir, server, project,
                            model_name, token, message, source_file, ca_bundle):
        candidates = [packages] if packages else (
            [str(DEFAULT_PACKAGES_DIR)] if DEFAULT_PACKAGES_DIR.is_dir() else [])
        for c in candidates:
            p = str(Path(c).expanduser())
            if not Path(p).is_dir():
                runner.registerWarning(f"python_packages_path '{p}' does not exist.")
            elif p not in sys.path:
                sys.path.insert(0, p)
        try:
            import speckle_publisher as pub
            pub._check_specklepy_version()
        except Exception as err:  # ImportError, binary-incompatible wheels, too old, ...
            runner.registerInfo(
                f"specklepy not usable in the OpenStudio Python {sys.version.split()[0]} "
                f"({type(err).__name__}: {err}).")
            return None
        try:
            if dry_run:
                return pub.build_local(payload, str(run_dir / "speckle_bundle"))
            return pub.publish(payload, server, project, model_name or None, token or None,
                               message or None, source_file, ca_bundle or None)
        except Exception as err:
            return {"ok": False, "error": pub.explain_error(err)}

    @staticmethod
    def _publish_external(runner, python, payload_path, dry_run, run_dir, server, project,
                          model_name, token, message, source_file, ca_bundle):
        script = _RESOURCES / "speckle_publisher.py"
        result_path = run_dir / RESULT_FILE
        cmd = [python, "-I", str(script), str(payload_path), "--server", server,
               "--project", project, "--result", str(result_path)]
        if model_name:
            cmd += ["--model", model_name]
        if message:
            cmd += ["--message", message]
        if source_file:
            cmd += ["--source-file", source_file]
        if ca_bundle:
            cmd += ["--ca-bundle", ca_bundle]
        if dry_run:
            cmd += ["--dry-run", "--bundle-dir", str(run_dir / "speckle_bundle")]
        env = dict(os.environ)
        # don't leak OpenStudio's embedded-Python settings into the child interpreter
        for k in ("PYTHONHOME", "PYTHONPATH"):
            env.pop(k, None)
        if token:
            env["SPECKLE_TOKEN"] = token
        runner.registerInfo(f"Publishing with external Python: {python}")
        try:
            proc = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=900)
        except Exception as err:
            return {"ok": False, "error": f"Could not run '{python}': {err}"}
        if result_path.exists():
            try:
                return json.loads(result_path.read_text(encoding="utf-8"))
            except Exception:
                pass
        tail = (proc.stderr or proc.stdout or "").strip().splitlines()[-5:]
        return {"ok": False, "error": "external publisher failed: " + " | ".join(tail)}


# register the measure to be used by the application
ExportModelToSpeckle().registerWithApplication()
