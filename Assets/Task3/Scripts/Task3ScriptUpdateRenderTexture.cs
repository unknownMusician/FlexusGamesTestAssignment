using UnityEngine;
using UnityEngine.InputSystem;

public sealed class Task3ScriptUpdateRenderTexture : MonoBehaviour
{
    [SerializeField] private Transform planeTransform;
    [SerializeField] private MeshFilter planeMeshFilter;
    [SerializeField] private RenderTexture renderTexture0;
    [SerializeField] private Material drawMaterial;
    [SerializeField] private float alphaOffsetScaling = 1;
    [SerializeField] private float drawRadius = 1;
    [SerializeField] private float elevationAdditionRadius = 0.1f;
    [SerializeField] [Range(0, 1)] private float normalizedAlphaOffsetCap = 1;
    [SerializeField] [Range(0, 1)] private float normalizedMaxDragDistance = 0.1f;
    [SerializeField] [Range(0, 1)] private float additionalDragPointAttraction = 0.1f;
    [SerializeField] [Range(0, 1)] private float drawOpacity = 0.5f;
    [SerializeField] private float drawEdgeSmoothing = 0.3f;

    private Vector3? lastDragPoint;

    private void Start()
    {
        ClearRT(renderTexture0);
    }

    private static void ClearRT(RenderTexture renderTexture)
    {
        var lastRT = RenderTexture.active;
        try
        {
            RenderTexture.active = renderTexture;
            GL.Clear(false, true, new Color(0.5f, 0, 0, 1));
        }
        finally
        {
            RenderTexture.active = lastRT;
        }
    }
    
    private void Update()
    {
        if (GetDrawPoint() is not { } drawPoint)
        {
            this.lastDragPoint = null;
            return;
        }

        var dragPoint = drawPoint;

        if (this.lastDragPoint is { } lastDragPoint)
        {
            lastDragPoint = Vector3.Lerp(lastDragPoint, drawPoint, Mathf.Pow(additionalDragPointAttraction, 4));
            
            var dragDirection = drawPoint - lastDragPoint;

            dragPoint -= Vector3.ClampMagnitude(dragDirection * alphaOffsetScaling, drawRadius * normalizedAlphaOffsetCap);

            var dragDirectionMagnitude = dragDirection.magnitude;
            var maxDragDistance = normalizedMaxDragDistance * drawRadius;
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

        //

        var boundsWS = planeMeshFilter.sharedMesh.bounds;
        boundsWS.center += planeTransform.localToWorldMatrix.GetPosition();
        boundsWS.extents.Scale(planeTransform.localToWorldMatrix.lossyScale);

        var uvTilingOffset = new Vector4(boundsWS.size.x, boundsWS.size.z, boundsWS.min.x, boundsWS.min.z);
        //
        
        drawMaterial.SetVector("_UvTS", uvTilingOffset);
        drawMaterial.SetVector("_DrawHeightCenter", new Vector4(dragPoint.x, dragPoint.y, dragPoint.z, 0.0f));
        drawMaterial.SetVector("_DrawAlphaCenter", new Vector4(drawPoint.x, drawPoint.y, drawPoint.z, 0.0f));
        drawMaterial.SetFloat("_DrawRadius", drawRadius);
        drawMaterial.SetFloat("_DrawAlphaRadius", drawRadius + elevationAdditionRadius);
        drawMaterial.SetFloat("_DrawOpacity", drawOpacity);
        drawMaterial.SetFloat("_AlphaSmoothing", drawEdgeSmoothing);
        Graphics.Blit(null, renderTexture0, drawMaterial);
    }

    private void OnDrawGizmos()
    {
        if (this.lastDragPoint is { } lastDragPoint)
        {
            Gizmos.color = Color.green;
            Gizmos.DrawSphere(lastDragPoint, 0.1f);
        }
    }

    private Vector3? GetDrawPoint()
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