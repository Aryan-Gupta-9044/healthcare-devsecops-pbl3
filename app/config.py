"""Environment-driven configuration. Nothing here is machine- or cluster-specific."""
import os

_LABELS = {"blue": "Blue Release", "green": "Green Release"}


def load_config():
    """Read configuration from the environment at call time (testable, 12-factor)."""
    color = os.getenv("DEPLOYMENT_COLOR", "standard").strip().lower()
    if color not in ("blue", "green", "standard"):
        color = "standard"
    return {
        "APP_NAME": os.getenv("APP_NAME", "Healthcare Patient Management System"),
        "APP_VERSION": os.getenv("APP_VERSION", "1.0.0"),
        "DEPLOYMENT_COLOR": color,
        "RELEASE_LABEL": os.getenv("RELEASE_LABEL") or _LABELS.get(color, "Standard Release"),
        "ENVIRONMENT": os.getenv("ENVIRONMENT", "local"),
        "HOST": os.getenv("APP_HOST", "127.0.0.1"),
        "PORT": int(os.getenv("APP_PORT", "8080")),
        # Optional secret, injected from a Kubernetes Secret or local env. No default on purpose.
        "SECRET_KEY": os.getenv("SECRET_KEY", ""),
    }
