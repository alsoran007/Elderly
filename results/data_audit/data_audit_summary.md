# Project3 Phase 1 Data Audit

- Project root: `D:/AI_project/project3`
- Raw root: `D:/AI_project/sql`
- Target records: 140
- Existing target records: 140
- Missing target records: 0
- Metadata reads attempted: 136
- Metadata reads successful: 136
- Metadata read errors: 0
- Candidate schema fields exported: 69146

## Interpretation

This audit is read-only. It does not run the harmonization scripts or modify raw files.
Rows reported as metadata_ok confirm that the file can be opened and its variable metadata can be inspected; they do not yet confirm valid ID linkage, death coding, event counts, or FI/IC availability.
The next gate is to inspect the candidate fields and codebooks, then build cohort-specific outcome and harmonization crosswalks.

## Output files

- `file_inventory.csv`: expected inputs, existence, size, and metadata read status.
- `schema_candidates.csv`: candidate ID, follow-up, mortality, weight, and phenotype fields.
- `harmonization_script_preflight.csv`: script existence and unresolved path placeholders.
- `missing_expected_inputs.csv`: expected files not found during this audit.
