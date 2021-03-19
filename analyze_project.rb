# frozen_string_literal: true

require "ripper"
require "set"

require_relative "lib/analyze_project"

pp AnalyzeProject::BuildAnalysis.new.call(ARGV.shift).to_s if __FILE__ == $PROGRAM_NAME
