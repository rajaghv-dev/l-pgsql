# Reflection — pgvector Retrieval

## Key takeaways
- pgvector integrates semantic search into PostgreSQL without a separate vector database.
- The `<=>` cosine distance operator is the right choice for text embeddings.
- HNSW is the recommended index for most production workloads; IVFFlat is simpler but requires data at build time.
- Hybrid search (vector + SQL filter) is the real power: semantic recall + relational precision.
- Embeddings are model-specific — store the model name with every vector.

## Production considerations
| Factor | Recommendation |
|---|---|
| Dimension | Use model's native dimension (768, 1536) |
| Index type | HNSW for most cases; IVFFlat if you need smaller index size |
| Distance metric | Cosine for text; L2 for images/spatial |
| ef_search | Start at 40, tune upward for better recall |
| Batch embedding | Use queue pattern (Practice 05 SKIP LOCKED) for async embedding |
| Model versioning | Store `embedding_model` column; re-embed on model change |

## RAG pipeline sketch
```
User query
  → embed query (Ollama/OpenAI)
  → SELECT ... ORDER BY embedding <=> query_vec LIMIT 5
  → retrieve chunks
  → construct LLM prompt with chunks
  → call LLM
  → return response + source_ids
```

## What to explore next
- Stage 11: Observability — measure vector search query performance with pg_stat_statements
- Concept 21: Ontology-driven schema — embedding ontology concepts as vectors
- pgvector README on GitHub — detailed index tuning guide
