import datetime
import json
from unittest.mock import MagicMock
from unittest.mock import patch

import pytest
import salt_tempo_relay as relay
from flask import url_for
from opentelemetry.sdk import trace


def test_fixed_id_generator():
    trace_id = int("d5c1eeb6ee114cab902c7d32bdf231bc", 16)
    generator = relay.FixedIdGenerator(trace_id)
    assert generator.generate_trace_id() == trace_id
    assert generator.generate_trace_id() == trace_id


def test_jid_to_timestamp():
    jid = "20221125153758613073"
    ts = datetime.datetime(2022, 11, 25, 15, 37, 58, 613073)
    assert relay.jid_to_timestamp(jid) == ts
    jid = "20221125153758613073_123"
    assert relay.jid_to_timestamp(jid) == ts


def test_ts_to_ns():
    ts = datetime.datetime(2022, 11, 25, 15, 37, 58, 13073)
    assert relay.ts_to_ns(ts) == 1669390678013073000


def test_parse_start_time():
    ts = datetime.datetime(2022, 11, 25, 15, 37, 58, 13073)
    assert relay.parse_start_time(ts, "15:38:00.011111") == datetime.datetime(
        2022, 11, 25, 15, 38, 00, 11111
    )
    assert relay.parse_start_time(ts, "15:37:00.111111") == datetime.datetime(
        2022, 11, 26, 15, 37, 00, 111111
    )


def test_get_tracer():
    trace_id = int("d5c1eeb6ee114cab902c7d32bdf231bc", 16)
    tracer1 = relay.get_tracer("saltmaster", trace_id=trace_id)
    assert tracer1.resource.attributes["service.name"] == "saltmaster"
    assert tracer1.id_generator.generate_trace_id() == trace_id
    tracer2 = relay.get_tracer("minion2")
    assert tracer2.resource.attributes["service.name"] == "minion2"
    assert tracer2.id_generator.generate_trace_id() != tracer2.id_generator.generate_trace_id()
    assert tracer1.span_processor._span_processors == tracer2.span_processor._span_processors


def test_index(client):
    res = client.get(url_for("api.index"))
    assert res.status_code == 200
    assert res.text == "Hello, world!"


class MySpanProcessor(trace.SpanProcessor):
    def __init__(self, name, span_list):
        self.name = name
        self.span_list = span_list

    @staticmethod
    def span_event_start_fmt(span_processor_name, span_name):
        return span_processor_name + ":" + span_name + ":start"

    @staticmethod
    def span_event_end_fmt(span_processor_name, span_name):
        return span_processor_name + ":" + span_name + ":end"

    def on_start(self, span, parent_context=None):
        self.span_list.append([self.span_event_start_fmt(self.name, span.name), span])

    def on_end(self, span):
        self.span_list.append([self.span_event_end_fmt(self.name, span.name), span])


