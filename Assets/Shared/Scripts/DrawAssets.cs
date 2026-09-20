using System;
using UnityEngine;

[Serializable]
public struct DrawAssets
{
    public Transform PlaneTransform;
    public MeshFilter PlaneMeshFilter;
    public RenderTexture RenderTextureDst;
    public Material DrawMaterial;
}