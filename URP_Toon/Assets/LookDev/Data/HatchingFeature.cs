using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


public class HatchingFeature : ScriptableRendererFeature
{
    class HatchingPass : ScriptableRenderPass
    {
        int kDepthBufferBits = 32;
        private RenderTargetHandle m_hatchingTexture { get; set; }

        //RenderTextureDescriptor はRenderTextureの作成に使用するデータを詰め込んだstructです。
        internal RenderTextureDescriptor descriptor { get; private set; }

        private Material depthNormalsMaterial = null;
        private FilteringSettings m_FilteringSettings;
        const string m_ProfilerTag = "HatchingOnly Pass"; //フレームデバッガーに表示されるプロファイラータグです。
        private ProfilingSampler m_ProfilingSampler = new ProfilingSampler(m_ProfilerTag);
        //ShaderTagId m_ShaderTagId = new ShaderTagId("DepthOnly");
        ShaderTagId m_ShaderTagId = new ShaderTagId("Hatching");


        //パスのコンストラクタです。ここでは、フレーム単位で更新する必要のないマテリアルプロパティを設定できます。
        /*public DepthNormalsPass(RenderQueueRange renderQueueRange, LayerMask layerMask, Material material)
        {
            ConfigureInput(ScriptableRenderPassInput.Normal);   //DepthNormals.shader内のSampleSceneNormals()を有効化するため これだけでdepth normals prepass　が入る！？

            m_FilteringSettings = new FilteringSettings(renderQueueRange, layerMask);
            depthNormalsMaterial = material;　
        }*/
        public HatchingPass(RenderPassEvent evt, RenderQueueRange renderQueueRange, LayerMask layerMask)
        {
            m_FilteringSettings = new FilteringSettings(renderQueueRange, layerMask);
            renderPassEvent = evt;
        }

        // Setup がないとTrying to get RenderBuffer with invalid antiAliasing(must be at least 1)エラー
        public void Setup(
        RenderTextureDescriptor baseDescriptor,
        RenderTargetHandle hatchingAttachmentHandle)
    {
        this.m_hatchingTexture = hatchingAttachmentHandle;
        baseDescriptor.colorFormat = RenderTextureFormat.ARGB32; // ARGB32は　RGBAチャンネルそれぞれに8bitずつ入るテクスチャフォーマット
        baseDescriptor.depthBufferBits = 32; // デプスバッファを32bitにする(Zテストに必要)

        baseDescriptor.msaaSamples = 1; // MSAAは使用しない
        descriptor = baseDescriptor;
    }
        /* public void Setup(RenderTextureDescriptor baseDescriptor, RenderTargetHandle depthAttachmentHandle)
         {
             this.depthAttachmentHandle = depthAttachmentHandle;
             baseDescriptor.colorFormat = RenderTextureFormat.ARGB32;
             baseDescriptor.depthBufferBits = kDepthBufferBits;
             descriptor = baseDescriptor;
         }*/

        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in an performance manner.
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            // RenderTextureの確保
            cmd.GetTemporaryRT(m_hatchingTexture.id, descriptor, FilterMode.Point);
            ConfigureTarget(m_hatchingTexture.Identifier());
            ConfigureClear(ClearFlag.All, Color.white);
        }
        
        // パスの実際の実行。ここでカスタムレンダリングが発生します。
        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        { 
           
            // マルチパスはこっち
             var cmd = CommandBufferPool.Get(m_ProfilerTag);
             using (new ProfilingSample(cmd, "HatchingOnly Pass"))
             {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
                 var drawSettings = CreateDrawingSettings(m_ShaderTagId, ref renderingData, sortFlags);
                 drawSettings.perObjectData = PerObjectData.None;

                 context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref m_FilteringSettings);
                 cmd.SetGlobalTexture("_HatchingTexture", m_hatchingTexture.id);
                 //cmd.Blit(depthNormalTargetHandle.id, SourceIdentifier);
                 // cmd.Blit(depthNormalTargetHandle.id, SourceIdentifier);
             }
            
           
            context.ExecuteCommandBuffer(cmd);  //これがないと描画がバグる　コマンドバッファがリリースされないから？
            CommandBufferPool.Release(cmd);         //これがないと描画がバグる　コマンドバッファがリリースされないから？
        
        }

        /// Cleanup any allocated resources that were created during the execution of this render pass.
        /*public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(depthAttachmentHandle.id);
            depthAttachmentHandle = RenderTargetHandle.CameraTarget;
            if (depthAttachmentHandle != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(depthAttachmentHandle.id);
                depthAttachmentHandle = RenderTargetHandle.CameraTarget;
            }
        }*/
    }

    HatchingPass hatchingPass;
    RenderTargetHandle m_HatchingTexture;
    Material depthNormalsMaterial;
    [SerializeField] private MyFeatureSettings settings = new MyFeatureSettings();
    public class MyFeatureSettings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
        public LayerMask layerMask = -1; // Everything
    }
    
    public override void Create()
    {

        /*
        //CreateEngineMaterialでパス内で使用するマテリアルを作成します。
        depthNormalsMaterial = CoreUtils.CreateEngineMaterial("BD/PostProcess/DepthNormals");   //https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/DefaultResourcesExtra/Internal-DepthNormalsTexture.shader
       // depthNormalsMaterial = CoreUtils.CreateEngineMaterial("Hidden/Internal-DepthNormalsTexture");   //https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/DefaultResourcesExtra/Internal-DepthNormalsTexture.shader
       //depthNormalsMaterial.renderQueue = ;
        depthNormalsPass = new DepthNormalsPass(RenderQueueRange.opaque,-1, depthNormalsMaterial);    //mokutsuno sumiki ここをRenderQueueRange.opaque から　RenderQueueRange.transparentにすることが関係ある？
        depthNormalsPass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
        depthNormalsTexture.Init("_CameraDepthNormalsTexture");
        */


        hatchingPass = new HatchingPass(settings.renderPassEvent, RenderQueueRange.opaque, settings.layerMask);  //コンストラクタ以外オーバーライドしてないからそれ以外デフォルトのはず
        // Configures where the render pass should be injected.
        m_HatchingTexture.Init("_HatchingTexture");
        //hatchingPass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        hatchingPass.Setup(cameraTargetDescriptor, m_HatchingTexture);
        renderer.EnqueuePass(hatchingPass);
        
    }
}
