# frozen_string_literal: true

module AnalyzeProject
  class RubyFileAST
    def initialize(file, tree)
      @file = file
      @tree = tree
    end

    attr_reader :file, :tree

    def missing_tree?
      tree.nil?
    end

    def focus(subtree)
      RubyFileAST.new(file, subtree)
    end
  end
end
