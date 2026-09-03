# coding=utf-8

import octoprint.plugin
from flask import url_for


class SaturnCanvasThemePlugin(
    octoprint.plugin.AssetPlugin,
    octoprint.plugin.StartupPlugin
):
    def get_assets(self):
        return dict(
            css=["css/saturn_canvas.css"]
        )

    def on_after_startup(self):
        self._logger.info("Saturn CANVAS Theme loaded")


def login_theming_hook(*args, **kwargs):
    return [
        url_for(
            "plugin.saturn_canvas_theme.static",
            filename="css/saturn_canvas.css"
        )
    ]


__plugin_name__ = "Saturn CANVAS Theme"
__plugin_pythoncompat__ = ">=3.9,<4"

__plugin_implementation__ = SaturnCanvasThemePlugin()

__plugin_hooks__ = {
    "octoprint.theming.login": login_theming_hook
}
