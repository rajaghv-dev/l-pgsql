# l-pgsql/reflections

Question banks for building deep, durable understanding of PostgreSQL — not memorization, but thinking.

## What these question banks are for

These are not quiz questions with trick answers. Each question has a clear, defensible answer that requires understanding a concept, not recalling a fact. The goal is to develop the kind of thinking that lets you debug problems you have never seen before.

## How to use them

### For self-testing
Pick a file, read one question, close the document, and write your answer in a notebook or scratch file. Then return and check against the hint. If you could not answer it, revisit the linked concept.

### For code review
Before reviewing a PR that touches a schema, query, or transaction, read through the relevant question file. Use the questions as a checklist lens: "Does this PR fall into any of these traps?"

### For teaching
Present the question first. Do not give the hint. Let the student reason out loud. The interesting part is not the answer — it is the reasoning process. Use the counter-examples in the design-principles files alongside the questions.

### For interview preparation
The "Critical Thinking" and "First Principles" files cover questions that senior PostgreSQL engineers are asked in technical interviews. The "Systems Thinking" file covers questions about production behavior under load.

## Files in this folder

| File | Type | Count | Best for |
|------|------|-------|---------|
| `beginner-thinking-prompts.md` | Beginner questions | 20+ | Early learners, first schemas |
| `intermediate-thinking-prompts.md` | Intermediate questions | 20+ | After first production app |
| `advanced-thinking-prompts.md` | Advanced questions | 20+ | Performance, production ops |
| `first-principles-questions.md` | First-principles reasoning | 15+ | Deep conceptual understanding |
| `critical-thinking-prompts.md` | Assumption-challenging | 15+ | Avoiding cargo-cult patterns |
| `creative-thinking-prompts.md` | Open-ended design | 10+ | System design, architecture |
| `systems-thinking-prompts.md` | System interactions | 15+ | Production behavior, incidents |
| `ontology-thinking-prompts.md` | Concept relationships | 10+ | Vocabulary, mental models |
| `extension-thinking-prompts.md` | Extension trade-offs | 10+ | Choosing the right tool |

## Question format

Each question follows this structure:
```
### Q: Question text
**Type:** Critical/Creative/Systems/Ontology/Agent
**Level:** Beginner/Intermediate/Advanced
**Hint:** [points toward the answer without giving it away]
**Reference:** [link to relevant concept or doc]
```
