"""Natural language questions over the AE dataset (Question 6).

Flow: question -> prompt (schema + question) -> LLM -> structured intent
(target_column, filter_value) -> pandas filter -> unique subjects.

Two back ends share the same prompt, parser and executor:

* a real chat model through LangChain (OpenAI), enabled from an environment
  variable;
* a deterministic model for use without an API key (tests and demos), wrapped
  as a LangChain runnable so that only the model call itself is swapped.

Environment variables:
    LLM_PROVIDER     "openai" or "mock". Default: openai if OPENAI_API_KEY is
                     set, else mock.
    LLM_MODEL        model name for the real back end (provider default if unset).
    AE_CSV_PATH      path to the AE CSV (default ../data/adae.csv).
"""
from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Literal, Optional

import pandas as pd
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import Runnable, RunnableLambda
from pydantic import BaseModel, Field

DEFAULT_AE_PATH = Path(__file__).resolve().parent.parent / "data" / "adae.csv"

# Columns the agent may filter on. "match" says how filter_value is compared:
# "exact" (case-insensitive equality) or "contains" (case-insensitive substring).
SCHEMA: dict[str, dict[str, str]] = {
    "AESEV": {
        "description": "Severity/intensity of the adverse event. Values: MILD, MODERATE, SEVERE.",
        "match": "exact",
    },
    "AETERM": {
        "description": "Reported term for the adverse event, a specific condition or symptom "
        "(e.g. HEADACHE, PRURITUS, DIZZINESS, NAUSEA).",
        "match": "contains",
    },
    "AESOC": {
        "description": "MedDRA System Organ Class, the body system affected "
        "(e.g. CARDIAC DISORDERS, SKIN AND SUBCUTANEOUS TISSUE DISORDERS, "
        "NERVOUS SYSTEM DISORDERS).",
        "match": "contains",
    },
    "AESER": {
        "description": "Serious adverse event flag. Values: Y (serious) or N (not serious).",
        "match": "exact",
    },
    "ACTARM": {
        "description": "Actual treatment arm of the subject (Placebo, Xanomeline Low Dose, "
        "Xanomeline High Dose).",
        "match": "contains",
    },
}

ColumnName = Literal["AESEV", "AETERM", "AESOC", "AESER", "ACTARM"]


class QueryIntent(BaseModel):
    """Structured interpretation of a user question."""

    target_column: ColumnName = Field(description="Dataset column the question refers to.")
    filter_value: str = Field(
        description="Value to look for in that column, as written in the question "
        "(for AESEV use MILD, MODERATE or SEVERE; for AESER use Y or N)."
    )


@dataclass
class QueryResult:
    """Outcome of executing a QueryIntent."""

    target_column: str
    filter_value: str
    n_records: int
    n_subjects: int
    subject_ids: list[str]


class AgentError(ValueError):
    """Raised for an invalid intent or a filter that matches nothing."""


def schema_text(schema: dict[str, dict[str, str]] = SCHEMA) -> str:
    """Render the schema as the text block placed in the prompt."""
    return "\n".join(f"- {col}: {meta['description']}" for col, meta in schema.items())


PROMPT = ChatPromptTemplate.from_messages(
    [
        (
            "system",
            "You translate questions from a clinical safety reviewer about an adverse "
            "event (AE) dataset into a single filter. The reviewer does not know the "
            "column names, so choose the column from the descriptions below.\n\n"
            "Columns:\n{schema}\n\n"
            "Rules:\n"
            "- Words like severity or intensity, or mild/moderate/severe, refer to AESEV.\n"
            "- A specific condition or symptom (headache, nausea) refers to AETERM.\n"
            "- A body system or organ class (cardiac, skin, nervous system) refers to AESOC.\n"
            "- Return the value as it appears in the question, without extra words.",
        ),
        ("human", "{question}"),
    ]
)


