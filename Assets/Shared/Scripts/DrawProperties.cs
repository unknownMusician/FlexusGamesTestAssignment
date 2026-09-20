using System;
using UnityEngine;

[Serializable]
public struct DrawProperties
{
    public float AlphaOffsetScaling;
    public float DrawRadius;
    public float ElevationAdditionRadius;
    [Range(0, 1)] public float NormalizedAlphaOffsetCap;
    [Range(0, 1)] public float NormalizedMaxDragDistance;
    [Range(0, 1)] public float AdditionalDragPointAttraction;
    [Range(0, 1)] public float DrawOpacity;
    [Range(0, 1)] public float BorderWidth;
    [Range(0, 1)] public float BorderAmplitude;

    public static DrawProperties Standard => new DrawProperties()
    {
        AlphaOffsetScaling = 1, 
        DrawRadius = 1, 
        ElevationAdditionRadius = 0.1f, 
        NormalizedAlphaOffsetCap = 1, 
        NormalizedMaxDragDistance = 0.1f, 
        AdditionalDragPointAttraction = 0.1f, 
        DrawOpacity = 0.5f, 
        BorderWidth = 0.5f, 
        BorderAmplitude = 0.5f,
    };
}