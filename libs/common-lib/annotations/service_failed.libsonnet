// common-lib annotations — service failed (warning, hidden by default).
local colors = import 'libs/common-lib/tokens/colors.libsonnet';
local base = import 'libs/common-lib/annotations/base.libsonnet';
base {
  new(title, target):
    super.new(title, target)
    + { spec+: { iconColor: colors.palette.warning, hide: true } },
}
