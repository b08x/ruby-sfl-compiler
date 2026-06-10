# SFL Analysis Agent & Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an intelligent agent and skill that generates custom SFL analysis scripts for conversation, documentation, and context analysis.

**Architecture:** Template-based script generation with modular formatters. Agent understands SFL framework capabilities and produces executable Ruby scripts tailored to user needs. First implementation focuses on conversation tenor/field tracking.

**Tech Stack:** Ruby 3.2+, RSpec (testing), Dry::Struct (data structures), ERB (templates), CSV/JSON (output)

---

## File Structure

**New Files:**
```
lib/sfl/compiler/
  analysis/
    tenor_tracker.rb          # Tenor shift detection logic
    field_tracker.rb          # Topic/process evolution tracking
    correlation_analyzer.rb   # Tenor ↔ field correlations
    speaker_profiler.rb       # Per-speaker aggregations
    insight_generator.rb      # Natural language insights
  
  formatters/
    base_formatter.rb         # Abstract formatter interface
    csv_formatter.rb          # CSV export
    json_formatter.rb         # JSON export
    markdown_formatter.rb     # Markdown report
    html_formatter.rb         # Interactive dashboard

scripts/sfl_analysis/
  templates/
    conversation_analysis_template.rb  # Main conversation script

.claude/
  agents/
    sfl-analyzer.md           # Agent configuration
  
  skills/sfl-analyze/
    SKILL.md                  # Skill interface
    handlers/
      conversation_handler.rb # /sfl-analyze conversation handler

spec/sfl_compiler/
  analysis/
    tenor_tracker_spec.rb
    field_tracker_spec.rb
    correlation_analyzer_spec.rb
    speaker_profiler_spec.rb
  
  formatters/
    csv_formatter_spec.rb
    json_formatter_spec.rb
    markdown_formatter_spec.rb
  
  integration/
    conversation_analysis_spec.rb
```

**Modified Files:**
```
lib/sfl/compiler/types.rb     # Add ConversationTurn, SpeakerProfile, AnalysisResult
lib/sfl/compiler.rb           # Require new modules
```

---

## Task 1: Data Structures for Analysis

**Files:**
- Modify: `lib/sfl/compiler/types.rb`
- Test: `spec/sfl_compiler/types_spec.rb`

- [ ] **Step 1: Write failing test for ConversationTurn**

```ruby
# spec/sfl_compiler/types_spec.rb (add to existing file)

RSpec.describe SFL::Compiler::Types do
  describe "ConversationTurn" do
    it "creates a valid conversation turn" do
      turn = Types::ConversationTurn.new(
        turn_id: 1,
        speaker: "Alice",
        timestamp: Time.now,
        message_text: "Hello world",
        clauses: [],
        avg_tenor: 0.5,
        avg_modality: 0.6,
        dominant_mood: "declarative",
        process_types: { "mental" => 2, "material" => 1 },
        participants: ["Alice", "world"],
        tenor_shift: 0.0
      )
      
      expect(turn.turn_id).to eq(1)
      expect(turn.speaker).to eq("Alice")
      expect(turn.avg_tenor).to eq(0.5)
    end
    
    it "requires all mandatory fields" do
      expect {
        Types::ConversationTurn.new(turn_id: 1)
      }.to raise_error(Dry::Struct::Error)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/sfl_compiler/types_spec.rb -e "ConversationTurn"
```

Expected: `uninitialized constant SFL::Compiler::Types::ConversationTurn`

- [ ] **Step 3: Add ConversationTurn to types.rb**

```ruby
# lib/sfl/compiler/types.rb (add after AnnotatedClause)

# Conversation analysis data structures

# A single turn in a conversation with SFL annotations
class ConversationTurn < Dry::Struct
  attribute :turn_id, Types::Integer
  attribute :speaker, Types::String
  attribute :timestamp, Types::Time
  attribute :message_text, Types::String
  attribute :clauses, Types::Array.of(AnnotatedClause)
  attribute :avg_tenor, Types::Float.constrained(gteq: 0.0, lteq: 1.0)
  attribute :avg_modality, Types::Float.constrained(gteq: 0.0, lteq: 1.0)
  attribute :dominant_mood, Types::MoodType
  attribute :process_types, Types::Hash.default({}.freeze)
  attribute :participants, Types::Array.of(Types::String).default([].freeze)
  attribute :tenor_shift, Types::Float.optional
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/sfl_compiler/types_spec.rb -e "ConversationTurn"
```

Expected: 2 examples, 0 failures

- [ ] **Step 5: Write failing test for SpeakerProfile**

```ruby
# spec/sfl_compiler/types_spec.rb (add after ConversationTurn tests)

describe "SpeakerProfile" do
  it "creates a valid speaker profile" do
    profile = Types::SpeakerProfile.new(
      speaker_name: "Alice",
      turn_count: 5,
      avg_tenor: 0.45,
      tenor_range: [0.2, 0.7],
      tenor_variance: 0.12,
      avg_modality: 0.52,
      mood_distribution: { "declarative" => 0.8, "interrogative" => 0.2 },
      dominant_processes: { "mental" => 10, "material" => 5 }
    )
    
    expect(profile.speaker_name).to eq("Alice")
    expect(profile.turn_count).to eq(5)
    expect(profile.tenor_range).to eq([0.2, 0.7])
  end
end
```

- [ ] **Step 6: Run test to verify it fails**

```bash
bundle exec rspec spec/sfl_compiler/types_spec.rb -e "SpeakerProfile"
```

Expected: `uninitialized constant SFL::Compiler::Types::SpeakerProfile`

- [ ] **Step 7: Add SpeakerProfile to types.rb**

```ruby
# lib/sfl/compiler/types.rb (add after ConversationTurn)

# Aggregated profile for a single speaker across conversation
class SpeakerProfile < Dry::Struct
  attribute :speaker_name, Types::String
  attribute :turn_count, Types::Integer
  attribute :avg_tenor, Types::Float.constrained(gteq: 0.0, lteq: 1.0)
  attribute :tenor_range, Types::Array.of(Types::Float).constrained(size: 2)
  attribute :tenor_variance, Types::Float.constrained(gteq: 0.0)
  attribute :avg_modality, Types::Float.constrained(gteq: 0.0, lteq: 1.0)
  attribute :mood_distribution, Types::Hash.default({}.freeze)
  attribute :dominant_processes, Types::Hash.default({}.freeze)
end
```

- [ ] **Step 8: Run test to verify it passes**

```bash
bundle exec rspec spec/sfl_compiler/types_spec.rb -e "SpeakerProfile"
```

Expected: 1 example, 0 failures

- [ ] **Step 9: Write failing test for AnalysisResult**

```ruby
# spec/sfl_compiler/types_spec.rb (add after SpeakerProfile tests)

describe "AnalysisResult" do
  it "creates a valid analysis result" do
    result = Types::AnalysisResult.new(
      metadata: { conversation_id: "test", turn_count: 5 },
      turns: [],
      speaker_profiles: {},
      tenor_timeline: [],
      field_evolution: [],
      correlations: {},
      insights: ["Sample insight"]
    )
    
    expect(result.metadata[:conversation_id]).to eq("test")
    expect(result.insights).to eq(["Sample insight"])
  end
end
```

- [ ] **Step 10: Run test to verify it fails**

```bash
bundle exec rspec spec/sfl_compiler/types_spec.rb -e "AnalysisResult"
```

Expected: `uninitialized constant SFL::Compiler::Types::AnalysisResult`

- [ ] **Step 11: Add AnalysisResult to types.rb**

```ruby
# lib/sfl/compiler/types.rb (add after SpeakerProfile)

# Complete analysis result for a conversation
class AnalysisResult < Dry::Struct
  attribute :metadata, Types::Hash
  attribute :turns, Types::Array.of(ConversationTurn)
  attribute :speaker_profiles, Types::Hash
  attribute :tenor_timeline, Types::Array.of(Types::Hash)
  attribute :field_evolution, Types::Array.of(Types::Hash)
  attribute :correlations, Types::Hash
  attribute :insights, Types::Array.of(Types::String)
end
```

- [ ] **Step 12: Run test to verify it passes**

```bash
bundle exec rspec spec/sfl_compiler/types_spec.rb -e "AnalysisResult"
```

Expected: 1 example, 0 failures

- [ ] **Step 13: Commit data structures**

```bash
git add lib/sfl/compiler/types.rb spec/sfl_compiler/types_spec.rb
git commit -m "feat: add conversation analysis data structures

Add ConversationTurn, SpeakerProfile, and AnalysisResult types for
conversation analysis pipeline. Includes tenor/field metrics,
speaker aggregations, and insight storage.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Tenor Tracking Logic

**Files:**
- Create: `lib/sfl/compiler/analysis/tenor_tracker.rb`
- Create: `spec/sfl_compiler/analysis/tenor_tracker_spec.rb`
- Create: `lib/sfl/compiler/analysis.rb` (module loader)

- [ ] **Step 1: Create analysis module loader**

```ruby
# lib/sfl/compiler/analysis.rb

# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Analysis modules for conversation/document processing
    end
  end
end
```

- [ ] **Step 2: Write failing test for tenor shift detection**

```ruby
# spec/sfl_compiler/analysis/tenor_tracker_spec.rb

require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::TenorTracker do
  let(:turn1) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 1,
      speaker: "Alice",
      timestamp: Time.now,
      message_text: "Hello",
      clauses: [],
      avg_tenor: 0.3,
      avg_modality: 0.5,
      dominant_mood: "declarative",
      process_types: {},
      participants: [],
      tenor_shift: nil
    )
  end
  
  let(:turn2) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 2,
      speaker: "Bob",
      timestamp: Time.now + 60,
      message_text: "Hi there",
      clauses: [],
      avg_tenor: 0.7,
      avg_modality: 0.6,
      dominant_mood: "declarative",
      process_types: {},
      participants: [],
      tenor_shift: nil
    )
  end
  
  let(:turn3) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 3,
      speaker: "Alice",
      timestamp: Time.now + 120,
      message_text: "Thanks",
      clauses: [],
      avg_tenor: 0.5,
      avg_modality: 0.55,
      dominant_mood: "declarative",
      process_types: {},
      participants: [],
      tenor_shift: nil
    )
  end
  
  describe "#calculate_shifts" do
    it "calculates tenor shifts between consecutive turns" do
      tracker = described_class.new([turn1, turn2, turn3])
      tracker.calculate_shifts
      
      expect(turn1.tenor_shift).to be_nil
      expect(turn2.tenor_shift).to eq(0.4)
      expect(turn3.tenor_shift).to eq(-0.2)
    end
  end
  
  describe "#detect_significant_shifts" do
    it "finds shifts above threshold" do
      tracker = described_class.new([turn1, turn2, turn3], threshold: 0.15)
      tracker.calculate_shifts
      shifts = tracker.detect_significant_shifts
      
      expect(shifts.count).to eq(2)
      expect(shifts.first[:turn_id]).to eq(2)
      expect(shifts.first[:delta]).to eq(0.4)
      expect(shifts.first[:direction]).to eq("more formal")
      
      expect(shifts.last[:turn_id]).to eq(3)
      expect(shifts.last[:delta]).to eq(-0.2)
      expect(shifts.last[:direction]).to eq("less formal")
    end
    
    it "ignores shifts below threshold" do
      tracker = described_class.new([turn1, turn2, turn3], threshold: 0.5)
      tracker.calculate_shifts
      shifts = tracker.detect_significant_shifts
      
      expect(shifts).to be_empty
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

```bash
bundle exec rspec spec/sfl_compiler/analysis/tenor_tracker_spec.rb
```

Expected: `uninitialized constant SFL::Compiler::Analysis::TenorTracker`

- [ ] **Step 4: Implement TenorTracker**

```ruby
# lib/sfl/compiler/analysis/tenor_tracker.rb

# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Tracks tenor (formality) evolution across conversation turns
      class TenorTracker
        attr_reader :turns, :threshold
        
        def initialize(turns, threshold: 0.15)
          @turns = turns
          @threshold = threshold
        end
        
        # Calculate tenor shifts between consecutive turns (mutates turns)
        def calculate_shifts
          turns.each_cons(2) do |prev_turn, curr_turn|
            curr_turn.instance_variable_set(:@tenor_shift, curr_turn.avg_tenor - prev_turn.avg_tenor)
          end
        end
        
        # Find significant tenor shifts (above threshold)
        # @return [Array<Hash>] Shift metadata
        def detect_significant_shifts
          calculate_shifts if turns.any? { |t| t.tenor_shift.nil? && t.turn_id > 1 }
          
          turns.select { |t| t.tenor_shift && t.tenor_shift.abs > threshold }.map do |turn|
            {
              turn_id: turn.turn_id,
              speaker: turn.speaker,
              from_tenor: turns[turn.turn_id - 2]&.avg_tenor,
              to_tenor: turn.avg_tenor,
              delta: turn.tenor_shift,
              direction: turn.tenor_shift > 0 ? "more formal" : "less formal"
            }
          end
        end
      end
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bundle exec rspec spec/sfl_compiler/analysis/tenor_tracker_spec.rb
```

Expected: 3 examples, 0 failures

- [ ] **Step 6: Require tenor_tracker in analysis.rb**

```ruby
# lib/sfl/compiler/analysis.rb

# frozen_string_literal: true

require_relative "analysis/tenor_tracker"

module SFL
  module Compiler
    module Analysis
      # Analysis modules for conversation/document processing
    end
  end
end
```

- [ ] **Step 7: Commit tenor tracking**

```bash
git add lib/sfl/compiler/analysis.rb lib/sfl/compiler/analysis/tenor_tracker.rb spec/sfl_compiler/analysis/tenor_tracker_spec.rb
git commit -m "feat: add tenor tracking for conversation analysis

Implements TenorTracker for detecting formality shifts across
conversation turns. Calculates deltas and identifies significant
changes above configurable threshold.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Speaker Profiling Logic

**Files:**
- Create: `lib/sfl/compiler/analysis/speaker_profiler.rb`
- Create: `spec/sfl_compiler/analysis/speaker_profiler_spec.rb`

- [ ] **Step 1: Write failing test for speaker profiling**

```ruby
# spec/sfl_compiler/analysis/speaker_profiler_spec.rb

require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::SpeakerProfiler do
  let(:alice_turns) do
    [
      build_turn(speaker: "Alice", avg_tenor: 0.3, avg_modality: 0.4, mood: "declarative", process: "mental"),
      build_turn(speaker: "Alice", avg_tenor: 0.5, avg_modality: 0.6, mood: "declarative", process: "mental"),
      build_turn(speaker: "Alice", avg_tenor: 0.4, avg_modality: 0.5, mood: "interrogative", process: "material")
    ]
  end
  
  let(:bob_turns) do
    [
      build_turn(speaker: "Bob", avg_tenor: 0.7, avg_modality: 0.8, mood: "declarative", process: "verbal"),
      build_turn(speaker: "Bob", avg_tenor: 0.75, avg_modality: 0.82, mood: "exclamative", process: "verbal")
    ]
  end
  
  def build_turn(speaker:, avg_tenor:, avg_modality:, mood:, process:)
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: rand(1..100),
      speaker: speaker,
      timestamp: Time.now,
      message_text: "Test",
      clauses: [],
      avg_tenor: avg_tenor,
      avg_modality: avg_modality,
      dominant_mood: mood,
      process_types: { process => 1 },
      participants: [],
      tenor_shift: nil
    )
  end
  
  describe "#build_profile" do
    it "builds speaker profile from turns" do
      profiler = described_class.new(alice_turns)
      profile = profiler.build_profile
      
      expect(profile.speaker_name).to eq("Alice")
      expect(profile.turn_count).to eq(3)
      expect(profile.avg_tenor).to be_within(0.01).of(0.4)
      expect(profile.tenor_range).to eq([0.3, 0.5])
      expect(profile.tenor_variance).to be > 0
      expect(profile.avg_modality).to be_within(0.01).of(0.5)
    end
    
    it "calculates mood distribution" do
      profiler = described_class.new(alice_turns)
      profile = profiler.build_profile
      
      expect(profile.mood_distribution["declarative"]).to be_within(0.01).of(0.67)
      expect(profile.mood_distribution["interrogative"]).to be_within(0.01).of(0.33)
    end
    
    it "aggregates process types" do
      profiler = described_class.new(alice_turns)
      profile = profiler.build_profile
      
      expect(profile.dominant_processes["mental"]).to eq(2)
      expect(profile.dominant_processes["material"]).to eq(1)
    end
  end
  
  describe ".build_profiles" do
    it "builds profiles for all speakers" do
      all_turns = alice_turns + bob_turns
      profiles = described_class.build_profiles(all_turns)
      
      expect(profiles.keys).to contain_exactly("Alice", "Bob")
      expect(profiles["Alice"].turn_count).to eq(3)
      expect(profiles["Bob"].turn_count).to eq(2)
      expect(profiles["Bob"].avg_tenor).to be > profiles["Alice"].avg_tenor
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/sfl_compiler/analysis/speaker_profiler_spec.rb
```

Expected: `uninitialized constant SFL::Compiler::Analysis::SpeakerProfiler`

- [ ] **Step 3: Implement SpeakerProfiler**

```ruby
# lib/sfl/compiler/analysis/speaker_profiler.rb

# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Builds aggregated profiles for speakers in a conversation
      class SpeakerProfiler
        attr_reader :turns
        
        def initialize(turns)
          @turns = turns
        end
        
        # Build profile for speaker from their turns
        # @return [Types::SpeakerProfile]
        def build_profile
          raise ArgumentError, "No turns provided" if turns.empty?
          
          speaker_name = turns.first.speaker
          tenors = turns.map(&:avg_tenor)
          modalities = turns.map(&:avg_modality)
          
          Types::SpeakerProfile.new(
            speaker_name: speaker_name,
            turn_count: turns.count,
            avg_tenor: mean(tenors),
            tenor_range: [tenors.min, tenors.max],
            tenor_variance: variance(tenors),
            avg_modality: mean(modalities),
            mood_distribution: calculate_mood_distribution,
            dominant_processes: aggregate_process_types
          )
        end
        
        # Build profiles for all speakers in conversation
        # @param all_turns [Array<ConversationTurn>]
        # @return [Hash{String => SpeakerProfile}]
        def self.build_profiles(all_turns)
          all_turns.group_by(&:speaker).transform_values do |speaker_turns|
            new(speaker_turns).build_profile
          end
        end
        
        private
        
        def calculate_mood_distribution
          mood_counts = turns.each_with_object(Hash.new(0)) do |turn, counts|
            counts[turn.dominant_mood] += 1
          end
          
          total = turns.count.to_f
          mood_counts.transform_values { |count| (count / total).round(3) }
        end
        
        def aggregate_process_types
          turns.each_with_object(Hash.new(0)) do |turn, totals|
            turn.process_types.each do |process_type, count|
              totals[process_type] += count
            end
          end
        end
        
        def mean(values)
          return 0.0 if values.empty?
          (values.sum / values.count.to_f).round(3)
        end
        
        def variance(values)
          return 0.0 if values.count < 2
          
          avg = mean(values)
          sum_squares = values.sum { |v| (v - avg)**2 }
          (sum_squares / values.count.to_f).round(4)
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/sfl_compiler/analysis/speaker_profiler_spec.rb
```

Expected: 5 examples, 0 failures

- [ ] **Step 5: Require speaker_profiler in analysis.rb**

```ruby
# lib/sfl/compiler/analysis.rb (add require)

require_relative "analysis/tenor_tracker"
require_relative "analysis/speaker_profiler"
```

- [ ] **Step 6: Commit speaker profiling**

```bash
git add lib/sfl/compiler/analysis.rb lib/sfl/compiler/analysis/speaker_profiler.rb spec/sfl_compiler/analysis/speaker_profiler_spec.rb
git commit -m "feat: add speaker profiling for conversation analysis

Aggregates per-speaker metrics: avg tenor/modality, tenor variance,
mood distribution, and dominant process types.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Correlation Analyzer

**Files:**
- Create: `lib/sfl/compiler/analysis/correlation_analyzer.rb`
- Create: `spec/sfl_compiler/analysis/correlation_analyzer_spec.rb`

- [ ] **Step 1: Write failing test for process-tenor correlation**

```ruby
# spec/sfl_compiler/analysis/correlation_analyzer_spec.rb

require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::CorrelationAnalyzer do
  let(:turns) do
    [
      build_turn_with_clauses("mental", tenor: 0.3, modality: 0.4),
      build_turn_with_clauses("mental", tenor: 0.35, modality: 0.42),
      build_turn_with_clauses("verbal", tenor: 0.7, modality: 0.8),
      build_turn_with_clauses("verbal", tenor: 0.75, modality: 0.82),
      build_turn_with_clauses("material", tenor: 0.5, modality: 0.6)
    ]
  end
  
  def build_turn_with_clauses(process_type, tenor:, modality:)
    clause = double("AnnotatedClause",
      ideational: double("IdeationalPayload", process_type: process_type),
      interpersonal: double("InterpersonalPayload", tenor: tenor, modality_weight: modality)
    )
    
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: rand(1..100),
      speaker: "Test",
      timestamp: Time.now,
      message_text: "Test",
      clauses: [clause],
      avg_tenor: tenor,
      avg_modality: modality,
      dominant_mood: "declarative",
      process_types: { process_type => 1 },
      participants: [],
      tenor_shift: nil
    )
  end
  
  describe "#correlate_process_tenor" do
    it "calculates avg tenor per process type" do
      analyzer = described_class.new(turns)
      correlations = analyzer.correlate_process_tenor
      
      expect(correlations["mental"][:avg_tenor]).to be_within(0.01).of(0.325)
      expect(correlations["verbal"][:avg_tenor]).to be_within(0.01).of(0.725)
      expect(correlations["material"][:avg_tenor]).to eq(0.5)
    end
    
    it "calculates avg modality per process type" do
      analyzer = described_class.new(turns)
      correlations = analyzer.correlate_process_tenor
      
      expect(correlations["mental"][:avg_modality]).to be_within(0.01).of(0.41)
      expect(correlations["verbal"][:avg_modality]).to be_within(0.01).of(0.81)
    end
    
    it "includes clause counts" do
      analyzer = described_class.new(turns)
      correlations = analyzer.correlate_process_tenor
      
      expect(correlations["mental"][:count]).to eq(2)
      expect(correlations["verbal"][:count]).to eq(2)
      expect(correlations["material"][:count]).to eq(1)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/sfl_compiler/analysis/correlation_analyzer_spec.rb
```

Expected: `uninitialized constant SFL::Compiler::Analysis::CorrelationAnalyzer`

- [ ] **Step 3: Implement CorrelationAnalyzer**

```ruby
# lib/sfl/compiler/analysis/correlation_analyzer.rb

# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Analyzes correlations between field (process types) and tenor
      class CorrelationAnalyzer
        attr_reader :turns
        
        def initialize(turns)
          @turns = turns
        end
        
        # Correlate process types with tenor/modality
        # @return [Hash{String => Hash}] {process_type => {count:, avg_tenor:, avg_modality:}}
        def correlate_process_tenor
          all_clauses = turns.flat_map(&:clauses)
          
          all_clauses.group_by { |c| c.ideational.process_type }.transform_values do |clauses|
            tenors = clauses.map { |c| c.interpersonal.tenor }
            modalities = clauses.map { |c| c.interpersonal.modality_weight }
            
            {
              count: clauses.count,
              avg_tenor: mean(tenors),
              avg_modality: mean(modalities)
            }
          end
        end
        
        private
        
        def mean(values)
          return 0.0 if values.empty?
          (values.sum / values.count.to_f).round(3)
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/sfl_compiler/analysis/correlation_analyzer_spec.rb
```

Expected: 3 examples, 0 failures

- [ ] **Step 5: Require correlation_analyzer in analysis.rb**

```ruby
# lib/sfl/compiler/analysis.rb (add require)

require_relative "analysis/tenor_tracker"
require_relative "analysis/speaker_profiler"
require_relative "analysis/correlation_analyzer"
```

- [ ] **Step 6: Commit correlation analyzer**

```bash
git add lib/sfl/compiler/analysis.rb lib/sfl/compiler/analysis/correlation_analyzer.rb spec/sfl_compiler/analysis/correlation_analyzer_spec.rb
git commit -m "feat: add process-tenor correlation analyzer

Correlates ideational features (process types) with interpersonal
features (tenor, modality) to identify rhetorical patterns.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: CSV Formatter

**Files:**
- Create: `lib/sfl/compiler/formatters/base_formatter.rb`
- Create: `lib/sfl/compiler/formatters/csv_formatter.rb`
- Create: `spec/sfl_compiler/formatters/csv_formatter_spec.rb`
- Create: `lib/sfl/compiler/formatters.rb` (module loader)

- [ ] **Step 1: Create formatters module loader**

```ruby
# lib/sfl/compiler/formatters.rb

# frozen_string_literal: true

module SFL
  module Compiler
    module Formatters
      # Output formatters for analysis results
    end
  end
end
```

- [ ] **Step 2: Create base formatter**

```ruby
# lib/sfl/compiler/formatters/base_formatter.rb

# frozen_string_literal: true

module SFL
  module Compiler
    module Formatters
      # Abstract base class for result formatters
      class BaseFormatter
        attr_reader :result
        
        def initialize(result)
          @result = result
        end
        
        # Render formatted output
        # @return [String]
        def render
          raise NotImplementedError, "Subclasses must implement #render"
        end
        
        # Write formatted output to file
        # @param path [String] Output file path
        def write_to(path)
          File.write(path, render)
        end
      end
    end
  end
end
```

- [ ] **Step 3: Write failing test for CSV formatter**

```ruby
# spec/sfl_compiler/formatters/csv_formatter_spec.rb

require "spec_helper"
require "csv"

