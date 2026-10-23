import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from test_validate_video import synthetic_mp4


ROOT = Path(__file__).resolve().parents[1]


class ValidateReelsTests(unittest.TestCase):
    def test_accepts_complete_twenty_second_reel(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            reel_dir = Path(temporary) / "ig" / "reel-1080x1920"
            reel_dir.mkdir(parents=True)
            (reel_dir / "reel.mp4").write_bytes(synthetic_mp4(20, 1080, 1920))
            metadata = {
                "caption": "A concrete Trelew service explanation.",
                "hashtags": ["#TrelewStudio"],
                "cta_url": (
                    "https://trelew.studio/ie/shopify-migration?"
                    "utm_source=instagram&utm_medium=social&"
                    "utm_campaign=organic_reel&utm_content=test"
                ),
                "video_path": "reel.mp4",
                "spoken_script": "",
                "audio_strategy": "No narration. Restrained generated sound design.",
                "on_screen_text": ["Plan the migration before moving data"],
                "brand_assets": ["brand/example.svg"],
                "duration_seconds": 20,
            }
            (reel_dir / "reel.json").write_text(json.dumps(metadata), encoding="utf-8")
            result = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "validate_reels.py"),
                    temporary,
                    "--platforms",
                    "ig",
                    "--duration",
                    "20",
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
