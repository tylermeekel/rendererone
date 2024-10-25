package main

import NS "core:sys/darwin/Foundation"
import MTL "vendor:darwin/Metal"
import SDL "vendor:sdl2"

import "core:fmt"
import "core:mem"
import "core:math/linalg"
import "core:math"

Vertex :: struct {
    position: [3]f32
}

Uniforms :: struct {
    projection_matrix: matrix[4,4]f32,
    view_matrix: matrix[4,4]f32,
    model_matrix: matrix[4,4]f32,
    camera_pos: [3]f32,
}

MainRenderPassParams :: struct {
    time: f32,
    num_sines: i32,
}

RenderPass :: struct {
    pass_proc: proc(renderer: ^Renderer),
    pso: ^MTL.RenderPipelineState,
}

VERTICES: []Vertex

build_main_renderpass :: proc(renderer: ^Renderer) -> RenderPass {
    vertex_function   := renderer.library->newFunctionWithName(NS.AT("vertex_main"))
	fragment_function := renderer.library->newFunctionWithName(NS.AT("fragment_main"))
	defer vertex_function->release()
	defer fragment_function->release()

	desc := MTL.RenderPipelineDescriptor.alloc()->init()
	defer desc->release()

	desc->setVertexFunction(vertex_function)
	desc->setFragmentFunction(fragment_function)
	desc->colorAttachments()->object(0)->setPixelFormat(.BGRA8Unorm_sRGB)
    desc->setDepthAttachmentPixelFormat(.Depth32Float)

	pso, err := renderer.device->newRenderPipelineStateWithDescriptor(desc)

    return RenderPass {
        pso = pso,
        pass_proc = main_render_pass_proc
    }
}

@(private="file")
main_render_pass_proc :: proc(renderer: ^Renderer) {
    pass := MTL.RenderPassDescriptor.renderPassDescriptor()
    defer pass->release()

    color_attachment := pass->colorAttachments()->object(0)
    assert(color_attachment != nil)
    color_attachment->setClearColor(MTL.ClearColor{1.0, 0.81, 0.7, 1.0})
    color_attachment->setLoadAction(.Clear)
    color_attachment->setStoreAction(.Store)
    color_attachment->setTexture(renderer.window_drawable->texture())

    depth_attachment := pass->depthAttachment()
    depth_attachment->setTexture(renderer.depth_texture)
    depth_attachment->setClearDepth(1.0)
    depth_attachment->setLoadAction(.Clear)
    depth_attachment->setStoreAction(.Store)

    render_encoder := renderer.command_buffer->renderCommandEncoderWithDescriptor(pass)
    defer render_encoder->release()

    render_encoder->setRenderPipelineState(renderer.pso)
    render_encoder->setDepthStencilState(renderer.depth_stencil_state)

    time := f32(SDL.GetTicks()) / 1000

    params := MainRenderPassParams {
        time,
        i32(len(SineWaves))
    }

    render_encoder->setVertexBuffer(renderer.vertex_buffer, 0, 0)
    render_encoder->setVertexBytes(mem.ptr_to_bytes(&renderer.uniforms), 1)
    render_encoder->setVertexBytes(mem.ptr_to_bytes(&params), 2)

    //render_encoder->setTriangleFillMode(.Lines)

    render_encoder->setVertexBuffer(renderer.sine_wave_buffer, 0, 11)

    render_encoder->setFragmentTexture(renderer.depth_texture, 21)

    render_encoder->drawPrimitives(.Triangle, 0, NS.UInteger(len(VERTICES)))

    render_encoder->endEncoding()
}