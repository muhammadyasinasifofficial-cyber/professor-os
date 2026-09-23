import os
from pathlib import Path

import pytest
from selenium import webdriver
from selenium.webdriver.chrome.options import Options


DEFAULT_APP_URL = "https://professor-os-production-65b2.up.railway.app"


@pytest.fixture
def app_url():
    return os.getenv("APP_URL", DEFAULT_APP_URL).rstrip("/")


@pytest.fixture
def admin_credentials():
    email = os.getenv("ADMIN_EMAIL")
    password = os.getenv("ADMIN_PASSWORD")
    return (email, password) if email and password else None


@pytest.fixture
def driver(request):
    options = Options()
    if os.getenv("HEADLESS", "1") != "0":
        options.add_argument("--headless=new")
    options.add_argument("--window-size=1440,1100")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

    browser = webdriver.Chrome(options=options)
    browser.set_page_load_timeout(int(os.getenv("SELENIUM_TIMEOUT", "45")))
    yield browser

    if request.node.rep_call.failed and os.getenv("SCREENSHOTS", "0") == "1":
        target = Path("selenium_tests") / "artifacts"
        target.mkdir(parents=True, exist_ok=True)
        browser.save_screenshot(str(target / f"{request.node.name}.png"))
    browser.quit()


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    report = outcome.get_result()
    setattr(item, f"rep_{report.when}", report)