RSpec.describe SFL::Compiler::Formatters::CSVFormatter do
  let(:turn1) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 1,
      speaker: "Alice",
      timestamp: Time.parse("2026-06-10 14:30:00"),
      message_text: "Hello there, how are you doing today?",
      clauses: [],
      avg_tenor: 0.32,
      avg_modality: 0.45,
      dominant_mood: "declarative",
      process_types: { "mental" => 1, "relational" => 1 },
      participants: ["I", "you"],
      tenor_shift: nil
    )
  end
  
  let(:turn2) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 2,
      speaker: "Bob",
      timestamp: Time.parse("2026-06-10 14:31:00"),
      message_text: "I'm doing great, thanks!",
      clauses: [],
      avg_tenor: 0.28,
      avg_modality: 0.82,
      dominant_mood: "declarative",
      process_types: { "material" => 1 },
      participants: ["I"],
      tenor_shift: -0.04
    )
  end
  
  let(:result) do
    SFL::Compiler::Types::AnalysisResult.new(
      metadata: { conversation_id: "test" },
      turns: [turn1, turn2],
      speaker_profiles: {},
      tenor_timeline: [],
      field_evolution: [],
      correlations: {},
      insights: []
    )
  end
  
  describe "#render" do
    it "generates CSV with correct headers" do
      formatter = described_class.new(result)
      csv_output = formatter.render
      
      csv = CSV.parse(csv_output, headers: true)
      expect(csv.headers).to eq([
        "turn_id", "speaker", "timestamp", "message_preview",
        "avg_tenor", "avg_modality", "dominant_mood",
        "process_counts", "participants", "tenor_shift"
      ])
    end
    
    it "includes turn data rows" do
      formatter = described_class.new(result)
      csv_output = formatter.render
      
      csv = CSV.parse(csv_output, headers: true)
      expect(csv.count).to eq(2)
      
      row1 = csv[0]
      expect(row1["turn_id"]).to eq("1")
      expect(row1["speaker"]).to eq("Alice")
      expect(row1["avg_tenor"]).to eq("0.32")
      expect(row1["avg_modality"]).to eq("0.45")
      expect(row1["dominant_mood"]).to eq("declarative")
      expect(row1["process_counts"]).to eq("mental:1 relational:1")
      expect(row1["participants"]).to eq("I you")
      expect(row1["tenor_shift"]).to eq("")
    end
    
    it "truncates long messages" do
      formatter = described_class.new(result)
      csv_output = formatter.render
      
      csv = CSV.parse(csv_output, headers: true)
      row1 = csv[0]
      expect(row1["message_preview"].length).to be <= 50
    end
  end
end
```

- [ ] **Step 4: Run test to verify it fails**

```bash
bundle exec rspec spec/sfl_compiler/formatters/csv_formatter_spec.rb
```

Expected: `uninitialized constant SFL::Compiler::Formatters::CSVFormatter`

- [ ] **Step 5: Implement CSVFormatter**

```ruby
# lib/sfl/compiler/formatters/csv_formatter.rb

# frozen_string_literal: true

require "csv"

module SFL
  module Compiler
    module Formatters
      # Exports conversation analysis to CSV format
      class CSVFormatter < BaseFormatter
        def render
          CSV.generate do |csv|
            csv << headers
            result.turns.each do |turn|
              csv << turn_to_row(turn)
            end
          end
        end
        
        private
        
        def headers
          %w[
            turn_id speaker timestamp message_preview
            avg_tenor avg_modality dominant_mood
            process_counts participants tenor_shift
          ]
        end
        
        def turn_to_row(turn)
          [
            turn.turn_id,
            turn.speaker,
            turn.timestamp.strftime("%Y-%m-%d %H:%M"),
            truncate_message(turn.message_text),
            turn.avg_tenor.round(2),
            turn.avg_modality.round(2),
            turn.dominant_mood,
            format_process_counts(turn.process_types),
            turn.participants.join(" "),
            turn.tenor_shift ? format("%.2f", turn.tenor_shift) : ""
          ]
        end
        
        def truncate_message(text, max_length: 50)
          text.length > max_length ? "#{text[0...max_length]}..." : text
        end
        
        def format_process_counts(process_types)
          process_types.map { |type, count| "#{type}:#{count}" }.join(" ")
        end
      end
    end
  end
end
```

- [ ] **Step 6: Run test to verify it passes**

```bash
bundle exec rspec spec/sfl_compiler/formatters/csv_formatter_spec.rb
```

Expected: 3 examples, 0 failures

- [ ] **Step 7: Require formatters in formatters.rb**

```ruby
# lib/sfl/compiler/formatters.rb

require_relative "formatters/base_formatter"
require_relative "formatters/csv_formatter"
```

- [ ] **Step 8: Commit CSV formatter**

```bash
git add lib/sfl/compiler/formatters.rb lib/sfl/compiler/formatters/base_formatter.rb lib/sfl/compiler/formatters/csv_formatter.rb spec/sfl_compiler/formatters/csv_formatter_spec.rb
git commit -m "feat: add CSV formatter for analysis results

Exports turn-by-turn conversation data to CSV format for spreadsheet
analysis. Includes all metrics with formatted process counts.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: JSON Formatter

**Files:**
- Create: `lib/sfl/compiler/formatters/json_formatter.rb`
- Create: `spec/sfl_compiler/formatters/json_formatter_spec.rb`

- [ ] **Step 1: Write failing test for JSON formatter**

```ruby
# spec/sfl_compiler/formatters/json_formatter_spec.rb

require "spec_helper"
require "json"

RSpec.describe SFL::Compiler::Formatters::JSONFormatter do
  let(:alice_profile) do
    SFL::Compiler::Types::SpeakerProfile.new(
      speaker_name: "Alice",
      turn_count: 3,
      avg_tenor: 0.38,
      tenor_range: [0.22, 0.61],
      tenor_variance: 0.14,
      avg_modality: 0.42,
      mood_distribution: { "declarative" => 0.72, "interrogative" => 0.28 },
      dominant_processes: { "mental" => 10, "material" => 5 }
    )
  end
  
  let(:result) do
    SFL::Compiler::Types::AnalysisResult.new(
      metadata: {
        conversation_id: "test-convo",
        turn_count: 5,
        speakers: ["Alice", "Bob"],
        analyzed_at: Time.parse("2026-06-10 14:32:15")
      },
      turns: [],
      speaker_profiles: { "Alice" => alice_profile },
      tenor_timeline: [
        { timestamp: Time.parse("2026-06-10 14:30"), tenor: 0.32, speaker: "Alice" }
      ],
      field_evolution: [],
      correlations: {
        "mental" => { avg_tenor: 0.34, avg_modality: 0.41 },
        "verbal" => { avg_tenor: 0.71, avg_modality: 0.78 }
      },
      insights: [
        "Alice maintains casual tenor across conversation",
        "Mental processes correlate with low tenor"
      ]
    )
  end
  
  describe "#render" do
    it "generates valid JSON" do
      formatter = described_class.new(result)
      json_output = formatter.render
      
      expect { JSON.parse(json_output) }.not_to raise_error
    end
    
    it "includes metadata" do
      formatter = described_class.new(result)
      json = JSON.parse(formatter.render)
      
      expect(json["metadata"]["conversation_id"]).to eq("test-convo")
      expect(json["metadata"]["turn_count"]).to eq(5)
      expect(json["metadata"]["speakers"]).to eq(["Alice", "Bob"])
    end
    
    it "includes speaker profiles" do
      formatter = described_class.new(result)
      json = JSON.parse(formatter.render)
      
      expect(json["speaker_profiles"]["Alice"]["avg_tenor"]).to eq(0.38)
      expect(json["speaker_profiles"]["Alice"]["turn_count"]).to eq(3)
      expect(json["speaker_profiles"]["Alice"]["mood_distribution"]["declarative"]).to eq(0.72)
    end
    
    it "includes correlations" do
      formatter = described_class.new(result)
      json = JSON.parse(formatter.render)
      
      expect(json["correlations"]["mental"]["avg_tenor"]).to eq(0.34)
      expect(json["correlations"]["verbal"]["avg_modality"]).to eq(0.78)
    end
    
    it "includes insights" do
      formatter = described_class.new(result)
      json = JSON.parse(formatter.render)
      
      expect(json["insights"]).to include("Alice maintains casual tenor across conversation")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/sfl_compiler/formatters/json_formatter_spec.rb
```

Expected: `uninitialized constant SFL::Compiler::Formatters::JSONFormatter`

- [ ] **Step 3: Implement JSONFormatter**

```ruby
# lib/sfl/compiler/formatters/json_formatter.rb

# frozen_string_literal: true

require "json"

module SFL
  module Compiler
    module Formatters
      # Exports conversation analysis to JSON format
      class JSONFormatter < BaseFormatter
        def render
          JSON.pretty_generate(build_hash)
        end
        
        private
        
        def build_hash
          {
            metadata: format_metadata,
            speaker_profiles: format_speaker_profiles,
            tenor_timeline: result.tenor_timeline,
            field_evolution: result.field_evolution,
            correlations: result.correlations,
            insights: result.insights
          }
        end
        
        def format_metadata
          result.metadata.merge(
            analyzed_at: result.metadata[:analyzed_at]&.iso8601
          )
        end
        
        def format_speaker_profiles
          result.speaker_profiles.transform_values do |profile|
            {
              turn_count: profile.turn_count,
              avg_tenor: profile.avg_tenor,
              tenor_range: profile.tenor_range,
              tenor_variance: profile.tenor_variance,
              avg_modality: profile.avg_modality,
              mood_distribution: profile.mood_distribution,
              dominant_processes: profile.dominant_processes
            }
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/sfl_compiler/formatters/json_formatter_spec.rb
```

