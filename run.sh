#!/bin/bash

../../sokol/sokol-tools-bin/bin/linux/sokol-shdc -i displayshader.glsl -o displayshader.odin -l glsl430 -f sokol_odin
../../sokol/sokol-tools-bin/bin/linux/sokol-shdc -i shader.glsl -o shader.odin -l glsl430 -f sokol_odin
../../sokol/sokol-tools-bin/bin/linux/sokol-shdc -i gridshader.glsl -o gridshader.odin -l glsl430 -f sokol_odin
../../sokol/sokol-tools-bin/bin/linux/sokol-shdc -i skyshader.glsl -o skyshader.odin -l glsl430 -f sokol_odin

odin run .
