# SQL Deep Dive: Full-Text Indexes and Search

## 1. Introduction: What is Full-Text Search?

Standard SQL `LIKE` clauses with wildcards (`%`, `_`) are often inefficient and limited when searching for words or phrases within large blocks of text (e.g., `VARCHAR(MAX)`, `NVARCHAR(MAX)`, `XML`, `VARBINARY(MAX)` storing documents). **Full-Text Search** is a specialized feature in SQL Server designed for fast and flexible linguistic searches on this type of data.

It works by creating **Full-Text Indexes** that store significant words (tokens) and their locations within the indexed columns. Queries then use special predicates (`CONTAINS`, `FREETEXT`) and functions (`CONTAINSTABLE`, `FREETEXTTABLE`) to efficiently search these indexes based on linguistic rules, rather than simple pattern matching.

**Why use Full-Text Search?**

*   **Performance:** Significantly faster than `LIKE` for searching words/phrases in large text columns because it uses an index optimized for this purpose.
*   **Linguistic Capabilities:** Understands word boundaries, ignores noise words (stopwords like "a", "the"), handles inflectional forms (searching for "run" can find "ran", "running"), supports synonyms (via thesaurus), and allows complex boolean logic (`AND`, `OR`, `NOT`) and proximity searches (`NEAR`).
*   **Relevance Ranking:** Can rank results based on how well they match the search criteria.

**Key Components:**

1.  **Full-Text Catalog:** A logical container for one or more full-text indexes. Often set as default or specified during index creation.
2.  **Full-Text Index:** Created on a specific table. It requires a unique, single-column, non-nullable index (usually the primary key) on the table (`KEY INDEX`). It specifies which text-based columns to index and the language to use for word breaking and stemming.
3.  **Word Breakers & Stemmers:** Language-specific components used during indexing and querying to identify word boundaries and reduce words to their base form.
4.  **Stoplist:** A list of common words (stopwords) to be ignored during indexing and searching.
5.  **Thesaurus:** An XML file defining synonyms for specific terms, allowing searches for one term to find matches for its synonyms.

**Key Predicates/Functions:**

*   `CONTAINS()`: Used in `WHERE` clause for precise searches involving boolean logic, proximity, wildcards, inflectional forms, etc.
*   `FREETEXT()`: Used in `WHERE` clause for natural language searches; breaks down the search string into meaningful words and finds matches based on meaning (less precise than `CONTAINS`).
*   `CONTAINSTABLE()`: Table-valued function used in `FROM` clause; returns a table with the key of matching rows and a relevance rank for `CONTAINS`-style searches.
*   `FREETEXTTABLE()`: Table-valued function used in `FROM` clause; returns key and rank for `FREETEXT`-style searches.

## 2. Full-Text Search in Action: Analysis of `54_FULL_TEXT_INDEXES.sql`

This script demonstrates the setup and usage of Full-Text Search.

**a) Creating Full-Text Catalogs (`CREATE FULLTEXT CATALOG`)**

```sql
CREATE FULLTEXT CATALOG DocumentCatalog WITH ACCENT_SENSITIVITY = OFF AS DEFAULT;
CREATE FULLTEXT CATALOG ResumeCatalog WITH ACCENT_SENSITIVITY = ON;
```

*   **Explanation:** Creates logical containers for full-text indexes. `WITH ACCENT_SENSITIVITY` controls whether accents are considered during searches (e.g., 'resume' vs 'résumé'). `AS DEFAULT` makes it the default catalog if none is specified during index creation.

**b) Creating Tables for Full-Text Search**

*   **Explanation:** Defines tables (`EmployeeDocuments`, `EmployeeResumes`) with `NVARCHAR(MAX)` columns suitable for storing text content that will be indexed.

**c) Creating Full-Text Indexes (`CREATE FULLTEXT INDEX`)**

