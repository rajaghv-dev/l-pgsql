# Ontology Notes — Full-Text Search and Fuzzy Search

## Lexemes as ontological primitives
FTS operates at the level of **lexemes** — normalized word stems that represent concepts rather than surface forms. "Running", "ran", "runs" all reduce to the lexeme "run". In ontological terms, a lexeme is an **abstract concept token**: the minimal unit of meaning that FTS can reason about.

The tsvector is a **concept fingerprint** of a document: a set of concepts (lexemes) with frequency and position information. Two documents with the same concept fingerprint are semantically equivalent from FTS's perspective.

## Semantic gap between FTS and ontology
FTS does not understand that "PostgreSQL" and "database system" are related. A search for "database" will not return an article that uses only "PostgreSQL" — they share no lexemes. Bridging this gap requires either:
- Synonym dictionaries (FTS custom dictionaries)
- Embedding-based search (pgvector, concept 15) — encodes semantic similarity in vector space
- Explicit ontology with synonymy/subsumption relations

## Trigrams as surface similarity
pg_trgm similarity is a **structural property** of strings, not a semantic one. "cat" and "car" are trigram-similar (0.5) but semantically unrelated. "cat" and "feline" are semantically related but trigram-dissimilar (0.0). FTS + trgm covers surface similarity; pgvector covers semantic similarity.

## Obsidian graph mapping
- `articles` → node type: Document
- `tags` → node type: Concept/Tag
- `article_tags` → edge: Document --[tagged_with]--> Concept
- `search_vector` → materialized property: Document::conceptFingerprint
- `to_tsquery` → function: UserIntent → ConceptQuery
- `ts_rank` → function: (Document, Query) → RelevanceScore
- `similarity()` → function: (String, String) → SurfaceSimilarity
