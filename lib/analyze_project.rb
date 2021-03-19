# frozen_string_literal: true

require_relative "analyze_project/class_reference"
require_relative "analyze_project/namespace"
require_relative "analyze_project/analysis"
require_relative "analyze_project/build_analysis"
require_relative "analyze_project/ruby_file_ast"
require_relative "analyze_project/project_path_to_asts"
require_relative "analyze_project/graph_analysis"

module AnalyzeProject
  module_function def analyze(path)
    ProjectPathToASTs.new.call(path)
      .then { |files_and_sexps| BuildAnalysis.new.call(files_and_sexps) }
  end
end
