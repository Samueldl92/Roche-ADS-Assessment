# Question 5: Clinical Data API (FastAPI)

API over the adverse event data (`data/adae.csv`, exported from `pharmaversesdtm::ae`).

## Run

```bash
python -m venv .venv
.venv/Scripts/activate        # Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
cd question_5_api
uvicorn main:app --reload
```

Interactive docs at http://127.0.0.1:8000/docs. The CSV is loaded once at start-up.

Optional environment variables:

| Variable | Default | Use |
|---|---|---|
| `AE_CSV_PATH` | `../data/adae.csv` (relative to `main.py`) | AE file |
| `DM_CSV_PATH` | `../data/dm.csv` | only read if the AE file has no `ACTARM` |

## Endpoints

```bash
curl http://127.0.0.1:8000/

curl -X POST http://127.0.0.1:8000/ae-query \
  -H "Content-Type: application/json" \
  -d '{"severity": ["MILD", "MODERATE"], "treatment_arm": "Placebo"}'

curl http://127.0.0.1:8000/subject-risk/01-701-1015
```

`POST /ae-query` returns `count` (matching AE records), `unique_subjects` and `usubjids` (sorted, unique).
Filters are combined with AND. A missing or `null` filter is ignored, and so are an empty list and an empty string.
Severity and arm are case-insensitive. An unknown severity value gives 422. An arm that does not exist gives an empty cohort.

`GET /subject-risk/{subject_id}` returns `subject_id`, `risk_score` and `risk_category`
(MILD=1, MODERATE=3, SEVERE=5; Low < 5, Medium 5 to < 15, High >= 15). Unknown subject: 404.

## Notes

* `pharmaversesdtm::ae` has no `ACTARM`. `data/export_adae.R` adds it from `dm` when writing `adae.csv`.
  If a file without `ACTARM` is used, the API tries `DM_CSV_PATH`; if that is also missing, arm filtering returns 400.
* A subject "exists" if it has at least one record in the AE file, so a subject with no AEs gets 404.
* AEs with a missing `AESEV` add 0 points.

## Tests

```bash
cd question_5_api
pytest
```

The tests use a small synthetic CSV and cover no filters, empty filters, invalid severity, unknown subject
and the 4/5 and 14/15 score boundaries.