# --------------------------------------------------------------------------- #
# Model without API key
# --------------------------------------------------------------------------- #
_SEVERITY_WORDS = {"mild": "MILD", "moderate": "MODERATE", "severe": "SEVERE"}
_SEVERITY_CUES = {"severity", "intensity", "grade"}
# Keyword -> SOC fragment (matched as substring against AESOC, so partial is fine).
_SOC_KEYWORDS = {
    "cardiac": "CARDIAC", "heart": "CARDIAC",
    "skin": "SKIN", "dermatolog": "SKIN", "cutaneous": "SKIN",
    "nervous": "NERVOUS", "neurolog": "NERVOUS",
    "gastro": "GASTROINTESTINAL", "stomach": "GASTROINTESTINAL",
    "respiratory": "RESPIRATORY", "lung": "RESPIRATORY",
    "psychiatric": "PSYCHIATRIC", "infection": "INFECTIONS",
    "renal": "RENAL", "kidney": "RENAL", "vascular": "VASCULAR",
    "eye": "EYE", "ocular": "EYE", "ear": "EAR",
    "musculoskeletal": "MUSCULOSKELETAL", "hepatic": "HEPATOBILIARY",
    "immune": "IMMUNE", "metabolism": "METABOLISM",
}
_ARM_WORDS = {"placebo": "Placebo", "xanomeline": "Xanomeline"}
_STOPWORDS = {
    "a", "an", "the", "of", "with", "who", "had", "have", "has", "give", "me", "show",
    "list", "find", "get", "which", "what", "are", "is", "were", "was", "subjects",
    "subject", "patients", "patient", "participants", "adverse", "event", "events",
    "ae", "aes", "experienced", "experiencing", "reported", "reporting", "any", "all",
    "for", "in", "on", "that", "to", "and", "related", "affecting", "system", "disorders",
}


def _mock_intent(question: str) -> QueryIntent:
    """Rule-based stand-in for the LLM: question text -> QueryIntent."""
    text = question.lower()
    words = re.findall(r"[a-z][a-z\-]*", text)

    for w in words:
        if w in _SEVERITY_WORDS:
            return QueryIntent(target_column="AESEV", filter_value=_SEVERITY_WORDS[w])
    if "serious" in words:
        return QueryIntent(target_column="AESER", filter_value="N" if "not" in words else "Y")
    for w in words:
        if w in _ARM_WORDS:
            return QueryIntent(target_column="ACTARM", filter_value=_ARM_WORDS[w])
    for key, soc in _SOC_KEYWORDS.items():
        if any(w.startswith(key) for w in words):
            return QueryIntent(target_column="AESOC", filter_value=soc)

    rest = [w for w in words if w not in _STOPWORDS and w not in _SEVERITY_CUES]
    if not rest:
        raise AgentError("Could not find anything to filter on in the question.")
    return QueryIntent(target_column="AETERM", filter_value=" ".join(rest))


def _mock_model(prompt_value: Any) -> QueryIntent:
    """Runnable body: reads the human message out of the rendered prompt."""
    human = [m for m in prompt_value.to_messages() if m.type == "human"][-1]
    return _mock_intent(str(human.content))


def build_chain(provider: Optional[str] = None) -> tuple[Runnable, str]:
    """Return (prompt | structured model chain, backend label).

    Only the presence of API keys is checked here; the keys themselves are read
    by the LangChain client classes.
    """
    provider = (provider or os.environ.get("LLM_PROVIDER", "")).lower() or None
    if provider is None:
        if os.environ.get("OPENAI_API_KEY"):
            provider = "openai"
        else:
            provider = "mock"

    model_name = os.environ.get("LLM_MODEL")
    if provider == "openai":
        from langchain_openai import ChatOpenAI

        llm = ChatOpenAI(model=model_name or "gpt-4o-mini", temperature=0)
    elif provider == "mock":
        return PROMPT | RunnableLambda(_mock_model), "mock"
    else:
        raise AgentError(f"Unknown LLM_PROVIDER '{provider}' (use openai or mock).")
    return PROMPT | llm.with_structured_output(QueryIntent), provider


