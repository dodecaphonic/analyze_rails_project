# frozen_string_literal: true

module AnalyzeProject
  class ProjectPathToASTs
    def call(base_path)
      app_files(base_path).map(&method(:to_sexp)).reject(&:missing_tree?)
    end

    private

    def app_files(base_path)
      (Dir[File.join(base_path, "app/**/*.rb")] + Dir[File.join(base_path, "lib/**/*.rb")])
        .reject { |f| f.match?(/_spec\.rb/) }
    end

    def to_sexp(file)
      RubyFileAST.new(file, Ripper.sexp(File.open(file))&.then { |s| s[1] })
    end
  end
end
