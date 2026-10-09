package main

import "core:fmt"
import img "vendor:stb/image"

WIDTH :: 128
HEIGHT :: 128
SEED :: 1234

Pixel_RGB :: struct #packed {
    r, g, b: u8,
}

generate_2d_noise_png :: proc() {

	pixels := make([]Pixel_RGB, HEIGHT * WIDTH)
	i := 0;
	for j in 0..<HEIGHT {
		for i in 0..<WIDTH {
			noise := curl_noise_2d(SEED, [2]f32{ f32(i), f32(j)} )
			pixels[j+i].r = u8(256 * noise[0] )
			pixels[j+i].g = u8(256 * noise[1])
			pixels[j+i].b = 0
			fmt.printfln("%v, r: %d g: %d", noise, pixels[j+i].r, pixels[j+i].g)

		}
	}

	img.write_png("curl.png", 128, 128, 3, rawptr(&pixels), 3)
}
