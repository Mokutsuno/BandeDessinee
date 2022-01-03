using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class EdgeDetectionRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public sealed class EdgeDetectionSettings
    {
        public bool Enabled;
        public RenderPassEvent Event = RenderPassEvent.BeforeRenderingPostProcessing;
        public RenderQueueRange RenderQueueRange = RenderQueueRange.all;
        public LayerMask LayerMask;
    }

    [SerializeField]
    EdgeDetectionSettings settings = new EdgeDetectionSettings();

    EdgeDetectionPass edgeDetectionPass;

    public override void Create()
    {
        edgeDetectionPass = new EdgeDetectionPass(
            settings.Event,
            settings.RenderQueueRange,
            settings.LayerMask);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        edgeDetectionPass.SourceIdentifier = renderer.cameraColorTarget;
        renderer.EnqueuePass(edgeDetectionPass);
    }
}


public sealed class EdgeDetectionPass : ScriptableRenderPass
{
    public RenderTargetIdentifier SourceIdentifier { get; set; }

    private RenderTargetHandle depthNormalTargetHandle { get; set; }

    readonly RenderTargetHandle normalTargetHandle;
    readonly ShaderTagId shaderTagId = new ShaderTagId("NormalOnly");

    FilteringSettings filteringSettings;

    public EdgeDetectionPass(
        RenderPassEvent renderPassEvent,
        RenderQueueRange renderQueueRange,
        LayerMask layerMask)
    {
        this.renderPassEvent = renderPassEvent;

        filteringSettings = new FilteringSettings(renderQueueRange, layerMask);

        normalTargetHandle.Init("_NormalTexture");
    }

    public void Setup(RenderTextureDescriptor baseDescriptor, RenderTargetHandle depthAttachmentHandle)
    {
        this.depthNormalTargetHandle = depthAttachmentHandle;
        baseDescriptor.colorFormat = RenderTextureFormat.ARGB32;
    }
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        var descriptor = new RenderTextureDescriptor(
            cameraTextureDescriptor.width / 2,
            cameraTextureDescriptor.height / 2,
            RenderTextureFormat.ARGB32,
            8,
            0);

        cmd.GetTemporaryRT(depthNormalTargetHandle.id, descriptor);
        ConfigureTarget(depthNormalTargetHandle.id);
        ConfigureClear(ClearFlag.All, Color.black);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get("EdgeDetection");
        using (new ProfilingSample(cmd, "DepthNormals Pass"))
        {
            var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
            var drawSettings = CreateDrawingSettings(shaderTagId, ref renderingData, sortFlags);
            drawSettings.perObjectData = PerObjectData.None;

            context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filteringSettings);
            cmd.SetGlobalTexture("_DepthNormalsTexture", depthNormalTargetHandle.id);
            // cmd.Blit(depthNormalTargetHandle.id, SourceIdentifier);
        }
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void FrameCleanup(CommandBuffer cmd)
    {
        cmd.ReleaseTemporaryRT(depthNormalTargetHandle.id);
    }
}