package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"

import sg "./sokol/gfx"
import img "vendor:stb/image"

load_texture :: proc(filename: cstring) -> sg.Image {

	t_width, t_height, t_chan: i32
	pixels := img.load(filename, &t_width, &t_height, &t_chan, 4)
	if pixels == nil {
		panic(fmt.tprintf("image failed to load %s", filename))
	}
	defer img.image_free(pixels)

	img_desc := sg.Image_Desc {
		width        = t_width,
		height       = t_height,
		pixel_format = .RGBA8,
	}

	img_desc.data.mip_levels[0] = {
		ptr  = pixels,
		size = uint(t_width * t_height * 4),
	}
	fmt.printf("Loaded: %s [%d %d %d]\n", filename, t_width, t_height, t_chan)
	return sg.make_image(img_desc)
}


load_array_texture_dir :: proc(path: string) -> []cstring {

	files, err := os.read_directory_by_path(path, 0, context.allocator)

	if err != nil {
		panic(fmt.tprintf("invalid array texture, failed to list files in %s, %v", path, err))
	}

	// count how many valid pngs the folder has
	layers := [dynamic]cstring{}

	for file in files {
		if os.is_file(file.fullpath) && strings.has_suffix(file.name, ".png") {
			cpath, err := strings.clone_to_cstring(file.fullpath)
			if err != nil {
				panic("failed to clone string")
			}
			append(&layers, cpath)
		}
	}

	if len(layers) == 0 {
		panic(fmt.tprintf("invalid array texture,  %s, contains no images", path))
	}
	return layers[:]
}

load_array_texture :: proc(paths: []cstring) -> sg.Image {

	assert(len(paths) > 0, "Invalid array texture, no paths provided")
	// TODO: query gfx and check its doesn't exceed max array texture size

	// Assume everything will be the same size as the first element
	width, height, chan: i32
	img.info(paths[0], &width, &height, &chan)

	// allocate pixel buffer
	layer_count := len(paths)
	layer_size := int(width * height * 4)
	total_size := layer_size * layer_count

	big_buffer := make([]u8, total_size)
	defer delete(big_buffer)

	fmt.printf("image with %d\n", layer_count)

	img_desc := sg.Image_Desc {
		type         = .ARRAY,
		width        = width,
		height       = height,
		pixel_format = .RGBA8,
		num_slices   = i32(layer_count),
	}

	for path, i in paths {
		_w, _h, _c: i32

		pixels := img.load(path, &_w, &_h, &_c, 4)
		assert(pixels != nil, "Failed to load image")
		defer img.image_free(pixels)

		// TODO: check h/w/c are correct

		dest := raw_data(big_buffer[i * layer_size:])
		mem.copy(dest, pixels, layer_size)
		fmt.printf("added %s to array texture\n", path)
	}

	img_desc.data.mip_levels[0] = {
		ptr  = raw_data(big_buffer),
		size = uint(total_size),
	}

	return sg.make_image(img_desc)
}