def test_main(client):
    spans_calls_list1 = []  # filled by MySpanProcessor
    spans_calls_list2 = []  # filled by MySpanProcessor

    sp1 = MySpanProcessor("SP1", spans_calls_list1)
    sp2 = MySpanProcessor("SP2", spans_calls_list2)

    def post(data):
        return client.post(
            url_for("api.endpoint"), data=json.dumps(data), content_type="application/json"
        )

    with patch.object(relay, "processor", sp1), patch.object(relay, "processor_console", sp2):
        res = post(
            [
                {
                    "jid": "20221125153758613073",
                    "traceID": "d5c1eeb6ee114cab902c7d32bdf231bc",
                    "job_name": "orch.FAILING_sequential_with_no_runner_call",
                    "saltenv": "myenv",
                    "success": False,
                    "data": {
                        "fun": "runner.state.orchestrate",
                        "jid": "20221125153758613073",
                        "_stamp": "2022-11-25T15:37:59.114879",
                        "success": False,
                        "return": {
                            "data": {
                                "saltmaster": {
                                    "pkg_vim": {
                                        "result": True,
                                        "changes": {"foo": "bar"},
                                        "duration": 45.107,
                                        "start_time": "15:38:02.964364",
                                        "__run_num__": 0,
                                    },
                                    "bin/false": {
                                        "result": False,
                                        "changes": {"foo": "bar fail"},
                                        "duration": 11.944,
                                        "start_time": "15:38:18.248273",
                                        "__run_num__": 2,
                                    },
                                    "highstate": {
                                        "out": "highstate",
                                        "comment": "Run failed on minions: minion2",
                                        "duration": 15233.946,
                                        "result": False,
                                        "__jid__": "20221125153803072145",
                                        "start_time": "15:38:03.012898",
                                        "__run_num__": 1,
                                        "changes": {
                                            "ret": {
                                                "minion1": {
                                                    "sleep-2-1": {
                                                        "result": True,
                                                        "changes": {
                                                            "pid": 2892837,
                                                            "stderr": "",
                                                            "stdout": "",
                                                            "retcode": 0,
                                                        },
                                                        "comment": 'Command "sleep 2" run',
                                                        "duration": 2011.29,
                                                        "start_time": "15:38:06.096880",
                                                        "__run_num__": 0,
                                                        "__parallel__": True,
                                                    },
                                                    "sleep-2-2": {
                                                        "result": True,
                                                        "changes": {
                                                            "pid": 2892839,
                                                            "stderr": "",
                                                            "stdout": "",
                                                            "retcode": 0,
                                                        },
                                                        "comment": 'Command "sleep 2" run',
                                                        "duration": 2011.078,
                                                        "start_time": "15:38:06.116943",
                                                        "__run_num__": 1,
                                                        "__parallel__": True,
                                                    },
                                                    "sleep-2-3": {
                                                        "result": True,
                                                        "changes": {
                                                            "pid": 2892841,
                                                            "stderr": "",
                                                            "stdout": "",
                                                            "retcode": 0,
                                                        },
                                                        "comment": 'Command "sleep 2" run',
                                                        "duration": 2008.484,
                                                        "start_time": "15:38:06.124938",
                                                        "__run_num__": 2,
                                                        "__parallel__": True,
                                                    },
                                                },
                                                "minion2": False,
                                            },
                                        },
                                    },
                                },
                                "retcode": 1,
                                "outputter": "highstate",
                            },
                        },
                    },
                }
            ]
        )

        assert [sp[0] for sp in spans_calls_list1] == [
            "SP1:orch.FAILING_sequential_with_no_runner_call:start",
            "SP1:pkg_vim:start",
            "SP1:pkg_vim:end",
            "SP1:highstate:start",
            "SP1:sleep-2-1:start",
            "SP1:sleep-2-1:end",
            "SP1:sleep-2-2:start",
            "SP1:sleep-2-2:end",
            "SP1:sleep-2-3:start",
            "SP1:sleep-2-3:end",
            "SP1:highstate:end",
            "SP1:bin/false:start",
            "SP1:bin/false:end",
            "SP1:orch.FAILING_sequential_with_no_runner_call:end",
        ]

        assert [dict(sp[1].attributes) for sp in spans_calls_list1] == [
            {"saltenv": "myenv", "master": "saltmaster", "jid": "20221125153758613073"},
            {},
            {},
            {
                "changes": '{"ret": {"minion1": {"sleep-2-1": {"result": true, "changes": '
                '{"pid": 2892837, "stderr": "", "stdout": "", "retcode": 0}, '
                '"comment": "Command \\"sleep 2\\" run", "duration": 2011.29, '
                '"start_time": "15:38:06.096880", "__run_num__": 0, '
                '"__parallel__": true}, "sleep-2-2": {"result": true, "changes": '
                '{"pid": 2892839, "stderr": "", "stdout": "", "retcode": 0}, '
                '"comment": "Command \\"sleep 2\\" run", "duration": 2011.078, '
                '"start_time": "15:38:06.116943", "__run_num__": 1, '
                '"__parallel__": true}, "sleep-2-3": {"result": true, "changes": '
                '{"pid": 2892841, "stderr": "", "stdout": "", "retcode": 0}, '
                '"comment": "Command \\"sleep 2\\" run", "duration": 2008.484, '
                '"start_time": "15:38:06.124938", "__run_num__": 2, '
                '"__parallel__": true}}, "minion2": false}}',
                "comment": "Run failed on minions: minion2",
            },
            {"minion": "minion1"},
            {"minion": "minion1"},
            {"minion": "minion1"},
            {"minion": "minion1"},
            {"minion": "minion1"},
            {"minion": "minion1"},
            {
                "changes": '{"ret": {"minion1": {"sleep-2-1": {"result": true, "changes": '
                '{"pid": 2892837, "stderr": "", "stdout": "", "retcode": 0}, '
                '"comment": "Command \\"sleep 2\\" run", "duration": 2011.29, '
                '"start_time": "15:38:06.096880", "__run_num__": 0, '
                '"__parallel__": true}, "sleep-2-2": {"result": true, "changes": '
                '{"pid": 2892839, "stderr": "", "stdout": "", "retcode": 0}, '
                '"comment": "Command \\"sleep 2\\" run", "duration": 2011.078, '
                '"start_time": "15:38:06.116943", "__run_num__": 1, '
                '"__parallel__": true}, "sleep-2-3": {"result": true, "changes": '
                '{"pid": 2892841, "stderr": "", "stdout": "", "retcode": 0}, '
                '"comment": "Command \\"sleep 2\\" run", "duration": 2008.484, '
                '"start_time": "15:38:06.124938", "__run_num__": 2, '
                '"__parallel__": true}}, "minion2": false}}',
                "comment": "Run failed on minions: minion2",
            },
            {"changes": '{"foo": "bar fail"}', "comment": ""},
            {"changes": '{"foo": "bar fail"}', "comment": ""},
            {"saltenv": "myenv", "master": "saltmaster", "jid": "20221125153758613073"},
        ]

        assert [(sp[1].start_time, sp[1].end_time) for sp in spans_calls_list1] == [
            (1669390682964364000, 1669390698260217000),
            (1669390682964364000, 1669390683009471000),
            (1669390682964364000, 1669390683009471000),
            (1669390683012898000, 1669390698246844000),
            (1669390686096880000, 1669390688108170000),
            (1669390686096880000, 1669390688108170000),
            (1669390686116943000, 1669390688128021000),
            (1669390686116943000, 1669390688128021000),
            (1669390686124938000, 1669390688133422000),
            (1669390686124938000, 1669390688133422000),
            (1669390683012898000, 1669390698246844000),
            (1669390698248273000, 1669390698260217000),
            (1669390698248273000, 1669390698260217000),
            (1669390682964364000, 1669390698260217000),
        ]

        assert [str(sp[1].status.status_code) for sp in spans_calls_list1] == [
            "StatusCode.ERROR",
            "StatusCode.OK",
            "StatusCode.OK",
            "StatusCode.ERROR",
            "StatusCode.OK",
            "StatusCode.OK",
            "StatusCode.OK",
            "StatusCode.OK",
            "StatusCode.OK",
            "StatusCode.OK",
            "StatusCode.ERROR",
            "StatusCode.ERROR",
            "StatusCode.ERROR",
            "StatusCode.ERROR",
        ]
