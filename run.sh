#!/bin/bash

../../sokol/sokol-tools-bin/bin/linux/sokol-shdc -i shaders/displayshader.glsl -o shaders/displayshader.odin -l glsl430 -f sokol_odin
../../sokol/sokol-tools-bin/bin/linux/sokol-shdc -i shaders/shader.glsl -o shaders/shader.odin -l glsl430 -f sokol_odin
../../sokol/sokol-tools-bin/bin/linux/sokol-shdc -i shaders/gridshader.glsl -o shaders/gridshader.odin -l glsl430 -f sokol_odin
../../sokol/sokol-tools-bin/bin/linux/sokol-shdc -i shaders/skyshader.glsl -o shaders/skyshader.odin -l glsl430 -f sokol_odin
../../sokol/sokol-tools-bin/bin/linux/sokol-shdc -i shaders/billboard.glsl -o shaders/billboard.odin -l glsl430 -f sokol_odin
../../sokol/sokol-tools-bin/bin/linux/sokol-shdc -i shaders/terrain.glsl -o shaders/terrain.odin -l glsl430 -f sokol_odin
../../sokol/sokol-tools-bin/bin/linux/sokol-shdc -i shaders/meshshader.glsl -o shaders/meshshader.odin -l glsl430 -f sokol_odin


odin run .
