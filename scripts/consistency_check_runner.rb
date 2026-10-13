#!/usr/bin/env ruby
# frozen_string_literal: true

# Declarative consistency-check runner. Parses consistency-checks.yaml
# at repo root; dispatches subprocess, diff, hash, regex-presence, tally,
# remote-query. Plain ASCII output.

require "digest"
require "fileutils"
require "open3"
require "pathname"
require "psych"
require "set"

# Force UTF-8 across all file I/O. Avoids `invalid byte sequence in
# US-ASCII` crashes on em dashes / other Unicode in target files when
# the shell locale isn't UTF-8 (Ruby's File.read otherwise inherits the
# external locale, which is ASCII on minimal shells).
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# PASS/SKIP lines go to stdout and FAIL lines to stderr. Unbuffered stdout keeps
# a check's own diagnostic output ahead of the FAIL line it explains.
$stdout.sync = true

ROOT = ENV.fetch("CONSISTENCY_REPO_ROOT")

# A subprocess check reports that it could not run (for example an optional
# tool is missing) by printing SKIP_REASON_PREFIX plus a reason as its last line
# of stdout and exiting SUBPROCESS_SKIP_EXIT. Both are required: a script that
# dies with 77 for any other reason is a failure, not a skip. Exit 0 always
# means PASS, so a check that cannot run must not exit 0. 77 is the automake
# SKIP convention.
SUBPROCESS_SKIP_EXIT = 77
SKIP_REASON_PREFIX = "SKIP_REASON: "

# Output that claims a skip. A script that prints it and exits 0 would read as
# a pass, so that combination is a failure.
SKIP_CLAIM = /^\s*SKIP(\b|_REASON:)/

# Every handler returns one of :pass, :fail or :skip. A skip is never a pass.
def fail_check(id, error, fix)
  warn "FAIL #{id}: #{error}"
  warn "     Fix: #{fix}"
  :fail
end

def pass_check(id)
  puts "PASS #{id}"
  :pass
end

def skip_check(id, reason)
  puts "SKIP #{id} (#{reason})"
  :skip
end

def load_config(path)
  raw = File.read(path)
  doc = Psych.safe_load(raw, permitted_classes: [Symbol])
  return doc["checks"] if doc.is_a?(Hash) && doc["checks"].is_a?(Array)

  doc if doc.is_a?(Array)
end

def expand_files(pattern)
  return [] if pattern.nil?

  list = pattern.is_a?(Array) ? pattern : [pattern]
  paths = []
  list.each do |entry|
    Dir.glob(File.join(ROOT, entry), File::FNM_PATHNAME | File::FNM_DOTMATCH).sort.each do |p|
      paths << p if File.file?(p)
    end
  end
  paths.uniq
end

def handle_subprocess(check)
  cmd = check.fetch("runs")
  env = { "ROOT" => ROOT }
  out, err, status = Open3.capture3(env, "bash", "-c", cmd, chdir: ROOT)

  # On a skip, the marker line carries the reason and is folded into the SKIP
  # line rather than printed twice.
  if status.exitstatus == SUBPROCESS_SKIP_EXIT
    lines = out.lines
    last = lines.last.to_s.chomp
    if last.start_with?(SKIP_REASON_PREFIX)
      lines.pop
      $stdout.write(lines.join)
      $stderr.write(err)
      reason = last.delete_prefix(SKIP_REASON_PREFIX).strip
      return skip_check(check["id"], reason.empty? ? "subprocess reported skip" : reason)
    end

    $stdout.write(out)
    $stderr.write(err)
    return fail_check(check["id"],
                      "subprocess exited #{SUBPROCESS_SKIP_EXIT} without a '#{SKIP_REASON_PREFIX}' last line of stdout",
                      "To skip, print '#{SKIP_REASON_PREFIX}<why>' as the last stdout line before exiting " \
                      "#{SUBPROCESS_SKIP_EXIT}. Otherwise the script failed: #{check.fetch('fix', '')}")
  end

  $stdout.write(out)
  $stderr.write(err)
  unless status.success?
    return fail_check(check["id"], "subprocess exited non-zero", check.fetch("fix", ""))
  end
  if (out + err).lines.any? { |l| SKIP_CLAIM.match?(l) }
    return fail_check(check["id"], "subprocess printed SKIP but exited 0, which reads as a pass",
                      "Print '#{SKIP_REASON_PREFIX}<why>' last and exit #{SUBPROCESS_SKIP_EXIT} when the check cannot run.")
  end

  pass_check(check["id"])
end

