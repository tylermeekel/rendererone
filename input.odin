package main

import "core:math/linalg"
import "core:math"
import "core:fmt"

import SDL "vendor:sdl2"

Camera :: struct {
    camera_pos: [3]f32,
    camera_front: [3]f32,
    camera_up: [3]f32,
    camera_speed: f32,
    pitch: f32,
    yaw: f32
}

first_mouse := true

init_camera :: proc() -> ^Camera {
    c := new(Camera)

    camera_pos := [3]f32{0, 3, 10}
    camera_up := [3]f32{0, 1, 0}

    c.camera_pos = camera_pos
    c.camera_up = camera_up
    c.camera_speed = 0.05
    c.pitch = -20
    c.yaw = -90

    direction := [3]f32{}
    direction.x = math.cos(math.to_radians(c.yaw)) * math.cos(math.to_radians(c.pitch))
    direction.y = math.sin(math.to_radians(c.pitch))
    direction.z = math.sin(math.to_radians(c.yaw)) * math.cos(math.to_radians(c.pitch))
    c.camera_front = linalg.normalize(direction)

    return c
}

handle_input :: proc(state: ^State) -> bool {
    keystate := SDL.GetKeyboardState(nil)
    cam := state.camera

    current_ticks := SDL.GetTicks()
    state.delta_time = f32(current_ticks - state.last_ticks) / 1000
    state.last_ticks = current_ticks

    cam.camera_speed = 2.5 * state.delta_time
    
    // Continuous-press Keys
    if keystate[SDL.Scancode.W] == 1 {
        cam.camera_pos += cam.camera_speed * cam.camera_front
    }
    if keystate[SDL.Scancode.S] == 1 {
        cam.camera_pos -= cam.camera_speed * cam.camera_front
    }
    if keystate[SDL.Scancode.A] == 1 {
        cam.camera_pos -= linalg.normalize(linalg.cross(cam.camera_front, cam.camera_up)) * cam.camera_speed
    }
    if keystate[SDL.Scancode.D] == 1 {
        cam.camera_pos += linalg.normalize(linalg.cross(cam.camera_front, cam.camera_up)) * cam.camera_speed
    }

    // Single-press Keys and Mouse Movement
    for e: SDL.Event; SDL.PollEvent(&e); {
        #partial switch e.type {
        case .QUIT:
            return true
        case .KEYDOWN:
            #partial switch e.key.keysym.sym {
                case .ESCAPE:
                    return true
            }
        case .WINDOWEVENT:
            if e.window.event == .RESIZED {
                width := e.window.data1
                height := e.window.data2
                renderer_resize(state.renderer, width, height)
            }
            case .MOUSEMOTION:
                if !first_mouse {
                    x_rel := f32(e.motion.xrel) * 0.25
                    y_rel := f32(e.motion.yrel) * 0.25

                    cam.pitch -= y_rel
                    cam.yaw += x_rel

                    if cam.pitch > 89 {
                        cam.pitch = 89
                    }
                    if cam.pitch < -89 {
                        cam.pitch = -89
                    }

                    direction := [3]f32{}
                    direction.x = math.cos(math.to_radians(cam.yaw)) * math.cos(math.to_radians(cam.pitch))
                    direction.y = math.sin(math.to_radians(cam.pitch))
                    direction.z = math.sin(math.to_radians(cam.yaw)) * math.cos(math.to_radians(cam.pitch))
                    cam.camera_front = linalg.normalize(direction)
                } else {
                    first_mouse = false
                }
        }
    }

    renderer_camera_update(state.renderer, cam)

    return false
}

delete_camera :: proc(camera: ^Camera) {
    free(camera)
}