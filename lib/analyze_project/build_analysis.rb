# frozen_string_literal: true

module AnalyzeProject
  class BuildAnalysis
    def initialize
      @analysis = Analysis.new
    end

    def call(base_path)
      find_direct_references(base_path)

      @analysis
    end

    def find_direct_references(base_path)
      app_files(base_path).each do |file|
        sexp = to_sexp(file)
        next if sexp.nil?

        analyze_tree(sexp[1], file: file)
      end
    end

    def infer_references(base_path)
    end

    def app_files(base_path)
      (Dir[File.join(base_path, "app/**/*.rb")] + Dir[File.join(base_path, "lib/**/*.rb")])
        .reject { |f| f.match?(/_spec\.rb/) }
    end

    def analyze_tree(tree, file: nil, parent_namespace: nil)
      classes_and_modules_from(tree).each do |ref|
        case ref.first
        when :module, :class
          analyze_namespace(
            type: ref.first,
            tree: ref.drop(1),
            file: file,
            parent_namespace: parent_namespace
          )
        end
      end
    end

    def analyze_namespace(type:, tree:, file:, parent_namespace:)
      identifier_tree, parent_tree, body_tree = tree
      namespace = Namespace.new(
        type: type,
        file: file,
        parent_namespace: parent_namespace,
        parent_identifier: build_full_identifier(parent_tree || []).join("::"),
        identifier: build_full_identifier(identifier_tree).join("::")
      )

      @analysis.add_namespace(namespace)

      if body_tree
        analyze_tree(
          body_tree.drop(1).first,
          file: file,
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

    def to_sexp(file)
      Ripper.sexp(File.open(file))
    end
  end
end
