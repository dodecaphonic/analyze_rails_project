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

    def test_includes_generate_included_in_references
      sexp = RubyFileAST.new("foo.rb", Ripper.sexp("class Foo; include Bar; include Baz; end")[1])
      analysis = BuildAnalysis.new.call([sexp])

      assert(analysis.references.size == 2)

      first_reference = analysis.references[0]
      second_reference = analysis.references[1]

      assert_equal("Foo", first_reference.from_klass)
      assert_equal("Bar", first_reference.to_klass)
      assert_equal(:includes, first_reference.type)

      assert_equal("Foo", second_reference.from_klass)
      assert_equal("Baz", second_reference.to_klass)
      assert_equal(:includes, second_reference.type)
    end

    def test_belongs_to_generates_belongs_to_reference
      source = <<-RUBY
        class FooModel < ApplicationRecord
          belongs_to :bar
        end
      RUBY

      sexp = RubyFileAST.new("foo.rb", Ripper.sexp(source)[1])
      analysis = BuildAnalysis.new.call([sexp])
      reference = analysis.references.find { |r| r.to_klass == "Bar" }

      assert_equal("FooModel", reference.from_klass)
      assert_equal("Bar", reference.to_klass)
      assert_equal(:belongs_to, reference.type)
    end

    def test_belongs_to_prefers_class_name_if_present
      source = <<-RUBY
        class FooModel < ApplicationRecord
          belongs_to :client, class_name: "Person", flang: flong
        end
      RUBY

      sexp = RubyFileAST.new("foo.rb", Ripper.sexp(source)[1])
      analysis = BuildAnalysis.new.call([sexp])
      reference = analysis.references.find { |r| r.to_klass == "Person" }

      assert_equal("FooModel", reference.from_klass)
      assert_equal("Person", reference.to_klass)
      assert_equal(:belongs_to, reference.type)
    end

    def test_belongs_to_prefers_class_name_in_hash_rocket_if_present
      source = <<-RUBY
        class FooModel < ApplicationRecord
          belongs_to :client, "class_name" => "Person", flang: flong
        end
      RUBY

      sexp = RubyFileAST.new("foo.rb", Ripper.sexp(source)[1])
      analysis = BuildAnalysis.new.call([sexp])
      reference = analysis.references.find { |r| r.to_klass == "Person" }

      assert_equal("FooModel", reference.from_klass)
      assert_equal("Person", reference.to_klass)
      assert_equal(:belongs_to, reference.type)
    end
  end
end
