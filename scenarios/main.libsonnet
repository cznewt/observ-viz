// observ-viz scenarios — deployment profiles. Each is a built scenario
// (folder of observ-lib boards + merged alerts + Backstage system).
local scenario = import 'scenarios/_scenario.libsonnet';
local build(cfg) = scenario.new(cfg);
{
  'linux-server': build(import 'scenarios/linux-server/config.libsonnet'),
  'linux-desktop': build(import 'scenarios/linux-desktop/config.libsonnet'),
  'linux-docker': build(import 'scenarios/linux-docker/config.libsonnet'),
  'linux-podman': build(import 'scenarios/linux-podman/config.libsonnet'),
  kubernetes: build(import 'scenarios/kubernetes/config.libsonnet'),
  lgtm: build(import 'scenarios/lgtm/config.libsonnet'),
}
