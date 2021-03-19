# frozen_string_literal: true

module AnalyzeProject
  class Analysis
    def initialize
      @namespaces = Set.new
      @references = []
    end

    def add_reference(reference)
      @references << reference
    end

    def add_namespace(namespace)
      @namespaces << namespace

      return unless namespace.child_class?

      add_reference(
        ClassReference.new(
          namespace.full_identifier,
          namespace.parent_identifier,
          :subclass_of
        )
      )
    end

    def to_s
      @references.map(&:to_s)
    end
  end
end
