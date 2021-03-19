# frozen_string_literal: true

module AnalyzeProject
  class BuildAnalysis
    def initialize
      @analysis = Analysis.new
    end

    def call(files_and_asts)
      find_direct_references(files_and_asts)

      @analysis
    end

    def find_direct_references(file_and_asts)
      file_and_asts.each do |file_and_ast|
        analyze_tree(file_and_ast)
      end
    end

    def infer_references(base_path)
    end

    def analyze_tree(file_and_ast, parent_namespace: nil)
      classes_and_modules_from(file_and_ast.tree).each do |ref|
        analyze_namespace(
          type: ref.first,
          file_and_ast: file_and_ast.focus(ref.drop(1)),
          parent_namespace: parent_namespace
        )
      end
    end

    def analyze_namespace(type:, file_and_ast:, parent_namespace:)
      identifier_tree, parent_tree, body_tree = file_and_ast.tree
      namespace = Namespace.new(
        type: type,
        file: file_and_ast.file,
        parent_namespace: parent_namespace,
        parent_identifier: build_full_identifier(parent_tree || []).join("::"),
        identifier: build_full_identifier(identifier_tree).join("::")
      )

      @analysis.add_namespace(namespace)

      if body_tree
        analyze_tree(
          file_and_ast.focus(body_tree.drop(1).first),
          parent_namespace: parent_namespace
        )
      end

      if parent_namespace
        add_reference(
          ClassReference.new(
            namespace.full_identifier,
            parent_namespace.full_identifier,
            :nested_in
          )
        )
      end
    end

    def build_full_identifier(identifier_tree, identifier = [])
      return identifier if identifier_tree.empty?

      case identifier_tree
      in [:@const, klass_name, _]
      build_full_identifier([], identifier + [klass_name])
      in [:top_const_ref, ref]
      build_full_identifier(ref, identifier)
      in [:const_ref, _] | [:var_ref, _]
      build_full_identifier(identifier_tree[1], identifier)
      in [:const_path_ref, left, right]
      build_full_identifier(left, identifier) + build_full_identifier(right, identifier)
      else
        identifier
      end
    end

    def classes_and_modules_from(tree)
      tree.select { |node| %i[module class].member?(node.first) }
    end
  end
end
