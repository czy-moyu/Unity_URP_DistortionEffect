using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DistortionFeature : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        private RenderTargetHandle tempColorTarget;
        private RenderingData? renderingData;

        public CustomRenderPass()
        {
            tempColorTarget = new RenderTargetHandle();
            tempColorTarget.Init("_CameraTransparentTexture");
        }
        
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            this.renderingData = renderingData;
            if (renderingData.cameraData.camera != Camera.main)
            {
                return;
            }
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
            descriptor.width /= 2;
            descriptor.height /= 2;
            cmd.GetTemporaryRT(tempColorTarget.id, descriptor);
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.camera != Camera.main)
            {
                return;
            }

            CommandBuffer cmd = CommandBufferPool.Get("Distortion");
            cmd.Clear();
            Blit(cmd, renderingData.cameraData.renderer.cameraColorTarget, tempColorTarget.Identifier());
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            if (renderingData == null)
            {
                return;
            }
            if (((RenderingData)renderingData).cameraData.camera != Camera.main)
            {
                return;
            }
            cmd.ReleaseTemporaryRT(tempColorTarget.id);
        }
    }

    class CustomRenderPass2 : ScriptableRenderPass
    {
        private ShaderTagId _shaderTagId = new ShaderTagId("Distortion");
        private FilteringSettings _filteringSettings = FilteringSettings.defaultValue;

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.camera != Camera.main)
            {
                return;
            }
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.camera != Camera.main)
            {
                return;
            }
            var drawingSettings = CreateDrawingSettings(_shaderTagId, ref renderingData, 
                renderingData.cameraData.defaultOpaqueSortFlags);
            context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref _filteringSettings);
        }
    }

    CustomRenderPass customRenderPass;
    private CustomRenderPass2 _customRenderPass2;

    /// <inheritdoc/>
    public override void Create()
    {
        customRenderPass = new CustomRenderPass();
        customRenderPass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        
        _customRenderPass2 = new CustomRenderPass2();
        _customRenderPass2.renderPassEvent = RenderPassEvent.AfterRenderingTransparents + 1;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(customRenderPass);
        renderer.EnqueuePass(_customRenderPass2);
    }
}


