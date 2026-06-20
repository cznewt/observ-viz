// observ-viz alert namespace — reusable alert rules + alert panels + signals.
{
  rule: import 'libs/common-lib/alert/rule.libsonnet',
  panels: import 'libs/common-lib/alert/panels.libsonnet',
  signals: import 'libs/common-lib/alert/signals.libsonnet',
}
