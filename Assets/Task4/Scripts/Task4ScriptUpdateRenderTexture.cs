using UnityEngine;

public sealed class Task4ScriptUpdateRenderTexture : MonoBehaviour
{
    [SerializeField] private RenderTexture renderTextureSrc;
    [SerializeField] private RenderTexture renderTextureDst;
    [SerializeField] private Material oscillationMaterial;

    private void Update()
    {
        Graphics.Blit(renderTextureSrc, renderTextureDst, oscillationMaterial);
    }
}