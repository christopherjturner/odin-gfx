#!/usr/bin/env bash
set -euo pipefail

odin check .

SHDC="../../sokol/sokol-tools-bin/bin/linux/sokol-shdc"
SHADER_DIR="shaders"

shaders=(
  displayshader
  shader
  gridshader
  skyshader
  billboard
  terrain
  meshshader
  starshader
  gameuishader
)

compile_shader() {
  local name="$1"
  local in_file="$SHADER_DIR/$name.glsl"
  #local out_file="$SHADER_DIR/$name.odin"
  local out_file="/dev/null"

  if [[ ! -f "$out_file" || "$in_file" -nt "$out_file" ]]; then
    echo "Checking $name"
    "$SHDC" -i "$in_file" -o "$out_file" -l glsl430 -f sokol_odin
  else
    echo "Up to date: $name"
  fi
}

for shader in "${shaders[@]}"; do
  compile_shader "$shader"
done

odin check .
