// common-lib tokens/colors
// Semantic colour palette reused by
// annotations + panel presets.
{
  palette: {
    critical: '#ff7383',  // light-red
    warning: '#fade2a',  // yellow
    info: '#5794f2',  // blue
    fatal: '#ca95e5',  // light-purple

    // request semantics
    rate: '#5794f2',
    duration: '#73bf69',
    errors: '#ff7383',
  },

  // Annotation colours: one per kind of event, the same on every board.
  annotation: {
    critical: '#ff7383',  // light-red: critical alerts
    warning: '#ff9830',  // orange: warning alerts
    info: '#5794f2',  // blue: info alerts
    fatal: '#ca95e5',  // light-purple: fatal
    restart: '#fade2a',  // yellow: something broke - container restarts, reboots, failed services
    start: '#5ac4cc',  // teal: something started - pod, container, process, service starts
    change: '#73bf69',  // green: a change shipped - deploys, version changes
    event: '#9fa7b3',  // grey: background - all Kubernetes events
  },
}
