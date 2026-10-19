"""Clinical Trial Data API (Question 5).

Serves the adverse-event (AE) dataset exported from ``pharmaversesdtm::ae`` and
exposes three endpoints:

* ``GET /``                          health/welcome message
* ``POST /ae-query``                 dynamic cohort filtering (AESEV and/or ACTARM)
* ``GET /subject-risk/{subject_id}`` weighted safety risk score per subject

Configuration (environment variables, all optional):

* ``AE_CSV_PATH``  path to the AE CSV (default ``../data/adae.csv``, resolved
  relative to this file, so it works from any working directory).
* ``DM_CSV_PATH``  path to a DM CSV used only when the AE file has no ``ACTARM``
  column (default ``../data/dm.csv``). ``pharmaversesdtm::ae`` does not carry
  ``ACTARM``; it lives in DM/ADSL, so it is joined on ``USUBJID``.
"""
from __future__ import annotations

import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import AsyncIterator, Optional

import pandas as pd
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel, Field, field_validator

HERE = Path(__file__).resolve().parent
DEFAULT_AE_PATH = HERE.parent / "data" / "adae.csv"
DEFAULT_DM_PATH = HERE.parent / "data" / "dm.csv"

# Severity weights and the allowed (normalised, upper-case) AESEV values.
SEVERITY_WEIGHTS: dict[str, int] = {"MILD": 1, "MODERATE": 3, "SEVERE": 5}
ARM_COLUMN = "ACTARM"


