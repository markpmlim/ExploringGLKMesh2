//
//  OpenGLView.m
//  SphericalProjection (aka EquiRectangular Projection)
//
//  Created by mark lim pak mun on 10/12/2023.
//  Copyright © 2023 Incremental Innovation. All rights reserved.
//

#import <GLKit/GLKit.h>
#import <OpenGL/gl3.h>
#import "OpenGLView.h"
#import "OGLShader.h"
#import "Model.h"

#define CheckGLError() { \
    GLenum err = glGetError(); \
    if (err != GL_NO_ERROR) { \
        printf("CheckGLError: %04x caught at %s:%u\n", err, __FILE__, __LINE__); \
    } \
}


@implementation OpenGLView
{
    OGLShader       *skyboxShader;
    OGLShader       *torusShader;
    
    Model           *skybox;
    Model           *torus;

    GLKTextureInfo  *cubemapTexInfo;

    GLKMatrix4      _projectionMatrix;
    GLint           _modelMatrixLoc;
    GLint           _viewMatrixLoc;
    GLint           _projectionMatrixLoc;
    GLint           _normalMatrixLoc;
    GLint           _skyboxMapLoc;
    GLint           _camerPositionLoc;

    CVDisplayLinkRef displayLink;
    double           deltaTime;
    double          _time;
    float           _angle;

    NSTrackingArea  *trackingArea;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    NSOpenGLPixelFormat *pf = [OpenGLView basicPixelFormat];
    self = [super initWithFrame:frameRect
                    pixelFormat:pf];
    if (self) {
        NSOpenGLContext *glContext = [[NSOpenGLContext alloc] initWithFormat:pf
                                                                shareContext:nil];
        self.pixelFormat = pf;
        self.openGLContext = glContext;
        // This call should be made for OpenGL 3.2 or later shaders
        // to be compiled and linked w/o problems.
        [[self openGLContext] makeCurrentContext];
    }
    return self;
}

// seems ok to use NSOpenGLProfileVersion4_1Core
+ (NSOpenGLPixelFormat*)basicPixelFormat
{
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,        // double buffered
        NSOpenGLPFADepthSize, 24,       // 24-bit depth buffer
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        (NSOpenGLPixelFormatAttribute)0
    };
    return [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
}

// overridden method of NSOpenGLView
- (void)prepareOpenGL
{
    [super prepareOpenGL];
    [self buildObjects];
    [self compileAndLinkShaders];
    [self loadTextures];
    glCullFace(GL_BACK);
    glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);
    glEnable(GL_DEPTH_TEST);

    CheckGLError();

    // Create a display link capable of being used with all active displays
    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);

    // Set the renderer output callback function
    CVDisplayLinkSetOutputCallback(displayLink,
                                   &MyDisplayLinkCallback,
                                   (__bridge void * _Nullable)(self));
    CVDisplayLinkStart(displayLink);
}

- (void)dealloc
{
    CVDisplayLinkStop(displayLink);
}

- (CVReturn)getFrameForTime:(const CVTimeStamp*)outputTime
{
    // deltaTime is unused in this bare bones demo, but here's how to calculate it using display link info
    // should be = 1/60
    deltaTime = 1.0 / (outputTime->rateScalar * (double)outputTime->videoTimeScale / (double)outputTime->videoRefreshPeriod);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsDisplay:YES];
    });
    return kCVReturnSuccess;
}

// This is the renderer output callback function. The displayLinkContext object
// can be a custom (C struct) object or Objective-C instance.
static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink,
                                      const CVTimeStamp* now,
                                      const CVTimeStamp* outputTime,
                                      CVOptionFlags flagsIn,
                                      CVOptionFlags* flagsOut,
                                      void* displayLinkContext)
{
    CVReturn result = [(__bridge OpenGLView *)displayLinkContext getFrameForTime:outputTime];
    return result;
}

