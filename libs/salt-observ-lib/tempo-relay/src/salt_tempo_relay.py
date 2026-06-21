#!/usr/bin/env python3
"""
Flask-based service to convert Salt events to Tempo traces.
"""
import calendar
import datetime
import json
import os

from flask import Blueprint
from flask import Flask
from flask import request
from flask import Response
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.resources import SERVICE_NAME
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.export import ConsoleSpanExporter
from opentelemetry.sdk.trace.id_generator import RandomIdGenerator


api = Blueprint("api", __name__)

TEMPO_RELAY_ENDPOINT = os.environ.get("TEMPO_RELAY_ENDPOINT", "http://localhost:4317")
TEMPO_RELAY_SOCKET = os.environ.get("TEMPO_RELAY_SOCKET", "127.0.0.1:8000")

# Not fork-safe https://opentelemetry-python.readthedocs.io/en/latest/examples/fork-process-model/README.html
# https://github.com/open-telemetry/opentelemetry-python/blob/main/docs/examples/fork-process-model/flask-uwsgi/app.py
processor = BatchSpanProcessor(OTLPSpanExporter(endpoint=TEMPO_RELAY_ENDPOINT, insecure=True))
processor_console = BatchSpanProcessor(ConsoleSpanExporter())


def create_app():
    """Create application."""
    app = Flask(__name__)
    app.register_blueprint(api)
    return app


class FixedIdGenerator(RandomIdGenerator):
    """Generate fixed trace_id."""

    def __init__(self, trace_id):
        self.trace_id = trace_id

    def generate_trace_id(self) -> int:
        return self.trace_id


def get_tracer(service, trace_id=None):
    """Return dynamic tracer based on service name."""
    provider = TracerProvider(resource=Resource.create(attributes={SERVICE_NAME: service}))
    provider.add_span_processor(processor)
    provider.add_span_processor(processor_console)
    tracer = trace.get_tracer(__name__, tracer_provider=provider)

    if trace_id is not None:
        tracer.id_generator = FixedIdGenerator(trace_id)
    return tracer


@api.route("/")
def index():
    """Health check."""
    return Response("Hello, world!", status=200)


def jid_to_timestamp(jid):
    """Convert jid to datetime timestamp."""
    return datetime.datetime.strptime(jid.split("_")[0], "%Y%m%d%H%M%S%f")


def parse_start_time(jid_ts, start_time):
    """Parse start time and adjust the day based on jid timestamp."""
    start_ts = datetime.datetime.strptime(start_time, "%H:%M:%S.%f")
    start_ts = start_ts.replace(year=jid_ts.year, month=jid_ts.month, day=jid_ts.day)
    if start_ts.time() < jid_ts.time():
        # Time of the day has wrapped
        start_ts += datetime.timedelta(days=1)
    return start_ts


def ts_to_ns(tstamp):
    """Convert timestamp to nanoseconds."""
    return int(f"{calendar.timegm(tstamp.timetuple()):0.0f}{tstamp.microsecond * 1000:09d}")


def parse_return(parent_span, service, jid, ret, attrs=None):
    """Recursively parse return data."""
    jid_ts = jid_to_timestamp(jid)
    start_ts = jid_ts
    end_ts = jid_ts
    # pylint: disable-next=cell-var-from-loop
    keys = sorted(ret, key=lambda k: ret[k].get("__run_num__", 0))
    for key in keys:
        start_ts = parse_start_time(jid_ts, ret[key].get("start_time"))
        end_ts = max(end_ts, start_ts + datetime.timedelta(milliseconds=ret[key]["duration"]))
        context = trace.set_span_in_context(parent_span)
        span = get_tracer(service).start_span(
            key, start_time=ts_to_ns(start_ts), context=context, attributes=attrs or {}
        )
        if ret[key]["result"]:
            span.set_status(trace.Status(status_code=trace.StatusCode.OK))
        else:
            span.set_status(trace.Status(status_code=trace.StatusCode.ERROR))
            span.set_attributes(
                {
                    "changes": json.dumps(ret[key].get("changes", {})),
                    "comment": ret[key].get("comment", ""),
                }
            )
        if "__jid__" in ret[key]:
            nested_jid = ret[key]["__jid__"]
            if "ret" in ret[key].get("changes", {}):
                # highstate
                for minion_id, minion_ret in ret[key]["changes"]["ret"].items():
                    if (
                        minion_ret
                        and isinstance(minion_ret, dict)
                        and "__run_num__" in list(minion_ret.items())[0][1]
                    ):
                        parse_return(
                            span, minion_id, nested_jid, minion_ret, attrs={"minion": minion_id}
                        )
                    else:
                        print(f"Warning unknown nested minion ret: {minion_ret}")
            elif "data" in ret[key].get("changes", {}).get("return", {}):
                # orchestrate
                nested_ret = list(ret[key]["changes"]["return"]["data"].items())[0][1]
                parse_return(span, service, nested_jid, nested_ret)
            else:
                print(f"Warning unknown nested ret: {ret['key']}")
        span.end(end_time=ts_to_ns(end_ts))
    return end_ts


@api.route("/endpoint", methods=["POST"])
def endpoint():
    """Endpoint to accept Salt events."""
    payload = request.get_json()
    for event in payload:
        print(json.dumps(event))
        jid = event["jid"]
        jid_ts = jid_to_timestamp(jid)
        if not isinstance(event["data"]["return"], dict):
            print(f"Warning unknown root ret {event['data']['return']}")
            continue
        master, ret = list(event["data"]["return"]["data"].items())[0]
        # pylint: disable-next=cell-var-from-loop
        keys = sorted(ret, key=lambda k: ret[k].get("__run_num__", 0))
        start_ts = parse_start_time(jid_ts, ret[keys[0]].get("start_time"))
        root_span = get_tracer(master, trace_id=int(event["traceID"], 16)).start_span(
            event["job_name"],
            start_time=ts_to_ns(start_ts),
            attributes={
                "saltenv": event["saltenv"] or "None",
                "master": master,
                "jid": jid,
            },
        )
        root_span.set_status(
            trace.Status(
                status_code=trace.StatusCode.OK if event["success"] else trace.StatusCode.ERROR
            )
        )
        end_ts = parse_return(root_span, master, jid, ret)
        root_span.end(end_time=ts_to_ns(end_ts))
    return Response("", status=201)


# https://flask.palletsprojects.com/en/2.2.x/deploying/
# https://blog.miguelgrinberg.com/post/running-a-flask-application-as-a-service-with-systemd
def run():
    """Run the app."""
    app = create_app()
    host, port = TEMPO_RELAY_SOCKET.split(":")
    app.run(threaded=True, host=host, port=int(port))


if __name__ == "__main__":
    run()