Expected: 5 examples, 0 failures

- [ ] **Step 5: Require json_formatter in formatters.rb**

```ruby
# lib/sfl/compiler/formatters.rb (add require)

require_relative "formatters/base_formatter"
require_relative "formatters/csv_formatter"
require_relative "formatters/json_formatter"
```

- [ ] **Step 6: Commit JSON formatter**

```bash
git add lib/sfl/compiler/formatters.rb lib/sfl/compiler/formatters/json_formatter.rb spec/sfl_compiler/formatters/json_formatter_spec.rb
git commit -m "feat: add JSON formatter for analysis results

Exports structured conversation analysis data to JSON format for
programmatic access. Includes metadata, profiles, correlations.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Markdown Formatter

**Files:**
- Create: `lib/sfl/compiler/formatters/markdown_formatter.rb`
- Create: `spec/sfl_compiler/formatters/markdown_formatter_spec.rb`

- [ ] **Step 1: Write failing test for Markdown formatter**

```ruby
# spec/sfl_compiler/formatters/markdown_formatter_spec.rb

require "spec_helper"

RSpec.describe SFL::Compiler::Formatters::MarkdownFormatter do
  let(:alice_profile) do
    SFL::Compiler::Types::SpeakerProfile.new(
      speaker_name: "Alice",
      turn_count: 3,
      avg_tenor: 0.38,
      tenor_range: [0.22, 0.61],
      tenor_variance: 0.14,
      avg_modality: 0.42,
      mood_distribution: { "declarative" => 0.72, "interrogative" => 0.28 },
      dominant_processes: { "mental" => 10, "material" => 5 }
    )
  end
  
  let(:result) do
    SFL::Compiler::Types::AnalysisResult.new(
      metadata: {
        conversation_id: "test-convo",
        turn_count: 5,
        speakers: ["Alice", "Bob"],
        analyzed_at: Time.parse("2026-06-10 14:32:15")
      },
      turns: [],
      speaker_profiles: { "Alice" => alice_profile },
      tenor_timeline: [],
      field_evolution: [],
      correlations: {
        "mental" => { avg_tenor: 0.34, avg_modality: 0.41, count: 10 },
        "verbal" => { avg_tenor: 0.71, avg_modality: 0.78, count: 8 }
      },
      insights: [
        "Alice maintains casual tenor (0.38) throughout conversation",
        "Mental processes correlate with casual tenor (0.34)"
      ]
    )
  end
  
  describe "#render" do
    it "generates markdown document" do
      formatter = described_class.new(result)
      md = formatter.render
      
      expect(md).to include("# Conversation Analysis:")
      expect(md).to include("## Summary")
      expect(md).to include("## Speaker Profiles")
    end
    
    it "includes metadata in summary" do
      formatter = described_class.new(result)
      md = formatter.render
      
      expect(md).to include("**Turns**: 5")
      expect(md).to include("**Speakers**: Alice, Bob")
    end
    
    it "includes speaker profile table" do
      formatter = described_class.new(result)
      md = formatter.render
      
      expect(md).to include("| Alice")
      expect(md).to include("0.38")
      expect(md).to include("[0.22, 0.61]")
    end
    
    it "includes correlations table" do
      formatter = described_class.new(result)
      md = formatter.render
      
      expect(md).to include("## Tenor ↔ Field Correlations")
      expect(md).to include("| mental")
      expect(md).to include("0.34")
      expect(md).to include("0.41")
    end
    
    it "includes insights section" do
      formatter = described_class.new(result)
      md = formatter.render
      
      expect(md).to include("## Generated Insights")
      expect(md).to include("Alice maintains casual tenor")
      expect(md).to include("Mental processes correlate")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/sfl_compiler/formatters/markdown_formatter_spec.rb
```

Expected: `uninitialized constant SFL::Compiler::Formatters::MarkdownFormatter`

- [ ] **Step 3: Implement MarkdownFormatter**

```ruby
# lib/sfl/compiler/formatters/markdown_formatter.rb

# frozen_string_literal: true

module SFL
  module Compiler
    module Formatters
      # Exports conversation analysis to Markdown report
      class MarkdownFormatter < BaseFormatter
        def render
          <<~MD
            # Conversation Analysis: #{result.metadata[:conversation_id]}
            
            **Generated**: #{result.metadata[:analyzed_at]&.strftime("%Y-%m-%d %H:%M:%S")}
            **Turns**: #{result.metadata[:turn_count]} | **Speakers**: #{result.metadata[:speakers]&.join(", ")}
            
            ---
            
            ## Summary
            
            This analysis tracks **tenor evolution** (formality shifts), **field evolution** (topic/process changes), and **tenor ↔ field correlations** across the conversation.
            
            ---
            
            ## Speaker Profiles
            
            #{speaker_profiles_table}
            
            ---
            
            ## Tenor ↔ Field Correlations
            
            #{correlations_table}
            
            ---
            
            ## Generated Insights
            
            #{insights_list}
            
            ---
            
            ## Methodology
            
            **SFL Framework**: Two-Pass SFL Compiler (sfl-compiler)
            - **Pass 1**: Syntactic parsing (spaCy) + Ideational extraction (process types, participants)
            - **Pass 2**: Interpersonal annotation (DSPy.rb + LLM) → mood, modality, tenor, attitude
            
            **Tenor Scale**: 0.0 (informal/casual) ↔ 1.0 (formal/technical)
            **Modality Scale**: 0.0 (hedged/uncertain) ↔ 1.0 (certain/assertive)
          MD
        end
        
        private
        
        def speaker_profiles_table
          return "_No speaker profiles available_" if result.speaker_profiles.empty?
          
          header = "| Speaker | Avg Tenor | Range | Variance | Avg Modality |\n"
          header += "|---------|-----------|-------|----------|--------------|\\n"
          
          rows = result.speaker_profiles.map do |name, profile|
            "| #{name} | #{profile.avg_tenor} (#{tenor_label(profile.avg_tenor)}) | #{profile.tenor_range.inspect} | #{profile.tenor_variance} | #{profile.avg_modality} |"
          end
          
          header + rows.join("\n")
        end
        
        def correlations_table
          return "_No correlations available_" if result.correlations.empty?
          
          header = "| Process Type | Avg Tenor | Avg Modality | Count |\n"
          header += "|--------------|-----------|--------------|-------|\\n"
          
          rows = result.correlations.map do |process_type, data|
            "| #{process_type} | #{data[:avg_tenor]} | #{data[:avg_modality]} | #{data[:count]} |"
          end
          
          header + rows.join("\n")
        end
        
        def insights_list
          return "_No insights generated_" if result.insights.empty?
          
          result.insights.map.with_index { |insight, i| "#{i + 1}. #{insight}" }.join("\n\n")
        end
        
        def tenor_label(tenor)
          case tenor
          when 0.0..0.3 then "casual"
          when 0.3..0.6 then "mixed"
          when 0.6..1.0 then "formal"
          else "unknown"
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/sfl_compiler/formatters/markdown_formatter_spec.rb
```

Expected: 5 examples, 0 failures

- [ ] **Step 5: Require markdown_formatter in formatters.rb**

```ruby
# lib/sfl/compiler/formatters.rb (add require)

require_relative "formatters/base_formatter"
require_relative "formatters/csv_formatter"
require_relative "formatters/json_formatter"
require_relative "formatters/markdown_formatter"
```

- [ ] **Step 6: Commit Markdown formatter**

```bash
git add lib/sfl/compiler/formatters.rb lib/sfl/compiler/formatters/markdown_formatter.rb spec/sfl_compiler/formatters/markdown_formatter_spec.rb
git commit -m "feat: add Markdown formatter for analysis results

Generates human-readable report with speaker profiles, correlations,
and insights. Includes methodology notes.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Conversation Analysis Template Script (Part 1: Core Logic)

**Files:**
- Create: `scripts/sfl_analysis/templates/conversation_analysis_template.rb`
- Create: `spec/integration/conversation_analysis_spec.rb`
- Create: `spec/fixtures/conversations/sample.jsonl`

- [ ] **Step 1: Create sample JSONL fixture**

```jsonl
# spec/fixtures/conversations/sample.jsonl

{"name":"Alice","is_user":true,"send_date":"June 10, 2026 2:30pm","mes":"Hey, I'm running into a weird issue with the auth flow.","extra":{"token_count":15}}
{"name":"Bob","is_user":false,"send_date":"June 10, 2026 2:31pm","mes":"Hmm, that's strange. Are you seeing any patterns in the logs?","extra":{"token_count":14}}
{"name":"Alice","is_user":true,"send_date":"June 10, 2026 2:33pm","mes":"Yeah, it seems to be happening with refresh tokens specifically.","extra":{"token_count":12}}
```

- [ ] **Step 2: Write integration test for conversation script**

