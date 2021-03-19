# frozen_string_literal: true

module AnalyzeProject
  class ClassReference
    def initialize(from_klass, to_klass, type)
      @from_klass = from_klass
      @to_klass = to_klass
      @type = type
    end

    attr_reader :from_klass, :to_klass, :type

    def to_s
      "#{from_klass} → #{to_klass} [#{type}]"
    end
  end
end
