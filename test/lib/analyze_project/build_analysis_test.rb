# frozen_string_literal: true

require "minitest/autorun"
require "ripper"

require_relative "../../../lib/analyze_project/ruby_file_ast"
require_relative "../../../lib/analyze_project/build_analysis"

module AnalyzeProject
  class BuildAnalysisTest < Minitest::Test
    def test_simple_class_doesnt_generate_reference
      sexp = RubyFileAST.new("foo.rb", Ripper.sexp("class Foo; end")[1])
      analysis = BuildAnalysis.new.call([sexp])

      assert(analysis.references.empty?)
      assert(analysis.namespaces.size == 1)

      namespace = analysis.namespaces.first
      assert_equal("Foo", namespace.identifier)
      assert_equal("", namespace.parent_identifier)
      assert_nil(namespace.parent_namespace)
    end

    def test_module_doesnt_generate_reference
      sexp = RubyFileAST.new("foo.rb", Ripper.sexp("module Foo; end")[1])
      analysis = BuildAnalysis.new.call([sexp])

      assert(analysis.references.empty?)
      assert(analysis.namespaces.size == 1)

      namespace = analysis.namespaces.first
      assert_equal(:module, namespace.type)
      assert_equal("Foo", namespace.identifier)
      assert_equal("", namespace.parent_identifier)
      assert_nil(namespace.parent_namespace)
    end

    def test_nested_class_generates_parent_namespace
      sexp = RubyFileAST.new("foo.rb", Ripper.sexp("class Foo; class Bar; end; end")[1])
      analysis = BuildAnalysis.new.call([sexp])

      assert(analysis.namespaces.size == 2)

      namespaces = analysis.namespaces.to_a
      first_namespace = namespaces[0]
      second_namespace = namespaces[1]

      assert(:class, first_namespace.type)
      assert("Foo", first_namespace.identifier)
      assert_equal("", first_namespace.parent_identifier)
      assert_nil(first_namespace.parent_namespace)

      assert(:class, second_namespace.type)
      assert_equal("Bar", second_namespace.identifier)
      assert_equal("", second_namespace.parent_identifier)
      assert_equal(first_namespace, second_namespace.parent_namespace)
    end

    def test_nested_class_generates_reference
      sexp = RubyFileAST.new("foo.rb", Ripper.sexp("class Foo; class Bar; end; end")[1])
      analysis = BuildAnalysis.new.call([sexp])

      reference = analysis.references.first

      assert_equal("Foo::Bar", reference.from_klass)
      assert_equal("Foo", reference.to_klass)
      assert_equal(:nested_in, reference.type)
    end

    def test_inheritance_generates_namespace_with_parent_identifier
      sexp = RubyFileAST.new("foo.rb", Ripper.sexp("class Foo < Bar; end")[1])
      analysis = BuildAnalysis.new.call([sexp])

      namespace = analysis.namespaces.first
      assert_equal(:class, namespace.type)
      assert_equal("Foo", namespace.identifier)
      assert_equal("Bar", namespace.parent_identifier)
    end

    def test_inheritance_builds_a_inherits_from_reference
      sexp = RubyFileAST.new("foo.rb", Ripper.sexp("class Foo < Bar; end")[1])
      analysis = BuildAnalysis.new.call([sexp])

      assert(analysis.references.size == 1)

      reference = analysis.references.first

      assert_equal("Foo", reference.from_klass)
      assert_equal("Bar", reference.to_klass)
      assert_equal(:subclass_of, reference.type)
    end
  end
end
