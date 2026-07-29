# CLHLS Codebook Probe

This probe reads CLHLS codebook DOCX files and SPSS metadata only. It does not modify raw data, recode variables, or construct the final outcome.

- Codebook documents found: 8
- Candidate codebook text elements: 11321
- Longitudinal SPSS files found: 8
- Metadata reads successful: 0
- Metadata reads with errors: 0

Candidate text still requires manual codebook confirmation. In particular, distinguish death date, death status, interview date, and birth date fields before outcome construction.

Outputs:
- clhls_codebook_candidates.csv
- clhls_codebook_document_summary.csv
- clhls_longitudinal_metadata_candidates.csv
