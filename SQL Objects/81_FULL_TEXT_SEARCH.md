# SQL Deep Dive: Full-Text Search

## 1. Introduction: What is Full-Text Search?

**Full-Text Search** in SQL Server provides advanced capabilities for searching text data stored in character-based columns (`VARCHAR`, `NVARCHAR`, `TEXT`, `NTEXT`), `VARBINARY(MAX)` (for documents stored directly), or `FILESTREAM` data. Unlike standard `LIKE` predicates which perform simple pattern matching, Full-Text Search uses linguistic analysis (word breakers, stemmers, thesaurus) to perform more sophisticated searches based on words and phrases.

**Why use Full-Text Search?**

*   **Linguistic Searching:** Finds variations of words (e.g., searching for "run" finds "running", "ran").
*   **Relevance Ranking:** Ranks search results based on how well they match the search criteria.
*   **Proximity Search:** Finds words or phrases that are near each other.
*   **Thesaurus Support:** Expands searches to include synonyms.
*   **Performance:** Generally much faster than `LIKE '%keyword%'` for searching large amounts of text data, as it uses specialized inverted indexes (Full-Text Indexes).
*   **Semantic Search (Advanced):** (SQL 2012+) Allows searching based on meaning, finding key phrases, and identifying similar documents.

**Key Components:**

1.  **Full-Text Catalog:** A logical container for one or more Full-Text Indexes within a database.
2.  **Full-Text Index:** A special type of index built on text columns. It stores information about significant words and their locations. Requires a unique, single-column index (usually the primary key) on the base table.
3.  **Word Breakers & Stemmers:** Language-specific components that parse text into individual words (tokens) and reduce words to their root form (stemming).
4.  **Stoplists:** Lists of common, non-significant words (like "a", "the", "is") that are ignored during indexing and searching.
5.  **Thesaurus:** XML files defining synonyms for specific languages.

**Predicates/Functions:**

