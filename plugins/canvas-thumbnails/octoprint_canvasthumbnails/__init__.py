import datetime
import os
from pathlib import Path
from urllib.parse import quote

import octoprint.plugin

from .renderer import render_thumbnail


class CanvasThumbnailsPlugin(
    octoprint.plugin.EventHandlerPlugin,
):

    def _is_canvas_gcode(self, filename):
        try:
            with open(filename, "r", errors="replace") as fh:
                for line_number, line in enumerate(fh):
                    if (
                        line.startswith("O25 ")
                        or "; Printing with input " in line
                    ):
                        return True

                    if line_number >= 500:
                        break

        except OSError:
            self._logger.exception(
                "Unable to inspect G-code: %s",
                filename,
            )

        return False


    def _thumbnail_filename(self, gcode_path):
        relative = Path(gcode_path).with_suffix(".png")

        return os.path.join(
            self.get_plugin_data_folder(),
            str(relative),
        )


    def _thumbnail_url(self, gcode_path):
        relative = Path(gcode_path).with_suffix(".png")
        parts = list(relative.parts)

        encoded = "/".join(
            quote(part, safe="")
            for part in parts
        )

        timestamp = datetime.datetime.now().strftime(
            "%Y%m%d%H%M%S"
        )

        return (
            f"plugin/canvasthumbnails/thumbnail/"
            f"{encoded}?{timestamp}"
        )


    def _generate_thumbnail(self, gcode_path):
        gcode_filename = self._file_manager.path_on_disk(
            "local",
            gcode_path,
        )

        if not self._is_canvas_gcode(gcode_filename):
            self._logger.debug(
                "Not CANVAS G-code, ignoring: %s",
                gcode_path,
            )
            return False

        thumbnail_filename = self._thumbnail_filename(
            gcode_path
        )

        os.makedirs(
            os.path.dirname(thumbnail_filename),
            exist_ok=True,
        )

        temporary = thumbnail_filename + ".tmp"

        try:
            render_thumbnail(
                Path(gcode_filename),
                Path(temporary),
            )

            os.replace(
                temporary,
                thumbnail_filename,
            )

        except Exception:
            self._logger.exception(
                "Failed rendering CANVAS thumbnail for %s",
                gcode_path,
            )

            if os.path.exists(temporary):
                os.remove(temporary)

            return False

        thumbnail_url = self._thumbnail_url(gcode_path)

        self._file_manager.set_additional_metadata(
            "local",
            gcode_path,
            "thumbnail",
            thumbnail_url,
            overwrite=True,
        )

        self._file_manager.set_additional_metadata(
            "local",
            gcode_path,
            "thumbnail_src",
            self._identifier,
            overwrite=True,
        )

        self._logger.info(
            "Generated CANVAS thumbnail for %s",
            gcode_path,
        )

        return True


    def _remove_thumbnail(self, gcode_path):
        thumbnail_filename = self._thumbnail_filename(
            gcode_path
        )

        try:
            if os.path.exists(thumbnail_filename):
                os.remove(thumbnail_filename)

        except OSError:
            self._logger.exception(
                "Failed removing CANVAS thumbnail for %s",
                gcode_path,
            )


    def on_event(self, event, payload):
        if event not in ("FileAdded", "FileRemoved"):
            return

        if payload.get("storage") != "local":
            return

        file_type = payload.get("type", [])

        if "gcode" not in file_type:
            return

        gcode_path = payload.get("path")

        if not gcode_path:
            return

        if event == "FileRemoved":
            self._remove_thumbnail(gcode_path)
            return

        # Do not overwrite a thumbnail another plugin already supplied.
        try:
            metadata = self._file_manager.get_metadata(
                "local",
                gcode_path,
            ) or {}

            existing_thumbnail = metadata.get("thumbnail")

            if existing_thumbnail:
                self._logger.debug(
                    "Thumbnail already exists for %s; "
                    "CANVAS fallback not needed",
                    gcode_path,
                )
                return

        except Exception:
            self._logger.debug(
                "Could not inspect existing thumbnail metadata "
                "for %s",
                gcode_path,
                exc_info=True,
            )

        self._generate_thumbnail(gcode_path)


    def route_hook(
        self,
        server_routes,
        *args,
        **kwargs,
    ):
        from octoprint.server import app
        from octoprint.server.util.flask import (
            permission_validator,
        )
        from octoprint.server.util.tornado import (
            LargeResponseHandler,
            access_validation_factory,
            path_validation_factory,
        )
        from octoprint.util import is_hidden_path
        from octoprint.access.permissions import Permissions

        return [
            (
                r"thumbnail/(.*)",
                LargeResponseHandler,
                {
                    "path": self.get_plugin_data_folder(),
                    "as_attachment": False,
                    "path_validation":
                        path_validation_factory(
                            lambda path:
                                not is_hidden_path(path),
                            status_code=404,
                        ),
                    "access_validation":
                        access_validation_factory(
                            app,
                            permission_validator,
                            Permissions.FILES_LIST,
                        ),
                },
            )
        ]


__plugin_name__ = "CANVAS Thumbnails"
__plugin_description__ = (
    "Generates Palette-aware thumbnails "
    "for Mosaic CANVAS G-code."
)
__plugin_version__ = "0.1.0"
__plugin_pythoncompat__ = ">=3.8,<4"


def __plugin_load__():
    global __plugin_implementation__

    __plugin_implementation__ = CanvasThumbnailsPlugin()

    global __plugin_hooks__

    __plugin_hooks__ = {
        "octoprint.server.http.routes":
            __plugin_implementation__.route_hook,
    }
