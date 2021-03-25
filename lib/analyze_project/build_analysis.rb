# frozen_string_literal: true

require_relative "analysis"
require_relative "class_reference"
require_relative "namespace"

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
          parent_namespace: namespace
        )

        analyze_top_level_statements(namespace, file_and_ast.focus(body_tree))
      end

      if parent_namespace
        @analysis.add_reference(
          ClassReference.new(
            namespace.full_identifier,
            parent_namespace&.full_identifier,
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

    def analyze_top_level_statements(namespace, file_and_ast)
      _, body = file_and_ast.tree

      body.each do |node|
        case node
        in [:command, [:@ident, cmd, _], args]
          case cmd
          in "include" then parse_include(namespace, args)
          in "belongs_to" then parse_relationship(namespace, args, :belongs_to)
          in "has_many" then parse_relationship(namespace, args, :has_many)
          else
          end
        else
        end
      end
    end

    def parse_include(namespace, args)
      case args
      in [:args_add_block, [[:var_ref, [:@const, ref, _]]], _]
         @analysis.add_reference(
           ClassReference.new(
             namespace.full_identifier,
             ref,
             :includes
           )
         )
      else
      end
    end

    def parse_relationship(namespace, args, relationship)
      case args
      in [:args_add_block, [[:symbol_literal, [:symbol, [:@ident, ref, _]]]], _]
        @analysis.add_reference(
          ClassReference.new(
            namespace.full_identifier,
            constantize(ref, to_singular: relationship == :has_many),
            relationship
          )
        )
      in [:args_add_block, [[:symbol_literal, [:symbol, [:@ident, ref, _]]], other_args], _]
        other_end = if other_args.is_a?(Array) && other_args.first == :bare_assoc_hash
                      class_name_from_hash(other_args.last) || constantize(ref, to_singular: relationship == :has_many)
                    else
                      constantize(ref, to_singular: relationship == :has_many)
                    end

        @analysis.add_reference(
          ClassReference.new(
            namespace.full_identifier,
            other_end,
            relationship
          )
        )
      else
      end
    end

    def class_name_from_hash(bare_assoc_hash)
      node = bare_assoc_hash.find do |subnode|
        case subnode
        in [:assoc_new, [:@label, label, _], _]
          label
        in [:assoc_new, [:string_literal, [:string_content, [_, label, _]]], _]
          label
        else
          ""
        end.match?(/class_name/)
      end

      return unless node

      node.dig(2, 1, 1, 1)
    end

    def constantize(ref, to_singular: false)
      *initial, last = ref.split("_")
      inflected_part = to_singular ? inflect(last) : last

      [*initial, inflected_part].map(&:capitalize).join
    end

    def inflect(str)
      if str.end_with?("ies")
        str.sub(/ies\Z/, "y")
      elsif str.end_with?("sses")
        str.sub(/es\Z/, "")
      else
        str.sub(/s\Z/, "")
      end
    end
  end
end