- (void)buildObjects
{
    skybox = [[Model alloc] initCubeWithRadius:1.0
                                 inwardNormals:YES];
    
    torus = [[Model alloc] initTorusWithRingRadius:5.0
                                        pipeRadius:2.5];

}

- (void)compileAndLinkShaders
{
    GLuint shaderIDs[2];

    skyboxShader = [[OGLShader alloc] init];
    shaderIDs[0] = [skyboxShader compile:@"Skybox.vs"
                              shaderType:GL_VERTEX_SHADER];
    shaderIDs[1] = [skyboxShader compile:@"Skybox.fs"
                              shaderType:GL_FRAGMENT_SHADER];
    [skyboxShader linkShaders:shaderIDs
                  shaderCount:2
                deleteShaders:YES];

    glUseProgram(skyboxShader.program);
    // The statement below is not necessay because there is only 1 texture.
    _skyboxMapLoc = glGetUniformLocation(skyboxShader.program, "cubeMap");
    CheckGLError();

    torusShader = [[OGLShader alloc] init];
    shaderIDs[0] = [torusShader compile:@"Reflect.vs"
                             shaderType:GL_VERTEX_SHADER];
    CheckGLError()
    shaderIDs[1] = [torusShader compile:@"Reflect.fs"
                             shaderType:GL_FRAGMENT_SHADER];
    [torusShader linkShaders:shaderIDs
                 shaderCount:2
               deleteShaders:YES];
    CheckGLError()

    // Once only
    glUseProgram(torusShader.program);
    _normalMatrixLoc  = glGetUniformLocation(torusShader.program, "normalMatrix");
    _camerPositionLoc = glGetUniformLocation(torusShader.program, "cameraPostion");
    glUseProgram(0);
}

- (void)loadTextures
{
    NSError *outError = nil;
    // The resolution of the skybox image should be 6:1 or 1:6
    NSString *path = [[NSBundle mainBundle] pathForResource:@"skybox_image"
                                                     ofType:@"jpg"];
    NSDictionary *texOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithBool:YES], GLKTextureLoaderGenerateMipmaps,
                                nil];
    cubemapTexInfo = [GLKTextureLoader cubeMapWithContentsOfFile:path
                                                         options:texOptions
                                                           error:&outError];
    if (outError != nil) {
        NSLog(@"Error loading image texture:%@", outError);
    }
}

// This method must be called periodically to ensure
// the camera's internal objects are updated.
- (void)update
{
    _angle += deltaTime;
     _time += deltaTime * 0.2;
}

