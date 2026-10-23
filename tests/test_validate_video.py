import struct
import tempfile
import unittest
from pathlib import Path

from validate_video import inspect_mp4


def box(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I4s", len(payload) + 8, kind) + payload


def synthetic_mp4(duration_seconds: int, width: int, height: int) -> bytes:
    mvhd = b"\0\0\0\0" + struct.pack(">IIII", 0, 0, 1000, duration_seconds * 1000)
    tkhd = b"\0" * 32 + struct.pack(">II", width * 65536, height * 65536)
    hdlr = b"\0\0\0\0" + b"\0\0\0\0" + b"vide"
    trak = box(b"tkhd", tkhd) + box(b"mdia", box(b"hdlr", hdlr))
    return (
        box(b"ftyp", b"isom\0\0\0\0isom")
        + box(b"moov", box(b"mvhd", mvhd) + box(b"trak", trak))
        + box(b"mdat", b"\0")
    )


class InspectMp4Tests(unittest.TestCase):
    def test_reads_duration_and_vertical_dimensions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "reel.mp4"
            path.write_bytes(synthetic_mp4(20, 1080, 1920))
            self.assertEqual(inspect_mp4(path), (20.0, 1080, 1920))


if __name__ == "__main__":
    unittest.main()
