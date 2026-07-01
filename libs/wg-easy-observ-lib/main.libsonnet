// observ-viz wg-easy (WireGuard) pack (hand-written).
// Built for wg-easy's built-in Prometheus endpoint (/metrics/prometheus,
// wireguard_* metrics) — enable it in wg-easy Admin > General > Prometheus and
// scrape with metrics_path=/metrics/prometheus.
// Usage:
//   g.libs.networking.wireguard.new({ selector: 'job="wg-easy"' }).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-wg-easy',
      dashboardTitle: 'WireGuard (wg-easy)',
      dashboardTags: ['wireguard', 'wg-easy', 'vpn'],
      datasource: '${datasource}',
      selector: 'job=~"$job", instance=~"$instance"',
      varMetric: 'wireguard_configured_peers',
      varLabels: ['instance'],
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';

    // per-peer metrics carry the wg-easy client name; if your build labels peers
    // differently (friendly_name / interface), override the legend.
    local sig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      configuredPeers: sig('Configured peers', 'sum(wireguard_configured_peers{%(queriesSelector)s})', 'short'),
      enabledPeers: sig('Enabled peers', 'sum(wireguard_enabled_peers{%(queriesSelector)s})', 'short'),
      connectedPeers: sig('Connected peers', 'sum(wireguard_connected_peers{%(queriesSelector)s})', 'short'),
      sentBytes: sig('Sent', 'rate(wireguard_sent_bytes{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{name}}'),
      receivedBytes: sig('Received', 'rate(wireguard_received_bytes{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{name}}'),
      // wg-easy already exports this as the AGE (seconds since last handshake),
      // not a unix timestamp — so use it directly, no `time() -`. 0 = never handshaked.
      handshakeAge: sig('Handshake age', 'wireguard_latest_handshake_seconds{%(queriesSelector)s}', 's', '{{instance}} / {{name}}'),
    };

    // Per-peer overview table: In (received) / Out (sent) transfer totals + handshake
    // age, joined by peer name via instant table queries + seriesToColumns.
    local tq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local peersTable =
      panel.table.new('Peer overview')
      + panel.table.withTargets([
        tq('wireguard_received_bytes{' + cfg.selector + '}'),         // A: In
        tq('wireguard_sent_bytes{' + cfg.selector + '}'),             // B: Out
        tq('wireguard_latest_handshake_seconds{' + cfg.selector + '}'),  // C: Handshake age
        // D: Active = handshaked within the last 3m (0/1 per peer; 0=never/stale)
        tq('sum by (name) ((wireguard_latest_handshake_seconds{' + cfg.selector + '} > bool 0) * (wireguard_latest_handshake_seconds{' + cfg.selector + '} < bool 180))'),
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['name', 'ipv4Address', 'enabled', 'Value #A', 'Value #B', 'Value #C', 'Value #D'] } } },
        { id: 'seriesToColumns', options: { byField: 'name' } },
        { id: 'organize', options: {
          excludeByName: { 'ipv4Address 2': true, 'ipv4Address 3': true, 'enabled 2': true, 'enabled 3': true },
          indexByName: { name: 0, ipv4Address: 1, 'Value #D': 2, 'Value #A': 3, 'Value #B': 4, 'Value #C': 5, enabled: 6 },
          renameByName: { name: 'Peer', ipv4Address: 'Address', enabled: 'Enabled', 'Value #A': 'In', 'Value #B': 'Out', 'Value #C': 'Handshake', 'Value #D': 'Active' },
        } },
      ])
      + panel.table.withOverrides([
        ov('In|Out', [{ id: 'unit', value: 'bytes' }]),
        ov('Handshake', [{ id: 'unit', value: 's' }]),
        ov('Active', [
          { id: 'mappings', value: [{ type: 'value', options: { '1': { text: 'true', color: 'green', index: 0 }, '0': { text: 'false', color: 'red', index: 1 } } }] },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
        ]),
      ]);

    pack.build(cfg, signals, [
      {
        title: 'Peer overview',
        width: 24,
        height: 9,
        elements: {
          peersTable: peersTable,
        },
      },
      {
        title: 'Peers',
        width: 12,
        height: 7,
        elements: {
          connectedPeers: signals.connectedPeers.asStat('Connected peers'),
          enabledPeers: signals.enabledPeers.asStat('Enabled peers'),
          configuredPeers: signals.configuredPeers.asStat('Configured peers'),
        },
      },
      {
        title: 'Traffic',
        width: 12,
        height: 7,
        elements: {
          receivedBytes: signals.receivedBytes.asTimeSeries('Received'),
          sentBytes: signals.sentBytes.asTimeSeries('Sent'),
        },
      },
      {
        title: 'Handshakes',
        width: 12,
        height: 7,
        elements: {
          handshakeAge: signals.handshakeAge.asTimeSeries('Time since last handshake'),
        },
      },
    ], [
      alert.rule.group('wg-easy', [
        alert.rule.new(
          'WireguardPeerHandshakeStale',
          'wireguard_latest_handshake_seconds' + rsBrace + ' > 600',
          '10m',
          'warning',
          {},
          {
            summary: 'WireGuard peer handshake is stale.',
            description: 'WireGuard peer {{ $labels.name }} on {{ $labels.instance }} has not completed a handshake in over 10 minutes.',
          }
        ),
      ]),
    ]),
}
