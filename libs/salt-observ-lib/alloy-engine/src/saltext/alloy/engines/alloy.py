"""
A Salt engine that reads the Salt event bus, enriches each event, and pushes it
to a Grafana Alloy ``loki.source.api`` endpoint using the Loki push protocol.

This replaces the Vector-based engine: the heavy VRL transforms that Vector used
to do (tag normalization, highstate summary, job-arg extraction) are done here in
Python — which is both simpler and avoids a second moving part. Alloy then only
labels the stream, derives ``salt_duration`` / ``salt_success`` metrics and ships
logs + metrics to Loki / Prometheus (see ``states/alloy/files/config.alloy``).

:configuration:

    .. code-block:: yaml

        engines:
          - alloy:
              url: "http://127.0.0.1:9000"   # alloy loki.source.api base url
              # host_id: myid                # master/minion id override, optional
              exclude_tags:
                - salt/auth
                - minion_start
                - minion/refresh/*
                - "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"
"""
import datetime
import fnmatch
import logging
import re
import time
import urllib.request

import salt.utils.event
import salt.utils.json

log = logging.getLogger(__name__)

__virtualname__ = "alloy"

# High-cardinality tag substrings -> keywords (port of vector transforms.tag).
_TAG_RULES = [
    (re.compile(r"^[0-9_]+$"), "JID"),
    (re.compile(r"^(salt/job|salt/run)/[0-9_]+/(.+)$"), r"\1/JID/\2"),
    (re.compile(r"^(minion/refresh)/[0-9a-zA-Z_.-]+$"), r"\1/MID"),
    (re.compile(r"^(salt/job/JID/ret)/[0-9a-zA-Z_.-]+$"), r"\1/MID"),
    (re.compile(r"^(salt/job/JID/prog)/[0-9a-zA-Z_.-]+/[0-9]+$"), r"\1/MID/RUN"),
    (re.compile(r"^(salt/minion)/[0-9a-zA-Z_.-]+/(start)$"), r"\1/MID/\2"),
    (re.compile(r"^(salt/cloud)/[0-9a-zA-Z_.-]+/([a-z_]+)$"), r"\1/VM/\2"),
    (re.compile(r"^(salt/stats)/MWorker-[0-9]+$"), r"\1/MW"),
]

_HIGHSTATE_FUNS = {"state.highstate", "state.apply", "runner.state.orch", "runner.state.orchestrate"}


def __virtual__():
    return __virtualname__


def _generic_tag(tag):
    out = tag
    for rx, repl in _TAG_RULES:
        out = rx.sub(repl, out)
    return out


def _split_args(data):
    args, kwargs = [], {}
    for v in data.get("fun_args", []) or []:
        if isinstance(v, dict):
            kwargs = v
        else:
            args.append(v)
    return args, kwargs


def _job_name(data):
    """state.apply/highstate -> saltenv; orchestrate -> first arg (port of transforms.args)."""
    args, kwargs = _split_args(data)
    fun = data.get("fun")
    if fun in ("state.highstate", "state.apply"):
        return kwargs.get("saltenv")
    if fun in ("runner.state.orch", "runner.state.orchestrate"):
        return args[0] if args else None
    return None


def _summary(data):
    """Count states and sum duration for highstate-formatted returns (port of transforms.summary)."""
    ret = data.get("return")
    if data.get("fun") not in _HIGHSTATE_FUNS or not isinstance(ret, dict):
        return {}
    total = succeeded = changed = failed = 0
    duration = 0.0
    for res in ret.values():
        if not isinstance(res, dict):
            continue
        total += 1
        if res.get("result") is True:
            succeeded += 1
        elif res.get("result") is False:
            failed += 1
        if res.get("changes"):
            changed += 1
        try:
            duration += float(res.get("duration", 0) or 0)
        except (TypeError, ValueError):
            pass
    return {
        "num_total": total,
        "num_succeeded": succeeded,
        "num_changed": changed,
        "num_failed": failed,
        "duration": round(duration / 1000.0, 3),  # salt reports ms -> seconds
        "success": 1 if (total and failed == 0) else 0,
    }


def _stamp_ns(data):
    """Salt event _stamp (e.g. 2020-01-02T03:04:05.123456) -> unix nanoseconds."""
    raw = data.get("_stamp")
    if raw:
        try:
            dt = datetime.datetime.strptime(raw, "%Y-%m-%dT%H:%M:%S.%f")
            return str(int(dt.replace(tzinfo=datetime.timezone.utc).timestamp() * 1e9))
        except (ValueError, TypeError):
            pass
    return str(int(time.time() * 1e9))


def _match_tag(tag, include_tags, exclude_tags):
    match = True
    if include_tags:
        match = any(fnmatch.fnmatch(tag, inc) for inc in include_tags)
    if match:
        for exc in exclude_tags:
            if fnmatch.fnmatch(tag, exc):
                return False
    return match


def _event_bus_context(opts):
    if opts["__role"] == "master":
        return salt.utils.event.get_master_event(opts, opts["sock_dir"], listen=True)
    return salt.utils.event.get_event("minion", opts=opts, sock_dir=opts["sock_dir"], listen=True)


def _push(url, stream_labels, ts_ns, line):
    payload = {"streams": [{"stream": stream_labels, "values": [[ts_ns, line]]}]}
    body = salt.utils.json.dumps(payload).encode("utf8")
    req = urllib.request.Request(
        url.rstrip("/") + "/loki/api/v1/push",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    urllib.request.urlopen(req, timeout=5).read()  # noqa: S310 (trusted local alloy)


def start(url="http://127.0.0.1:9000", host_id=None, include_tags=None, exclude_tags=None):
    """Listen to the event bus, enrich, and push to Alloy's loki.source.api."""
    id_value = host_id or __opts__.get("id")

    include_tags = [] if include_tags is None else include_tags
    exclude_tags = [] if exclude_tags is None else exclude_tags
    if not isinstance(include_tags, list) or not isinstance(exclude_tags, list):
        raise TypeError("include_tags/exclude_tags must be lists")

    log.info("Alloy engine started, pushing to %s", url)
    with _event_bus_context(__opts__) as event_bus:
        while True:
            event = event_bus.get_event(full=True)
            if not event or not _match_tag(event.get("tag", ""), include_tags, exclude_tags):
                continue
            tag = event["tag"]
            data = event.get("data", {}) or {}

            enriched = {
                "tag": tag,
                "generic_tag": _generic_tag(tag),
                "host": id_value,
                "fun": data.get("fun"),
                "jid": data.get("jid"),
                "id": data.get("id"),
                "saltenv": (_split_args(data)[1] or {}).get("saltenv"),
                "job_name": _job_name(data),
            }
            enriched.update(_summary(data))

            # stream labels mirror the old vector loki sink (job/job_name/saltenv/id);
            # only set bounded-cardinality labels that are present.
            labels = {"job": "salt_events", "host": str(id_value)}
            for key in ("job_name", "saltenv", "id", "generic_tag"):
                if enriched.get(key):
                    labels[key] = str(enriched[key])

            line = salt.utils.json.dumps({**event, **enriched})
            try:
                _push(url, labels, _stamp_ns(data), line)
            except OSError as exc:
                log.error("Alloy engine push failed (%s): %s", url, exc)