- (void)render:(NSRect)rect
{
    [self update];
    CGLLockContext([[self openGLContext] CGLContextObj]);
    glClearColor(0.5, 0.5, 0.5, 1.0);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    glViewport(0, 0, rect.size.width, rect.size.height);

    // viewer's location
    GLKVector3 cameraPosition = GLKVector3Make(10.0f * cos(_angle),
                                               2.0f,
                                               10.0f * sin(_angle));

    GLKMatrix4 viewMatrix = GLKMatrix4Identity;
    GLKMatrix4 modelMatrix = GLKMatrix4Identity;
    modelMatrix = GLKMatrix4TranslateWithVector3(modelMatrix,
                                                 GLKVector3Make(0.0, 0.0, -20.0));
    // Then rotate the model about its local y- and then local z-axis.
    modelMatrix = GLKMatrix4RotateY(modelMatrix,
                                    GLKMathDegreesToRadians(80.0*_time*3.0));

    modelMatrix = GLKMatrix4RotateZ(modelMatrix,
                                    GLKMathDegreesToRadians(70.0*_time*3.0));
    bool isInvertible = NO;
    GLKMatrix4 normalMatrix4 = GLKMatrix4InvertAndTranspose(modelMatrix,
                                                            &isInvertible);
    GLKMatrix3 normalMatrix3 = GLKMatrix4GetMatrix3(normalMatrix4);

    glUseProgram(torusShader.program);
    _modelMatrixLoc = glGetUniformLocation(torusShader.program, "modelMatrix");
    _viewMatrixLoc = glGetUniformLocation(torusShader.program, "viewMatrix");
    _projectionMatrixLoc = glGetUniformLocation(torusShader.program, "projectionMatrix");
    glUniformMatrix4fv(_modelMatrixLoc, 1, GL_FALSE, modelMatrix.m);
    glUniformMatrix4fv(_viewMatrixLoc, 1, GL_FALSE, viewMatrix.m);
    glUniformMatrix4fv(_projectionMatrixLoc, 1, GL_FALSE, _projectionMatrix.m);
    glUniformMatrix3fv(_normalMatrixLoc, 1, GL_FALSE, normalMatrix3.m);
    glUniform3fv(_camerPositionLoc, 1, cameraPosition.v);
    glActiveTexture(GL_TEXTURE0);   // Texture unit 0
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapTexInfo.name);
    [torus render];

    // Render the skybox last.
    // Note: the depth function must be set to less than or equal to so that
    // the skybox's depth values (which are set all 1.0s in the vertex shader)
    // will pass the test.
    glDepthFunc(GL_LEQUAL);
    modelMatrix = GLKMatrix4RotateY(GLKMatrix4Identity,
                                    GLKMathDegreesToRadians(60.0*_time*5.0));
    _modelMatrixLoc = glGetUniformLocation(skyboxShader.program, "modelMatrix");
    _viewMatrixLoc = glGetUniformLocation(skyboxShader.program, "viewMatrix");
    _projectionMatrixLoc = glGetUniformLocation(skyboxShader.program, "projectionMatrix");

    glUseProgram(skyboxShader.program);
    glUniformMatrix4fv(_modelMatrixLoc, 1, GL_FALSE, modelMatrix.m);
    glUniformMatrix4fv(_viewMatrixLoc, 1, GL_FALSE, viewMatrix.m);
    glUniformMatrix4fv(_projectionMatrixLoc, 1, GL_FALSE, _projectionMatrix.m);
    glActiveTexture(GL_TEXTURE0);   // Texture unit 0
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapTexInfo.name);
    [skybox render];
    glDepthFunc(GL_LESS);           // Set depth function back to default

    glUseProgram(0);

    CGLUnlockContext([[self openGLContext] CGLContextObj]);
    CGLFlushDrawable([[self openGLContext] CGLContextObj]);
}

// overridden method
-(void)reshape
{
    [super reshape];
    NSRect frame = [self frame];
    GLfloat aspectRatio = frame.size.width/frame.size.height;
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(60.0),
                                                 aspectRatio,
                                                 0.1, 1000.0);
}

// overridden method
- (void)drawRect:(NSRect)dirtyRect
{
    [self render:dirtyRect];
}

// these methods may need to be overridden or key events will not be detected.
- (BOOL)acceptsFirstResponder
{
    return YES;
} // acceptsFirstResponder

- (BOOL)becomeFirstResponder
{
    return  YES;
} // becomeFirstResponder

- (BOOL)resignFirstResponder
{
    return YES;
} // resignFirstResponder


- (void)mouseDown:(NSEvent *)event
{
}

// rotational movement about x- and y-axis
- (void)mouseDragged:(NSEvent *)event
{
}

- (void) mouseUp:(NSEvent *)event
{
}

// The camera is at the centre of the scene so
// we don't have to support zooming in and out.
- (void)scrollWheel:(NSEvent *)event
{
    //CGFloat dz = event.scrollingDeltaY;
    //[_camera zoomInOrOut:dz];
}

- (void)keyDown:(NSEvent *)event
{
    if (event)
    {
        NSString* pChars = [event characters];
        if ([pChars length] != 0)
        {
            unichar key = [[event characters] characterAtIndex:0];
            switch(key) {
            case 27:
                exit(0);
                break;
            default:
                break;
            }
        }
    }
}


@end
