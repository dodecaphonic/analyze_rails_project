# frozen_string_literal: true

require "ripper"
require "set"

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

class ExploreCodebase
  def initialize
    @analysis = Analysis.new
  end

  def call(base_path)
    app_files(base_path).each do |file|
      analyze_tree(to_sexp(file)[1], file: file)
    end

    @analysis
  end

  def app_files(base_path)
    Dir[File.join(base_path, "app/**/*.rb")]
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

pp ExploreCodebase.new.call(ARGV.shift).to_s if __FILE__ == $PROGRAM_NAME
