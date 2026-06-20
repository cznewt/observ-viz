// common-lib annotations — reboot. Marks host reboots (uses the value as the
// event time), tagged by instance labels.
local colors = import 'libs/common-lib/tokens/colors.libsonnet';
local base = import 'libs/common-lib/annotations/base.libsonnet';
base {
  new(title, target, instanceLabels=[]):
    super.new(title, target)
    + { spec+: { iconColor: colors.palette.warning, hide: true, useValueForTime: 'on' } }
    + base.withTagKeys(instanceLabels),
}
