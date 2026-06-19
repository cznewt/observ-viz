// This file is generated, do not manually edit.
// TimeSettingsSpec field setters. Compose with `+`, pass result to
// g.dashboard.withTimeSettings(...).
{
  '#withTimezone':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'IANA TZDB zone, "browser" or "utc".' } },
  withTimezone(value): { timezone: value },
  '#withFrom':: { 'function': { args: [{ default: 'now-6h', enums: null, name: 'value', type: ['string'] }], help: 'Range start.' } },
  withFrom(value='now-6h'): { from: value },
  '#withTo':: { 'function': { args: [{ default: 'now', enums: null, name: 'value', type: ['string'] }], help: 'Range end.' } },
  withTo(value='now'): { to: value },
  '#withAutoRefresh':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Auto-refresh interval, "" for off.' } },
  withAutoRefresh(value): { autoRefresh: value },
  '#withAutoRefreshIntervals':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Selectable refresh intervals.' } },
  withAutoRefreshIntervals(value): { autoRefreshIntervals: value },
  '#withHideTimepicker':: { 'function': { args: [{ default: true, enums: null, name: 'value', type: ['boolean'] }], help: 'Hide the timepicker UI.' } },
  withHideTimepicker(value=true): { hideTimepicker: value },
  '#withWeekStart':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Week start day.' } },
  withWeekStart(value): { weekStart: value },
  '#withFiscalYearStartMonth':: { 'function': { args: [{ default: 0, enums: null, name: 'value', type: ['integer'] }], help: 'Fiscal year start month (0-11).' } },
  withFiscalYearStartMonth(value=0): { fiscalYearStartMonth: value },
  '#withNowDelay':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Delay applied to "now".' } },
  withNowDelay(value): { nowDelay: value },
}
