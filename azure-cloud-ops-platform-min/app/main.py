import os, time, uuid
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
try:
    from agent.agent import IncidentAgent
except Exception:
    IncidentAgent = None

app = FastAPI(title="Azure CloudOps API", version=os.getenv("APP_VERSION", "1.0.0"))
FAILURE_MODE = os.getenv("FAILURE_MODE", "false").lower() == "true"

class FailureRequest(BaseModel):
    mode: str  # error | latency | clear

@app.get("/health")
def health():
    if FAILURE_MODE:
        raise HTTPException(status_code=503, detail="simulated unhealthy state")
    return {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()}

@app.get("/api/orders")
def orders():
    if FAILURE_MODE:
        raise HTTPException(status_code=503, detail="orders dependency unavailable")
    return {"orders": [{"id": "ORD-1001", "status": "processed"}], "request_id": str(uuid.uuid4())}

@app.get("/api/version")
def version():
    return {"version": os.getenv("APP_VERSION", "1.0.0")}

@app.post("/simulate/failure")
def simulate_failure(req: FailureRequest):
    global FAILURE_MODE
    if req.mode == "error":
        FAILURE_MODE = True
    elif req.mode == "clear":
        FAILURE_MODE = False
    elif req.mode == "latency":
        time.sleep(5)
    else:
        raise HTTPException(status_code=400, detail="mode must be error, latency, or clear")
    return {"failure_mode": FAILURE_MODE, "mode": req.mode}


class Incident(BaseModel):
    title: str
    service: str
    symptoms: str
    telemetry: dict = {}

@app.post("/api/incidents/analyze")
def analyze_incident(incident: Incident):
    if IncidentAgent is None:
        raise HTTPException(status_code=503, detail="AI dependencies are not installed")
    try:
        return IncidentAgent().analyze(incident.model_dump())
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"AI analysis unavailable: {exc}")
