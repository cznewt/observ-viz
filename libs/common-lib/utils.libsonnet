// common-lib utils.
// Label -> selector / legend / URL helpers + chainLabels for chained variables.
// Pure std (no grafonnet dependency); reused across common-lib.
{
  local this = self,

  labelsToURLvars(labels, prefix)::
    std.join('&', ['var-%s=${%s%s}' % [label, prefix, label] for label in labels]),

  // For PromQL or LogQL
  labelsToPromQLSelector(labels): std.join(',', ['%s=~"$%s"' % [label, label] for label in labels]),
  labelsToLogQLSelector: self.labelsToPromQLSelector,
  labelsToPromQLSelectorAdvanced(labels): std.join(',', ['%s=~"${%s:regex}"' % [label, label] for label in labels]),
  labelsToLogQLSelectorAdvanced: self.labelsToPromQLSelectorAdvanced,

  labelsToPanelLegend(labels, separator='/'): std.join(separator, ['{{%s}}' % [label] for label in labels]),

  // One PromQL/LogQL expression as a markdown table cell: pipes escaped (they
  // would end the cell), newlines folded, and a line break before each ' / ' so
  // a ratio does not stretch the Query column. HTML <code> rather than a
  // backtick span, because a markdown code span renders <br> literally.
  mdQuery(expr, breakOn=[' / '])::
    local oneLine = std.strReplace(expr, '\n', ' ');
    local escaped = std.strReplace(oneLine, '|', '\\|');
    local broken = std.foldl(function(acc, op) std.strReplace(acc, op, '<br>' + std.lstripChars(op, ' ')), breakOn, escaped);
    '<code>' + broken + '</code>',

  toSentenceCase(string)::
    std.asciiUpper(string[0]) + std.slice(string, 1, std.length(string), 1),

  // Generate a chain of labels. Useful to create chained variables:
  chainLabels(labels, additionalFilters=[]):
    local last(arr) = std.reverse(arr)[0];
    local chainSelector(chain) =
      std.join(
        ',',
        additionalFilters
        + (if std.length(chain) > 0
           then [this.labelsToPromQLSelector(chain)]
           else [])
      );
    std.foldl(
      function(prev, label)
        prev
        + [{
          label: label,
          chainSelector: chainSelector(self.chain),
          chain::
            if std.length(prev) > 0
            then last(prev).chain + [last(prev).label]
            else [],
        }],
      labels,
      []
    ),
}
