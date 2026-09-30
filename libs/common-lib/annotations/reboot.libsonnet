// common-lib annotations — reboot. Marks host reboots (uses the value as the
// event time), tagged by instance labels.
local base = import 'libs/common-lib/annotations/base.libsonnet';
local colors = import 'libs/common-lib/tokens/colors.libsonnet';
base {
  new(title, target, instanceLabels=[]):
    super.new(title, target)
    + { spec+: { iconColor: colors.palette.warning, hide: true, legacyOptions+: { useValueForTime: true } } }
    + base.withTagKeys(instanceLabels),
}
