# Selenium deployment tests

This folder contains the browser-level tests for the deployed ProfessorOS Flutter Web application. It replaces the old mixed mock/API test package.

## Install

```powershell
python -m pip install -r selenium_tests/requirements.txt
```

Selenium Manager downloads or locates a compatible ChromeDriver. Chrome/Chromium must still be installed.

## Run

Smoke tests do not need credentials:

```powershell
python -m pytest -v selenium_tests/tests/test_smoke.py
```

Authenticated admin and course-management tests use credentials from environment variables. They are skipped when credentials are not set:

```powershell
$env:APP_URL = "https://professor-os-production-65b2.up.railway.app"
$env:ADMIN_EMAIL = "your-admin-email"
$env:ADMIN_PASSWORD = "your-admin-password"
python -m pytest -v selenium_tests/tests
```

To execute each case one at a time in the defined order:

```powershell
python selenium_tests/run_sequential.py
```

Set `ADMIN_EMAIL` and `ADMIN_PASSWORD` in the shell before running this command so the admin and course cases are not skipped.

For the simplest run from the repository root, use:

```powershell
python run_tests.py
```

Useful options:

- `SELENIUM_TIMEOUT` — explicit wait/page-load timeout in seconds; defaults to `45` for the slower deployment.
- `HEADLESS=0` — show Chrome locally.
- `SCREENSHOTS=1` — save failure screenshots in `selenium_tests/artifacts/`.

The tests intentionally avoid creating semesters, courses, users, or other persistent production data. They verify loading, authentication outcomes, admin navigation/controls, and course-management navigation/controls.

## Test coverage

- Smoke: deployed document and login surface.
- Authentication: empty credentials, invalid password, and optional valid admin login.
- Admin: authenticated admin area and management controls.
- Courses: authenticated course-management area and core course controls.

Flutter Web can render through canvas/semantics rather than stable HTML IDs. The page objects therefore prefer explicit waits, visible semantic text, and keyboard-compatible input interaction.
