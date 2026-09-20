using UnityEngine;

public static class SharedUtils
{
    public static void ClearRenderTexture(RenderTexture renderTexture, Color color)
    {
        var lastRT = RenderTexture.active;
        try
        {
            RenderTexture.active = renderTexture;
            GL.Clear(false, true, color);
        }
        finally
        {
            RenderTexture.active = lastRT;
        }
    }
}