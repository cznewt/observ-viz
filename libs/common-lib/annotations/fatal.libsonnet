// common-lib annotations — fatal (light-purple).
local base = import 'libs/common-lib/annotations/base.libsonnet';
local colors = import 'libs/common-lib/tokens/colors.libsonnet';
base {
  new(title, target):
    super.new(title, target)
    + { spec+: { iconColor: colors.palette.fatal } },
}