def handle_diff(check)
  a = File.join(ROOT, check.fetch("a"))
  b = File.join(ROOT, check.fetch("b"))
  return fail_check(check["id"], "missing #{check['a']}", check["fix"]) unless File.file?(a)
  return fail_check(check["id"], "missing #{check['b']}", check["fix"]) unless File.file?(b)

  ok = system("diff", "-q", a, b, out: File::NULL, err: File::NULL)
  return pass_check(check["id"]) if ok

  fail_check(check["id"], "#{check['a']} and #{check['b']} differ", check.fetch("fix", ""))
end

def handle_hash(check)
  src = File.join(ROOT, check.fetch("source"))
  hf = File.join(ROOT, check.fetch("hash_file"))
  return fail_check(check["id"], "missing #{check['source']}", check["fix"]) unless File.file?(src)
  return fail_check(check["id"], "missing #{check['hash_file']}", check["fix"]) unless File.file?(hf)

  actual = Digest::SHA256.file(src).hexdigest
  expected = File.read(hf).strip.split(/\s+/).first
  return pass_check(check["id"]) if actual == expected

  fail_check(check["id"], "sha256 mismatch", check.fetch("fix", ""))
end

def handle_regex_presence(check)
  pattern = Regexp.new(check.fetch("pattern"))
  exempt = Set.new(check.fetch("exempt", []))
  paths = expand_files(check.fetch("files"))
  return fail_check(check["id"], "no files matched", check.fetch("fix", "")) if paths.empty?

  missing = paths.reject do |p|
    rel = Pathname.new(p).relative_path_from(Pathname.new(ROOT)).to_s
    next true if exempt.include?(rel)

    pattern.match?(File.read(p))
  end
  return fail_check(check["id"], "pattern not found in: #{missing.join(', ')}", check.fetch("fix", "")) unless missing.empty?

  pass_check(check["id"])
end

def handle_tally(check)
  case check.fetch("validator", "")
  when "propagation-tracker"
    tally_propagation_tracker(check)
  else
    pattern = Regexp.new(check.fetch("pattern"))
    count = 0
    expand_files(check.fetch("files")).each do |p|
      count += File.read(p).scan(pattern).length
    end
    expected = check.fetch("expected")
    return fail_check(check["id"], "expected #{expected} occurrences, found #{count}", check.fetch("fix", "")) unless count == expected

    pass_check(check["id"])
  end
end

def tally_propagation_tracker(check)
  path = File.join(ROOT, "commercial", "BRAND_POSITIONING_PROPAGATION_TRACKER.md")
  return fail_check(check["id"], "missing tracker file", check["fix"]) unless File.file?(path)

  body = File.read(path)
  summary = parse_tracker_summary(body)
  return fail_check(check["id"], "could not parse summary table", check.fetch("fix", "")) if summary[:repos].empty?

  summary[:repos].each do |name, cols|
    a, d, c, p, t = cols
    sum = a + d + c + p
    unless sum == t
      return fail_check(check["id"], "#{name}: column sum #{sum} != Total #{t}", check.fetch("fix", ""))
    end
  end

  repo_total_sum = summary[:repos].values.sum { |cols| cols.last }
  unless repo_total_sum == summary[:grand_total]
    return fail_check(check["id"], "sum of per-repo Totals (#{repo_total_sum}) != grand total #{summary[:grand_total]}",
                      check.fetch("fix", ""))
  end

  col_sums = column_sums(summary[:repos])
  unless col_sums == summary[:total_row][0..3]
    return fail_check(check["id"], "column sums #{col_sums.inspect} != TOTAL row #{summary[:total_row][0..3].inspect}",
                      check.fetch("fix", ""))
  end

  section_counts = count_tracker_section_rows(body, summary[:repos].keys)
  section_counts.each do |name, counted|
    expected = summary[:repos][name].last
    unless counted == expected
      return fail_check(check["id"], "#{name}: section rows #{counted} != summary Total #{expected}", check.fetch("fix", ""))
    end
  end

  pass_check(check["id"])
end

