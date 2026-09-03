#!/opt/octoprint-status/venv/bin/python

import math
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw


SIZE = 600
PADDING = 30
BACKGROUND = (32, 34, 37, 0)

INPUT_RE = re.compile(r";\s*Printing with input\s+(\d+)")
TYPE_RE = re.compile(r";TYPE:(.+)")
PARAM_RE = re.compile(r"([XYZEIJK])(-?\d+(?:\.\d+)?)")
COLOR_RE = re.compile(r"D1([0-9A-Fa-f]{6})([^\s]*)")


def parse_palette_colors(line):
    colors = {}

    if not line.startswith("O25 "):
        return colors

    for index, match in enumerate(COLOR_RE.finditer(line)):
        hex_color = match.group(1)

        colors[index] = (
            int(hex_color[0:2], 16),
            int(hex_color[2:4], 16),
            int(hex_color[4:6], 16),
            255,
        )

    return colors


def parse_params(line):
    return {
        key: float(value)
        for key, value in PARAM_RE.findall(line)
    }


def arc_points(x0, y0, x1, y1, i, j, clockwise):
    cx = x0 + i
    cy = y0 + j
    radius = math.hypot(x0 - cx, y0 - cy)

    if radius == 0:
        return [(x1, y1)]

    start = math.atan2(y0 - cy, x0 - cx)
    end = math.atan2(y1 - cy, x1 - cx)

    if clockwise:
        while end >= start:
            end -= 2 * math.pi
    else:
        while end <= start:
            end += 2 * math.pi

    sweep = end - start

    steps = max(
        4,
        min(
            180,
            int(abs(sweep) / math.radians(2)) + 1,
        ),
    )

    points = []

    for n in range(1, steps + 1):
        angle = start + sweep * (n / steps)

        points.append(
            (
                cx + radius * math.cos(angle),
                cy + radius * math.sin(angle),
            )
        )

    points[-1] = (x1, y1)

    return points


def collect_segments(filename):
    segments = []
    palette_colors = {}

    x = 0.0
    y = 0.0
    e = 0.0

    absolute_xy = True
    absolute_e = True

    current_input = 0
    current_type = ""
    model_started = False

    with open(filename, "r", errors="replace") as fh:
        for raw in fh:
            line = raw.strip()

            if not line:
                continue

            if line.startswith("O25 "):
                parsed = parse_palette_colors(line)

                if parsed:
                    palette_colors.update(parsed)

                continue

            if line.startswith(";LAYER_CHANGE"):
                model_started = True
                continue

            match = INPUT_RE.search(line)

            if match:
                current_input = int(match.group(1))
                continue

            match = TYPE_RE.search(line)

            if match:
                current_type = match.group(1).strip()
                continue

            command = line.split(";", 1)[0].strip()

            if not command:
                continue

            if command.startswith("G90"):
                absolute_xy = True
                continue

            if command.startswith("G91"):
                absolute_xy = False
                continue

            if command.startswith("M82"):
                absolute_e = True
                continue

            if command.startswith("M83"):
                absolute_e = False
                continue

            if command.startswith("G92"):
                params = parse_params(command)

                if "X" in params:
                    x = params["X"]

                if "Y" in params:
                    y = params["Y"]

                if "E" in params:
                    e = params["E"]

                continue

            if not (
                command.startswith("G0 ")
                or command.startswith("G1 ")
                or command.startswith("G2 ")
                or command.startswith("G3 ")
            ):
                continue

            params = parse_params(command)

            nx = x
            ny = y

            if "X" in params:
                nx = params["X"] if absolute_xy else x + params["X"]

            if "Y" in params:
                ny = params["Y"] if absolute_xy else y + params["Y"]

            new_e = e

            if "E" in params:
                new_e = params["E"] if absolute_e else e + params["E"]

            extruding = (
                "E" in params
                and new_e > e + 0.00001
                and (nx != x or ny != y)
            )

            ignore = (
                not model_started
                or current_type.lower() == "wipe tower"
            )

            if extruding and not ignore:
                color_index = current_input

                if command.startswith("G2 ") or command.startswith("G3 "):
                    if "I" in params or "J" in params:
                        points = arc_points(
                            x,
                            y,
                            nx,
                            ny,
                            params.get("I", 0.0),
                            params.get("J", 0.0),
                            clockwise=command.startswith("G2 "),
                        )

                        px = x
                        py = y

                        for ax, ay in points:
                            segments.append(
                                (px, py, ax, ay, color_index)
                            )
                            px = ax
                            py = ay
                    else:
                        segments.append(
                            (x, y, nx, ny, color_index)
                        )
                else:
                    segments.append(
                        (x, y, nx, ny, color_index)
                    )

            x = nx
            y = ny
            e = new_e

    return segments, palette_colors


def render_thumbnail(filename, output):
    segments, colors = collect_segments(filename)

    if not segments:
        raise RuntimeError("No printable extrusion segments found")

    xs = []
    ys = []

    for x1, y1, x2, y2, _ in segments:
        xs.extend((x1, x2))
        ys.extend((y1, y2))

    min_x = min(xs)
    max_x = max(xs)
    min_y = min(ys)
    max_y = max(ys)

    width = max_x - min_x
    height = max_y - min_y

    if width <= 0 or height <= 0:
        raise RuntimeError("Invalid model bounds")

    drawable = SIZE - (PADDING * 2)
    scale = min(drawable / width, drawable / height)

    image = Image.new("RGBA", (SIZE, SIZE), BACKGROUND)
    draw = ImageDraw.Draw(image)

    def convert(px, py):
        sx = PADDING + (px - min_x) * scale
        sy = SIZE - PADDING - (py - min_y) * scale
        return sx, sy

    fallback_colors = {
        0: (240, 240, 240, 255),
        1: (235, 80, 80, 255),
        2: (40, 40, 40, 255),
        3: (70, 120, 220, 255),
    }

    line_width = max(1, round(scale * 0.42))
    outline_width = line_width + 2
    outline_color = (18, 18, 18, 220)

    for x1, y1, x2, y2, input_number in segments:
        p1 = convert(x1, y1)
        p2 = convert(x2, y2)

        color = colors.get(
            input_number,
            fallback_colors.get(
                input_number,
                (180, 180, 180, 255),
            ),
        )

        draw.line(
            [p1, p2],
            fill=outline_color,
            width=outline_width,
        )

        draw.line(
            [p1, p2],
            fill=color,
            width=line_width,
        )

    image.save(output, "PNG")

    print(f"Rendered: {output}")
    print(f"Segments: {len(segments)}")
    print(
        f"Bounds: X {min_x:.2f}-{max_x:.2f}, "
        f"Y {min_y:.2f}-{max_y:.2f}"
    )
    print(f"Palette inputs: {colors}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(
            "Usage: canvas_thumbnail.py INPUT.gcode OUTPUT.png",
            file=sys.stderr,
        )
        sys.exit(2)

    render_thumbnail(
        Path(sys.argv[1]),
        Path(sys.argv[2]),
    )