```ruby
# spec/integration/conversation_analysis_spec.rb

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "Conversation Analysis Script", type: :integration do
  let(:fixture_path) { File.expand_path("../fixtures/conversations/sample.jsonl", __dir__) }
  let(:output_dir) { Dir.mktmpdir("sfl_output") }
  
  after do
    FileUtils.rm_rf(output_dir)
  end
  
  it "processes JSONL conversation and generates outputs" do
    # Load and execute the template script logic
    require_relative "../../scripts/sfl_analysis/templates/conversation_analysis_template"
    
    analyzer = SFL::Compiler::ConversationAnalyzer.new(
      input_file: fixture_path,
      output_dir: output_dir
    )
    
    result = analyzer.analyze
    
    expect(result).to be_a(SFL::Compiler::Types::AnalysisResult)
    expect(result.turns.count).to eq(3)
    expect(result.speaker_profiles.keys).to contain_exactly("Alice", "Bob")
  end
  
  it "generates CSV output" do
    require_relative "../../scripts/sfl_analysis/templates/conversation_analysis_template"
    
    analyzer = SFL::Compiler::ConversationAnalyzer.new(
      input_file: fixture_path,
      output_dir: output_dir
    )
    
    analyzer.analyze
    analyzer.write_outputs
    
    csv_path = File.join(output_dir, "conversation_analysis.csv")
    expect(File.exist?(csv_path)).to be true
    
    csv = CSV.read(csv_path, headers: true)
    expect(csv.count).to eq(3)
    expect(csv.headers).to include("turn_id", "speaker", "avg_tenor")
  end
  
  it "generates JSON output" do
    require_relative "../../scripts/sfl_analysis/templates/conversation_analysis_template"
    
    analyzer = SFL::Compiler::ConversationAnalyzer.new(
      input_file: fixture_path,
      output_dir: output_dir
    )
    
    analyzer.analyze
    analyzer.write_outputs
    
    json_path = File.join(output_dir, "conversation_analysis.json")
    expect(File.exist?(json_path)).to be true
    
    json = JSON.parse(File.read(json_path))
    expect(json).to have_key("metadata")
    expect(json).to have_key("speaker_profiles")
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

```bash
bundle exec rspec spec/integration/conversation_analysis_spec.rb
```

Expected: `cannot load such file -- conversation_analysis_template`

- [ ] **Step 4: Create conversation analyzer class (first part of template)**

```ruby
# scripts/sfl_analysis/templates/conversation_analysis_template.rb

#!/usr/bin/env ruby
# frozen_string_literal: true

# SFL Conversation Analysis Script
# Analyzes JSONL conversation for tenor/field evolution and correlations

$LOAD_PATH.unshift(File.expand_path("../../../lib", __dir__))
require "sfl/compiler"
require "json"
require "csv"
require "fileutils"

module SFL
  module Compiler
    # Main conversation analyzer class
    class ConversationAnalyzer
      attr_reader :input_file, :output_dir, :db, :pipeline, :result
      
      def initialize(input_file:, output_dir:)
        @input_file = input_file
        @output_dir = output_dir
        @db = setup_database
        @pipeline = SFL::Compiler::Pipeline.new(db: @db)
      end
      
      # Run full analysis
      # @return [Types::AnalysisResult]
      def analyze
        puts "Loading conversation from #{input_file}..."
        raw_turns = load_jsonl
        
        puts "Compiling #{raw_turns.count} turns through SFL pipeline..."
        compiled_turns = compile_turns(raw_turns)
        
        puts "Analyzing tenor shifts..."
        tenor_tracker = Analysis::TenorTracker.new(compiled_turns)
        tenor_tracker.calculate_shifts
        
        puts "Building speaker profiles..."
        speaker_profiles = Analysis::SpeakerProfiler.build_profiles(compiled_turns)
        
        puts "Correlating process types with tenor..."
        correlations = Analysis::CorrelationAnalyzer.new(compiled_turns).correlate_process_tenor
        
        puts "Generating insights..."
        @result = Types::AnalysisResult.new(
          metadata: build_metadata(raw_turns),
          turns: compiled_turns,
          speaker_profiles: speaker_profiles,
          tenor_timeline: build_tenor_timeline(compiled_turns),
          field_evolution: [],
          correlations: correlations,
          insights: generate_insights(speaker_profiles, correlations, tenor_tracker)
        )
      end
      
      # Write outputs to files
      def write_outputs
        raise "Must call analyze first" unless result
        
        FileUtils.mkdir_p(output_dir)
        
        puts "Writing outputs to #{output_dir}..."
        
        csv_formatter = Formatters::CSVFormatter.new(result)
        csv_formatter.write_to(File.join(output_dir, "conversation_analysis.csv"))
        
        json_formatter = Formatters::JSONFormatter.new(result)
        json_formatter.write_to(File.join(output_dir, "conversation_analysis.json"))
        
        md_formatter = Formatters::MarkdownFormatter.new(result)
        md_formatter.write_to(File.join(output_dir, "conversation_analysis.md"))
        
        puts "✓ Analysis complete!"
        puts "  - CSV:      #{output_dir}/conversation_analysis.csv"
        puts "  - JSON:     #{output_dir}/conversation_analysis.json"
        puts "  - Markdown: #{output_dir}/conversation_analysis.md"
      end
      
      private
      
      def setup_database
        SFL::Compiler.configure do |c|
          c.database_url = ENV.fetch("DATABASE_URL", "postgresql:///sfl_compiler_dev")
          c.spacy_model = ENV.fetch("SPACY_MODEL", "en_core_web_sm")
          c.dspy_provider = ENV.fetch("DSPY_PROVIDER", "openai/gpt-4o-mini")
        end
        
        db = SFL::Compiler::Database.connect
        SFL::Compiler::Database.setup_extensions(db)
        SFL::Compiler::Migrator.new(db).run_all
        db
      end
      
      def load_jsonl
        File.readlines(input_file).map.with_index do |line, idx|
          data = JSON.parse(line)
          {
            turn_id: idx + 1,
            speaker: data["name"],
            timestamp: Time.parse(data["send_date"]),
            message_text: data["mes"]
          }
        end
      end
      
      def compile_turns(raw_turns)
        raw_turns.map do |turn_data|
          clauses = pipeline.compile(
            turn_data[:message_text],
            document_id: "turn:#{turn_data[:turn_id]}",
            store: true,
            embed: false  # Skip embedding for now
          )
          
          process_types = clauses.each_with_object(Hash.new(0)) do |clause, counts|
            counts[clause.ideational.process_type] += 1
          end
          
          participants = clauses.flat_map { |c| c.ideational.participants.map(&:text) }.uniq
          
          Types::ConversationTurn.new(
            turn_id: turn_data[:turn_id],
            speaker: turn_data[:speaker],
            timestamp: turn_data[:timestamp],
            message_text: turn_data[:message_text],
            clauses: clauses,
            avg_tenor: clauses.map { |c| c.interpersonal.tenor }.sum / clauses.count.to_f,
            avg_modality: clauses.map { |c| c.interpersonal.modality_weight }.sum / clauses.count.to_f,
            dominant_mood: clauses.map { |c| c.interpersonal.mood }.max_by { |mood| clauses.count { |c| c.interpersonal.mood == mood } },
            process_types: process_types,
            participants: participants,
            tenor_shift: nil
          )
        end
      end
      
      def build_metadata(raw_turns)
        {
          conversation_id: File.basename(input_file, ".*"),
          turn_count: raw_turns.count,
          speakers: raw_turns.map { |t| t[:speaker] }.uniq,
          analyzed_at: Time.now
        }
      end
      
      def build_tenor_timeline(turns)
        turns.map do |turn|
          {
            timestamp: turn.timestamp,
            tenor: turn.avg_tenor,
            speaker: turn.speaker
          }
        end
      end
      
      def generate_insights(speaker_profiles, correlations, tenor_tracker)
        insights = []
        
        # Speaker comparison
        if speaker_profiles.count == 2
          speakers = speaker_profiles.values.sort_by(&:avg_tenor)
          ratio = (speakers.last.avg_tenor / speakers.first.avg_tenor).round(1)
          insights << "#{speakers.last.speaker_name} maintains #{ratio}x higher avg tenor (#{speakers.last.avg_tenor.round(2)}) than #{speakers.first.speaker_name} (#{speakers.first.avg_tenor.round(2)})"
        end
        
        # Process correlations
        mental_tenor = correlations.dig("mental", :avg_tenor)
        verbal_tenor = correlations.dig("verbal", :avg_tenor)
        if mental_tenor && verbal_tenor
          insights << "Mental processes correlate with #{mental_tenor < 0.5 ? 'casual' : 'formal'} tenor (#{mental_tenor.round(2)}), while verbal processes are #{verbal_tenor < 0.5 ? 'casual' : 'formal'} (#{verbal_tenor.round(2)})"
        end
        
        insights
      end
    end
  end
end

# CLI execution (when run as script)
if __FILE__ == $PROGRAM_NAME
  input_file = ARGV[0] || raise("Usage: #{$0} <input.jsonl> [output_dir]")
  output_dir = ARGV[1] || "./sfl_output"
  
  analyzer = SFL::Compiler::ConversationAnalyzer.new(
    input_file: input_file,
    output_dir: output_dir
  )
  
  analyzer.analyze
  analyzer.write_outputs