*   `CONTAINS()`: Checks if columns contain specific words or phrases, proximity terms, inflectional forms, etc. Returns TRUE/FALSE. Used in `WHERE` clause.
*   `FREETEXT()`: Searches for words matching the *meaning*, not just exact wording, of the search string. Uses stemming and thesaurus implicitly. Returns TRUE/FALSE. Used in `WHERE` clause.
*   `CONTAINSTABLE()`: Similar to `CONTAINS` but returns a table with a `KEY` (matching row's unique key) and `RANK` (relevance score). Used in `FROM` clause like a table, typically joined back to the base table.
*   `FREETEXTTABLE()`: Similar to `FREETEXT` but returns a table with `KEY` and `RANK`. Used in `FROM` clause.

## 2. Full-Text Search in Action: Analysis of `81_FULL_TEXT_SEARCH.sql`

This script demonstrates setting up and using Full-Text Search for HR resumes.

**Part 1: Setting Up Full-Text Search**

*   **1. Create Full-Text Catalog:**
    ```sql
    CREATE FULLTEXT CATALOG HRDocumentsCatalog WITH ACCENT_SENSITIVITY = ON AS DEFAULT;
    ```
    *   **Explanation:** Creates a catalog to hold the index(es). `ACCENT_SENSITIVITY` controls whether accents are considered during search. `AS DEFAULT` makes it the default catalog for the database.
*   **2. Create Table:** Defines the `HR.EmployeeResumes` table with `NVARCHAR(MAX)` columns to store text content.
*   **3. Create Full-Text Index:**
    ```sql
    CREATE FULLTEXT INDEX ON HR.EmployeeResumes
    ( ResumeContent, SkillsSummary, Education, WorkExperience ) -- Columns to index
    KEY INDEX PK__Employee__EE2E4F7A9F8D4A57 -- Unique index on the table (replace with actual PK name)
    ON HRDocumentsCatalog -- Specify the catalog
    WITH CHANGE_TRACKING AUTO; -- Automatically update index as data changes
    ```
    *   **Explanation:** Creates the index on specified columns. Requires specifying the table's unique key index (`KEY INDEX`). Associates the index with a catalog. `CHANGE_TRACKING AUTO` (default) means SQL Server automatically updates the index as data changes in the base table. Other options include `MANUAL` or `OFF`.

**Part 2: Basic Full-Text Search**

*   **1. Simple `CONTAINS` Search:**
    ```sql
    -- Inside HR.SearchResumes procedure:
    WHERE CONTAINS(er.ResumeContent, @SearchTerm) OR CONTAINS(er.SkillsSummary, @SearchTerm);
    ```
    *   **Explanation:** Uses `CONTAINS` in the `WHERE` clause to find rows where either `ResumeContent` or `SkillsSummary` contains the specified `@SearchTerm`. `CONTAINS` supports various search conditions (simple terms, prefixes, boolean operators like `AND`, `OR`, `NEAR`).
*   **2. `CONTAINSTABLE` for Ranking:**
    ```sql
    -- Inside HR.SearchResumesRanked procedure:
    INNER JOIN CONTAINSTABLE(HR.EmployeeResumes, (ResumeContent, SkillsSummary), @SearchTerm) AS KEY_TBL
    ON er.ResumeID = KEY_TBL.[KEY]
    ORDER BY KEY_TBL.RANK DESC;
    ```
    *   **Explanation:** Uses `CONTAINSTABLE` in the `FROM` clause. It searches specified columns for the term and returns a table containing the `KEY` of the matching rows from `HR.EmployeeResumes` and a `RANK` score indicating relevance. The result is joined back to the base table using the `KEY`. Results are ordered by relevance.

**Part 3: Advanced Search Techniques**

*   **1. Proximity Search (`NEAR`)**:
    ```sql
    -- Inside HR.SearchResumesByProximity procedure:
    WHERE CONTAINS(er.ResumeContent, 'NEAR(("' + @Term1 + '", "' + @Term2 + '"), ' + CAST(@MaxDistance AS VARCHAR(10)) + ')');
    ```
    *   **Explanation:** Uses the `NEAR` keyword within `CONTAINS` to find rows where `@Term1` occurs within a specified maximum distance (`@MaxDistance`) of `@Term2`. Useful for finding related concepts.
*   **2. Thesaurus-Based Search:**
    ```sql
    -- Inside HR.SearchResumesBySkillCategory procedure:
    INNER JOIN CONTAINSTABLE(HR.EmployeeResumes, SkillsSummary, @SkillCategory, LANGUAGE 1033) AS KEY_TBL ...
    ```
    *   **Explanation:** By specifying a `LANGUAGE` (e.g., 1033 for US English), `CONTAINSTABLE` (and `CONTAINS`/`FREETEXT`) can utilize the corresponding thesaurus file (if configured) to expand the search term (`@SkillCategory`) to include its synonyms.

**Part 4: Semantic Search (SQL 2012+)**

*   **Requires:** Installation of Semantic Language Statistics database during SQL Server setup and registration for the specific database (`ALTER DATABASE ... SET SEMANTIC_STATISTICS = ON`). Full-Text Index must also be created.
*   **1. Find Similar Documents (`SEMANTICSIMILARITYTABLE`)**:
    ```sql
    -- Inside HR.FindSimilarResumes procedure:
    INNER JOIN SEMANTICSIMILARITYTABLE(HR.EmployeeResumes, ResumeContent, (SELECT ResumeContent ... WHERE ResumeID = @ResumeID)) AS KEY_TBL ...
    ```
    *   **Explanation:** Returns a table ranking documents based on semantic similarity (similarity in meaning/topic) to a source document. Compares the statistical significance of key phrases between documents.
*   **2. Extract Key Phrases (`SEMANTICKEYPHRASETABLE`)**:
    ```sql
    -- Inside HR.ExtractKeyPhrases procedure:
    CROSS APPLY SEMANTICKEYPHRASETABLE(HR.EmployeeResumes, ResumeContent, er.ResumeID) AS KEY_TBL ...
    ```
    *   **Explanation:** Returns a table containing the key phrases found within the specified document(s) along with a relevance score for each phrase.

**Part 5: Maintenance and Optimization**

*   **1. Rebuilding Index (`ALTER FULLTEXT INDEX ... START FULL POPULATION`):** Forces a complete rebuild of the full-text index. Necessary if change tracking is manual or off, or sometimes to resolve issues.
*   **2. Monitoring:** Shows querying system views (`sys.fulltext_indexes`, `sys.fulltext_catalogs`) to check the status, configuration, and population progress of full-text indexes.

**Part 6: Sample Data and Testing**

*   Provides sample `INSERT` and `EXEC` statements to test the created procedures.

## 3. Targeted Interview Questions (Based on `81_FULL_TEXT_SEARCH.sql`)

**Question 1:** What is the main difference between using `CONTAINS` and `LIKE '%keyword%'` for searching text columns? Why is `CONTAINS` generally preferred for searching words or phrases in large text columns?

**Solution 1:**

*   **`LIKE '%keyword%'`:** Performs simple string pattern matching. It scans the entire column value for every row to see if the pattern exists anywhere. It cannot use standard indexes effectively (especially with a leading wildcard `%`) and doesn't understand word boundaries, stemming, or relevance.
*   **`CONTAINS(Column, 'keyword')`:** Uses the specialized **Full-Text Index**. It searches for the specific word (or variations, depending on options) using the pre-built index, which is much faster than scanning the table for large text columns. It understands word boundaries, noise words (stoplist), and can perform linguistic searches (stemming, thesaurus).
*   **Preference:** `CONTAINS` (or `FREETEXT`) is generally preferred for searching words/phrases in large text columns due to significantly better **performance** (using the index) and more **flexible/intelligent search capabilities** (linguistic analysis, ranking).

**Question 2:** What is the difference between `CONTAINS` and `CONTAINSTABLE`?

**Solution 2:**

*   **`CONTAINS`:** Is a **predicate** used in the `WHERE` clause. It returns `TRUE` or `FALSE` indicating whether the search condition is met for a given row. It does not provide relevance ranking.
*   **`CONTAINSTABLE`:** Is a **table-valued function** used in the `FROM` clause. It returns a table containing the unique key (`KEY`) of the rows matching the search criteria and a relevance score (`RANK`) for each match. It needs to be joined back to the base table using the `KEY` column to retrieve other data. It's used when you need relevance ranking or want to process the matches as a set.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What must be created before you can create a Full-Text Index on a table?
    *   **Answer:** A **Full-Text Catalog** must exist in the database, and the table must have a **unique, single-column, non-nullable index** (usually the primary key).
2.  **[Easy]** What is the purpose of a Stoplist in Full-Text Search?
    *   **Answer:** A Stoplist contains common, non-significant words (like "a", "the", "is", "in") that are ignored during both indexing and querying to save space and improve search relevance by focusing on meaningful terms.
3.  **[Medium]** Can you create a Full-Text Index on multiple columns?
    *   **Answer:** Yes. You can specify multiple character-based columns within the `CREATE FULLTEXT INDEX ON TableName (...)` statement. Queries using `CONTAINS` or `CONTAINSTABLE` can then search across all indexed columns or specify which column(s) to target.
4.  **[Medium]** What does `CHANGE_TRACKING AUTO` mean when creating a Full-Text Index?
    *   **Answer:** It means SQL Server will automatically track changes (inserts, updates, deletes) made to the base table and update the Full-Text Index accordingly in the background. This keeps the index relatively up-to-date without manual intervention. Alternatives are `MANUAL` or `OFF`.
5.  **[Medium]** How does `FREETEXT` differ from `CONTAINS`?
    *   **Answer:** `FREETEXT` performs a more "natural language" search based on the *meaning* of the search terms. It implicitly breaks the search string into words, performs stemming (finding variations like run/running/ran), and uses the thesaurus (if configured) to find synonyms. `CONTAINS` is more literal and requires explicit syntax for boolean logic (`AND`, `OR`, `NEAR`), prefix searching (`"word*"`), inflectional forms (`FORMSOF(INFLECTIONAL, ...)`) or thesaurus (`FORMSOF(THESAURUS, ...)`). `FREETEXT` is simpler for basic meaning-based searches, while `CONTAINS` offers more precise control.
6.  **[Medium]** Can you Full-Text index data stored in `VARBINARY(MAX)` or `IMAGE` columns? If so, how?
    *   **Answer:** Yes, but it requires additional configuration. SQL Server needs to know the document *type* (e.g., `.docx`, `.pdf`, `.xlsx`) to use the correct **IFilter** component to extract the text content. You typically store the document type in a separate column (e.g., `FileType VARCHAR(10)`) and specify this column in the `CREATE FULLTEXT INDEX` statement using the `TYPE COLUMN` clause. Appropriate IFilters must be installed and registered with SQL Server.
7.  **[Hard]** What is the difference between a Full Population, Incremental Population, and Change Tracking population for a Full-Text Index?
    *   **Answer:**
        *   **Full Population:** Rebuilds the entire index from scratch by scanning all rows in the base table. Used initially or when `CHANGE_TRACKING` is `MANUAL` and a full update is requested (`START FULL POPULATION`).
        *   **Incremental Population:** (Requires a `timestamp` column in the base table) Updates the index only for rows whose `timestamp` value has changed since the last population. Less resource-intensive than a full population for tables where changes can be tracked via timestamp. Triggered by `START INCREMENTAL POPULATION`.
        *   **Change Tracking Population:** (`AUTO` or `MANUAL` with `START UPDATE POPULATION`) Uses internal tracking tables (populated by triggers or internal mechanisms) to identify rows that have been inserted, updated, or deleted since the last index update and processes only those changes. `AUTO` does this automatically in the background; `MANUAL` requires explicit initiation.
8.  **[Hard]** How does Semantic Search differ from standard Full-Text Search? What additional setup is required?
    *   **Answer:** Semantic Search goes beyond keyword matching to understand the *meaning* and *context* of the text. It allows searching for **semantically similar documents** (based on statistically significant key phrases) and **extracting key phrases** from documents. Standard Full-Text Search focuses on matching words, phrases, and their linguistic variations. Semantic Search requires installing the **Semantic Language Statistics Database** during SQL Server setup and enabling semantic indexing on specific columns within the Full-Text Index definition.
9.  **[Hard]** Can you combine a Full-Text predicate (like `CONTAINS`) with a standard relational predicate (like `WHERE DepartmentID = 1`) in the same `WHERE` clause? How might this affect performance?
    *   **Answer:** Yes, you can combine them using `AND` or `OR`. For example: `WHERE CONTAINS(ResumeContent, 'SQL') AND DepartmentID = 1`. Performance depends on selectivity. The optimizer might apply the most selective predicate first. If the Full-Text predicate is highly selective, it can quickly narrow down rows before the relational predicate is checked. If the relational predicate uses an efficient index seek and is highly selective, it might be applied first. The optimizer estimates the costs of different approaches. Combining them can be very effective if both predicates help reduce the result set significantly.
10. **[Hard/Tricky]** If you search using `CONTAINSTABLE` and get a `RANK` value, what does this rank represent, and is it comparable across different queries or servers?
    *   **Answer:** The `RANK` value represents a **relative relevance score** (typically between 0 and 1000) indicating how well a particular document matches the search criteria *within the context of that specific query*. It's calculated based on factors like the frequency of search terms, proximity, etc., using internal algorithms (like Okapi BM25). The rank values are **not absolute** and are **not directly comparable** across different queries (searching for different terms) or different servers/indexes, as the calculation depends on the specific terms, the overall document corpus statistics, and index properties. It's primarily useful for *ordering* the results of a single query from most relevant to least relevant.
