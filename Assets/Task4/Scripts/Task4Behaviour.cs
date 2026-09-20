using UnityEngine;

public sealed class Task4Behaviour : MonoBehaviour
{
    [SerializeField] private DrawAssets drawAssets;
    [SerializeField] private DrawProperties drawProperties = DrawProperties.Standard;
    [SerializeField] private RenderTexture renderTextureSrc;
    [SerializeField] private Material simulationMaterial;

    private Drawer drawer;
    private Vector3? lastDragPoint;

    private void Start()
    {
        SharedUtils.ClearRenderTexture(renderTextureSrc, new Color(0.0f, 0, 0, 1));
        SharedUtils.ClearRenderTexture(drawAssets.RenderTextureDst, new Color(0.0f, 0, 0, 1));
    }

    private void Update()
    {
        drawer ??= new();
        drawer.DrawOrBlit(drawAssets, drawProperties, renderTextureSrc);
        
        Graphics.Blit(drawAssets.RenderTextureDst, renderTextureSrc, simulationMaterial);
    }

}