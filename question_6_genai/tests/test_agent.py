import sys
from pathlib import Path

import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from clinical_agent import AgentError, ClinicalTrialDataAgent, QueryIntent  # noqa: E402


@pytest.fixture()
def agent(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    monkeypatch.delenv("LLM_PROVIDER", raising=False)
    ae = pd.DataFrame(
        {
            "USUBJID": ["A", "A", "B", "C", "D"],
            "AESEV": ["MILD", "MODERATE", "MODERATE", "SEVERE", "MILD"],
            "AETERM": ["HEADACHE", "NAUSEA", "TENSION HEADACHE", "SINUS BRADYCARDIA", "RASH"],
            "AESOC": [
                "NERVOUS SYSTEM DISORDERS",
                "GASTROINTESTINAL DISORDERS",
                "NERVOUS SYSTEM DISORDERS",
                "CARDIAC DISORDERS",
                "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
            ],
            "AESER": ["N", "N", "N", "Y", "N"],
            "ACTARM": ["Placebo", "Placebo", "Xanomeline High Dose", "Placebo", "Xanomeline Low Dose"],
        }
    )
    return ClinicalTrialDataAgent(ae)


def test_defaults_to_mock_without_keys(agent):
    assert agent.backend == "mock"


@pytest.mark.parametrize(
    "question,col,value",
    [
        ("Give me the subjects who had Adverse events of Moderate severity", "AESEV", "MODERATE"),
        ("What is the intensity SEVERE about?", "AESEV", "SEVERE"),
        ("Which patients reported Headache?", "AETERM", "headache"),
        ("List subjects with cardiac events", "AESOC", "CARDIAC"),
        ("Any skin problems?", "AESOC", "SKIN"),
        ("subjects with serious events", "AESER", "Y"),
        ("who was on placebo", "ACTARM", "Placebo"),
    ],
)
def test_parse(agent, question, col, value):
    intent = agent.parse(question)
    assert intent.target_column == col
    assert intent.filter_value.lower() == value.lower()


def test_moderate_severity(agent):
    r = agent.ask("Give me the subjects who had Adverse events of Moderate severity")
    assert r.subject_ids == ["A", "B"] and r.n_records == 2


def test_term_partial_match_case_insensitive(agent):
    assert agent.ask("headache").subject_ids == ["A", "B"]


def test_soc_partial_match(agent):
    assert agent.ask("cardiac").subject_ids == ["C"]
    assert agent.ask("skin").subject_ids == ["D"]


def test_no_match_error(agent):
    with pytest.raises(AgentError, match="No records"):
        agent.ask("Which patients reported Zzzzitis?")


def test_unknown_column_error(agent):
    bad = QueryIntent.model_construct(target_column="FOO", filter_value="x")
    with pytest.raises(AgentError, match="schema"):
        agent.execute(bad)


def test_missing_column_in_data(agent):
    agent.ae = agent.ae.drop(columns=["AESOC"])
    with pytest.raises(AgentError, match="not present"):
        agent.ask("cardiac")


def test_empty_question(agent):
    with pytest.raises(AgentError):
        agent.parse("   ")


def test_unknown_provider():
    with pytest.raises(AgentError, match="Unknown"):
        ClinicalTrialDataAgent(pd.DataFrame({"USUBJID": ["A"]}), provider="foo")


def test_real_data_if_available(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    path = Path(__file__).resolve().parents[2] / "data" / "adae.csv"
    if not path.is_file():
        pytest.skip("data/adae.csv not generated yet")
    a = ClinicalTrialDataAgent.from_csv(path)
    assert a.ask("Give me the subjects who had Adverse events of Moderate severity").n_subjects > 0
    assert a.ask("Headache").n_subjects > 0
    assert a.ask("Cardiac").n_subjects > 0
