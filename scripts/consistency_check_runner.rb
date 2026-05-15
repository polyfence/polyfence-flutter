#!/usr/bin/env ruby
# frozen_string_literal: true

# Declarative consistency-check runner (Phase 2). Parses consistency-checks.yaml
# at repo root; dispatches subprocess, diff, hash, regex-presence, tally,
# remote-query. Plain ASCII output.

require "digest"
require "fileutils"
require "pathname"
require "psych"
require "set"

ROOT = ENV.fetch("CONSISTENCY_REPO_ROOT")

def fail_check(id, error, fix)
  warn "FAIL #{id}: #{error}"
  warn "     Fix: #{fix}"
  false
end

def pass_check(id)
  puts "PASS #{id}"
  true
end

def skip_check(id, reason)
  puts "SKIP #{id} (#{reason})"
  true
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
  ok = system(env, "bash", "-c", cmd, chdir: ROOT)
  unless ok
    return fail_check(check["id"], "subprocess exited non-zero", check.fetch("fix", ""))
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
    one_check = argv[idx + 1] if a == "--check" && argv[idx + 1]
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

  checks.select! { |c| c["id"] == one_check } if one_check

  failed = 0
  checks.each do |check|
    id = check["id"]
    type = check["type"]
    next if remote_only && type != "remote-query"
    if local_only && type == "remote-query"
      skip_check(id, "remote check, --local-only")
      next
    end

    ok = case type
         when "subprocess" then handle_subprocess(check)
         when "diff" then handle_diff(check)
         when "hash" then handle_hash(check)
         when "regex-presence" then handle_regex_presence(check)
         when "tally" then handle_tally(check)
         when "remote-query" then handle_remote_query(check, local_only)
         else
           fail_check(id, "unknown type #{type}", "Fix consistency-checks.yaml")
         end
    failed += 1 unless ok
  end

  exit(failed.positive? ? 1 : 0)
end

main(ARGV)
