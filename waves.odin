package main

import "core:math/rand"

SineWave :: struct {
    amplitude: f32,
    wavelength: f32,
    speed: f32,
    direction: [2]f32,
}

SineWaves: []SineWave

generate_sine_waves :: proc(num_waves: int) -> []SineWave {
    // 2 is nice!
    rand_state := rand.create(2)
    generator := rand.default_random_generator(&rand_state)
    waves := make([]SineWave, num_waves)

    direction_min :: f32(-1)
    direction_max :: f32(1)
    speed_min :: f32(1)
    speed_max :: f32(1.4)

    for i in 0..<num_waves {
        wave: SineWave

        wave.amplitude = 0.04
        wave.wavelength = rand.float32_range(0.7, 2, generator)
        wave.direction.x = rand.float32_range(direction_min, direction_max, generator)
        wave.direction.y = rand.float32_range(direction_min, direction_max, generator)
        wave.speed = rand.float32_range(speed_min, speed_max, generator)

        waves[i] = wave
    }

    return waves
}