```sql
-- Requires a unique index on the table first
CREATE UNIQUE INDEX UI_EmployeeDocuments_DocumentID ON HR.EmployeeDocuments(DocumentID);
GO
-- Create the full-text index
CREATE FULLTEXT INDEX ON HR.EmployeeDocuments
(
    DocumentTitle LANGUAGE 1033, -- Specify language for word breaking/stemming
    DocumentContent LANGUAGE 1033,
    DocumentSummary LANGUAGE 1033
)
KEY INDEX UI_EmployeeDocuments_DocumentID -- Specify the unique key index
ON DocumentCatalog -- Specify the catalog (or use default)
WITH CHANGE_TRACKING AUTO; -- How index is updated (AUTO, MANUAL, OFF)
GO
```

*   **Explanation:** Creates the index on the specified table (`HR.EmployeeDocuments`).
    *   Lists the columns to be indexed (`DocumentTitle`, `DocumentContent`, etc.).
    *   `LANGUAGE 1033`: Specifies the language (LCID for US English) used for word breaking and stemming for each column.
    *   `KEY INDEX`: Specifies the **unique index** on the table used to identify rows.
    *   `ON CatalogName`: Assigns the index to a specific catalog.
    *   `WITH CHANGE_TRACKING`: Determines how the index is kept up-to-date as data changes (`AUTO` is common, `MANUAL` requires explicit updates, `OFF` disables updates).

**d) Inserting Sample Data**

*   **Explanation:** Populates the tables with text data that can be searched. The full-text index population happens asynchronously in the background (for `CHANGE_TRACKING AUTO` or `MANUAL` after population is started).

**e) Basic Full-Text Queries (`CONTAINS`, `FREETEXT`)**

```sql
-- Precise search for a word
SELECT ... FROM HR.EmployeeDocuments WHERE CONTAINS(DocumentContent, 'project');
-- Natural language search for meaning
SELECT ... FROM HR.EmployeeDocuments WHERE FREETEXT(DocumentContent, 'technical skills improvement');
```

*   **Explanation:** Demonstrates the two main predicates used in the `WHERE` clause. `CONTAINS` offers precise control, while `FREETEXT` is more forgiving and searches based on the meaning of the search phrase.

**f) Advanced `CONTAINS` Techniques**

```sql
-- Boolean logic
WHERE CONTAINS(Skills, 'SQL AND (Python OR R)');
-- Proximity search (words within 10 words of each other)
WHERE CONTAINS(DocumentContent, 'NEAR((performance, improvement), 10)');
-- Prefix wildcard search
WHERE CONTAINS(ResumeContent, '"data*"'); -- Note: Wildcard only at the end
```

*   **Explanation:** Shows the power of `CONTAINS` for combining terms (`AND`, `OR`, `NOT`), finding words near each other (`NEAR`), and performing prefix searches (`"term*"`).

**g) Searching Multiple Columns**

```sql
WHERE CONTAINS((ResumeContent, Skills, Experience), 'SQL Server');
```

*   **Explanation:** Allows searching for terms across multiple full-text indexed columns simultaneously by listing them in parentheses.

**h) Ranking Search Results (`CONTAINSTABLE`, `FREETEXTTABLE`)**

```sql
SELECT d.DocumentID, ..., ft.RANK
FROM HR.EmployeeDocuments d
INNER JOIN CONTAINSTABLE(HR.EmployeeDocuments, DocumentContent, 'project AND management') AS ft
    ON d.DocumentID = ft.[KEY] -- Join on the table's unique key
ORDER BY ft.RANK DESC; -- Order by relevance rank
```

*   **Explanation:** Uses the table-valued functions `CONTAINSTABLE` (for `CONTAINS`-style searches) or `FREETEXTTABLE` (for `FREETEXT`-style searches). These functions return a table containing the unique key (`KEY`) of the matching rows and a relevance score (`RANK`) indicating how well each row matches the search criteria. Joining this back to the original table allows retrieving full rows ordered by relevance.

**i) Altering Full-Text Indexes (`ALTER FULLTEXT INDEX`)**

```sql
ALTER FULLTEXT INDEX ON HR.EmployeeDocuments ADD (DocumentType LANGUAGE 1033);
ALTER FULLTEXT INDEX ON HR.EmployeeDocuments DROP (DocumentSummary);
ALTER FULLTEXT INDEX ON HR.EmployeeResumes SET CATALOG DocumentCatalog;
ALTER FULLTEXT INDEX ON HR.EmployeeDocuments SET CHANGE_TRACKING MANUAL;
```

