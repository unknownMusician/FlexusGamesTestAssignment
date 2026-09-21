using UnityEngine;
using UnityEngine.InputSystem;

public sealed class Drawer
{
    private static class ShaderProperties
    {
        public static readonly int UvTs = Shader.PropertyToID("_UvTS");
        public static readonly int DrawHeightCenter = Shader.PropertyToID("_DrawHeightCenter");
        public static readonly int DrawAlphaCenter = Shader.PropertyToID("_DrawAlphaCenter");
        public static readonly int DrawRadius = Shader.PropertyToID("_DrawRadius");
        public static readonly int DrawAlphaRadius = Shader.PropertyToID("_DrawAlphaRadius");
        public static readonly int DrawOpacity = Shader.PropertyToID("_DrawOpacity");
        public static readonly int BorderWidth = Shader.PropertyToID("_BorderWidth");
        public static readonly int BorderAmplitude = Shader.PropertyToID("_BorderAmplitude");
    }

    private Vector3? lastDragPoint;

    public void DrawOrBlit(DrawAssets assets, DrawProperties properties, RenderTexture renderTextureSrc)
    {
        if (!TryDraw(assets, properties, renderTextureSrc) && renderTextureSrc != null)
        {
            Graphics.CopyTexture(renderTextureSrc, assets.RenderTextureDst);
        }
    }

    private bool TryDraw(DrawAssets assets, DrawProperties properties, RenderTexture renderTextureSrc)
    {
        if (GetDrawPoint(assets.PlaneTransform) is not { } drawPoint)
        {
            this.lastDragPoint = null;
            return false;
        }

        var dragPoint = drawPoint;

        if (this.lastDragPoint is { } lastDragPoint)
        {
            lastDragPoint = Vector3.Lerp(lastDragPoint, drawPoint, Mathf.Pow(properties.AdditionalDragPointAttraction, 4));
            
            var dragDirection = drawPoint - lastDragPoint;

            dragPoint -= Vector3.ClampMagnitude(dragDirection * properties.AlphaOffsetScaling, properties.DrawRadius * properties.NormalizedAlphaOffsetCap);

            var dragDirectionMagnitude = dragDirection.magnitude;
            var maxDragDistance = properties.NormalizedMaxDragDistance * properties.DrawRadius;
            if (dragDirectionMagnitude > maxDragDistance)
            {
                lastDragPoint = drawPoint - dragDirection / dragDirectionMagnitude * maxDragDistance;
            }

            this.lastDragPoint = lastDragPoint;
        }
        else
        {
            this.lastDragPoint = drawPoint;
        }

        var uvTilingOffset = ToPlaneUvTilingOffset(assets);
        
        assets.DrawMaterial.SetVector(ShaderProperties.UvTs, uvTilingOffset);
        assets.DrawMaterial.SetVector(ShaderProperties.DrawHeightCenter, new Vector4(dragPoint.x, dragPoint.y, dragPoint.z, 0.0f));
        assets.DrawMaterial.SetVector(ShaderProperties.DrawAlphaCenter, new Vector4(drawPoint.x, drawPoint.y, drawPoint.z, 0.0f));
        assets.DrawMaterial.SetFloat(ShaderProperties.DrawRadius, properties.DrawRadius);
        assets.DrawMaterial.SetFloat(ShaderProperties.DrawAlphaRadius, properties.DrawRadius + properties.ElevationAdditionRadius);
        assets.DrawMaterial.SetFloat(ShaderProperties.DrawOpacity, properties.DrawOpacity);
        assets.DrawMaterial.SetFloat(ShaderProperties.BorderWidth, properties.BorderWidth);
        assets.DrawMaterial.SetFloat(ShaderProperties.BorderAmplitude, properties.BorderAmplitude);

        Graphics.Blit(renderTextureSrc, assets.RenderTextureDst, assets.DrawMaterial);

        return true;
    }

    private static Vector4 ToPlaneUvTilingOffset(DrawAssets assets)
    {
        var boundsWS = assets.PlaneMeshFilter.sharedMesh.bounds;
        boundsWS.center += assets.PlaneTransform.localToWorldMatrix.GetPosition();
        boundsWS.extents.Scale(assets.PlaneTransform.localToWorldMatrix.lossyScale);

        return new Vector4(boundsWS.size.x, boundsWS.size.z, boundsWS.min.x, boundsWS.min.z);
    }
    
    private static Vector3? GetDrawPoint(Transform planeTransform)
    {
        if (Pointer.current == null || !Pointer.current.press.isPressed)
        {
            return null;
        }

        var pointerScreenPosition = Pointer.current.position.ReadValue();
        var pointerRay = Camera.main.ScreenPointToRay(pointerScreenPosition);

        var planeRay = new Ray(planeTransform.position, planeTransform.up);

        return FindIntersection(pointerRay, planeRay);
    }


    private static Vector3 FindIntersection(Ray ray, Ray plane)
    {
        var t = Vector3.Dot((plane.origin - ray.origin), plane.direction) / Vector3.Dot(ray.direction, plane.direction);

        return ray.origin + ray.direction * t;
    }
}