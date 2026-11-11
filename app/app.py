"""Healthcare Patient Management System - lightweight Flask app (sample data only)."""
import re
import socket
import threading

from flask import Flask, jsonify, render_template, request

from config import load_config

DEPARTMENTS = ["Cardiology", "Neurology", "Orthopedics", "Pediatrics", "General Medicine", "Radiology"]
STATUSES = ["Scheduled", "Checked-In", "Completed", "Cancelled"]
NAME_RE = re.compile(r"^[A-Za-z][A-Za-z .'-]{1,78}$")

SAMPLE_PATIENTS = [  # entirely fictional
    ("Aarav Sharma", 34, "Cardiology", "Scheduled"),
    ("Diya Patel", 8, "Pediatrics", "Completed"),
    ("Rohan Mehta", 52, "Orthopedics", "Checked-In"),
    ("Isha Verma", 29, "General Medicine", "Scheduled"),
    ("Kabir Singh", 61, "Neurology", "Cancelled"),
    ("Meera Nair", 45, "Radiology", "Completed"),
]


def create_app():
    app = Flask(__name__)
    cfg = load_config()
    app.config.update(cfg)
    if cfg["SECRET_KEY"]:
        app.secret_key = cfg["SECRET_KEY"]

    lock = threading.Lock()
    patients = []

    def add_patient(name, age, dept, status):
        pid = f"P-{1001 + len(patients)}"
        rec = {"id": pid, "name": name, "age": age, "department": dept, "status": status}
        patients.append(rec)
        return rec

    for p in SAMPLE_PATIENTS:
        add_patient(*p)

    def meta():
        return {
            "version": app.config["APP_VERSION"],
            "color": app.config["DEPLOYMENT_COLOR"],
            "label": app.config["RELEASE_LABEL"],
            "environment": app.config["ENVIRONMENT"],
            "pod": socket.gethostname(),
        }

    @app.after_request
    def headers(resp):
        resp.headers["X-Content-Type-Options"] = "nosniff"
        resp.headers["X-Frame-Options"] = "DENY"
        resp.headers["Referrer-Policy"] = "no-referrer"
        resp.headers["Content-Security-Policy"] = "default-src 'self'"
        resp.headers["Cache-Control"] = "no-store"
        return resp

    @app.get("/")
    def index():
        return render_template("index.html", app_name=app.config["APP_NAME"],
                               departments=DEPARTMENTS, statuses=STATUSES, **meta())

    @app.get("/health")
    def health():
        return jsonify(status="healthy"), 200

    @app.get("/api/status")
    def api_status():
        with lock:
            count = len(patients)
        return jsonify(status="ok", app=app.config["APP_NAME"], patients=count, **meta())

    @app.get("/api/patients")
    def list_patients():
        with lock:
            return jsonify(list(patients))

    @app.post("/api/patients")
    def register_patient():
        data = request.get_json(silent=True) or {}
        name = str(data.get("name", "")).strip()
        dept = data.get("department")
        status = data.get("status", "Scheduled")
        try:
            age = int(data.get("age"))
        except (TypeError, ValueError):
            return jsonify(error="age must be a whole number"), 400
        if not NAME_RE.match(name):
            return jsonify(error="invalid name"), 400
        if not 0 <= age <= 120:
            return jsonify(error="age must be between 0 and 120"), 400
        if dept not in DEPARTMENTS:
            return jsonify(error="invalid department"), 400
        if status not in STATUSES:
            return jsonify(error="invalid status"), 400
        with lock:
            rec = add_patient(name, age, dept, status)
        return jsonify(rec), 201

    @app.get("/api/stats")
    def stats():
        with lock:
            rows = list(patients)
        by_status = {s: 0 for s in STATUSES}
        by_dept = {}
        for r in rows:
            by_status[r["status"]] += 1
            by_dept[r["department"]] = by_dept.get(r["department"], 0) + 1
        avg = round(sum(r["age"] for r in rows) / len(rows), 1) if rows else 0
        return jsonify(total=len(rows), by_status=by_status, by_department=by_dept, average_age=avg)

    return app


app = create_app()

if __name__ == "__main__":  # development only; containers use gunicorn
    cfg = load_config()
    app.run(host=cfg["HOST"], port=cfg["PORT"])