*   **Explanation:** Allows adding or dropping columns from the index, changing the associated catalog, or modifying the change tracking mechanism.

**j) Managing Population (`ALTER FULLTEXT INDEX ... START/STOP POPULATION`)**

```sql
ALTER FULLTEXT INDEX ON HR.EmployeeDocuments START FULL POPULATION;
ALTER FULLTEXT INDEX ON HR.EmployeeResumes START INCREMENTAL POPULATION;
ALTER FULLTEXT INDEX ON HR.EmployeeDocuments STOP POPULATION;
ALTER FULLTEXT CATALOG DocumentCatalog REBUILD; -- Rebuild entire catalog
```

*   **Explanation:** Commands to manually control the population (indexing) process. `FULL` re-indexes everything. `INCREMENTAL` (requires timestamp column) indexes only changes since the last population. `REBUILD` completely rebuilds all indexes within a catalog.

**k) Dropping Full-Text Objects (`DROP FULLTEXT INDEX`, `DROP FULLTEXT CATALOG`)**

```sql
DROP FULLTEXT INDEX ON HR.EmployeeDocuments;
DROP FULLTEXT CATALOG ResumeCatalog;
```

*   **Explanation:** Removes the full-text index or catalog. Dropping a catalog requires dropping all indexes within it first.

**l) Querying Full-Text Metadata (System Views)**

```sql
SELECT name, is_default, ... FROM sys.fulltext_catalogs;
SELECT OBJECT_NAME(object_id), change_tracking_state_desc, ... FROM sys.fulltext_indexes;
SELECT COL_NAME(...), language_id, ... FROM sys.fulltext_index_columns;
```

*   **Explanation:** Uses system views like `sys.fulltext_catalogs`, `sys.fulltext_indexes`, and `sys.fulltext_index_columns` to retrieve metadata about existing full-text objects and their configurations.

**m) Thesaurus (Conceptual)**

*   **Explanation:** Describes how thesaurus files (XML) can be configured per language to define synonym expansions (e.g., searching for 'database' also finds 'DB'). Requires file system setup and loading using `sp_fulltext_load_thesaurus_file`.

**n) Stopwords/Stoplist (`CREATE/ALTER FULLTEXT STOPLIST`)**

```sql
CREATE FULLTEXT STOPLIST CustomStoplist;
ALTER FULLTEXT STOPLIST CustomStoplist ADD 'the' LANGUAGE 1033;
-- Apply to index: CREATE FULLTEXT INDEX ... WITH STOPLIST = CustomStoplist;
```

*   **Explanation:** Stopwords are common words ignored during indexing. You can use the system stoplist or create custom stoplists and associate them with a full-text index using the `WITH STOPLIST = ...` clause.

## 3. Targeted Interview Questions (Based on `54_FULL_TEXT_INDEXES.sql`)

**Question 1:** What is the main difference between searching text using `LIKE '%word%'` and using `CONTAINS(Column, 'word')`?

**Solution 1:** `LIKE '%word%'` performs a simple substring search, finding the exact sequence of characters 'word' anywhere. It's often slow on large text columns and doesn't understand language rules. `CONTAINS(Column, 'word')` uses a Full-Text Index to perform a linguistic search, finding the actual *word* 'word', potentially matching variations (like plurals or different verb tenses if stemming is used), ignoring noise words, and performing much faster due to the index.

**Question 2:** What two components must generally be created *before* you can create a `FULLTEXT INDEX` on a table?

**Solution 2:**
1.  A **Full-Text Catalog:** A container for the index (unless using the default catalog). (`CREATE FULLTEXT CATALOG ...`)
2.  A **Unique, Single-Column, Non-Nullable Index:** Usually the table's primary key, specified in the `KEY INDEX` clause of the `CREATE FULLTEXT INDEX` statement. This index is used by the full-text engine to map index entries back to specific table rows.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which predicate is better for natural language or "meaning-based" searches: `CONTAINS` or `FREETEXT`?
    *   **Answer:** `FREETEXT`.
