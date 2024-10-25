package main

import "core:fmt"
import "core:math/linalg"
import "core:math"

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

Renderer :: struct {
    device: ^MTL.Device,
    swapchain: ^CA.MetalLayer,
    window_drawable: ^CA.MetalDrawable,
    command_queue: ^MTL.CommandQueue,
    command_buffer: ^MTL.CommandBuffer,
    pso: ^MTL.RenderPipelineState,
    library: ^MTL.Library,
    depth_stencil_state: ^MTL.DepthStencilState,
    depth_texture: ^MTL.Texture,

    passes: [dynamic]RenderPass,
    uniforms: Uniforms,
    vertex_buffer: ^MTL.Buffer,
    sine_wave_buffer: ^MTL.Buffer
}

init_renderer :: proc(ns_window: ^NS.Window) -> ^Renderer {
    r := new(Renderer)

    device := MTL.CreateSystemDefaultDevice()
	r.device = device

    // TODO: Move this to a list of buffers or something
    vert_buf := r.device->newBufferWithSlice(VERTICES[:], {.StorageModeManaged})
    r.vertex_buffer = vert_buf

    sine_buf := r.device->newBufferWithSlice(SineWaves[:], {.StorageModeManaged})
    r.sine_wave_buffer = sine_buf

	swapchain := CA.MetalLayer.layer()
    r.swapchain = swapchain

	swapchain->setDevice(device)
	swapchain->setPixelFormat(.BGRA8Unorm_sRGB)
	swapchain->setFramebufferOnly(true)
	swapchain->setFrame(ns_window->frame())

	ns_window->contentView()->setLayer(swapchain)
	ns_window->setOpaque(true)
	ns_window->setBackgroundColor(nil)

    command_queue := device->newCommandQueue()
    r.command_queue = command_queue

    shader_src := #load("Shader.metal", string)
	shader_src_str := NS.String.alloc()->initWithOdinString(shader_src)
	defer shader_src_str->release()

	library, err := device->newLibraryWithSource(shader_src_str, nil)
    r.library = library

    depth_desc := MTL.DepthStencilDescriptor.alloc()->init()
    depth_desc->setDepthCompareFunction(.Less)
    depth_desc->setDepthWriteEnabled(true)
    depth_stencil_state := device->newDepthStencilState(depth_desc)
    r.depth_stencil_state = depth_stencil_state
    depth_desc->release()

    // TODO: make this update when the frame changes
    depth_texture_desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
        .Depth32Float,
        WIDTH,
        HEIGHT,
        false
    )
    defer depth_texture_desc->release()

    depth_texture_desc->setUsage({.RenderTarget, .ShaderRead})
    depth_texture_desc->setStorageMode(.Private)

    r.depth_texture = r.device->newTextureWithDescriptor(depth_texture_desc)

    if err != nil {
        fmt.println(err->localizedDescription()->odinString())
    }

    proj := linalg.matrix4_perspective_f32(math.to_radians(f32(45)), 800/600, 0.1, 100)
    view := linalg.Matrix4x4f32(1)
    view *= linalg.matrix4_translate_f32({0, 0, -3})
    model := linalg.Matrix4x4f32(1)

    uniforms := Uniforms{
        projection_matrix = proj,
        view_matrix = view,
        model_matrix = model,
    }

    r.uniforms = uniforms

    //I don't really need a dynamic array, but it wasn't working
    // without it. There is probably a better solution, but I'm
    // not completely familiar with Odin yet.
    append(&r.passes, build_main_renderpass(r))
 
    renderer_resize(r, WIDTH, HEIGHT)

    return r
}

delete_renderer :: proc(renderer: ^Renderer) {
    renderer.device->release()
    renderer.swapchain->release()
    renderer.command_queue->release()
    renderer.library->release()
    renderer.pso->release()
    free(renderer)
}

render :: proc(renderer: ^Renderer) {
    command_buffer := renderer.command_queue->commandBuffer()
    defer command_buffer->release()
    renderer.command_buffer = command_buffer

    drawable := renderer.swapchain->nextDrawable()
    defer drawable->release()
    renderer.window_drawable = drawable

    //MainRenderPass.pass_proc(renderer)

    for pass in renderer.passes {
        renderer.pso = pass.pso
        pass.pass_proc(renderer)
    }

    renderer.command_buffer->presentDrawable(drawable)
	renderer.command_buffer->commit()
}

renderer_resize :: proc(renderer: ^Renderer, width, height: i32) {
    // Set the new drawable size
    nswidth := NS.Float(width)
    nsheight := NS.Float(height)
    renderer.swapchain->setDrawableSize(NS.Size{width = nswidth, height = nsheight})

    // Set width and height to float to allow for
    // non-floor division
    fwidth := f32(width)
    fheight := f32(height)

    // Update the projection matrix
    proj := linalg.matrix4_perspective_f32(math.to_radians(f32(45)), fwidth/fheight, 0.1, 100)
    renderer.uniforms.projection_matrix = proj
}

renderer_camera_update :: proc(renderer: ^Renderer, camera: ^Camera) {
    // Create new lookat matrix using the camera settings
    view := linalg.matrix4_look_at_f32(camera.camera_pos, camera.camera_pos + camera.camera_front, camera.camera_up)

    // update the view matrix using new lookat matrix
    renderer.uniforms.view_matrix = view
    renderer.uniforms.camera_pos = camera.camera_pos
}