from pathlib import Path
import shutil
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[3]
OUT_VIDEOS = ROOT / 'evaluation_artifacts' / 'co5_testing_bundle' / 'outputs' / 'videos'
OUT_SHOTS = ROOT / 'evaluation_artifacts' / 'co5_testing_bundle' / 'outputs' / 'screenshots'
URL = 'https://professor-os-production-65b2.up.railway.app'


def finalize_video(video_path: str, target_name: str) -> Path:
    src = Path(video_path)
    dst = OUT_VIDEOS / target_name
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        dst.unlink()
    shutil.move(str(src), str(dst))
    return dst


def record_demo():
    OUT_VIDEOS.mkdir(parents=True, exist_ok=True)
    OUT_SHOTS.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            record_video_dir=str(OUT_VIDEOS),
            record_video_size={'width': 1280, 'height': 720},
        )
        page = context.new_page()
        video = page.video

        page.goto(URL, wait_until='domcontentloaded')
        page.wait_for_timeout(6000)

        # Positive login flow
        page.keyboard.press('Tab')
        page.keyboard.press('Tab')
        page.keyboard.type('admin@professoros.edu.pk')
        page.keyboard.press('Tab')
        page.keyboard.type('admin123')
        page.keyboard.press('Enter')
        page.wait_for_timeout(7000)
        page.screenshot(path=str(OUT_SHOTS / 'video_login_success_frame.png'), full_page=True)

        # Negative login flow
        page.goto(URL, wait_until='domcontentloaded')
        page.wait_for_timeout(6000)
        page.keyboard.press('Tab')
        page.keyboard.press('Tab')
        page.keyboard.type('student@professoros.edu.pk')
        page.keyboard.press('Tab')
        page.keyboard.type('wrongpass123')
        page.keyboard.press('Enter')
        page.wait_for_timeout(5000)
        page.screenshot(path=str(OUT_SHOTS / 'video_login_negative_frame.png'), full_page=True)

        page.close()
        context.close()
        browser.close()

        final_video = finalize_video(video.path(), 'co5_demo_full.webm')
        print(f'Video saved: {final_video}')


if __name__ == '__main__':
    record_demo()
