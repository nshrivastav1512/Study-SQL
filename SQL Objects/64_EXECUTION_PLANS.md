# SQL Deep Dive: Execution Plans

## 1. Introduction: What are Execution Plans?

An **Execution Plan** (or Query Plan) is the roadmap that the SQL Server Query Optimizer generates to execute a T-SQL query. It details the sequence of physical operations (like scanning tables, seeking indexes, joining data, sorting results) that SQL Server will perform to retrieve the requested data.

**Why are Execution Plans Important?**

*   **Performance Tuning:** They are the **primary tool** for understanding *why* a query is slow and identifying performance bottlenecks. By analyzing the plan, you can see how SQL Server is accessing data and where inefficiencies lie.
*   **Troubleshooting:** Help diagnose issues like missing indexes, inefficient join algorithms, implicit conversions, or inaccurate statistics.
*   **Understanding Query Execution:** Provide insight into the internal workings of the query optimizer and how it chooses to execute your SQL code.

## 2. Types of Execution Plans

1.  **Estimated Execution Plan:**
    *   Generated *without* actually executing the query.
    *   Based on database metadata and statistics available at the time.
    *   Shows the plan the optimizer *intends* to use.
    *   Useful for quick analysis and checking the potential impact of query changes or index additions without running resource-intensive queries.
    *   Viewed in SSMS using `CTRL+L` or the "Display Estimated Execution Plan" button.
2.  **Actual Execution Plan:**
    *   Generated *after* the query has been executed.
    *   Shows the plan that was *actually* used.
    *   Includes runtime statistics like actual number of rows processed by each operator, execution counts, wait times (in newer versions), etc.
    *   Crucial for identifying discrepancies between estimated and actual row counts, which often point to outdated statistics or complex predicates the optimizer struggles with.
    *   Viewed in SSMS by enabling "Include Actual Execution Plan" (`CTRL+M`) before executing the query.

## 3. Reading Execution Plans

*   **Graphical Plans (SSMS):** The most common way to view plans. Read from **right to left**, and **top to bottom** (following the arrows). Data flows from right to left towards the final `SELECT` operator.
*   **Operators:** Each icon represents a physical operation (e.g., Index Seek, Table Scan, Hash Match Join).
*   **Arrows:** Show the flow of data between operators. The thickness often indicates the relative number of rows being passed.
*   **Tooltips/Properties:** Hovering over operators and arrows (or using the Properties window - F4) reveals detailed information:
    *   Operator cost (relative percentage of the total query cost).
    *   Estimated vs. Actual number of rows.
    *   Predicate details (WHERE/JOIN conditions applied).
    *   Output columns.
    *   Index names used.
    *   Warnings (e.g., implicit conversions, missing statistics).

## 4. Common Plan Operators

*   **Data Access Operators:**
    *   **Table Scan:** Reads every row from a table (heap). Often inefficient for large tables unless selecting most/all rows.
    *   **Clustered Index Scan:** Reads every row from a table by scanning the leaf level of the clustered index. Similar implications to Table Scan.
    *   **Index Seek:** Uses a non-clustered index's B-tree structure to efficiently navigate directly to rows matching specific `WHERE` clause predicates (equality or small range). Highly desirable for selective queries.
    *   **Key Lookup (RID Lookup for heaps):** Occurs when a non-clustered index seek retrieves the row locator (clustered key or RID), but then needs to access the base table (clustered index or heap) to retrieve additional columns requested in the `SELECT` list that weren't in the non-clustered index. Can be costly if performed for many rows; often indicates a need for a covering index.
*   **Join Operators:**
    *   **Nested Loops Join:** Iterates through rows from the outer input, and for each outer row, probes the inner input to find matching rows. Efficient when the outer input is small and there's a good index on the join column of the inner input.
    *   **Merge Join:** Requires both inputs to be sorted on the join columns. Reads both sorted inputs concurrently and merges matching rows. Efficient for large, already sorted inputs.
    *   **Hash Match Join:** Builds a hash table in memory from one input (build input, usually the smaller one) and then probes this hash table using rows from the other input (probe input) to find matches. Efficient for large, unsorted inputs but requires memory.
