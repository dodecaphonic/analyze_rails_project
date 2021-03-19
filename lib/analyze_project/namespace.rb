# frozen_string_literal: true

module AnalyzeProject
  class Namespace
    def initialize(parent_namespace: nil, type:, file:, parent_identifier: "", identifier:)
      @type = type
      @file = file
      @parent_namespace = parent_namespace
      @parent_identifier = parent_identifier
      @identifier = identifier
    end

    attr_reader :type, :file, :parent_identifier, :parent_namespace, :identifier

    def child_class?
      !parent_identifier.empty?
    end

    def full_identifier
      return identifier unless parent_namespace

      "#{parent_namespace.identifier}::#{identifier}"
    end

    def to_s
      inherits_from = parent_identifier.then { _1.empty? ? "" : " < #{_1}"}
      "#{full_identifier}#{inherits_from}"
    end

    def to_h
      [parent_namespace, parent_identifier, identifier].to_h
    end
  end
end
