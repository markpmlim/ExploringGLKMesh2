## Exploring GLKMesh
<br />
<br />

We continue with the investigation on how to create **GLKMeshes** objects that can be used in OpenGL demos on the macOS and iOS. 


As mentioned in the previous demo (ExploringGLKMesh), the **GLKMesh** class method:


```objective-C

    NSArray<GLKMesh *> *glkMeshes = [GLKMesh newMeshesFromAsset:mdlAsset
                                                   sourceMeshes:&mdlMeshes
                                                          error:&error];


```

will crash if an instance of **MDLAsset** is passed as the first parameter. We also noted that an instance of **GLKMesh** could be created if the **MDLMesh** object has been instantiated by a **GLKMeshBufferAllocator** object using the call below:


```objective-C

    GLKMesh *glkMesh = [[GLKMesh alloc] initWithMesh:mdlMesh
                                                error:&error];

```

Perusing through Apple's API documents, we came across a typed method of **MDLMesh** which accepts an allocator as one of its parameters.

```objective-C

    MDLMesh *mdlMesh = [MDLMesh meshWithSCNGeometry:scnGeometry
                                    bufferAllocator:allocator];

```

Apple has a few sub-classes of **SCNGeometry**. So we decided to instantiate a torus with the following call:

```objective-C

        SCNGeometry *torus = [SCNTorus torusWithRingRadius:ringRadius
                                                pipeRadius:pipeRadius];
```

and pass the torus object to the type method *meshWithSCNGeometry:bufferAllocator:*

Got a crash with the console message:

Failed to set (contentViewController) user defined inspected property on (NSWindow): *** -[NSPlaceholderString initWithString:]: nil argument


We searched the Internet for information but nothing relevant turned up. So, we decided to assign an **NSString** to the **SCNGeometry** object's *name* property. Voila! It works.

It is necessary to investigate the properties of the newly-created **GLKMesh** object and those of its associated class objects further before using it in a demo. Briefly, instead of a single vertex buffer, the system has allocated 3 vertex buffers. There is still a single index buffer. The system, as usual, allocates OpenGL Vertex Buffer and Index Buffer objects (VBOs and EBOs) which are accessed as *glBufferName* properties. And the Model class has to be updated to handle multiple VBOs and EBOs.

Now, that opens up a path to using custom **SCNGeometry** (e.g. a Mobius strip, an Octahedron) to create **GLKMesh** objects. 

## A brief detail of the demo.

(a) Two models, a skybox and a torus object are instantiated.
<br />
(b) Two pairs of vertex-fragment shaders are compiled.
<br />
(c) A skybox texture is instantiated from an image with a resolution of 6:1.
<br />
(d) A **CVDisplayLink** Object is created to drive a per-frame update of the rendering process.
<br />

## The Rendering Process

The demo proceeds with setting up the conditions to render the torus object first. The position of a camera is required and is passed as a uniform to the reflection fragment shader. Since the model matrix is not a rotation matrix, its associated normal matrix must be computed. We decided to create a normal matrix on the client side because performing the inverse transpose of the model matrix is expensive if done in the GPU. All the required uniforms are then passed to the torus program before the model is rendered.

Rendering the skybox is straighforward because Modern GPU hardware supports cubemapping out-of-the-box. The vertex shader of the skybox shader program passes the position attribute of a vertex of the skybox as a 3D texture coordinate to its fragment shader. This 3D texture coordinate serves a direction vector from the centre of the skybox to one of its vertices. We normalise the vector in the fragment shader and use it to access the cubemap texture although it is not necessary.

<br />
<br />
<br />

Compiled and run under XCode 8.3.2
<br />
<br />
Tested on macOS 10.12
<br />
<br />
Deployment set at macOS 10.11.

<br />
<br />

Resources:

www.learnopengl.com

