//
//  Model.m
//  ExploringGLKMesh
//
//  Created by mark lim pak mun on 10/12/2023.
//  Copyright © 2023 mark lim pak mun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import <SceneKit/ModelIO.h>
#import <GLKit/GLKit.h>
#import "OGLShader.h"
#import "Model.h"


@implementation Model
{
    GLKMesh     *_glkMesh;
    GLuint      _vao;           // vertex array object

    GLuint      *_vbos;         // a dynamic array of vertex buffer objects
    GLuint      *_ebos;         // a dynamic array element/index buffer objects
    GLsizei     *_indicesCounts;
    GLenum      *_modes;
    GLenum      *_indexTypes;
    NSUInteger  *_indexBufferOffsets;

}

- (nullable instancetype)initCubeWithRadius:(GLfloat)radius
                              inwardNormals:(BOOL)inwardNormals
{
    self = [super init];
    if (self) {
        GLKMeshBufferAllocator *allocator = [[GLKMeshBufferAllocator alloc] init];

        MDLMesh *mdlMesh = [MDLMesh newBoxWithDimensions:(vector_float3){radius, radius, radius}
                                                segments:(vector_uint3){1, 1, 1}
                                            geometryType:MDLGeometryTypeTriangles
                                           inwardNormals:YES
                                               allocator:allocator];
        NSError *error = nil;
        _glkMesh = [[GLKMesh alloc] initWithMesh:mdlMesh
                                           error:&error];
        if (error != nil) {
            self = nil;
        }
        // If self is NIL, the following method will not be executed since
        // sending a message to a NIL object is allowed  in Objective-C.
        [self prepareForOpenGL];
    }
    return self;
}
- (nullable instancetype)initTorusWithRingRadius:(float)ringRadius
                                      pipeRadius:(float)pipeRadius
{
    self = [super init];
    if (self) {
        GLKMeshBufferAllocator *allocator = [[GLKMeshBufferAllocator alloc] init];
        SCNGeometry *torus = [SCNTorus torusWithRingRadius:ringRadius
                                                pipeRadius:pipeRadius];
        // The following instruction will force an immediate
        // execution of the above method.
        [SCNTransaction flush];
        // The GLKMesh object has a property labelled name which can
        // not be NIL.
        // Must give the SCNGeomtry object a name or the demo will crash when
        // the GLKMesh instance method initWithMesh:error: is called.
        torus.name = @"torus";
        MDLMesh *mdlMesh = [MDLMesh meshWithSCNGeometry:torus
                                        bufferAllocator:allocator];

        NSError *error = nil;
        _glkMesh = [[GLKMesh alloc] initWithMesh:mdlMesh
                                           error:&error];
        if (error != nil) {
            self = nil;
        }
        // If self is NIL, the following method will not be executed since
        // sending a message to a NIL object is allowed  in Objective-C.
        [self prepareForOpenGL];
    }
    return self;
}

- (void)dealloc
{
    glDeleteVertexArrays(1, &_vao);
    // We assume the VBOs and EBOs are deleted by the system.
    free(_vbos);
    free(_ebos);
    free(_indicesCounts);
    free(_modes);
    free(_indexTypes);
    free(_indexBufferOffsets);
}
    
- (void)render
{
    glBindVertexArray(_vao);
    // Note: the EBO is internally bound to the VAO.
    for (int i=0; i<_glkMesh.submeshes.count; i++) {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _ebos[i]);
        glDrawElements(_modes[i], _indicesCounts[i], _indexTypes[i],
                       (const void *)_indexBufferOffsets[i]);
    }
}

/*
 Extract the values that were assigned to the various properties.
 */
    
- (void)prepareForOpenGL
{
    glGenVertexArrays(1, &_vao);
    glBindVertexArray(_vao);
    MDLVertexDescriptor *vertDesc = _glkMesh.vertexDescriptor;
    // All built-in parametric MDLMeshes have position, normal and tex coords attributes in that order.
    MDLVertexAttribute *posAttr = [vertDesc attributeNamed:MDLVertexAttributePosition];
    // MDLVertexAttributeData is not available for GLKMesh so we access an element of
    // the array of MDLVertexBufferLayouts
    // When there is more than 1 layouts, it seems all have the same stride value.
    NSUInteger stride = vertDesc.layouts[0].stride;
    // There may be more than One Vertex Buffer
    _vbos = malloc(_glkMesh.vertexBuffers.count * sizeof(GLuint));
    for (int i=0; i<_glkMesh.vertexBuffers.count; i++) {
        _vbos[i] = _glkMesh.vertexBuffers[i].glBufferName;
        //glBindBuffer(GL_ARRAY_BUFFER, _vbos[i]);
        // Assumes the system will bind
    }
    GLKVertexAttributeParameters vertAttrParms = GLKVertexAttributeParametersFromModelIO(posAttr.format);
    // We need the stride, format and offset properties to call
    // glEnableVertexAttribArray & glVertexAttribPointer
    // The vertex shader should precede the position attribute with the phrase
    // layout(location = 0)
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0,
                          vertAttrParms.size,           // # of components - 1, 2, 3 or 4
                          vertAttrParms.type,           // e.g. GL_FLOAT
                          vertAttrParms.normalized,     // usually 0 (false)
                          (GLsizei)stride,
                          (const void *)posAttr.offset);
    MDLVertexAttribute *normalAttr = [vertDesc attributeNamed:MDLVertexAttributeNormal];
    vertAttrParms = GLKVertexAttributeParametersFromModelIO(normalAttr.format);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1,
                          vertAttrParms.size,
                          vertAttrParms.type,
                          vertAttrParms.normalized,
                          (GLsizei)stride,
                          (const void *)normalAttr.offset);
    MDLVertexAttribute *texCoordAttr = [vertDesc attributeNamed:MDLVertexAttributeTextureCoordinate];
    vertAttrParms = GLKVertexAttributeParametersFromModelIO(texCoordAttr.format);
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2,
                          vertAttrParms.size,
                          vertAttrParms.type,
                          vertAttrParms.normalized,
                          (GLsizei)stride,
                          (const void *)texCoordAttr.offset);
    //NSLog(@"%@ %@ %@", posAttr, normalAttr, texCoordAttr);
    // There may be more than only 1 element in the array of submeshes etc.
    // We require the following values to perform glBindBuffer ...
    for (int i=0; i<_glkMesh.submeshes.count; i++) {
        _ebos = malloc(_glkMesh.submeshes.count * sizeof(GLuint));
        _modes = malloc(_glkMesh.submeshes.count * sizeof(GLenum));
        _indexTypes = malloc(_glkMesh.submeshes.count * sizeof(GLenum));
        _indicesCounts = malloc(_glkMesh.submeshes.count * sizeof(GLsizei));
        _indexBufferOffsets = malloc(_glkMesh.submeshes.count * sizeof(NSUInteger));
    }

    // ...  and glDrawElements
    for (int i=0; i<_glkMesh.submeshes.count; i++) {
        _ebos[i] = _glkMesh.submeshes[0].elementBuffer.glBufferName;
        // An example of mode is GL_TRIANGLES
        _modes[i] = _glkMesh.submeshes[0].mode;
        // An example of type is GL_UNSIGNED_SHORT
        _indexTypes[i] = _glkMesh.submeshes[0].type;
        // # of elements in the elementBuffer (GLKMeshBuffer).
        _indicesCounts[i] = _glkMesh.submeshes[0].elementCount;
        // offset, in bytes, into the element buffer (usually 0)
        _indexBufferOffsets[i] = _glkMesh.submeshes[0].elementBuffer.offset;
    }
}
    
@end