end
```

- [ ] **Step 5: Run integration test**

```bash
bundle exec rspec spec/integration/conversation_analysis_spec.rb
```

Expected: 3 examples, 0 failures (may need database setup)

- [ ] **Step 6: Make script executable**

```bash
chmod +x scripts/sfl_analysis/templates/conversation_analysis_template.rb
```

- [ ] **Step 7: Commit conversation analyzer**

```bash
git add scripts/sfl_analysis/templates/conversation_analysis_template.rb spec/integration/conversation_analysis_spec.rb spec/fixtures/conversations/sample.jsonl
git commit -m "feat: add conversation analysis template script

Complete conversation analyzer with JSONL loading, SFL compilation,
tenor/field tracking, and multi-format output generation.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Agent Configuration

**Files:**
- Create: `.claude/agents/sfl-analyzer.md`

- [ ] **Step 1: Create agent configuration**

```markdown
# .claude/agents/sfl-analyzer.md

---
name: sfl-analyzer
description: Generates analysis scripts using the SFL compiler framework for conversation, documentation, and context analysis
model: sonnet
tools: [Read, Write, Bash, Edit]
skills: [sfl-analyze]
---

You are an expert in Systemic Functional Linguistics (SFL) and the sfl-compiler Ruby gem. Your role is to help users analyze text (conversations, documentation, general context) by generating custom Ruby scripts that leverage the SFL framework's two-pass compiler.

## Your Expertise

**SFL Framework Knowledge**:
- Pass 1: Syntactic parsing (spaCy) + Ideational extraction (process types, participants, circumstances)
- Pass 2: Interpersonal annotation (DSPy.rb + LLM) → mood, modality weight, tenor, speaker attitude
- Storage: PostgreSQL + pgvector with scalar indices on interpersonal features
- Retrieval: Hybrid RRF (semantic + keyword) with scalar metadata filtering

**Data Model**:
- `Types::SyntacticClause`: text, tokens, root_index, sentence_index
- `Types::IdeationalPayload`: process_type, participants, circumstances
- `Types::InterpersonalPayload`: mood, modality_weight, tenor, speaker_attitude
- `Types::AnnotatedClause`: full output combining all metafunctions
- `Types::ConversationTurn`: turn-level aggregation for conversation analysis
- `Types::SpeakerProfile`: per-speaker metrics (tenor, modality, process types)
- `Types::AnalysisResult`: complete analysis output

**Analysis Modules**:
- `Analysis::TenorTracker`: Detect formality shifts across conversation
- `Analysis::SpeakerProfiler`: Aggregate speaker-level metrics
- `Analysis::CorrelationAnalyzer`: Correlate process types with tenor/modality

**Formatters**:
- `Formatters::CSVFormatter`: Spreadsheet-compatible turn-by-turn data
- `Formatters::JSONFormatter`: Structured data for APIs
- `Formatters::MarkdownFormatter`: Human-readable reports
- `Formatters::HTMLFormatter`: Interactive dashboards (future)

## Common Patterns

**Conversation Analysis**:
- Track tenor/field evolution
- Detect significant shifts (>0.15 tenor change)
- Build speaker profiles
- Correlate process types with rhetorical stance

**Documentation Audit**:
- Find certainty mismatches (hedged language in critical sections)
- Extract imperative statements (requirements)
- Check tone consistency across sections

**Context Extraction**:
- Filter by rhetorical stance (mood, modality, tenor, process_type)
- Hybrid retrieval (semantic + keyword)
- Export annotated results

## When Invoked

1. **Understand the request**: What type of analysis? What input format? What insights are needed?

2. **Select approach**:
   - Template script (conversation analysis available now)
   - Custom script (for specific analysis logic)

3. **Generate or customize the script**:
   - Read template if using one
   - Customize for user's input format, analysis goals, output preferences
   - Add comments explaining SFL concepts
   - Include usage instructions

4. **Test the script** (optional):
   - Run on sample data if provided
   - Debug any errors
   - Validate output format

5. **Provide to user**:
   - Show generated script path
   - Explain what it does and how to run it
   - Suggest refinements or follow-up analyses

## Script Generation Principles

- **Clarity**: Scripts should be readable by users with basic Ruby knowledge
- **Comments**: Explain SFL concepts (tenor, modality, process types) inline
- **Error handling**: Graceful failures with helpful error messages
- **Modularity**: Separate concerns (loading, compilation, analysis, output)
- **Extensibility**: Easy to modify filters, add output formats, tweak thresholds

## Example Interaction

User: "Analyze this chat log for formality shifts"

You:
1. Read the chat log to understand format
2. Use conversation analysis template
3. Explain what the script will analyze (tenor tracking, speaker profiling, correlations)
4. Show user how to run it: `ruby scripts/sfl_analysis/templates/conversation_analysis_template.rb chat.jsonl ./output`
5. Offer to refine analysis or add visualizations
```

- [ ] **Step 2: Commit agent configuration**

```bash
git add .claude/agents/sfl-analyzer.md
git commit -m "feat: add SFL analyzer agent configuration

Configures agent with SFL framework expertise for generating analysis
scripts. Includes data model, analysis modules, and common patterns.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 10: Skill Interface

**Files:**
- Create: `.claude/skills/sfl-analyze/SKILL.md`
- Create: `.claude/skills/sfl-analyze/handlers/conversation_handler.rb`

- [ ] **Step 1: Create skill documentation**

```markdown
# .claude/skills/sfl-analyze/SKILL.md

---
name: sfl-analyze
description: Generate SFL analysis scripts for conversations, documentation, and context extraction
---

# SFL Analysis Skill

Generates custom analysis scripts using the SFL compiler framework.

## Usage

```bash
# Analyze conversation (JSONL format)
/sfl-analyze conversation <path> [options]

# Future subcommands (not yet implemented):
# /sfl-analyze documentation <path> [options]
# /sfl-analyze context <query> [options]
# /sfl-analyze generate-script "<description>"
```

## Subcommands

### `conversation`

Analyzes chat logs, transcripts, or turn-based conversations.

**Arguments**:
- `<path>`: Path to JSONL file (required)

**Options**:
- `--output-dir <dir>`: Output directory [default: ./sfl_output]

**Example**:
```bash
/sfl-analyze conversation chat.jsonl
/sfl-analyze conversation chat.jsonl --output-dir ./results
```

**What it does**:
1. Loads JSONL conversation (format: `{name, send_date, mes}`)
2. Compiles each turn through SFL pipeline (Pass 1 + Pass 2)
3. Tracks tenor evolution (formality shifts)
4. Builds speaker profiles (avg tenor, modality, mood distribution)
5. Correlates process types with tenor/modality
6. Generates insights
7. Exports to CSV + JSON + Markdown

**Output Files**:
- `conversation_analysis.csv` — Turn-by-turn data for spreadsheet analysis
- `conversation_analysis.json` — Structured data for programmatic access
- `conversation_analysis.md` — Human-readable report with insights

---

## Script Location

The skill runs the existing template script:
- `scripts/sfl_analysis/templates/conversation_analysis_template.rb`

---

## Examples

**Example 1: Analyze support conversation**
```bash
/sfl-analyze conversation support_chat.jsonl
```

**Example 2: Custom output directory**
```bash
/sfl-analyze conversation meeting_transcript.jsonl --output-dir ./analysis_results
```

---

## Requirements

- PostgreSQL database with pgvector extension
- spaCy with `en_core_web_sm` model
- OpenAI API key (for Pass 2 interpersonal annotation)

Set via environment variables:
```bash
export DATABASE_URL="postgresql:///sfl_compiler_dev"
export OPENAI_API_KEY="sk-..."
```
```

- [ ] **Step 2: Create conversation handler**

```ruby
# .claude/skills/sfl-analyze/handlers/conversation_handler.rb

# frozen_string_literal: true

module SFLAnalyze
  # Handles /sfl-analyze conversation subcommand
  class ConversationHandler
    def self.handle(path, options = {})
      # Validate input
      raise ArgumentError, "File not found: #{path}" unless File.exist?(path)
      raise ArgumentError, "File must be JSONL format" unless path.end_with?(".jsonl")
      
      # Prepare script path
      script_path = File.expand_path(
        "../../../../scripts/sfl_analysis/templates/conversation_analysis_template.rb",
        __FILE__
      )
      
      # Prepare output directory
      output_dir = options[:output_dir] || "./sfl_output"
      
      # Build command
      cmd = "ruby #{script_path} #{path} #{output_dir}"
      
      # Return execution info
      {
        script: script_path,
        command: cmd,
        input: path,
        output_dir: output_dir,
        description: "Conversation analysis: tenor tracking, speaker profiling, correlations"
      }
    end
  end
