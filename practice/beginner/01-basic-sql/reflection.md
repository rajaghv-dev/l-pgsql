# Reflection — Practice 01: Basic SQL

---

## Comprehension

1. What is the difference between `WHERE available = true` and `WHERE available IS NOT NULL`? When would each be appropriate?

2. Why does `RETURNING` eliminate the need for a second SELECT after an INSERT? What are the advantages for an application that needs the generated `id`?

3. What happens if you run `DELETE FROM books;` without a WHERE clause? Is there a way to undo it?

4. After deleting the row with `id = 5` and inserting a new book, what `id` will the new book receive? Why?

---

## Design

5. The `books` table has a single `author` column that stores the author's full name as text. What problem does this create if a book has two authors? Design an alternative schema that handles multiple authors correctly.

6. The `available` column is a BOOLEAN. A library system might need more states: "available," "checked out," "reserved," "damaged," "archived." How would you redesign this column? What SQL type would you use?

7. If you wanted to track *when* each book was added to the catalog and *when* it was last updated, what columns would you add? What types? What defaults?

---

## Systems

8. `ORDER BY year ASC` sorts results in PostgreSQL. What does PostgreSQL do when two books have the same year? Is the tie-breaking order guaranteed to be consistent across queries? Why or why not?

9. If 1,000 users simultaneously run `SELECT * FROM books WHERE available = true`, does PostgreSQL need to lock anything? Why or why not? (Hint: think about MVCC.)

10. A Python application runs `UPDATE books SET available = false WHERE year < 1960`. An agent simultaneously runs `SELECT * FROM books WHERE available = true`. What does the agent see during the UPDATE? What does it see after?

---

## Agent/MCP

11. Design a tool specification (name, description, parameters, returns) for an MCP tool called `checkout_book` that marks a book as unavailable and returns its details. Write the SQL it would execute.

12. An agent needs to find books that were checked out more than 30 days ago (assume there is a `last_checkout_date TIMESTAMPTZ` column). Write the SQL. What PostgreSQL function computes date differences?
