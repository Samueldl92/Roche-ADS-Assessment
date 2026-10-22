# Question 6: Clinical data assistant (LangChain)

`ClinicalTrialDataAgent` takes a free-text question about the AE data, asks an LLM which column and value it
refers to, and runs the corresponding pandas filter. It returns the unique `USUBJID`s.

```
question -> prompt (schema + question) -> LLM -> {target_column, filter_value} -> pandas filter -> subjects
```

## Install and run

```bash
python -m venv .venv
.venv/Scripts/activate        # Linux/macOS: source .venv/bin/activate
pip install -r question_6_genai/requirements.txt
cd question_6_genai
python clinical_agent.py      # runs the 3 example queries
pytest
```

Uses `../data/adae.csv` unless `AE_CSV_PATH` is set.

## Backends

Chosen from environment variables (keys are never read or stored by this code, LangChain picks them up):

| Setting | Backend |
|---|---|
| `OPENAI_API_KEY` set | OpenAI (`langchain-openai`, default `gpt-4o-mini`) |
| no key | mock (below) |

`LLM_PROVIDER=openai|mock` forces a choice and `LLM_MODEL` sets the model name.

**Mock mode (no key, for tests and demos).** The chain is the same: the prompt is rendered with the schema and the
question, a runnable stands in for the chat model and returns a `QueryIntent`, and the same executor filters the data.
Only the model call is replaced, by deterministic keyword rules (severity words to `AESEV`, body-system words to
`AESOC`, anything else to `AETERM`). It handles the kinds of question in the examples, it is not a general language model.

## Design

* The schema (`SCHEMA`) holds the description of each queryable column (`AESEV`, `AETERM`, `AESOC`, `AESER`, `ACTARM`)
  and how to compare it. It is injected into the prompt, so adding a column means adding one entry.
* `with_structured_output(QueryIntent)` makes the model return a validated Pydantic object. `target_column` is a
  `Literal`, so a column outside the schema is rejected at parse time.
* `AESEV` and `AESER` use case-insensitive equality. `AETERM`, `AESOC` and `ACTARM` use case-insensitive substring
  match, so "Cardiac" finds `CARDIAC DISORDERS` and "Headache" also finds `TENSION HEADACHE`.
* Errors raise `AgentError` with a message: empty question, column missing from the data, no matching records
  (with the available values when there are few).

## Limitations

* One column and one value per question; no combinations ("severe headaches in placebo") or negations.
* `AETERM` is matched on the reported term only, not on `AEDECOD`, so synonyms ("cephalalgia") are not found.
* The real backends were not called while developing (no key available); the chain construction was checked offline.
  The mock is tested end to end.
