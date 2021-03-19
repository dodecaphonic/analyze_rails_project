# frozen_string_literal: true

require "ruby-graphviz"

module AnalyzeProject
  class GraphAnalysis
    def call(analysis)
      graph = GraphViz.new(:G, type: :digraph)
      nodes = {}

      analysis.namespaces.each do |namespace|
        node = graph.add_node(namespace.full_identifier)
        nodes[namespace.full_identifier] = node
      end

      analysis.references.each do |reference|
        from_node = nodes[reference.from_klass]
        to_node = nodes[reference.to_klass]

        next if !from_node || !to_node

        graph.add_edges(from_node, to_node, label: reference.type)
      end

      graph.output(svg: "analysis.svg")
    end
  end
end
