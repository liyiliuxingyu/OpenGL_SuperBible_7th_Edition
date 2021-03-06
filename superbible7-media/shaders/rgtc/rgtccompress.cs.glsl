/*
* Copyright ? 2012-2015 Graham Sellers
*
* Permission is hereby granted, free of charge, to any person obtaining a
* copy of this software and associated documentation files (the "Software"),
* to deal in the Software without restriction, including without limitation
* the rights to use, copy, modify, merge, publish, distribute, sublicense,
* and/or sell copies of the Software, and to permit persons to whom the
* Software is furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice (including the next
* paragraph) shall be included in all copies or substantial portions of the
* Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
* DEALINGS IN THE SOFTWARE.
*/

#version 440 core

layout (local_size_x = 1) in;
layout (local_size_y = 1) in;

layout (binding = 0) uniform sampler2D input_image;
layout (binding = 0, rg32ui) writeonly uniform uimageBuffer output_buffer;

uniform PARAMS
{
    uint        uImageWidth;
};

void fetchTexels(uvec2 blockCoord, out float texels[16])
{
    vec2 texSize = textureSize(input_image, 0);
    vec2 tl = (vec2(blockCoord * 4) + vec2(1.0)) / texSize;
    
    vec4 tx0 = textureGatherOffset(input_image, tl, ivec2(0, 0));
    vec4 tx1 = textureGatherOffset(input_image, tl, ivec2(2, 0));
    vec4 tx2 = textureGatherOffset(input_image, tl, ivec2(0, 2));
    vec4 tx3 = textureGatherOffset(input_image, tl, ivec2(2, 2));

    texels[0] = tx0.w;
    texels[1] = tx0.z;
    texels[2] = tx1.w;
    texels[3] = tx1.z;

    texels[4] = tx0.x;
    texels[5] = tx0.y;
    texels[6] = tx1.x;
    texels[7] = tx1.y;

    texels[8] = tx2.w;
    texels[9] = tx2.z;
    texels[10] = tx3.w;
    texels[11] = tx3.z;

    texels[12] = tx2.x;
    texels[13] = tx2.y;
    texels[14] = tx3.x;
    texels[15] = tx3.y;
}

void fetchTexels__(uvec2 blockCoord, out float texels[16])
{
    ivec2 tl = ivec2(blockCoord * 4);

    texels[0] = texelFetch(input_image, tl + ivec2(0, 0), 0).x;
    texels[1] = texelFetch(input_image, tl + ivec2(1, 0), 0).x;
    texels[2] = texelFetch(input_image, tl + ivec2(2, 0), 0).x;
    texels[3] = texelFetch(input_image, tl + ivec2(3, 0), 0).x;

    texels[4] = texelFetch(input_image, tl + ivec2(0, 1), 0).x;
    texels[5] = texelFetch(input_image, tl + ivec2(1, 1), 0).x;
    texels[6] = texelFetch(input_image, tl + ivec2(2, 1), 0).x;
    texels[7] = texelFetch(input_image, tl + ivec2(3, 1), 0).x;

    texels[8] = texelFetch(input_image, tl + ivec2(0, 2), 0).x;
    texels[9] = texelFetch(input_image, tl + ivec2(1, 2), 0).x;
    texels[10] = texelFetch(input_image, tl + ivec2(2, 2), 0).x;
    texels[11] = texelFetch(input_image, tl + ivec2(3, 2), 0).x;

    texels[12] = texelFetch(input_image, tl + ivec2(0, 3), 0).x;
    texels[13] = texelFetch(input_image, tl + ivec2(1, 3), 0).x;
    texels[14] = texelFetch(input_image, tl + ivec2(2, 3), 0).x;
    texels[15] = texelFetch(input_image, tl + ivec2(3, 3), 0).x;
}

