package main

import NS  "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA  "vendor:darwin/QuartzCore"

import SDL "vendor:sdl2"

import "core:math/linalg"
import "core:math"
import "core:mem"
import "core:fmt"
import "core:os"

WIDTH :: 1366
HEIGHT :: 768

State :: struct {
    renderer: ^Renderer,
    camera: ^Camera,
    last_ticks: u32,
    delta_time: f32,
}

metal_main :: proc() -> (err: ^NS.Error) {
	SDL.SetHint(SDL.HINT_RENDER_DRIVER, "metal")
	SDL.setenv("METAL_DEVICE_WRAPPER_TYPE", "1", 0)
	SDL.Init({.VIDEO})
	defer SDL.Quit()

    SDL.SetRelativeMouseMode(true)

	window := SDL.CreateWindow("Metal Renderer",
		SDL.WINDOWPOS_CENTERED, SDL.WINDOWPOS_CENTERED,
		WIDTH, HEIGHT,
		{.ALLOW_HIGHDPI, .HIDDEN, .RESIZABLE},
	)
	defer SDL.DestroyWindow(window)

	window_system_info: SDL.SysWMinfo
	SDL.GetVersion(&window_system_info.version)
	SDL.GetWindowWMInfo(window, &window_system_info)
	assert(window_system_info.subsystem == .COCOA)

	native_window := (^NS.Window)(window_system_info.info.cocoa.window)

    // TODO: REMOVE THIS AT SOME POINT!
    VERTICES = create_plane(100, 100, 600, 600)
	SineWaves = generate_sine_waves(200)

    renderer := init_renderer(native_window)
    defer delete_renderer(renderer)

    camera := init_camera()
    defer delete_camera(camera)
    renderer_camera_update(renderer, camera)

    state := State {
        renderer,
        camera,
        0,
        0,
    }

	SDL.ShowWindow(window)
	for quit := false; !quit;  {
		quit = handle_input(&state)
		render(renderer)
	}

	return nil
}

main :: proc() {

	err := metal_main()
	if err != nil {
		fmt.eprintln(err->localizedDescription()->odinString())
		os.exit(1)
	}
}