end
```

- [ ] **Step 3: Commit skill interface**

```bash
git add .claude/skills/sfl-analyze/SKILL.md .claude/skills/sfl-analyze/handlers/conversation_handler.rb
git commit -m "feat: add /sfl-analyze skill interface

Provides user-facing command for running conversation analysis.
Includes handler for routing to template script.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 11: Integration Test with Real Conversation

**Files:**
- Create: `spec/integration/real_conversation_spec.rb`

- [ ] **Step 1: Write integration test with user's actual conversation**

```ruby
# spec/integration/real_conversation_spec.rb

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "Real Conversation Analysis", type: :integration do
  let(:conversation_path) { "/home/b08x/Workspace/Datasets/steve-oliver-2025-08-29@13h25m38s.jsonl" }
  let(:output_dir) { Dir.mktmpdir("sfl_real_output") }
  
  before do
    skip "Conversation file not found" unless File.exist?(conversation_path)
  end
  
  after do
    FileUtils.rm_rf(output_dir) if File.exist?(output_dir)
  end
  
  it "analyzes real steve-oliver conversation" do
    require_relative "../../scripts/sfl_analysis/templates/conversation_analysis_template"
    
    analyzer = SFL::Compiler::ConversationAnalyzer.new(
      input_file: conversation_path,
      output_dir: output_dir
    )
    
    result = analyzer.analyze
    
    expect(result.turns.count).to eq(28)
    expect(result.speaker_profiles.keys).to contain_exactly("Robert", "Steve")
    
    # Verify tenor patterns from design spec
    robert_profile = result.speaker_profiles["Robert"]
    steve_profile = result.speaker_profiles["Steve"]
    
    expect(robert_profile.avg_tenor).to be < steve_profile.avg_tenor
    expect(steve_profile.avg_tenor).to be > 0.6  # Formal
    expect(robert_profile.avg_tenor).to be < 0.5  # Casual
  end
  
  it "generates all output files" do
    require_relative "../../scripts/sfl_analysis/templates/conversation_analysis_template"
    
    analyzer = SFL::Compiler::ConversationAnalyzer.new(
      input_file: conversation_path,
      output_dir: output_dir
    )
    
    analyzer.analyze
    analyzer.write_outputs
    
    expect(File.exist?(File.join(output_dir, "conversation_analysis.csv"))).to be true
    expect(File.exist?(File.join(output_dir, "conversation_analysis.json"))).to be true
    expect(File.exist?(File.join(output_dir, "conversation_analysis.md"))).to be true
  end
  
  it "identifies tenor shifts" do
    require_relative "../../scripts/sfl_analysis/templates/conversation_analysis_template"
    
    analyzer = SFL::Compiler::ConversationAnalyzer.new(
      input_file: conversation_path,
      output_dir: output_dir
    )
    
    result = analyzer.analyze
    
    # Should detect shift from Robert (casual) to Steve (formal)
    shifts = result.turns.select { |t| t.tenor_shift && t.tenor_shift.abs > 0.15 }
    expect(shifts).not_to be_empty
  end
end
```

- [ ] **Step 2: Run integration test (optional - requires database)**

```bash
bundle exec rspec spec/integration/real_conversation_spec.rb
```

Expected: 3 examples, 0 failures (or skipped if conversation file not found)

- [ ] **Step 3: Commit integration test**

```bash
git add spec/integration/real_conversation_spec.rb
git commit -m "test: add integration test for real conversation analysis

Tests full pipeline with steve-oliver conversation. Verifies tenor
patterns, speaker profiles, and output generation.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 12: Update Main Library Loader

**Files:**
- Modify: `lib/sfl/compiler.rb`

- [ ] **Step 1: Require new modules in main loader**

```ruby
# lib/sfl/compiler.rb (add requires after existing modules)

require_relative "compiler/analysis"
require_relative "compiler/formatters"
```

- [ ] **Step 2: Run full test suite**

```bash
bundle exec rspec
```

Expected: All tests passing

- [ ] **Step 3: Commit loader updates**

```bash
git add lib/sfl/compiler.rb
git commit -m "chore: require analysis and formatters modules

Loads new conversation analysis and formatting infrastructure.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 13: Documentation Updates

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README with analysis section**

```markdown
# README.md (add after "Retrieval with Scalar Filters" section)

### Conversation Analysis

Analyze chat logs for tenor evolution, speaker patterns, and rhetorical correlations:

```bash
# Run conversation analysis script
ruby scripts/sfl_analysis/templates/conversation_analysis_template.rb conversation.jsonl ./output

# Or use the Claude Code skill
/sfl-analyze conversation conversation.jsonl
```

**Input Format** (JSONL):
```jsonl
{"name":"Alice","send_date":"June 10, 2026 2:30pm","mes":"Message text..."}
{"name":"Bob","send_date":"June 10, 2026 2:31pm","mes":"Response text..."}
```

**Outputs**:
- `conversation_analysis.csv` — Turn-by-turn data (speaker, tenor, modality, process types)
- `conversation_analysis.json` — Structured analysis data
- `conversation_analysis.md` — Human-readable report with insights

**Analysis Features**:
- **Tenor Tracking**: Detect formality shifts across conversation
- **Speaker Profiling**: Aggregate tenor/modality/mood per speaker
- **Process Correlation**: Link process types (mental/verbal/material) with rhetorical stance
- **Insight Generation**: Automated observations about communication patterns

**Example Insights**:
- "Steve maintains 2.0x higher tenor (0.76) than Robert (0.38)"
- "Mental processes correlate with casual tenor (0.34)"
- "Largest tenor shift at turn #2: Δ = +0.46"
```

- [ ] **Step 2: Commit documentation**

```bash
git add README.md
git commit -m "docs: add conversation analysis usage to README

Documents /sfl-analyze skill and template script usage. Includes
input format, outputs, and example insights.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 14: Final Verification

**Files:**
- Run: Full test suite
- Run: Script manually with sample data

- [ ] **Step 1: Run full test suite**

```bash
bundle exec rspec --format documentation
```

Expected: All examples passing

- [ ] **Step 2: Test script manually with sample conversation**

```bash
ruby scripts/sfl_analysis/templates/conversation_analysis_template.rb \
  spec/fixtures/conversations/sample.jsonl \
  ./test_output
```

Expected: Script completes without errors, generates 3 output files

- [ ] **Step 3: Inspect CSV output**

```bash
cat ./test_output/conversation_analysis.csv
```

Expected: Headers + 3 data rows with tenor/modality values

- [ ] **Step 4: Inspect JSON output**

```bash
cat ./test_output/conversation_analysis.json | jq '.speaker_profiles'
```

Expected: Alice and Bob profiles with aggregated metrics

- [ ] **Step 5: Inspect Markdown output**

```bash
cat ./test_output/conversation_analysis.md
```

Expected: Formatted report with sections for profiles, correlations, insights

- [ ] **Step 6: Clean up test output**

```bash
rm -rf ./test_output
```

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "✅ verify: complete SFL analysis agent implementation

Full working implementation of conversation analysis with:
- Data structures (ConversationTurn, SpeakerProfile, AnalysisResult)
- Analysis modules (TenorTracker, SpeakerProfiler, CorrelationAnalyzer)
- Formatters (CSV, JSON, Markdown)
- Template script (conversation_analysis_template.rb)
- Agent & skill configuration (/sfl-analyze)
- Integration tests with real conversation
- Documentation

Verified with test suite and manual script execution.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Self-Review Checklist

### Spec Coverage

✓ ConversationTurn data structure → Task 1
✓ SpeakerProfile data structure → Task 1
✓ AnalysisResult data structure → Task 1
✓ Tenor shift detection → Task 2
✓ Speaker profiling → Task 3
✓ Process-tenor correlation → Task 4
✓ CSV formatter → Task 5
✓ JSON formatter → Task 6
✓ Markdown formatter → Task 7
✓ Conversation template script → Task 8
✓ Agent configuration → Task 9
✓ Skill configuration → Task 10
✓ Integration test → Task 11
✓ Documentation → Task 13

### Placeholder Scan

No placeholders found. All code blocks contain complete implementations.

### Type Consistency

- `Types::ConversationTurn` used consistently across Tasks 1-11
- `Types::SpeakerProfile` used in Tasks 1, 3, 6-8
- `Types::AnalysisResult` used in Tasks 1, 5-8
- `Analysis::TenorTracker#calculate_shifts` called in Task 8
- `Analysis::SpeakerProfiler.build_profiles` called in Task 8
- `Analysis::CorrelationAnalyzer#correlate_process_tenor` called in Task 8
- `Formatters::CSVFormatter`, `JSONFormatter`, `MarkdownFormatter` all inherit from `BaseFormatter`

All method signatures and type names are consistent across tasks.

---

## Plan Complete

**Plan saved to**: `docs/superpowers/plans/2026-06-10-sfl-analysis-agent.md`

**Two execution options:**

**1. Subagent-Driven (recommended)** — Fresh subagent per task, review between tasks, fast iteration. Use the `superpowers:subagent-driven-development` skill.

**2. Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints.

**Which approach?**
