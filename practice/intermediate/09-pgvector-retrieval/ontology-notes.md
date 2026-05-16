# Ontology Notes — pgvector Retrieval

## Embeddings as semantic coordinates
An embedding is a point in semantic space — a coordinate that encodes the "meaning" of a piece of text as learned by a neural model. The distance between two embeddings measures their semantic proximity. This is the operationalization of ontological similarity: two concepts that share many properties and relations will have embeddings that are geometrically close.

## Vector space as implicit ontology
A trained embedding model has learned an implicit ontology from its training data. Concepts related by `is-a` (hypernymy), `part-of` (mereology), and `co-occurs-with` (distributional semantics) relationships will cluster in the embedding space. pgvector exposes this implicit ontology as a queryable structure.

## Explicit vs implicit ontology
| Dimension | Explicit ontology (ltree, RLS) | Implicit ontology (pgvector) |
|---|---|---|
| Defined by | Schema designer | Embedding model training |
| Queryable via | SQL predicates | Vector distance |
| Updatable | Yes (ALTER TABLE) | Requires re-embedding |
| Interpretable | Yes (named relations) | No (learned weights) |
| Captures | Known relationships | Emergent relationships |

The combination of explicit (relational + ltree) and implicit (pgvector) ontology is the architecture for semantically-aware databases.

## RAG as ontology traversal
In a RAG pipeline, the query embedding is a probe into the implicit ontology. `ORDER BY embedding <=> query LIMIT k` traverses the ontology to find the k most relevant concepts (document chunks). The retrieved chunks are then passed to an LLM, which traverses its own parametric ontology to generate a response.

## Obsidian graph mapping
- `documents.embedding` → property: hasSemanticCoordinates (type: vector(3..1536))
- `<=>` operator → relation: semanticallySimilarTo (bidirectional, graded)
- KNN query → function: nearestNeighborsInOntology(probe, k) → [Document]
- HNSW index → structure: SemanticProximityGraph (approximates the ontology's neighborhood structure)
- `embedding_model` → provenance: coordinateSystem (which implicit ontology was used)
