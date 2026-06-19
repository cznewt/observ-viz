// observ-viz string utilities (hand-written veneer)
{
  // slugify lowercases, replaces any run of non-alphanumeric chars with a single
  // dash, and trims leading/trailing dashes. Used to derive a default dashboard
  // uid (metadata.name) from a title.
  slugify(s)::
    local lower = std.asciiLower(s);
    local mapped = std.join('', [
      local c = std.codepoint(ch);
      if (c >= 97 && c <= 122) || (c >= 48 && c <= 57) then ch else '-'
      for ch in std.stringChars(lower)
    ]);
    // collapse repeated dashes
    local collapsed =
      std.join('-', std.filter(function(x) x != '', std.split(mapped, '-')));
    collapsed,
}
