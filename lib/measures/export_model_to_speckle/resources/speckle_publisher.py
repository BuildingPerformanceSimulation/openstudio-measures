"""Publish an OpenStudio "Speckle payload" (see os_speckle_extract.py) to Speckle.

Uses the specklepy 2026.9+ bundle API (``BundleBuilder`` + ``operations.send3``).
Works two ways:

* imported in-process by the measure (when specklepy is importable from the
  OpenStudio embedded Python), or
* run as a script by an external Python 3.11+ interpreter that has specklepy:

      SPECKLE_TOKEN=... python speckle_publisher.py payload.json \
          --server https://app.speckle.systems --project <id-or-url> \
          --model "My Building" --message "From OpenStudio" --result result.json

The token is read from the SPECKLE_TOKEN environment variable (never from the
command line, so it does not show up in process listings or logs).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from urllib.parse import urlparse

DEFAULT_SERVER = "https://app.speckle.systems"
MIN_SPECKLEPY = (2026, 9)


# ───────────────────────────── target parsing ────────────────────────────────


def parse_target(server: str, project: str, model_name: str | None):
    """Accept a bare project id, a project URL or a model URL.

    Returns (server_url, project_id, model_id_or_None, model_name_or_None).
    """
    server = (server or DEFAULT_SERVER).strip().rstrip("/")
    if not server.startswith("http"):
        server = "https://" + server
    project = (project or "").strip()
    model_id = None
    if project.startswith("http"):
        u = urlparse(project)
        server = f"{u.scheme}://{u.netloc}"
        m = re.search(r"/projects/([^/?#]+)(?:/models/([^/?#@,]+))?", u.path)
        if not m:
            raise ValueError(f"Could not find a project id in URL '{project}'.")
        project = m.group(1)
        model_id = m.group(2)
    if not project:
        raise ValueError("A Speckle project id or URL is required.")
    return server, project, model_id, (model_name or "").strip() or None


# ───────────────────────────── TLS / corporate proxies ───────────────────────

# Netskope (and similar TLS-inspecting proxies) re-sign HTTPS traffic with their own
# root CA. macOS/Windows trust it, but Python's bundled certifi list does not, which
# shows up as "CERTIFICATE_VERIFY_FAILED: self-signed certificate in certificate chain".
KNOWN_CA_BUNDLES = [
    # Netskope client (macOS / Windows / Linux): the tenant's re-signing CA chain
    "/Library/Application Support/Netskope/STAgent/data/nscacert_combined.pem",
    "/Library/Application Support/Netskope/STAgent/data/nscacert.pem",
    r"C:\ProgramData\netskope\stagent\data\nscacert_combined.pem",
    r"C:\ProgramData\netskope\stagent\data\nscacert.pem",
    "/opt/netskope/stagent/data/nscacert_combined.pem",
    "/opt/netskope/stagent/data/nscacert.pem",
]
_CA_ENV = ("SSL_CERT_FILE", "REQUESTS_CA_BUNDLE", "CURL_CA_BUNDLE")


def _with_public_roots(extra: str) -> str:
    """Return a PEM file = certifi's public roots + ``extra``.

    A corporate CA file alone would break hosts the proxy does *not* intercept (e.g.
    bypassed storage endpoints), so always keep the public roots too."""
    import tempfile

    try:
        import certifi

        public = open(certifi.where(), encoding="utf-8", errors="ignore").read()
    except Exception:
        public = ""
    extra_text = open(extra, encoding="utf-8", errors="ignore").read()
    if "BEGIN CERTIFICATE" not in extra_text:
        raise ValueError(f"'{extra}' does not contain any PEM certificates.")
    fd, out = tempfile.mkstemp(prefix="speckle-ca-", suffix=".pem")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(public + "\n" + extra_text + "\n")
    return out


def _use_bundle(path: str) -> str:
    combined = _with_public_roots(path)
    for k in _CA_ENV:
        os.environ[k] = combined
    return combined


def configure_tls(ca_bundle: str | None = None) -> str:
    """Make Python trust a corporate TLS-inspection CA. Returns what was used.

    Order: explicit ca_bundle argument > CA env var already set > a known
    corporate-proxy bundle (Netskope) > the `truststore` package (OS trust store) >
    certifi. Bundles are always merged with certifi's public roots, and the result is
    exported to SSL_CERT_FILE (httpx) and REQUESTS_CA_BUNDLE (requests/gql).
    """
    if ca_bundle:
        path = os.path.expanduser(ca_bundle)
        if not os.path.isfile(path):
            raise FileNotFoundError(f"CA bundle '{path}' does not exist.")
        _use_bundle(path)
        return f"CA bundle {path} + public roots"
    for k in _CA_ENV:
        if os.environ.get(k):
            path = os.path.expanduser(os.environ[k])
            if os.path.isfile(path):
                _use_bundle(path)
                return f"CA bundle {path} (from ${k}) + public roots"
    for path in KNOWN_CA_BUNDLES:
        if os.path.isfile(path):
            try:
                _use_bundle(path)
                return f"CA bundle {path} + public roots"
            except Exception:
                continue
    try:
        import truststore

        truststore.inject_into_ssl()
        return "OS trust store (truststore)"
    except Exception:
        pass
    return "certifi (default)"


# ───────────────────────────── account / client ──────────────────────────────


def _check_specklepy_version():
    import specklepy  # noqa: F401
    from importlib.metadata import version

    v = version("specklepy")
    parts = tuple(int(p) for p in re.findall(r"\d+", v)[:2])
    if parts < MIN_SPECKLEPY:
        raise RuntimeError(
            f"specklepy {v} is too old; the bundle API needs specklepy >= 2026.9 "
            "(pip install 'specklepy[bundle]>=2026.9')."
        )
    return v


def get_account(server: str, token: str | None):
    from specklepy.api.credentials import Account, get_accounts_for_server

    token = (token or os.environ.get("SPECKLE_TOKEN") or "").strip()
    if token:
        return Account.from_token(token, server), "token"
    host = urlparse(server).netloc
    accounts = [a for a in get_accounts_for_server(host) if a.token]
    if accounts:
        acct = next((a for a in accounts if a.isDefault), accounts[0])
        return acct, "local Speckle account"
    raise RuntimeError(
        "No Speckle token. Set the SPECKLE_TOKEN environment variable, fill in the "
        "measure's token argument, or sign in with a Speckle desktop connector."
    )


def _client(server: str, account):
    from specklepy.api.client import SpeckleClient

    client = SpeckleClient(host=server, use_ssl=server.startswith("https"))
    client.authenticate_with_account(account)
    # authenticate_with_account fills serverInfo + userInfo; send3 needs the url
    if not account.serverInfo.url:
        account.serverInfo.url = server
    return client


def resolve_model(client, project_id: str, model_id: str | None, model_name: str | None,
                  create: bool = True):
    """Return (model_id, model_name, created). Finds a model by exact name
    (case-insensitive) or creates it."""
    if model_id:
        m = client.model.get(model_id, project_id)
        return m.id, m.name, False
    if not model_name:
        raise ValueError("A model name is required when the target is not a model URL.")
    from specklepy.api.inputs.model_inputs import CreateModelInput
    from specklepy.api.inputs.project_inputs import ProjectModelsFilter

    cursor = None
    while True:
        proj = client.project.get_with_models(
            project_id, models_limit=50, models_cursor=cursor,
            models_filter=ProjectModelsFilter(search=model_name),
        )
        for m in proj.models.items:
            if m.name.strip().lower() == model_name.lower():
                return m.id, m.name, False
        cursor = getattr(proj.models, "cursor", None)
        if not cursor or not proj.models.items:
            break
    if not create:
        raise ValueError(f"Model '{model_name}' not found in project {project_id}.")
    m = client.model.create(CreateModelInput(name=model_name, project_id=project_id,
                                             description="Published from OpenStudio"))
    return m.id, m.name, True


# ───────────────────────────── bundle building ───────────────────────────────


def build_bundle(payload: dict, output_dir: str | None = None):
    """Translate the payload into a specklepy BundleBuilder (not yet built)."""
    from specklepy.bundle import BundleBuilder, Level, Material, Producer, SceneViewKey
    from specklepy.objects.geometry import Mesh

    units = payload.get("units", "m")
    prod = payload.get("producer", {})
    builder = BundleBuilder(
        Producer(prod.get("slug", "openstudio"), str(prod.get("version", ""))),
        units,
        output_dir=output_dir,
    )

    levels = {
        lv["key"]: builder.get_or_add_level(lv["key"], Level(elevation=float(lv["elevation"]),
                                                             name=lv["name"]))
        for lv in payload.get("levels", [])
    }
    groups = {}
    for g in payload.get("groups", []):
        groups[g["key"]] = builder.get_or_add_semantic_container(
            g["key"], g["name"], None, "System" if g["subtype"] == "Air Loop" else "Group")
    materials = {
        mt["key"]: builder.get_or_add_material(
            mt["key"],
            Material(argb=int(mt["argb"]), opacity=float(mt["opacity"]),
                     metalness=0.0, roughness=0.9 if mt["opacity"] >= 1 else 0.1,
                     name=mt["name"]))
        for mt in payload.get("materials", [])
    }

    root = payload.get("model_name") or "OpenStudio Model"
    handles = {}
    for o in payload["objects"]:
        bo = builder.get_or_add_object(o["id"])
        bo.set_properties(o.get("properties") or {}, name=o.get("name"),
                          speckle_type=f"Objects.BuiltElements.OpenStudio.{o['category']}",
                          source_type=o["category"])
        bo.collection = builder.get_or_add_container_path([root, *o["collection"]])
        if o.get("level") in levels:
            bo.level = levels[o["level"]]
        if o.get("material") in materials:
            bo.material = materials[o["material"]]
        mesh = o.get("mesh")
        if mesh:
            bo.add_geometry(Mesh(vertices=mesh["vertices"], faces=mesh["faces"], units=units))
        for gk in o.get("groups", []):
            if gk in groups:
                bo.add_to_group(groups[gk])
        for sk in o.get("systems", []):
            if sk in groups:
                bo.add_to_system(groups[sk])
        handles[o["id"]] = bo

    # relations that need both ends to exist
    for o in payload["objects"]:
        bo = handles[o["id"]]
        if o.get("host") in handles:
            bo.host = handles[o["host"]]
        if o.get("room") in handles and o["room"] != o["id"]:
            bo.room = handles[o["room"]]

    for path, value in payload.get("model_properties", {}).items():
        builder.add_model_property(path, value)

    for sv in payload.get("scene_views", []):
        keys = [SceneViewKey.rel(int(r)) if kind == "rel" else SceneViewKey.eav(r)
                for kind, r in sv["keys"]]
        builder.scene_view(sv["name"], bool(sv.get("default")), *keys)
    return builder


def build_local(payload: dict, output_dir: str) -> dict:
    """Dry run: build the parquet bundle on disk without uploading."""
    builder = build_bundle(payload, output_dir)
    files = builder.build()
    return {"ok": True, "dry_run": True, "bundle_dir": files.directory,
            "files": [os.path.basename(f) for f in files.files],
            "object_count": files.object_count}


def publish(payload: dict, server: str, project: str, model_name: str | None = None,
            token: str | None = None, message: str | None = None,
            source_file: str | None = None, ca_bundle: str | None = None) -> dict:
    sdk = _check_specklepy_version()
    tls = configure_tls(ca_bundle)
    from specklepy.api import operations
    from specklepy.bundle import SendOptions

    server, project_id, model_id, model_name = parse_target(
        server, project, model_name or payload.get("model_name"))
    account, auth_source = get_account(server, token)
    client = _client(server, account)
    model_id, model_name, created = resolve_model(client, project_id, model_id, model_name)

    builder = build_bundle(payload)
    result = operations.send3(
        account, project_id, model_id, builder,
        SendOptions(message=message or "Published from OpenStudio",
                    file_name=os.path.basename(source_file) if source_file else None),
    )
    return {
        "ok": True,
        "dry_run": False,
        "server": server,
        "project_id": project_id,
        "model_id": model_id,
        "model_name": model_name,
        "model_created": created,
        "version_id": result.version_id,
        "object_count": result.object_count,
        "url": f"{server}/projects/{project_id}/models/{model_id}@{result.version_id}",
        "auth": auth_source,
        "tls": tls,
        "specklepy": sdk,
    }


def explain_error(err: Exception) -> str:
    msg = f"{type(err).__name__}: {err}"
    if "CERTIFICATE_VERIFY_FAILED" in msg:
        msg += (" -- HINT: a TLS-inspecting proxy (e.g. Netskope) is likely re-signing "
                "HTTPS traffic. Set the measure's ca_bundle argument (or SSL_CERT_FILE) to "
                "a PEM file containing your organisation's root CA, or pip install "
                "'truststore' next to specklepy. See the README.")
    return msg


# ───────────────────────────── CLI ───────────────────────────────────────────


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("payload")
    ap.add_argument("--server", default=DEFAULT_SERVER)
    ap.add_argument("--project", default="")
    ap.add_argument("--model", default="")
    ap.add_argument("--message", default="")
    ap.add_argument("--source-file", default="")
    ap.add_argument("--ca-bundle", default="")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--bundle-dir", default="")
    ap.add_argument("--result", default="", help="write the result JSON here")
    a = ap.parse_args(argv)

    with open(a.payload, encoding="utf-8") as f:
        payload = json.load(f)
    try:
        if a.dry_run:
            out_dir = a.bundle_dir or os.path.join(os.path.dirname(os.path.abspath(a.payload)),
                                                   "speckle_bundle")
            res = build_local(payload, out_dir)
        else:
            res = publish(payload, a.server, a.project, a.model or None, None,
                          a.message or None, a.source_file or None, a.ca_bundle or None)
    except Exception as err:  # report cleanly to the calling measure
        res = {"ok": False, "error": explain_error(err)}
    text = json.dumps(res, indent=2)
    if a.result:
        with open(a.result, "w", encoding="utf-8") as f:
            f.write(text)
    print(text)
    return 0 if res.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