def parse_tracker_summary(body)
  repos = {}
  total_row = nil
  grand_total = nil
  pos = body.index("## Status summary")
  return { repos: repos, total_row: total_row, grand_total: grand_total } unless pos

  lines = body[pos..].lines
  hdr = lines.index { |l| l.strip.match?(/^\|\s*Repo\s*\|/) }
  return { repos: repos, total_row: total_row, grand_total: grand_total } unless hdr

  data_lines = lines[(hdr + 2)..] || []
  data_lines.each do |line|
    stripped = line.strip
    break if stripped.empty?
    break if stripped.start_with?("(")

    next unless stripped.start_with?("|")
    next if stripped.include?("---")

    cells = stripped.split("|").map(&:strip).reject(&:empty?)
    next if cells.first =~ /^Repo$/i

    if cells.first =~ /\*\*TOTAL\*\*/
      nums = cells[1..5].map { |x| x.gsub(/\*+/, "").to_i }
      total_row = nums
      grand_total = nums.last
      next
    end

    name = cells.first
    nums = cells[1..5]&.map(&:to_i)
    repos[name] = nums if nums&.length == 5
  end

  { repos: repos, total_row: total_row, grand_total: grand_total }
end

def column_sums(repo_hash)
  sums = [0, 0, 0, 0]
  repo_hash.each_value do |cols|
    4.times { |i| sums[i] += cols[i] }
  end
  sums
end

def count_tracker_section_rows(body, repo_names)
  counts = {}
  repo_names.each do |full_name|
    short = full_name.split("(").first.strip
    rx = /^## #{Regexp.escape(short)}(\s|$)/
    start = body.index(rx)
    next counts[full_name] = 0 unless start

    rest = body[start..]
    nxt = rest.index(/^## /m, 3)
    section = nxt ? rest[0...nxt] : rest
    counts[full_name] = count_markdown_table_rows(section)
  end
  counts
end

def count_markdown_table_rows(section)
  lines = section.lines.map(&:chomp)
  i = 0
  while i < lines.length - 1
    cur = lines[i]
    nxt = lines[i + 1]
    if cur.start_with?("|") && !cur.include?("---") && nxt&.start_with?("|") && nxt.include?("---")
      i += 2
      count = 0
      while i < lines.length && lines[i].start_with?("|")
        count += 1 unless lines[i].include?("---")
        i += 1
      end
      return count
    end
    i += 1
  end
  0
end

def handle_remote_query(check, local_only)
  return skip_check(check["id"], "remote check, --local-only") if local_only

  fail_check(check["id"], "remote-query not wired in this repo", check.fetch("fix", ""))
end

def main(argv)
  local_only = argv.include?("--local-only")
  remote_only = argv.include?("--remote-only")
  one_check = nil
  argv.each_with_index do |a, idx|
    next unless a == "--check"

    one_check = argv[idx + 1]
    if one_check.nil? || one_check.start_with?("--")
      warn "FAIL: --check needs a check id"
      exit 2
    end
  end

  cfg = File.join(ROOT, "consistency-checks.yaml")
  unless File.file?(cfg)
    warn "FAIL: consistency-checks.yaml missing at repo root"
    exit 2
  end

  checks = load_config(cfg)
  unless checks.is_a?(Array)
    warn "FAIL: consistency-checks.yaml must be a list or checks: array"
    exit 2
  end

  if one_check
    checks.select! { |c| c["id"] == one_check }
    if checks.empty?
      warn "FAIL: no check with id #{one_check}"
      exit 2
    end
  end

  results = { pass: [], skip: [], fail: [] }
  checks.each do |check|
    id = check["id"]
    type = check["type"]
    next if remote_only && type != "remote-query"
    if local_only && type == "remote-query"
      results[:skip] << id
      skip_check(id, "remote check, --local-only")
      next
    end

    result = case type
             when "subprocess" then handle_subprocess(check)
             when "diff" then handle_diff(check)
             when "hash" then handle_hash(check)
             when "regex-presence" then handle_regex_presence(check)
             when "tally" then handle_tally(check)
             when "remote-query" then handle_remote_query(check, local_only)
             else
               fail_check(id, "unknown type #{type}", "Fix consistency-checks.yaml")
             end
    results.fetch(result) << id
  end

  print_summary(results)
  exit 2 if results.values.sum(&:length).zero?
  exit(results[:fail].empty? ? 0 : 1)
end

# Skips do not fail the run: a missing optional tool must not block a push.
# They are reported as unverified so the summary never claims they passed.
# A run in which nothing ran verified nothing, so it exits non-zero rather than
# reading as a clean pass.
def print_summary(results)
  puts
  if results.values.sum(&:length).zero?
    puts "RESULT: no checks ran"
    return
  end

  puts "#{results[:pass].length} passed, #{results[:skip].length} skipped, #{results[:fail].length} failed"
  if results[:fail].any?
    puts "RESULT: FAILED (#{results[:fail].join(', ')})"
  elsif results[:skip].any?
    puts "RESULT: no failures, but not verified: #{results[:skip].join(', ')}"
  else
    puts "RESULT: all passed"
  end
end

main(ARGV)
