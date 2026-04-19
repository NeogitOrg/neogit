local eq = assert.are.same
local diff = require("neogit.lib.diff_highlights")

describe("word_diff_spans", function()
  it("returns empty spans for identical strings", function()
    local old_spans, new_spans, distance = diff.word_diff_spans("hello", "hello")
    eq({}, old_spans)
    eq({}, new_spans)
    eq(0, distance)
  end)

  it("returns empty spans for two empty strings", function()
    local old_spans, new_spans, distance = diff.word_diff_spans("", "")
    eq({}, old_spans)
    eq({}, new_spans)
    eq(0, distance)
  end)

  it("handles completely different strings", function()
    local old_spans, new_spans, distance = diff.word_diff_spans("abc", "xyz")
    eq({ { 0, 3 } }, old_spans)
    eq({ { 0, 3 } }, new_spans)
    eq(1.0, distance)
  end)

  -- Inspired by delta: method rename d.iteritems() -> d.items()
  it("detects a word change with shared prefix and suffix", function()
    local old_spans, new_spans, distance = diff.word_diff_spans("d.iteritems()", "d.items()")
    -- "item" is shared, "d.iter" vs "d." prefix and "s()" suffix are shared
    -- algorithm finds deletion of "iteri" at positions 5..9 in old
    eq({ { 2, 11 } }, old_spans)
    eq({ { 2, 7 } }, new_spans)
    assert.is_true(distance < 0.5)
  end)

  -- Inspired by delta: insertion in the middle
  it("detects an insertion in the middle", function()
    local old_spans, new_spans, distance =
      diff.word_diff_spans("range(0, options):", "range(0, int(options)):")
    -- "int(" inserted and ")" inserted
    assert.is_true(#new_spans > 0)
    eq({ { 16, 18 } } , old_spans)
    assert.is_true(distance < 0.5)
  end)

  -- Inspired by delta: word replacement in natural language
  it("detects word replacement in a sentence", function()
    local old_spans, new_spans, distance =
      diff.word_diff_spans("safe to read the commit number from", "safe to read build info from")
    assert.is_true(#old_spans > 0)
    assert.is_true(#new_spans > 0)
    assert.is_true(distance < 0.6)
  end)

  -- Inspired by delta: appending to end of line
  it("detects appended text", function()
    local old_spans, new_spans, distance =
      diff.word_diff_spans("self.table[index] =", "self.table[index] = candidates")
    eq({ { 16, 19 } }, old_spans)
    -- " candidates" is inserted
    assert.is_true(#new_spans > 0)
    assert.is_true(distance < 0.5)
  end)

  it("reports high distance for completely unrelated lines", function()
    local _, _, distance = diff.word_diff_spans(
      "#![allow(unreachable_pub)]",
      "// dead_code is a false positive here because rust will compile each integration test file as their own"
    )
    assert.is_true(distance > 0.6)
  end)

  it("handles deletion from one side only", function()
    local old_spans, new_spans, distance = diff.word_diff_spans("abcdef", "abef")
    -- "cd" removed at positions 2..4
    eq({ { 0, 6 } }, old_spans)
    eq({ { 0, 4 } }, new_spans)
    assert.is_true(distance == 1)
  end)

  it("handles insertion to one side only", function()
    local old_spans, new_spans, distance = diff.word_diff_spans("abef", "abcdef")
    eq({ { 0, 4 } }, old_spans)
    -- "cd" inserted at positions 2..4
    eq({ { 0, 6 } }, new_spans)
    assert.is_true(distance == 1)
  end)

  -- Inspired by delta: single character change
  it("detects a single character change", function()
    local old_spans, new_spans, distance = diff.word_diff_spans("aaa", "aba")
    eq({ { 0, 3 } }, old_spans)
    eq({ { 0, 3 } }, new_spans)
    assert.is_true(distance == 1)
  end)

  -- Inspired by delta: comma moves outside bracket
  it("detects moved punctuation", function()
    local old_spans, new_spans, distance = diff.word_diff_spans("[element,]", "[element],")
    assert.is_true(#old_spans > 0 or #new_spans > 0)
    assert.is_true(distance < 0.5)
  end)

  it("handles one empty string", function()
    local old_spans, new_spans, distance = diff.word_diff_spans("hello", "")
    eq({}, old_spans)
    eq({}, new_spans)
    eq(1.0, distance)
  end)

  it("handles other empty string", function()
    local old_spans, new_spans, distance = diff.word_diff_spans("", "hello")
    eq({}, old_spans)
    eq({}, new_spans)
    eq(1.0, distance)
  end)
end)
