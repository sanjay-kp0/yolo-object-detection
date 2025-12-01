## Keep SnakeYAML classes used by ultralytics_yolo
-keep class org.yaml.snakeyaml.** { *; }

## SnakeYAML references java.beans APIs that don't exist on Android.
## Suppress R8 missing-class warnings for these optional types.
-dontwarn java.beans.**

