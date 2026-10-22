// observ-viz alert runbooks (hand-written). An alerting rule's runbook is the
// one it carries (alert.rule.withRunbook -> the `runbook` annotation), else a
// generated one in the shape of runbooks.prometheus-operator.dev - what it
// means, what it affects, how to check it, what to do about it. The packs'
// Runbooks tab and the docs site (scripts/gen-lib-doc.py) both read it from here.
// Every alerting rule a pack renders carries a runbook_url: the one it was
// written with, else its page on the docs site, <docsBase>runbooks/<alert>/
// (scripts/gen-board-pages.py writes one page per alert name).
{
  // the docs site the runbook links point at (a pack's config.runbookBaseUrl
  // overrides it, '' for no link)
  docsBase:: 'https://cznewt.github.io/observ-viz/',

  // a rule annotation, or the fallback when it is missing or empty
  ann(r, k, fallback=''):: if std.objectHas(r, 'annotations') && std.objectHas(r.annotations, k) && r.annotations[k] != '' then r.annotations[k] else fallback,
  severity(r):: if std.objectHas(r, 'labels') && std.objectHas(r.labels, 'severity') then r.labels.severity else 'warning',

  // the docs site's slug (gen-board-pages.py slug()): lower case, each run of
  // characters outside [a-z0-9] one dash, no dash at either end
  slug(s)::
    local keep(c) = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9');
    local dashed = std.join('', [if keep(c) then c else '-' for c in std.stringChars(std.asciiLower(s))]);
    std.join('-', [p for p in std.split(dashed, '-') if p != '']),

  // the runbook_url of a rule: the written one, else its page under `base`
  url(r, base=self.docsBase):: self.ann(r, 'runbook_url', if base == '' then '' else base + 'runbooks/' + self.slug(r.alert) + '/'),

  // a written runbook's URL - the rule's runbook_url unless it is the docs
  // site's own page for the alert
  writtenUrl(r)::
    local url = self.ann(r, 'runbook_url');
    local n = std.length(self.docsBase);
    if std.length(url) >= n && std.substr(url, 0, n) == self.docsBase then '' else url,

  // the pack's rule groups with a runbook_url on every alerting rule
  withUrls(groups, base=self.docsBase)::
    local rb = self;
    if base == '' then groups else [
      grp + { rules: [
        if std.objectHas(r, 'alert') && rb.ann(r, 'runbook_url') == '' then r + { annotations+: { runbook_url: rb.url(r, base) } } else r
        for r in grp.rules
      ] }
      for grp in groups
    ],

  generated(r)::
    local summary = self.ann(r, 'summary', r.alert + ' is firing.');
    local description = self.ann(r, 'description', '');
    local url = self.writtenUrl(r);
    local sev = self.severity(r);
    local impact =
      if sev == 'critical' then 'Something users depend on is already broken or about to be. Treat it as an incident.'
      else if sev == 'warning' then 'Nothing is broken yet, and it will be if the trend holds. Look at it this working day.'
      else 'Informational. It is context for another alert rather than work of its own.';
    std.join('\n', [
      '### Meaning',
      '',
      summary,
      '',
    ] + (if description != '' then [description, ''] else []) + [
      'It fires when the expression below holds for ' + (if std.objectHas(r, 'for') then r['for'] else 'one evaluation') + '.',
      '',
      '### Impact',
      '',
      impact,
      '',
      '### Diagnosis',
      '',
      'Run the alert expression and look at which series cross the threshold:',
      '',
      '```promql',
      r.expr,
      '```',
      '',
      'Then open this board with the same selectors: the tab that carries those metrics shows how long the series has been where it is, and the restart and deploy annotations show whether a release or a restart lines up with the change.',
      '',
      '### Mitigation',
      '',
      '- Confirm the target is the one you think it is: check the labels on the firing series.',
      '- Compare against the same series on a healthy peer; a single instance out of line is a different problem from every instance moving together.',
      '- If a deploy or restart lines up with the change, that is the first thing to undo.',
      '- If the threshold no longer matches how this service behaves, change the rule rather than living with a permanent alert.',
    ] + (if url != '' then ['', 'Written runbook: ' + url] else [])),

  // the runbook to show: the written one, else the generated one
  of(r):: self.ann(r, 'runbook', self.generated(r)),
}