2.  **[Easy]** What does the `LANGUAGE` clause specify when creating a full-text index on a column?
    *   **Answer:** It specifies the language whose rules (word breakers, stemmers, stopwords, thesaurus) should be used for indexing and querying that column.
3.  **[Medium]** What is the purpose of the `KEY INDEX` clause in `CREATE FULLTEXT INDEX`?
    *   **Answer:** It specifies the name of the unique, single-column, non-nullable index on the base table that the Full-Text engine will use to uniquely identify each row being indexed. This is typically the table's primary key index.
4.  **[Medium]** What is the difference between `CONTAINS(Column, 'database')` and `CONTAINS(Column, '"database*"')`?
    *   **Answer:** `CONTAINS(Column, 'database')` searches for the exact word "database" (and potentially its inflectional forms like "databases"). `CONTAINS(Column, '"database*"')` performs a **prefix search**, finding words that *start with* "database" (like "database", "databases", "databasing"). The asterisk `*` acts as a wildcard only at the end of a term within double quotes.
5.  **[Medium]** What do the `CONTAINSTABLE` and `FREETEXTTABLE` functions return? How are they typically used?
    *   **Answer:** They are table-valued functions that return a table containing two main columns: `KEY` (the unique key value from the base table's `KEY INDEX` for matching rows) and `RANK` (a relevance score from 0 to 1000). They are typically used in the `FROM` clause and joined back to the base table using the `KEY` column to retrieve the full matching rows, often ordered by `RANK`.
6.  **[Medium]** What does `CHANGE_TRACKING AUTO` mean for a full-text index?
    *   **Answer:** It means SQL Server automatically tracks changes (inserts, updates, deletes) to the base table and updates the full-text index accordingly in the background without requiring manual intervention to start population.
7.  **[Hard]** Can you create a full-text index on a view?
    *   **Answer:** No, you can only create a full-text index directly on a base table. To search data exposed through a view using full-text search, you would need to create the full-text index on the underlying base table(s) and then potentially query the base table(s) directly using full-text predicates, or create an indexed view (if possible) and full-text index that.
8.  **[Hard]** How does accent sensitivity (`WITH ACCENT_SENSITIVITY = ON/OFF`) in a Full-Text Catalog affect searches?
    *   **Answer:** `ACCENT_SENSITIVITY = OFF` (default for many languages like English) treats characters with and without accents as the same for searching (e.g., searching for 'resume' finds 'résumé' and vice-versa). `ACCENT_SENSITIVITY = ON` treats characters with different accents as distinct (e.g., searching for 'resume' would *not* find 'résumé').
9.  **[Hard]** Can `CONTAINS` be used to search for words that are very close together but not necessarily adjacent, potentially in a different order?
    *   **Answer:** Yes, using the `NEAR` operator within `CONTAINS`. You can specify a maximum distance or use the default. For example, `CONTAINS(Column, 'NEAR((word1, word2), 5)')` finds rows where `word1` is within 5 words of `word2`, regardless of order. `CONTAINS(Column, 'NEAR((word1, word2), 10, TRUE)')` requires them to be in the specified order.
10. **[Hard/Tricky]** If you full-text index a `VARBINARY(MAX)` column, what additional information does SQL Server need to know to index it correctly? How is this provided?
    *   **Answer:** SQL Server needs to know the **document type** of the binary data (e.g., '.docx', '.pdf', '.xlsx') to use the appropriate filter (IFilter) to extract the text content. This is typically provided via a **type column** specified during `CREATE FULLTEXT INDEX`. The syntax looks like: `CREATE FULLTEXT INDEX ON MyTable (BinaryColumn TYPE COLUMN FileTypeColumn LANGUAGE ... ) ...`. The `FileTypeColumn` contains the file extension (e.g., '.docx') for each row, telling the full-text engine which IFilter to load for text extraction from the `BinaryColumn`. The necessary IFilters must also be installed on the server.