# --------------------------------------------------------------------------- #
# Agent
# --------------------------------------------------------------------------- #
class ClinicalTrialDataAgent:
    """Answers free-text questions about the AE dataframe.

    Args:
        ae: AE dataframe (needs USUBJID plus the columns in SCHEMA that you query).
        provider: "openai" or "mock". Defaults to the environment.
    """

    def __init__(self, ae: pd.DataFrame, provider: Optional[str] = None) -> None:
        if "USUBJID" not in ae.columns:
            raise AgentError("The dataframe needs a USUBJID column.")
        self.ae = ae
        self.chain, self.backend = build_chain(provider)

    @classmethod
    def from_csv(cls, path: Path | str | None = None, provider: Optional[str] = None):
        """Build the agent from a CSV (default: AE_CSV_PATH or ../data/adae.csv)."""
        path = Path(path or os.environ.get("AE_CSV_PATH", DEFAULT_AE_PATH))
        if not path.is_file():
            raise FileNotFoundError(f"AE dataset not found: {path}")
        return cls(pd.read_csv(path, dtype=str, keep_default_na=False), provider)

    def parse(self, question: str) -> QueryIntent:
        """Prompt + parse: turn the question into a QueryIntent."""
        if not question or not question.strip():
            raise AgentError("The question is empty.")
        out = self.chain.invoke({"schema": schema_text(), "question": question.strip()})
        return out if isinstance(out, QueryIntent) else QueryIntent.model_validate(out)

    def execute(self, intent: QueryIntent) -> QueryResult:
        """Apply the intent as a pandas filter and return the unique subjects."""
        col, value = intent.target_column, intent.filter_value.strip()
        if col not in SCHEMA:
            raise AgentError(f"Column '{col}' is not part of the schema: {list(SCHEMA)}")
        if col not in self.ae.columns:
            raise AgentError(f"Column '{col}' is not present in the loaded dataset.")
        if not value:
            raise AgentError("The filter value is empty.")

        series = self.ae[col].astype(str).str.strip()
        if SCHEMA[col]["match"] == "exact":
            mask = series.str.casefold() == value.casefold()
        else:
            mask = series.str.contains(value, case=False, regex=False)
        hits = self.ae[mask]
        if hits.empty:
            known = sorted(series.unique())
            hint = f" Available values: {known}" if len(known) <= 10 else ""
            raise AgentError(f"No records where {col} matches '{value}'.{hint}")
        ids = sorted(hits["USUBJID"].unique().tolist())
        return QueryResult(col, value, len(hits), len(ids), ids)

    def ask(self, question: str) -> QueryResult:
        """Full flow: parse the question, then execute the resulting filter."""
        return self.execute(self.parse(question))


# --------------------------------------------------------------------------- #
# Example queries
# --------------------------------------------------------------------------- #
EXAMPLE_QUESTIONS = [
    "Give me the subjects who had Adverse events of Moderate severity",
    "Which patients reported Headache?",
    "List subjects with cardiac events",
]


def run_examples(agent: ClinicalTrialDataAgent, questions: list[str] = EXAMPLE_QUESTIONS) -> None:
    """Run each question through the agent and print the outcome."""
    print(f"Backend: {agent.backend}\n")
    for q in questions:
        print(f"Q: {q}")
        try:
            intent = agent.parse(q)
            res = agent.execute(intent)
        except AgentError as exc:
            print(f"  error: {exc}\n")
            continue
        print(f"  intent: {intent.model_dump()}")
        shown = ", ".join(res.subject_ids[:5]) + (" ..." if res.n_subjects > 5 else "")
        print(f"  {res.n_subjects} unique subjects ({res.n_records} records): {shown}\n")


if __name__ == "__main__":
    run_examples(ClinicalTrialDataAgent.from_csv())
