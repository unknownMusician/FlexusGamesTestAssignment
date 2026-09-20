using UnityEngine;

public sealed class Task3Behaviour : MonoBehaviour
{
    [SerializeField] private DrawAssets drawAssets;
    [SerializeField] private DrawProperties drawProperties = DrawProperties.Standard;

    private Drawer drawer;
    private Vector3? lastDragPoint;

    private void Start()
    {
        SharedUtils.ClearRenderTexture(drawAssets.RenderTextureDst, new Color(0.5f, 0, 0, 1));
    }

    private void Update()
    {
        drawer ??= new();

        drawer.DrawOrBlit(drawAssets, drawProperties, null);
    }
}