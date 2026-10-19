"""Tests for the Clinical Trial Data API (synthetic data, no real dataset needed)."""
import pandas as pd
import pytest
from fastapi.testclient import TestClient

import main


def _rows(subj, sevs, arm):
    return [
        {"STUDYID": "S1", "USUBJID": subj, "AETERM": "X", "AESOC": "Y", "AESEV": s, "ACTARM": arm}
        for s in sevs
    ]


@pytest.fixture()
def client(tmp_path, monkeypatch):
    rows = (
        _rows("S-001", ["MILD"] * 4, "Placebo")  # 4 -> Low
        + _rows("S-002", ["MILD", "MODERATE", "MODERATE"], "Placebo")  # 7 -> Medium
        + _rows("S-003", ["MILD"] * 5, "Xanomeline High Dose")  # 5 -> Medium (boundary)
        + _rows("S-004", ["SEVERE"] * 2 + ["MODERATE"] + ["MILD"] * 2, "Placebo")  # 15 -> High
        + _rows("S-005", ["SEVERE"] * 2 + ["MODERATE"] + ["MILD"], "Placebo")  # 14 -> Medium
        + _rows("S-006", ["moderate"], "Xanomeline Low Dose")  # lower-case in data
    )
    p = tmp_path / "adae.csv"
    pd.DataFrame(rows).to_csv(p, index=False)
    monkeypatch.setenv("AE_CSV_PATH", str(p))
    with TestClient(main.app) as c:
        yield c


def test_root(client):
    r = client.get("/")
    assert r.status_code == 200
    assert r.json() == {"message": "Clinical Trial Data API is running"}


def test_no_filters_returns_everything(client):
    d = client.post("/ae-query", json={}).json()
    assert d["unique_subjects"] == 6 and d["count"] == 4 + 3 + 5 + 5 + 4 + 1


def test_null_and_empty_filters_ignored(client):
    for body in ({"severity": None, "treatment_arm": None}, {"severity": [], "treatment_arm": ""}):
        assert client.post("/ae-query", json=body).json()["unique_subjects"] == 6


def test_severity_filter_case_insensitive(client):
    d = client.post("/ae-query", json={"severity": ["moderate"]}).json()
    assert d["usubjids"] == ["S-002", "S-004", "S-005", "S-006"]


def test_and_of_filters(client):
    d = client.post(
        "/ae-query", json={"severity": ["MILD", "MODERATE"], "treatment_arm": "placebo"}
    ).json()
    assert d["usubjids"] == ["S-001", "S-002", "S-004", "S-005"]
    assert d["count"] == 4 + 3 + 3 + 2


def test_unknown_arm_gives_empty_cohort(client):
    d = client.post("/ae-query", json={"treatment_arm": "Nope"}).json()
    assert d == {"count": 0, "unique_subjects": 0, "usubjids": []}


def test_invalid_severity_422(client):
    assert client.post("/ae-query", json={"severity": ["CATASTROPHIC"]}).status_code == 422


def test_wrong_types_422(client):
    assert client.post("/ae-query", json={"severity": "MILD"}).status_code == 422


@pytest.mark.parametrize(
    "sid,score,cat",
    [
        ("S-001", 4, "Low"),
        ("S-003", 5, "Medium"),
        ("S-005", 14, "Medium"),
        ("S-004", 15, "High"),
        ("S-006", 3, "Low"),
    ],
)
def test_risk_boundaries(client, sid, score, cat):
    assert client.get(f"/subject-risk/{sid}").json() == {
        "subject_id": sid,
        "risk_score": score,
        "risk_category": cat,
    }


def test_unknown_subject_404(client):
    assert client.get("/subject-risk/NOPE").status_code == 404


def test_categorise_risk_unit():
    assert [main.categorise_risk(s) for s in (0, 4, 5, 14, 15, 100)] == [
        "Low", "Low", "Medium", "Medium", "High", "High",
    ]


def test_arm_joined_from_dm_when_missing(tmp_path, monkeypatch):
    pd.DataFrame({"USUBJID": ["A", "B"], "AESEV": ["MILD", "SEVERE"]}).to_csv(tmp_path / "ae.csv", index=False)
    pd.DataFrame({"USUBJID": ["A", "B"], "ACTARM": ["Placebo", "Drug"]}).to_csv(tmp_path / "dm.csv", index=False)
    monkeypatch.setenv("AE_CSV_PATH", str(tmp_path / "ae.csv"))
    monkeypatch.setenv("DM_CSV_PATH", str(tmp_path / "dm.csv"))
    with TestClient(main.app) as c:
        assert c.post("/ae-query", json={"treatment_arm": "drug"}).json()["usubjids"] == ["B"]


def test_arm_unavailable_400(tmp_path, monkeypatch):
    pd.DataFrame({"USUBJID": ["A"], "AESEV": ["MILD"]}).to_csv(tmp_path / "ae.csv", index=False)
    monkeypatch.setenv("AE_CSV_PATH", str(tmp_path / "ae.csv"))
    monkeypatch.setenv("DM_CSV_PATH", str(tmp_path / "none.csv"))
    with TestClient(main.app) as c:
        assert c.post("/ae-query", json={"treatment_arm": "x"}).status_code == 400
