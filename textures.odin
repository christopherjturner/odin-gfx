package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"

import sg "./sokol/gfx"
import img "vendor:stb/image"

Texture_Manager :: struct {
	textures: map[string]sg.Image,
}

texture_manager_init :: proc(tm: ^Texture_Manager) {
	tm.textures = make(map[string]sg.Image)
}

texture_manager_destroy :: proc(tm: ^Texture_Manager) {
	for path, img in tm.textures {
		sg.destroy_image(img)
	}
	delete(tm.textures)
}

get_texture :: proc(tm: ^Texture_Manager, path: string) -> sg.Image {
	if img, exists := tm.textures[path]; exists {
		return img
	}

	new_img, ok := load_texture(strings.clone_to_cstring(path, context.temp_allocator))
	if ok {
		tm.textures[strings.clone(path)] = new_img
	} else {
		// TODO: work out how to handle the error better
		panic(fmt.tprintf("image failed to load %s", path))
	}

	return new_img
}

get_array_texture :: proc(tm: ^Texture_Manager, path: string) -> sg.Image {
	if img, exists := tm.textures[path]; exists {
		return img
	}

	if !os.is_dir(path) {
		fmt.printfln("failed to load array textures %s is not a dir", path)
		panic(fmt.tprintf("failed to load array textures %s is not a dir", path))
	}

	new_img, ok := load_array_texture_dir(path)
	if ok {
		tm.textures[strings.clone(path)] = new_img
	} else {
		panic(fmt.tprintf("image failed to load %s", path))
	}

	return new_img
}

load_texture :: proc(path: cstring) -> (sg.Image, bool) {

	t_width, t_height, t_chan: i32
	pixels := img.load(path, &t_width, &t_height, &t_chan, 4)
	if pixels == nil {
		fmt.printfln("image failed to load %s", path)
		//panic("failed to load image")
		return sg.Image{}, false
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
	fmt.printf("Loaded: %s [%d %d %d]\n", path, t_width, t_height, t_chan)
	return sg.make_image(img_desc), true
}


load_array_texture_dir :: proc(path: string) -> (sg.Image, bool) {

	files, err := os.read_directory_by_path(path, 0, context.allocator)

	if err != nil {
		panic(fmt.tprintf("invalid array texture, failed to list files in %s, %v", path, err))
	}

	// count how many valid pngs the folder has
	layers := [dynamic]cstring{}

	for file in files {
		if os.is_file(file.fullpath) && strings.has_suffix(file.name, ".png") {
			cpath, err := strings.clone_to_cstring(file.fullpath, context.temp_allocator)
			if err != nil {
				panic("failed to clone string")
			}
			append(&layers, cpath)
		}
	}

	if len(layers) == 0 {
		fmt.printfln("invalid array texture,  %s, contains no images", path)
		return sg.Image{}, false
	}
	return load_array_texture(layers[:])
}

load_array_texture :: proc(paths: []cstring) -> (sg.Image, bool) {

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

	return sg.make_image(img_desc), true
}
