import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import render_heygen


class RenderHeygenTests(unittest.TestCase):
    def test_submits_portable_avatar_payload_with_typed_color_background(self) -> None:
        captured_payloads: list[dict[str, object]] = []

        def reject_after_capture(
            _url: str,
            _api_key: str,
            payload: dict[str, object] | None = None,
        ) -> dict[str, object]:
            self.assertIsNotNone(payload)
            captured_payloads.append(payload or {})
            raise RuntimeError("stop after capturing request")

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            metadata = root / "ad.json"
            metadata.write_text(
                json.dumps(
                    {
                        "title": "Regression test",
                        "spoken_script": "A short test script.",
                        "voice_speed": 1.0,
                        "language_code": "en-GB",
                    }
                ),
                encoding="utf-8",
            )

            arguments = [
                "render_heygen.py",
                "--metadata",
                str(metadata),
                "--output",
                str(root / "source.mp4"),
                "--avatar-id",
                "avatar-test",
                "--voice-id",
                "voice-test",
            ]
            with (
                mock.patch.dict(os.environ, {"HEYGEN_API_KEY": "test-key"}),
                mock.patch.object(sys, "argv", arguments),
                mock.patch.object(render_heygen, "request_json", side_effect=reject_after_capture),
                mock.patch("sys.stdout", new_callable=io.StringIO),
            ):
                self.assertEqual(render_heygen.main(), 1)

        self.assertEqual(len(captured_payloads), 1)
        payload = captured_payloads[0]
        self.assertEqual(
            payload["background"],
            {"type": "color", "value": "#FBF6E8"},
        )
        self.assertNotIn("motion_prompt", payload)
        self.assertNotIn("watermark", payload)


if __name__ == "__main__":
    unittest.main()
