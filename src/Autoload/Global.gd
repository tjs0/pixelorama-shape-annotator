class_name Global
extends Node
## Compile-time stub of Pixelorama's host `Global` singleton.
##
## Like src/Tools/BaseTool.gd, this exists ONLY so the extension's scripts can
## resolve their `Global.*` references when packing the .pck outside the
## Pixelorama source tree. It is EXCLUDED from the exported pack (see
## `res://src/Autoload/*` in export_presets.cfg) so it never ships; at runtime
## Pixelorama provides the real Global autoload, against which the packed
## scripts are recompiled.
##
## Members are declared `static` so `Global.<member>` resolves at parse time the
## same way Pixelorama's autoload-singleton access does. Only the members the
## extension actually reads are declared here.

const CONFIG_PATH := "user://cache.ini"
static var config_cache := ConfigFile.new()
static var current_project: GlobalProjectStub
