from setuptools import setup

plugin_identifier = "canvasthumbnails"
plugin_package = "octoprint_canvasthumbnails"
plugin_name = "CANVAS Thumbnails"
plugin_version = "0.1.0"
plugin_description = "Generates Palette-aware thumbnails for Mosaic CANVAS G-code."

setup(
    name="OctoPrint-CanvasThumbnails",
    version=plugin_version,
    description=plugin_description,
    packages=[plugin_package],
    include_package_data=True,
    zip_safe=False,
    install_requires=[
        "Pillow>=9",
    ],
    entry_points={
        "octoprint.plugin": [
            f"{plugin_identifier} = {plugin_package}"
        ]
    },
)
