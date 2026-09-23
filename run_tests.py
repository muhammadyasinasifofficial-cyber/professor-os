"""One-command Selenium test runner for ProfessorOS deployment."""

import os

from selenium_tests.run_sequential import main


os.environ.setdefault("APP_URL", "https://professor-os-production-65b2.up.railway.app")
os.environ.setdefault("ADMIN_EMAIL", "admin@professoros.edu.pk")
os.environ.setdefault("ADMIN_PASSWORD", "admin123")
os.environ.setdefault("SELENIUM_TIMEOUT", "60")


if __name__ == "__main__":
    raise SystemExit(main())
