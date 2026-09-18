using UnityEngine;

public sealed class Task4ScriptUpdateRenderTexture : MonoBehaviour
{
    [SerializeField] private RenderTexture renderTexture0;
    [SerializeField] private RenderTexture renderTexture1;
    [SerializeField] private Material oscillationMaterial;

    private void Update()
    {
        Graphics.Blit(renderTexture0, renderTexture1, oscillationMaterial);
        (renderTexture0, renderTexture1) = (renderTexture1, renderTexture0);
    }
}