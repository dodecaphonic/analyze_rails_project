# analyze\_rails\_project

Builds an entity relationship tree from a Rails project based on Ripper ASTs. The end goal is to try and look at method bodies and use some heuristics to associate references and calls to existing model.

It's obviously incredibly fail-prone. It's just a way to get a 50000 ft level view of a project by looking at its dependency graph.
