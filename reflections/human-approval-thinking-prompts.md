# Human-in-the-Loop Thinking Prompts

## How to use these questions

Use these when designing human approval workflows for AI agent systems. The goal is to understand where human oversight is essential and how to make it reliable.

## When to require approval

### Q: When should an agent ALWAYS require human approval, regardless of how confident it is?
**Type:** Critical
**Level:** Intermediate
**Hint:** Think about irreversibility, blast radius, regulated domains, and legal liability.

### Q: What distinguishes a "low-risk" agent action from a "high-risk" one that needs approval?
**Type:** Critical
**Level:** Intermediate
**Hint:** Consider reversibility, scope (one row vs. many), domain (financial, medical, legal), and novelty.

### Q: Should approval be required per-action or per-session? What is the difference in risk?
**Type:** Critical
**Level:** Advanced
**Hint:** Per-session approval is more convenient — what could go wrong if a session runs for hours?

## Implementing approval workflows

### Q: What are the risks of implementing the human approval workflow in application memory instead of the database?
**Type:** Systems
**Level:** Intermediate
**Hint:** What happens if the server restarts? What if two servers run the same application?

### Q: How would you handle a human approval timeout — auto-reject, auto-approve, or escalate?
**Type:** Critical
**Level:** Intermediate
**Hint:** Which option is safer? Which is more useful? Can the choice depend on the action type?

### Q: Why should the approval decision be stored in the database, not just logged?
**Type:** Systems
**Level:** Intermediate
**Hint:** Who needs to read the decision, and when? What if the original agent crashes?

### Q: An agent submits an approval request and the human never responds. How does PostgreSQL help you detect this?
**Type:** Systems
**Level:** Intermediate
**Hint:** Think about TIMESTAMPTZ columns, age() function, and a scheduled expiry check.

### Q: How would you notify a human reviewer that an approval is pending, using only PostgreSQL?
**Type:** Creative
**Level:** Advanced
**Hint:** LISTEN/NOTIFY. What triggers the NOTIFY? What listens to it?

### Q: Should the agent be able to see who approved (or rejected) its request? Why or why not?
**Type:** Critical
**Level:** Intermediate
**Hint:** Consider: accountability, feedback loops, and whether the agent could exploit this information.

### Q: An agent submits 100 approval requests in 10 seconds. Is this a problem? How would you detect and prevent it?
**Type:** Systems
**Level:** Advanced
**Hint:** Rate limiting at the database level — what mechanism would you use?