*   **Other Operators:**
    *   **Sort:** Sorts data according to `ORDER BY`, `GROUP BY`, or join requirements. Can be expensive (CPU and memory/tempdb usage) for large datasets.
    *   **Aggregate (Stream/Hash):** Performs aggregate functions (`SUM`, `COUNT`, `AVG`, etc.). Stream Aggregate requires sorted input; Hash Aggregate uses a hash table.
    *   **Compute Scalar:** Calculates a simple expression or function result.
    *   **Filter:** Applies a predicate to filter rows (often seen when a `WHERE` clause couldn't be applied during a scan/seek).
    *   ...and many others.

## 5. Identifying Performance Issues in Plans

*   **High-Cost Operators:** Look for operators consuming a large percentage of the total query cost (shown in SSMS). Focus tuning efforts there.
*   **Scans vs. Seeks:** Table Scans or Clustered Index Scans on large tables for queries retrieving few rows are usually bad. Aim for Index Seeks where possible by creating appropriate indexes or rewriting queries to be SARGable.
*   **Key/RID Lookups:** Frequent lookups (high actual row count) indicate missing covering indexes. Add necessary columns to the `INCLUDE` clause of the non-clustered index being used.
*   **Estimated vs. Actual Rows Discrepancy:** Large differences often point to outdated or missing statistics, or complex predicates the optimizer misinterprets. Update statistics (`UPDATE STATISTICS`) or investigate query/index design.
*   **Warnings:** Yellow triangles with exclamation marks indicate potential issues like implicit type conversions (can prevent index usage), missing join predicates (Cartesian products), missing statistics, etc. Address these warnings.
*   **Expensive Sorts/Hashes:** Indicate large amounts of data being sorted or hashed, potentially spilling to `tempdb`. Check if indexes can provide the required order or if memory grants are sufficient.

## 6. Plan Caching and Reuse

*   SQL Server caches execution plans in memory (the plan cache) to avoid the cost of recompiling the same query repeatedly.
*   **Parameter Sniffing:** When a parameterized query or stored procedure is first compiled, the optimizer generates a plan based on the *specific parameter values* supplied during that initial compilation. This cached plan is then reused for subsequent executions, even with different parameter values. This can be good if the initial values were typical, but bad if they were atypical, leading to a suboptimal plan being reused ("parameter sniffing problem").
*   **Factors Invalidating Cache:** Schema changes on referenced objects, statistics updates, explicit recompilation requests (`sp_recompile`, `WITH RECOMPILE`), certain `SET` option changes, memory pressure.
*   **Monitoring:** `sys.dm_exec_cached_plans` and related DMVs allow inspecting the plan cache.

## 7. Influencing Execution Plans

*   **Query Hints:** (`OPTION (...)`, `WITH (...)`) Provide direct instructions to the optimizer. Use sparingly!
    *   `OPTION (RECOMPILE)`: Force new plan on every execution (solves parameter sniffing but adds CPU overhead).
    *   `OPTION (OPTIMIZE FOR ...)`: Tell optimizer to generate plan based on specific or "unknown" parameter values.
    *   `OPTION (MAXDOP N)`: Limit parallelism.
    *   `INNER MERGE JOIN`, `INNER HASH JOIN`, `INNER LOOP JOIN`: Force a specific join algorithm.
    *   `WITH (INDEX(IndexName))`, `WITH (FORCESEEK)`: Force index usage or seek operation.
*   **Plan Guides:** Attach hints to queries without modifying code, useful for third-party applications or stabilizing plans (`sp_create_plan_guide`).
*   **Query Store Plan Forcing:** (SQL Server 2016+) A modern, preferred method. Query Store captures query history and plans. You can identify poorly performing plans and force SQL Server to use a known good plan for a specific query (`sp_query_store_force_plan`).

## 8. Real-World Scenarios & Best Practices

*   **Scenario 1: Missing Index:** Query is slow, plan shows Clustered Index Scan and a missing index recommendation. Create the suggested index (after validation).
*   **Scenario 2: Parameter Sniffing:** Procedure runs fast sometimes, slow others depending on input. Plan cache shows one plan being reused. Solutions: `OPTION (RECOMPILE)`, `OPTION (OPTIMIZE FOR UNKNOWN)`, local variables, Query Store plan forcing.
*   **Scenario 3: Improving Complex Query:** Analyze plan, identify high-cost operators (e.g., expensive join, sort), add covering indexes, potentially rewrite query or use hints if necessary.
*   **Best Practices:** Regularly review plans for critical queries, focus on high-cost operators and warnings, use Query Store, update statistics, index appropriately, use hints cautiously, document baseline plans.

## 9. Monitoring Tools

*   **SSMS:** Graphical Estimated/Actual Plans.
*   **DMVs:** `sys.dm_exec_query_stats`, `sys.dm_exec_sql_text`, `sys.dm_exec_query_plan`, `sys.dm_exec_cached_plans`.
*   **Query Store:** (SQL Server 2016+) Captures query text, plans, and runtime statistics over time. Excellent for tracking performance regressions and forcing plans.
*   **Extended Events:** Capture detailed event information, including query plan generation, recompiles, warnings, etc.
*   **SQL Trace/Profiler:** (Deprecated, prefer Extended Events).

## 3. Targeted Interview Questions (Based on `64_EXECUTION_PLANS.sql`)

**Question 1:** What is the difference between an Estimated Execution Plan and an Actual Execution Plan? Which one includes runtime statistics like actual row counts?

**Solution 1:**

*   **Estimated Plan:** Generated *before* query execution based on statistics and metadata. Shows the optimizer's intended strategy. Does *not* include runtime statistics.
*   **Actual Plan:** Generated *after* query execution. Shows the plan that was actually used and *includes* runtime statistics like the actual number of rows processed by each operator, execution counts, etc.

**Question 2:** You see a "Key Lookup" operator in an execution plan with a high "Actual Number of Rows". What does this typically indicate, and how might you resolve it?

**Solution 2:**

*   **Indication:** It typically indicates that a non-clustered index seek was used to find the relevant rows, but the `SELECT` list requested columns that were not present in that non-clustered index. SQL Server therefore had to perform an additional lookup (using the row locator from the index, which is the clustered key or RID) back to the base table (clustered index or heap) to retrieve these extra columns for each row identified by the seek.
*   **Resolution:** The most common resolution is to create or modify the non-clustered index to make it a **covering index**. This involves adding the missing columns (that were causing the lookup) to the `INCLUDE` clause of the non-clustered index definition. This allows the query to retrieve all required columns directly from the non-clustered index, eliminating the costly key lookup.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** In SSMS graphical plans, which direction do you typically read the plan flow?
    *   **Answer:** Right to left, top to bottom.
2.  **[Easy]** Which is generally more efficient for retrieving a small number of rows from a large table: an Index Seek or a Table Scan?
    *   **Answer:** Index Seek.
3.  **[Medium]** What does a high cost percentage for a `SORT` operator often indicate?
    *   **Answer:** It indicates that sorting a large number of rows is consuming a significant portion of the query's resources (CPU, potentially memory and `tempdb` I/O if it spills). This might suggest a need for an index that can provide the data in the required order, avoiding the explicit sort.
4.  **[Medium]** What is "parameter sniffing"? Is it always bad?
    *   **Answer:** Parameter sniffing is the behavior where SQL Server creates and caches an execution plan for a stored procedure or parameterized query based on the *specific parameter values* used during the *first* compilation. This plan is then reused for subsequent executions, even with different parameter values. It's *not always bad* – if the first parameter values are typical, the cached plan is often efficient. It becomes a *problem* when the initial parameter values are atypical, resulting in a cached plan that is inefficient for subsequent, more common parameter values.
5.  **[Medium]** What does a warning symbol (yellow triangle) on an operator in an execution plan signify? Give an example.
    *   **Answer:** It signifies a potential issue or inefficiency detected by the optimizer during query execution. Examples include: Implicit type conversions (e.g., comparing an `NVARCHAR` column to a `VARCHAR` literal, potentially preventing index usage), missing statistics, join predicates missing (leading to Cartesian products), or memory/tempdb spills during sort or hash operations.
6.  **[Medium]** What is the purpose of the Query Store feature introduced in SQL Server 2016?
    *   **Answer:** Query Store automatically captures a history of queries, execution plans, and runtime statistics within a database. It allows DBAs to easily track query performance over time, identify performance regressions caused by plan changes, analyze different plans for the same query, and **force** the use of a specific, known-good execution plan for a query.
7.  **[Hard]** What are the three main types of physical join operators SQL Server can use, and under what general conditions might each be chosen?
    *   **Answer:**
        1.  **Nested Loops:** Efficient when one input (outer) is small, and there is an efficient index seek available on the join column of the other (inner) input. Iterates through the outer input, seeking matches in the inner input for each outer row.
        2.  **Merge Join:** Efficient when both inputs are large and already sorted on the join columns (or can be sorted efficiently). Reads both inputs concurrently and merges matching rows.
        3.  **Hash Match:** Efficient for large, unsorted inputs, especially when indexes aren't helpful for the join predicate. Builds a hash table in memory from the smaller (build) input and probes it with rows from the larger (probe) input to find matches. Requires sufficient memory.
8.  **[Hard]** What is the difference between logical operators (in the query text, like `INNER JOIN`) and physical operators (in the execution plan, like `Hash Match Join`)?
    *   **Answer:** Logical operators define the *what* – the requested operation or result based on relational algebra (e.g., join these two tables based on this condition). Physical operators define the *how* – the specific algorithm or implementation method chosen by the query optimizer to physically execute that logical operation (e.g., use a Hash Match algorithm to perform the join). A single logical operation (like `INNER JOIN`) can be implemented using different physical operators (`Nested Loops`, `Merge`, `Hash Match`) depending on data size, statistics, and indexes.
9.  **[Hard]** If an Actual Execution Plan shows "Estimated Number of Rows" = 1 and "Actual Number of Rows" = 1,000,000 for a specific operator, what is the most likely underlying cause?
    *   **Answer:** The most likely cause is **outdated or missing statistics** on the tables/columns involved in the predicate being evaluated by that operator. The query optimizer relies heavily on statistics to estimate row counts. A massive discrepancy like this indicates the statistics do not accurately reflect the actual data distribution, leading the optimizer to make poor cardinality estimates and potentially choose a very inefficient execution plan (e.g., choosing a Nested Loops join when a Hash Match would be far better for a million rows). Updating statistics is the first step to investigate.
10. **[Hard/Tricky]** Can forcing a specific execution plan using Query Store or a Plan Guide sometimes lead to performance *degradation* in the future? Why?
    *   **Answer:** Yes. Forcing a plan locks the query into using that specific strategy. While that plan might be optimal *now*, it prevents the query optimizer from adapting to future changes, such as:
        *   **Data Volume/Distribution Changes:** The forced plan might become inefficient as the table size or data skew changes significantly over time.
        *   **Statistics Updates:** The optimizer cannot use updated statistics to potentially find a better plan.
        *   **Index Changes:** The forced plan might not leverage new, beneficial indexes that are created later, or it might try to use an index that gets dropped.
        *   **SQL Server Upgrades:** The forced plan prevents the query from potentially benefiting from new optimizer improvements or features introduced in later SQL Server versions or compatibility levels.
    *   Plan forcing should be used cautiously as a targeted solution for specific problematic queries, and forced plans should be periodically reviewed.