# --------------------------------------------------------------------------- #
# Data loading
# --------------------------------------------------------------------------- #
def load_ae_data(ae_path: Path | str, dm_path: Path | str | None = None) -> pd.DataFrame:
    """Load the AE dataset and make sure it has USUBJID, AESEV and (if possible) ACTARM.

    ``ACTARM`` is used directly when present in the AE file. Otherwise it is
    taken from the DM file (joined on ``USUBJID``) when that file exists. If it
    cannot be resolved the column is left out and arm filtering is reported as
    unavailable (HTTP 400) instead of silently returning wrong cohorts.

    Raises:
        FileNotFoundError: if the AE CSV does not exist.
        ValueError: if mandatory columns are missing.
    """
    ae_path = Path(ae_path)
    if not ae_path.is_file():
        raise FileNotFoundError(f"AE dataset not found: {ae_path} (set AE_CSV_PATH)")
    df = pd.read_csv(ae_path, dtype=str, keep_default_na=False, na_values=[""])
    missing = {"USUBJID", "AESEV"} - set(df.columns)
    if missing:
        raise ValueError(f"AE dataset is missing required columns: {sorted(missing)}")

    if ARM_COLUMN not in df.columns and dm_path is not None and Path(dm_path).is_file():
        dm = pd.read_csv(dm_path, dtype=str, keep_default_na=False, na_values=[""])
        if {"USUBJID", ARM_COLUMN} <= set(dm.columns):
            arms = dm[["USUBJID", ARM_COLUMN]].drop_duplicates("USUBJID")
            df = df.merge(arms, on="USUBJID", how="left")

    df["AESEV"] = df["AESEV"].str.strip().str.upper()
    df["USUBJID"] = df["USUBJID"].str.strip()
    if ARM_COLUMN in df.columns:
        df[ARM_COLUMN] = df[ARM_COLUMN].str.strip()
    return df


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Load the dataset once at start-up (paths come from the environment)."""
    ae_path = os.environ.get("AE_CSV_PATH", str(DEFAULT_AE_PATH))
    dm_path = os.environ.get("DM_CSV_PATH", str(DEFAULT_DM_PATH))
    app.state.ae = load_ae_data(ae_path, dm_path)
    yield


app = FastAPI(
    title="Clinical Trial Data API",
    description="Dynamic AE cohort queries and subject safety risk scores.",
    version="1.0.0",
    lifespan=lifespan,
)


def get_df(request: Request) -> pd.DataFrame:
    """Return the in-memory AE dataframe loaded at start-up."""
    return request.app.state.ae


# --------------------------------------------------------------------------- #
# Schemas
# --------------------------------------------------------------------------- #
class WelcomeResponse(BaseModel):
    """Body of ``GET /``."""

    message: str


class AEQueryRequest(BaseModel):
    """Optional filters for ``POST /ae-query``.

    Absent or ``null`` fields are ignored. An empty list or blank string is
    treated the same way (no filter on that dimension). Severity and arm are
    case-insensitive.
    """

    severity: Optional[list[str]] = Field(
        default=None, description="AESEV values, e.g. ['MILD', 'MODERATE']."
    )
    treatment_arm: Optional[str] = Field(
        default=None, description="ACTARM value, e.g. 'Placebo'."
    )

    @field_validator("severity")
    @classmethod
    def _normalise_severity(cls, v: Optional[list[str]]) -> Optional[list[str]]:
        if v is None:
            return None
        out = [s.strip().upper() for s in v if s.strip()]
        bad = sorted(set(out) - set(SEVERITY_WEIGHTS))
        if bad:
            raise ValueError(
                f"Invalid severity value(s) {bad}; allowed: {sorted(SEVERITY_WEIGHTS)}"
            )
        return out

    @field_validator("treatment_arm")
    @classmethod
    def _strip_arm(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        v = v.strip()
        return v or None


class AEQueryResponse(BaseModel):
    """Result of ``POST /ae-query``."""

    count: int = Field(description="Number of matching AE records.")
    unique_subjects: int = Field(description="Number of distinct USUBJID in the cohort.")
    usubjids: list[str] = Field(description="Sorted unique USUBJID values.")


class RiskResponse(BaseModel):
    """Result of ``GET /subject-risk/{subject_id}``."""

    subject_id: str
    risk_score: int
    risk_category: str


# --------------------------------------------------------------------------- #
# Logic
# --------------------------------------------------------------------------- #
def categorise_risk(score: int) -> str:
    """Map a risk score to Low (<5), Medium (5 to <15) or High (>=15)."""
    if score < 5:
        return "Low"
    if score < 15:
        return "Medium"
    return "High"


def compute_risk_score(severities: pd.Series) -> int:
    """Sum severity weights (MILD=1, MODERATE=3, SEVERE=5); unknown/missing add 0."""
    return int(severities.map(SEVERITY_WEIGHTS).fillna(0).sum())


# --------------------------------------------------------------------------- #
# Endpoints
# --------------------------------------------------------------------------- #
@app.get("/", response_model=WelcomeResponse)
def root() -> WelcomeResponse:
    """Welcome / health-check message."""
    return WelcomeResponse(message="Clinical Trial Data API is running")


@app.post("/ae-query", response_model=AEQueryResponse)
def ae_query(body: AEQueryRequest, request: Request) -> AEQueryResponse:
    """Filter AEs by severity list and/or treatment arm (AND of the given filters)."""
    df = get_df(request)
    mask = pd.Series(True, index=df.index)
    if body.severity:
        mask &= df["AESEV"].isin(body.severity)
    if body.treatment_arm:
        if ARM_COLUMN not in df.columns:
            raise HTTPException(
                status_code=400,
                detail="Treatment arm (ACTARM) is not available in the loaded data.",
            )
        mask &= df[ARM_COLUMN].str.casefold() == body.treatment_arm.casefold()
    sub = df[mask]
    ids = sorted(sub["USUBJID"].dropna().unique().tolist())
    return AEQueryResponse(count=len(sub), unique_subjects=len(ids), usubjids=ids)


@app.get("/subject-risk/{subject_id}", response_model=RiskResponse)
def subject_risk(subject_id: str, request: Request) -> RiskResponse:
    """Weighted safety risk score for one subject; 404 if the subject has no records."""
    df = get_df(request)
    sid = subject_id.strip()
    rows = df[df["USUBJID"] == sid]
    if rows.empty:
        raise HTTPException(status_code=404, detail=f"Subject '{subject_id}' not found")
    score = compute_risk_score(rows["AESEV"])
    return RiskResponse(subject_id=sid, risk_score=score, risk_category=categorise_risk(score))
