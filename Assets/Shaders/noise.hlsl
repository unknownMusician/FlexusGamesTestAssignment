// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------

float2 Fade(float2 t)
{
    // 6t^5 - 15t^4 + 10t^3
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float3 Fade(float3 t)
{
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float3 FadeDt(float3 t)
{
    return 30.0 * t * t * (t * (t - 2.0) + 1.0);
}

// Hash: integer 2D -> pseudo-random uint
uint Hash2D(int2 p)
{
    uint h = asuint(p.x) * 374761393u;
    h += asuint(p.y) * 668265263u;

    h = (h ^ (h >> 13)) * 1274126177u;
    h ^= h >> 16;

    return h;
}

// Hash: integer 3D -> pseudo-random uint
uint Hash3D(int3 p)
{
    uint h = asuint(p.x) * 374761393u;
    h += asuint(p.y) * 668265263u;
    h += asuint(p.z) * 2147483647u;

    h = (h ^ (h >> 13)) * 1274126177u;
    h ^= h >> 16;

    return h;
}

float2 Gradient2D(uint hash)
{
    // 8 evenly distributed gradient directions
    static const float2 gradients[8] =
    {
        float2( 1,  0),
        float2(-1,  0),
        float2( 0,  1),
        float2( 0, -1),
        float2( 0.70710678,  0.70710678),
        float2(-0.70710678,  0.70710678),
        float2( 0.70710678,-0.70710678),
        float2(-0.70710678,-0.70710678)
    };

    return gradients[hash & 7u];
}

float3 Gradient3D(uint hash)
{
    // 12 classic Perlin gradient directions
    static const float3 gradients[12] =
    {
        float3( 1,  1,  0),
        float3(-1,  1,  0),
        float3( 1, -1,  0),
        float3(-1, -1,  0),

        float3( 1,  0,  1),
        float3(-1,  0,  1),
        float3( 1,  0, -1),
        float3(-1,  0, -1),

        float3( 0,  1,  1),
        float3( 0, -1,  1),
        float3( 0,  1, -1),
        float3( 0, -1, -1)
    };

    return normalize(gradients[hash % 12u]);
}


// ------------------------------------------------------------
// 2D Perlin
// ------------------------------------------------------------

float PerlinNoise2D(float2 p)
{
    int2 i = (int2)floor(p);
    float2 f = frac(p);

    float2 u = Fade(f);

    // Dot products at the four corners.
    float n00 = dot(Gradient2D(Hash2D(i + int2(0, 0))), f - float2(0, 0));
    float n10 = dot(Gradient2D(Hash2D(i + int2(1, 0))), f - float2(1, 0));
    float n01 = dot(Gradient2D(Hash2D(i + int2(0, 1))), f - float2(0, 1));
    float n11 = dot(Gradient2D(Hash2D(i + int2(1, 1))), f - float2(1, 1));

    float nx0 = lerp(n00, n10, u.x);
    float nx1 = lerp(n01, n11, u.x);

    return lerp(nx0, nx1, u.y);
}


// ------------------------------------------------------------
// 3D Perlin
// ------------------------------------------------------------

float PerlinNoise3D(float3 p)
{
    int3 i = (int3)floor(p);
    float3 f = frac(p);

    float3 u = Fade(f);

    float n000 = dot(Gradient3D(Hash3D(i + int3(0, 0, 0))), f - float3(0, 0, 0));
    float n100 = dot(Gradient3D(Hash3D(i + int3(1, 0, 0))), f - float3(1, 0, 0));
    float n010 = dot(Gradient3D(Hash3D(i + int3(0, 1, 0))), f - float3(0, 1, 0));
    float n110 = dot(Gradient3D(Hash3D(i + int3(1, 1, 0))), f - float3(1, 1, 0));
    float n001 = dot(Gradient3D(Hash3D(i + int3(0, 0, 1))), f - float3(0, 0, 1));
    float n101 = dot(Gradient3D(Hash3D(i + int3(1, 0, 1))), f - float3(1, 0, 1));
    float n011 = dot(Gradient3D(Hash3D(i + int3(0, 1, 1))), f - float3(0, 1, 1));
    float n111 = dot(Gradient3D(Hash3D(i + int3(1, 1, 1))), f - float3(1, 1, 1));

    float nx00 = lerp(n000, n100, u.x);
    float nx10 = lerp(n010, n110, u.x);
    float nx01 = lerp(n001, n101, u.x);
    float nx11 = lerp(n011, n111, u.x);

    float nxy0 = lerp(nx00, nx10, u.y);
    float nxy1 = lerp(nx01, nx11, u.y);

    return lerp(nxy0, nxy1, u.z);
}

float4 PerlinNoise3DWithDerivative(float3 p)
{
    int3 i = (int3)floor(p);
    float3 f = frac(p);

    float3 u = Fade(f);
    float3 du = FadeDt(f);

    // gradients
    float3 g000 = Gradient3D(Hash3D(i + int3(0, 0, 0)));
    float3 g100 = Gradient3D(Hash3D(i + int3(1, 0, 0)));
    float3 g010 = Gradient3D(Hash3D(i + int3(0, 1, 0)));
    float3 g110 = Gradient3D(Hash3D(i + int3(1, 1, 0)));
    float3 g001 = Gradient3D(Hash3D(i + int3(0, 0, 1)));
    float3 g101 = Gradient3D(Hash3D(i + int3(1, 0, 1)));
    float3 g011 = Gradient3D(Hash3D(i + int3(0, 1, 1)));
    float3 g111 = Gradient3D(Hash3D(i + int3(1, 1, 1)));

    // corner distances
    float3 d000 = f - float3(0, 0, 0);
    float3 d100 = f - float3(1, 0, 0);
    float3 d010 = f - float3(0, 1, 0);
    float3 d110 = f - float3(1, 1, 0);
    float3 d001 = f - float3(0, 0, 1);
    float3 d101 = f - float3(1, 0, 1);
    float3 d011 = f - float3(0, 1, 1);
    float3 d111 = f - float3(1, 1, 1);

    // perlin results
    float n000 = dot(g000, d000);
    float n100 = dot(g100, d100);
    float n010 = dot(g010, d010);
    float n110 = dot(g110, d110);
    float n001 = dot(g001, d001);
    float n101 = dot(g101, d101);
    float n011 = dot(g011, d011);
    float n111 = dot(g111, d111);
    
    float nx00 = lerp(n000, n100, u.x);
    float nx10 = lerp(n010, n110, u.x);
    float nx01 = lerp(n001, n101, u.x);
    float nx11 = lerp(n011, n111, u.x);

    float nxy0 = lerp(nx00, nx10, u.y);
    float nxy1 = lerp(nx01, nx11, u.y);

    float nxyz = lerp(nxy0, nxy1, u.z);

    // derivatives
    
    // Corner derivatives.
    float3 dn000 = g000;
    float3 dn100 = g100;
    float3 dn010 = g010;
    float3 dn110 = g110;
    float3 dn001 = g001;
    float3 dn101 = g101;
    float3 dn011 = g011;
    float3 dn111 = g111;

    float3 dnx00 = lerp(dn000, dn100, u.x) + (n100 - n000) * float3(du.x, 0, 0);
    float3 dnx10 = lerp(dn010, dn110, u.x) + (n110 - n010) * float3(du.x, 0, 0);
    float3 dnx01 = lerp(dn001, dn101, u.x) + (n101 - n001) * float3(du.x, 0, 0);
    float3 dnx11 = lerp(dn011, dn111, u.x) + (n111 - n011) * float3(du.x, 0, 0);
    
    float3 dnxy0 = lerp(dnx00, dnx10, u.y) + (nx10 - nx00) * float3(0, du.y, 0);
    float3 dnxy1 = lerp(dnx01, dnx11, u.y) + (nx11 - nx01) * float3(0, du.y, 0);
    
    float3 dnxyz = lerp(dnxy0, dnxy1, u.z) + (nxy1 - nxy0) * float3(0, 0, du.z);

    return float4(dnxyz, nxyz);
}