﻿using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class OutlineMaskFeature :  ScriptableRendererFeature
{
    class OutlineMaskPass : ScriptableRenderPass
    {
        int kDepthBufferBits = 32;
        private RenderTargetHandle depthAttachmentHandle { get; set; }
        internal RenderTextureDescriptor descriptor { get; private set; }

        private Material outlineMaskMaterial = null;
        private FilteringSettings m_FilteringSettings;
        string m_ProfilerTag = "DepthNormals Prepass";
        ShaderTagId m_ShaderTagId = new ShaderTagId("DepthOnly");

        public OutlineMaskPass(RenderQueueRange renderQueueRange, LayerMask layerMask, Material material)
        {
            m_FilteringSettings = new FilteringSettings(renderQueueRange, layerMask);
            outlineMaskMaterial = material;
        }

        public void Setup(RenderTextureDescriptor baseDescriptor, RenderTargetHandle depthAttachmentHandle)
        {
            this.depthAttachmentHandle = depthAttachmentHandle;
            baseDescriptor.colorFormat = RenderTextureFormat.ARGB32;
            baseDescriptor.depthBufferBits = kDepthBufferBits;
            descriptor = baseDescriptor;
        }

        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in an performance manner.
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            cmd.GetTemporaryRT(depthAttachmentHandle.id, descriptor, FilterMode.Point);
            ConfigureTarget(depthAttachmentHandle.Identifier());
            ConfigureClear(ClearFlag.All, Color.black);
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        //https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@7.1/api/UnityEngine.Rendering.Universal.ScriptableRenderPass.html << Executeについて
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);

            using (new ProfilingSample(cmd, m_ProfilerTag))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
                var drawSettings = CreateDrawingSettings(m_ShaderTagId, ref renderingData, sortFlags);
                drawSettings.perObjectData = PerObjectData.None;


                ref CameraData cameraData = ref renderingData.cameraData;
                Camera camera = cameraData.camera;
                if (cameraData.isStereoEnabled)
                    context.StartMultiEye(camera);


                drawSettings.overrideMaterial = outlineMaskMaterial;    // マテリアルをオーバーライドか？


                context.DrawRenderers(renderingData.cullResults, ref drawSettings,
                    ref m_FilteringSettings);

                cmd.SetGlobalTexture("_OutlineMaskTexture", depthAttachmentHandle.id);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        /// Cleanup any allocated resources that were created during the execution of this render pass.
        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (depthAttachmentHandle != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(depthAttachmentHandle.id);
                depthAttachmentHandle = RenderTargetHandle.CameraTarget;
            }
        }
    }

    OutlineMaskPass outlineMaskPass;
    RenderTargetHandle outlineMaskTexture;
    Material outlineMaskMaterial;

    public override void Create()   //Initializes this feature's resources.
    {
        outlineMaskMaterial = CoreUtils.CreateEngineMaterial("Hidden/OutlineMask");                 //ここを任意のマテリアルに設定してあげる
        outlineMaskPass = new OutlineMaskPass(RenderQueueRange.opaque, -1, outlineMaskMaterial);
        outlineMaskPass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
        outlineMaskTexture.Init("_OutlineMaskTexture");
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        outlineMaskPass.Setup(renderingData.cameraData.cameraTargetDescriptor, outlineMaskTexture);
        renderer.EnqueuePass(outlineMaskPass);
    }
}
