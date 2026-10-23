#!/usr/bin/env python3
"""Validate MP4 duration and frame dimensions without external media tools."""

from __future__ import annotations

import argparse
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO, Iterator


CONTAINERS = {b"moov", b"trak", b"mdia"}


@dataclass(frozen=True)
class Box:
    kind: bytes
    payload_start: int
    end: int


def boxes(handle: BinaryIO, start: int, end: int) -> Iterator[Box]:
    offset = start
    while offset + 8 <= end:
        handle.seek(offset)
        header = handle.read(8)
        if len(header) != 8:
            return
        size, kind = struct.unpack(">I4s", header)
        header_size = 8
        if size == 1:
            extended = handle.read(8)
            if len(extended) != 8:
                return
            size = struct.unpack(">Q", extended)[0]
            header_size = 16
        elif size == 0:
            size = end - offset
        if size < header_size or offset + size > end:
            return
        yield Box(kind, offset + header_size, offset + size)
        offset += size


def read_payload(handle: BinaryIO, box: Box) -> bytes:
    handle.seek(box.payload_start)
    return handle.read(box.end - box.payload_start)


def movie_duration(handle: BinaryIO, moov: Box) -> float:
    for box in boxes(handle, moov.payload_start, moov.end):
        if box.kind != b"mvhd":
            continue
        payload = read_payload(handle, box)
        if len(payload) < 20:
            break
        version = payload[0]
        if version == 0 and len(payload) >= 20:
            timescale = struct.unpack(">I", payload[12:16])[0]
            duration = struct.unpack(">I", payload[16:20])[0]
        elif version == 1 and len(payload) >= 32:
            timescale = struct.unpack(">I", payload[20:24])[0]
            duration = struct.unpack(">Q", payload[24:32])[0]
        else:
            break
        if not timescale:
            break
        return duration / timescale
    raise ValueError("MP4 has no readable movie duration")


def track_dimensions(handle: BinaryIO, trak: Box) -> tuple[int, int] | None:
    tkhd: Box | None = None
    video_track = False
    for child in boxes(handle, trak.payload_start, trak.end):
        if child.kind == b"tkhd":
            tkhd = child
        elif child.kind == b"mdia":
            for media_child in boxes(handle, child.payload_start, child.end):
                if media_child.kind == b"hdlr":
                    payload = read_payload(handle, media_child)
                    video_track = len(payload) >= 12 and payload[8:12] == b"vide"
    if not video_track or tkhd is None:
        return None
    payload = read_payload(handle, tkhd)
    if len(payload) < 8:
        return None
    width_fixed, height_fixed = struct.unpack(">II", payload[-8:])
    return round(width_fixed / 65536), round(height_fixed / 65536)


def inspect_mp4(path: Path) -> tuple[float, int, int]:
    size = path.stat().st_size
    if size < 24:
        raise ValueError("file is too small to be a valid MP4")
    with path.open("rb") as handle:
        top_level = list(boxes(handle, 0, size))
        kinds = {box.kind for box in top_level}
        if b"ftyp" not in kinds or b"moov" not in kinds or b"mdat" not in kinds:
            raise ValueError("file is missing required MP4 boxes")
        moov = next(box for box in top_level if box.kind == b"moov")
        duration = movie_duration(handle, moov)
        dimensions = None
        for child in boxes(handle, moov.payload_start, moov.end):
            if child.kind == b"trak":
                dimensions = track_dimensions(handle, child)
                if dimensions:
                    break
    if not dimensions:
        raise ValueError("MP4 has no readable video track dimensions")
    return duration, dimensions[0], dimensions[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("video", type=Path)
    parser.add_argument("--duration", type=float, required=True)
    parser.add_argument("--tolerance", type=float, default=1.0)
    parser.add_argument("--width", type=int, default=1080)
    parser.add_argument("--height", type=int, default=1920)
    args = parser.parse_args()

    try:
        duration, width, height = inspect_mp4(args.video)
    except (OSError, ValueError) as exc:
        print(f"FAIL: {args.video}: {exc}")
        return 1

    errors = []
    if abs(duration - args.duration) > args.tolerance:
        errors.append(
            f"duration is {duration:.2f}s; expected {args.duration:.2f}s "
            f"± {args.tolerance:.2f}s"
        )
    if (width, height) != (args.width, args.height):
        errors.append(
            f"frame is {width}x{height}; expected {args.width}x{args.height}"
        )
    if errors:
        for error in errors:
            print(f"FAIL: {args.video}: {error}")
        return 1
    print(f"PASS: {args.video} is {width}x{height} and {duration:.2f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