void buildPalette(float texels[16], out float palette[8])
{
    float minValue = 1.0;
    float maxValue = 0.0;
    int i;

    for (i = 0; i < 16; i++)
    {
        maxValue = max(texels[i], maxValue);
        minValue = min(texels[i], minValue);
    }

    palette[0] = maxValue;
    palette[1] = minValue;
    palette[2] = mix(maxValue, minValue, 1.0 / 7.0);
    palette[3] = mix(maxValue, minValue, 2.0 / 7.0);
    palette[4] = mix(maxValue, minValue, 3.0 / 7.0);
    palette[5] = mix(maxValue, minValue, 4.0 / 7.0);
    palette[6] = mix(maxValue, minValue, 5.0 / 7.0);
    palette[7] = mix(maxValue, minValue, 6.0 / 7.0);
}

void buildPalette2(float texels[16], out float palette[8])
{
    float minValue = 1.0;
    float maxValue = 0.0;
    int i;

    for (i = 0; i < 16; i++)
    {
        if (texels[i] != 1.0)
        {
            maxValue = max(texels[i], maxValue);
        }
        if (texels[i] != 0.0)
        {
            minValue = min(texels[i], minValue);
        }
    }

    palette[0] = minValue;
    palette[1] = maxValue;
    palette[2] = mix(minValue, maxValue, 1.0 / 5.0);
    palette[3] = mix(minValue, maxValue, 2.0 / 5.0);
    palette[4] = mix(minValue, maxValue, 3.0 / 5.0);
    palette[5] = mix(minValue, maxValue, 4.0 / 5.0);
    palette[6] = 0.0;
    palette[7] = 1.0;
}

float paletizeTexels(float texels[16], float palette[8], out uint entries[16])
{
    int i, j;
    float totalError = 0.0;

    for (i = 0; i < 16; i++)
    {
        int bestEntryIndex = 0;
        float texel = texels[i];
        float bestError = abs(texel - palette[0]);
        for (j = 1; j < 8; j++)
        {
            float absError = abs(texel - palette[j]);
            if (absError < bestError)
            {
                bestError = absError;
                bestEntryIndex = j;
            }
        }
        entries[i] = bestEntryIndex;
        totalError += bestError;
    }

    return totalError;
}

void packRGTC(float palette0,
              float palette1,
              uint entries[16],
              out uvec2 block)
{
    uint t0 = 0x00000000;
    uint t1 = 0x00000000;

    t0 = (entries[0] << 0u) +
         (entries[1] << 3u) +
         (entries[2] << 6u) +
         (entries[3] << 9u) +
         (entries[4] << 12) +
         (entries[5] << 15) +
         (entries[6] << 18) +
         (entries[7] << 21);

    t1 = (entries[8] << 0u) +
         (entries[9] << 3u) +
         (entries[10] << 6u) +
         (entries[11] << 9u) +
         (entries[12] << 12u) +
         (entries[13] << 15u) +
         (entries[14] << 18u) +
         (entries[15] << 21u);

    block.x = (uint(palette0 * 255.0) << 0u) +
              (uint(palette1 * 255.0) << 8u) +
              (t0 << 16u);
    block.y = (t0 >> 16u) + (t1 << 8u);
}

void main(void)
{
    float texels[16];
    float palette[8];
    uint entries[16];
    float palette2[8];
    uint entries2[16];
    uvec2 compressed_block;

    fetchTexels(gl_GlobalInvocationID.xy, texels);

    buildPalette(texels, palette);
    buildPalette2(texels, palette2);

    float error1 = paletizeTexels(texels, palette, entries);
    float error2 = paletizeTexels(texels, palette2, entries2);

    if (error1 < error2)
    {
        packRGTC(palette[0],
                 palette[1],
                 entries,
                 compressed_block);
    }
    else
    {
        packRGTC(palette2[0],
                 palette2[1],
                 entries2,
                 compressed_block);
    }

    imageStore(output_buffer,
               int(gl_GlobalInvocationID.y * 128 + gl_GlobalInvocationID.x),
               compressed_block.xyxy);
}
