// observ-viz wg-easy (WireGuard) pack (hand-written).
// Built for wg-easy's built-in Prometheus endpoint (/metrics/prometheus,
// wireguard_* metrics) — enable it in wg-easy Admin > General > Prometheus and
// scrape with metrics_path=/metrics/prometheus.
// Usage:
//   g.libs.networking.wireguard.new({ selector: 'job="wg-easy"' }).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

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

    pack.build(cfg, signals, [
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
