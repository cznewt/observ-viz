# The observ-lib container

Each observ-lib is a **container** that handles both the Grafana **viz** and the
Prometheus **rules**. One entry point renders it to **three dirs**:

```
build/<lib>/dashboards/<uid>.json    Grafana v2 dashboard resources
build/<lib>/alerts/<group>.yaml      alerting rule groups   (one file per group)
build/<lib>/rules/<group>.yaml       recording rule groups  (one file per group)
```

## Entry points

| command | does |
|---------|------|
| `just render-lib <lib>` | render to the 3 dirs |
| `just validate-lib <lib>` | render + structural checks (+ `promtool check rules` if installed) |
| `just deploy-lib <lib>` | render + validate + deploy: dashboards → Grafana (v2 API), rule groups → Mimir ruler (if `MIMIR_RULER_URL` set) |

```sh
just render-lib   iot.homeAssistant
just validate-lib iot.homeAssistant
just deploy-lib   iot.homeAssistant
# or directly / in the image:
python3 scripts/render-lib.py iot.homeAssistant --validate --deploy
docker run --rm -v "$PWD/build":/work/build ghcr.io/cznewt/observ-viz render-lib iot.homeAssistant --validate
```

## Contract

```jsonnet
g.libs.<group>.<name>.new(config) -> {
  signals,
  grafana:    { dashboard, dashboards, elements, layout, groups },
  prometheus: { alerts: [ruleGroup], rules: [ruleGroup] },   // alerting + recording
  asMonitoringMixin(),                                       // grafanaDashboards + prometheusAlerts + prometheusRules
}
```

Rules are authored with the common-lib alert builder and passed to `pack.build`:

```jsonnet
local alert = g.common.alert;
pack.build(cfg, signals, groups,
  [ alert.rule.group('home-assistant', [
      alert.rule.new('HomeAssistantDeviceLowBattery', 'hass_device_battery_remaining < 15', '10m', 'warning', {},
                     { summary: 'Device {{ $labels.device_name }} battery low.' }),
    ]) ],
  [ alert.rule.group('home-assistant.rules', [
      alert.rule.record('hass:entity_available:ratio', 'avg(hass_entity_available)'),
    ]) ])
```

## Example — home-assistant

`iot.homeAssistant` is the worked example: a 14-panel dashboard, a `home-assistant`
alerting group (low battery / entity unavailable / stale entity / weak Zigbee
signal) and a `home-assistant.rules` recording group (availability ratio, min
battery, device count) — rendered, validated and deployed by the commands above.
