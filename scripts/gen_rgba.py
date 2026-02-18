#!/usr/bin/env python3
import sys
import struct


def write_fixture(path, width, height, pixels):
    with open(path, "wb") as f:
        f.write(struct.pack("<I", width))
        f.write(struct.pack("<I", height))
        f.write(bytes(pixels))


def make_palette_stats_a(path):
    width = 4
    height = 4
    pixels = []
    for i in range(width * height):
        if i % 5 == 0:
            pixels += [0, 0, 255, 255]
        else:
            pixels += [255, 0, 0, 255]
    write_fixture(path, width, height, pixels)


def make_palette_stats_b(path):
    width = 4
    height = 4
    pixels = []
    for i in range(width * height):
        if i % 3 == 0:
            pixels += [0, 255, 0, 255]
        else:
            pixels += [255, 255, 0, 255]
    write_fixture(path, width, height, pixels)


def make_threads_8x8(path):
    width = 8
    height = 8
    pixels = []
    for i in range(width * height):
        if i % 7 == 0:
            pixels += [123, 50, 200, 255]
        else:
            pixels += [10, 200, 100, 255]
    write_fixture(path, width, height, pixels)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "spec/fixtures"
    make_palette_stats_a(out + "/palette_stats_a_4x4.bin")
    make_palette_stats_b(out + "/palette_stats_b_4x4.bin")
    make_threads_8x8(out + "/palette_threads_8x8.bin")
    # leave larger favicon/32x32 generation to the Crystal generator for parity
    print("wrote fixtures to", out)
