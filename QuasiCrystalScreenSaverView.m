//
//  QuasiCrystalScreenSaverView.m
//  QuasiCrystalScreenSaver
//
//  Copyright (C) 2011 Roger Allen (rallen@gmail.com)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//

#import "QuasiCrystalScreenSaverView.h"

@implementation GmailRallen_QuasiCrystalScreenSaverView

static NSString * const MyModuleName = @"com.gmail.rallen.QuasiCrystalScreenSaver";

- (id)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:MyModuleName];
        // Register our default values
        [defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                    @"64",  @"Rate",
                                    @"128", @"Scale",
                                    @"1",   @"Color",
                                    @"7",   @"Symmetry",
                                    nil]];

        NSOpenGLPixelFormatAttribute attributes[] = { 
            NSOpenGLPFAAccelerated, 
            NSOpenGLPFAMinimumPolicy, 
            NSOpenGLPFAClosestPolicy, 0 
        }; 
        NSOpenGLPixelFormat *format; 
        format = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
        glView = [[MyOpenGLView alloc] initWithFrame:NSZeroRect pixelFormat:format]; 
        if (!glView) { 
            NSLog( @"Couldn't initialize OpenGL view." ); 
            [self autorelease]; 
            return nil; 
        } 
        [self addSubview:glView]; 
        [self setUpOpenGL]; 
        [self setAnimationTimeInterval:1/30.0];
    }
    return self;
}

- (void)dealloc { 
    [glView removeFromSuperview]; 
    [glView release]; 
    [super dealloc]; 
}

- (GLboolean)checkOpenGL {
    // Just some rudimentary checks
    const GLubyte * strVersion;
    const GLubyte * strExt;
    strVersion = glGetString (GL_VERSION);
    strExt = glGetString (GL_EXTENSIONS);
    //GLboolean isShade = gluCheckExtension ((const GLubyte*)"GL_ARB_shading_language_100", strExt);
    return TRUE;
}

- (void)compileAndCheckProg:(GLuint)prog vshader:(GLuint)vshader fshader:(GLuint)fshader {
    glCompileShader(vshader);
    glCompileShader(fshader);
    glAttachShader(prog, vshader);
    glAttachShader(prog, fshader);
    glLinkProgram(prog);
    glValidateProgram(prog);
    GLint logLen;
    char theLog[2048];
    glGetShaderiv(vshader, GL_INFO_LOG_LENGTH, &logLen);
    if(logLen > 0) {
        glGetShaderInfoLog(vshader, logLen, &logLen, theLog);
        fprintf(stderr, "VShader Info Log: %s\n", theLog);
    }
    glGetShaderiv(fshader, GL_INFO_LOG_LENGTH, &logLen);
    if(logLen > 0) {
        glGetShaderInfoLog(fshader, logLen, &logLen, theLog);
        fprintf(stderr, "FShader Info Log: %s\n", theLog);
    }
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLen);
    if(logLen > 0) {
        glGetProgramInfoLog(prog, logLen, &logLen, theLog);
        fprintf(stderr, "Prog Info Log: %s\n", theLog);
    }
    
}

- (void)setUpShaders {
    const GLchar *vsText = 
	"#version 120\n"
    "attribute vec2 aPosition;\n"
    "attribute vec2 aUV;\n"
    "varying vec2 vUV;\n"
    "void main(void) {\n"
    "    gl_Position = vec4(aPosition, -0.5, 1.0);\n"
    "    vUV = aUV;\n"
    "}\n";
    
    const GLchar *fsText[] = 
    {
        // 0 = original shader
        "#version 120\n"
        "varying vec2 vUV;\n"
        "uniform float timer;\n"
        "uniform float scale;\n"
        "uniform float tscale;\n"
        "uniform float xpixels;\n"
        "uniform float ypixels;\n"
        "uniform int symmetry;\n"
        "uniform vec4 clut[5];\n"
        "\n"
        "const float PI = 3.1415926535897931;\n"
        "const float ra = 0.0 / 3.0 * 2.0 * PI;\n"
        "const float ga = 1.0 / 3.0 * 2.0 * PI;\n"
        "const float ba = 2.0 / 3.0 * 2.0 * PI;\n"
        "\n"
        "float adj(float n, float m)\n"
        "{\n"
        "    return scale * ((2.0 * n / (m-1.0)) - 1.0);\n"
        "}\n"
        "\n"
        "vec2 point(vec2 src)\n"
        "{\n"
        "    return vec2(adj(src.x,ypixels), adj(src.y,ypixels));\n"
        "}\n"
        "\n"
        "float wave(vec2 p, float th)\n"
        "{\n"
        "    float t = fract(timer/tscale);\n"
        "    t *= 2.0 * PI;\n"
        "    float sth = sin(th);\n"
        "    float cth = cos(th);\n"
        "    return (cos (cth*p.x + sth*p.y + t) + 1.0) / 2.0;\n"
        "}\n"
        "\n"
        "float combine(vec2 p)\n"
        "{\n"
        "    float sum = 0.0;\n"
        "    for (int i = 0; i < symmetry; i++)\n"
        "    {\n"
        "        sum += wave(point(p), float(i)*PI/float(symmetry));\n"
        "    }\n"
        //"    sum /= float( symmetry );\n"
        "    return mod(floor(sum), 2.0) == 0.0 ? fract(sum) : 1.0 - fract(sum);\n"
        "\n"
        "}\n"
        "\n"
        "void main(void)\n"
        "{\n"
        // Using OpenGL Driver Monitor on NV GeForce 9400
        // SS  CLUT
        // --- ----
        // 1x1    0   30Hz
        // 2x2    0   30
        // 2x2    1   30
        // 2x2    2   30 ***
        // 3x3    0   16
        // 3x3    1   14
        // 3x3    2   16
        // 3x3    3   15-16
        //
        // Looks like 2x2 supersampling with CLUT code 2 is probably best.
#define MY_SS   1
#define MY_CLUT 2
        "    float s = 0.0;\n"
        "    vec4 c;\n"
#if MY_SS==0
        // NO SS
        "     s = combine(vec2(vUV.x*xpixels, vUV.y*ypixels));\n"
#endif
#if MY_SS==1
        // 3x3 SS
        "    for( float xx = 0.0; xx < 1.0; xx += 1.0/2.0) {\n"
        "        for( float yy = 0.0; yy < 1.0; yy += 1.0/2.0) {\n"
        "            s += combine(vec2(vUV.x*xpixels+xx, vUV.y*ypixels+yy));\n"
        "        }\n" 
        "     }\n"
        "     s = s/4.0;\n"  
#endif
#if MY_SS==2
        // 3x3 SS
        "    for( float xx = 0.0; xx < 1.0; xx += 1.0/3.0) {\n"
        "        for( float yy = 0.0; yy < 1.0; yy += 1.0/3.0) {\n"
        "            s += combine(vec2(vUV.x*xpixels+xx, vUV.y*ypixels+yy));\n"
        "        }\n" 
        "     }\n"
        "     s = s/9.0;\n"  
#endif
#if MY_CLUT==0
        // No color table
        "     c = vec4(s,s,s,s);\n"
#endif
#if MY_CLUT==1
        // "simplest" code color table
        "     s = 3.999*s;\n"
        "     int si = int(s);\n"
        "     float sf = fract(s);\n"
        "     c = mix( clut[si], clut[si+1], sf);\n"
#endif
#if MY_CLUT==2
        "     if(s<=0.25) {\n"
        "         c = mix( clut[0], clut[1], s*4.0 );\n"
        "     } else if(s<=0.5) {\n"
        "         c = mix( clut[1], clut[2], s*4.0-1.0 );\n"
        "     } else if(s<=0.75) {\n"
        "         c = mix( clut[2], clut[3], s*4.0-2.0 );\n"
        "     } else {\n"
        "         c = mix( clut[3], clut[4], s*4.0-3.0 );\n"
        "     }\n"
#endif
#if MY_CLUT==3
        "     float k0=0.0, k1=0.0, k2=0.0, k3=0.0;\n"
        "     if(s<=0.25) {\n"
        "        k0=1.0;\n"
        "     } else if(s<=0.5) {\n"
        "        k1=1.0;\n"
        "     } else if(s<=0.75) {\n"
        "        k2=1.0;\n"
        "     } else {\n"
        "        k3=1.0;\n"
        "     }\n"
        "     c  = k0*mix( clut[0], clut[1], s*4.0 );\n"
        "     c += k1*mix( clut[1], clut[2], s*4.0-1.0 );\n"
        "     c += k2*mix( clut[2], clut[3], s*4.0-2.0 );\n"
        "     c += k3*mix( clut[3], clut[4], s*4.0-3.0 );\n"
#endif
        "     gl_FragColor = c;\n" 
        "}",
        
        // (mainly) Ed's version of the shader
        "#version 120\n"
        "varying vec2 vUV;\n"
        "uniform float timer;\n"
        "uniform float scale;\n"
        "uniform float tscale;\n"
        "uniform float xpixels;\n"
        "uniform float ypixels;\n"
        "uniform int symmetry;\n"
        "uniform vec4 clut[5];\n"
        "\n"
        "const float PI = 3.1415926535897931;\n"
        "const float ra = 0.0 / 3.0 * 2.0 * PI;\n"
        "const float ga = 1.0 / 3.0 * 2.0 * PI;\n"
        "const float ba = 2.0 / 3.0 * 2.0 * PI;\n"
        "\n"
        "float adj(float n, float m)\n"
        "{\n"
        "    return scale * ((2.0 * n / (m-1.0)) - 1.0);\n"
        "//    return scale * (n / m);\n"
        "}\n"
        "\n"
        "vec2 point(vec2 src)\n"
        "{\n"
        "    return vec2(adj(src.x,ypixels), adj(src.y,ypixels));\n"
        "}\n"
        "\n"
        "vec2 wave( vec2 p, float th )\n"
        "{\n"
        "    float t = fract( timer / tscale );\n"
        "    t *= 2.0 * PI;\n"
        "    vec2 d = vec2( cos( th ), sin( th ) );\n"
        "    d = d * cos( dot( d, p ) + t );\n"
        "    d = (d + vec2(1.0,1.0))*0.5;\n"
        "    return d;\n"
        "}\n"
        "\n"
        "vec3 combine( vec2 p )\n"
        "{\n"
        "    vec2 sum = vec2( 0.0 );\n"
        "    vec2 rdir = vec2( cos( ra ), sin( ra ) );\n"
        "    vec2 gdir = vec2( cos( ga ), sin( ga ) );\n"
        "    vec2 bdir = vec2( cos( ba ), sin( ba ) );\n"
        "    for (int i = 0; i < symmetry; ++i)\n"
        "    {\n"
        "        sum += wave( point( p ), float( i ) * PI / float( symmetry ) );\n"
        "    }\n"
        "    sum /= float(symmetry);\n"
        "    sum.x = mod(floor(sum.x), 2.0) == 0.0 ? fract(sum.x) : 1.0 - fract(sum.x);\n"
        "    sum.y = mod(floor(sum.y), 2.0) == 0.0 ? fract(sum.y) : 1.0 - fract(sum.y);\n"
        "    sum = 2*sum - vec2(1.0,1.0);\n"
        "    float m = length( sum );\n"
        "    return m * (vec3( 2.0 ) + vec3( dot( rdir, sum ), dot( gdir, sum ), dot( bdir, sum ) ));\n"
        "\n"
        "}\n"
        "\n"
        "void main(void)\n"
        "{\n"
        "    float s = 0.0;\n"
        "    gl_FragColor = vec4( combine( vec2( vUV.x * xpixels, vUV.y * ypixels ) ), 1.0 );\n"
        "}",
        
        // Roger riffing on Ed's version of the shader
        "#version 120\n"
        "varying vec2 vUV;\n"
        "uniform float timer;\n"
        "uniform float scale;\n"
        "uniform float tscale;\n"
        "uniform float xpixels;\n"
        "uniform float ypixels;\n"
        "uniform int symmetry;\n"
        "uniform vec4 clut[5];\n"
        "\n"
        "const float PI = 3.1415926535897931;\n"
        "const float ra = 0.0 / 3.0 * 2.0 * PI;\n"
        "const float ga = 1.0 / 3.0 * 2.0 * PI;\n"
        "const float ba = 2.0 / 3.0 * 2.0 * PI;\n"
        "\n"
        "float adj(float n, float m)\n"
        "{\n"
        //"    return scale * ((2.0 * n / (m-1.0)) - 1.0);\n"
        "    return scale * (n / m);\n"
        "}\n"
        "\n"
        "vec2 point(vec2 src)\n"
        "{\n"
        "    return vec2(adj(src.x,ypixels), adj(src.y,ypixels));\n"
        "}\n"
        "\n"
        "vec2 wave( vec2 p, float th )\n"
        "{\n"
        "    float t = fract( timer / tscale );\n"
        "    t *= 2.0 * PI;\n"
        "    vec2 d = vec2( cos( th ), sin( th ) );\n"
        "    d = d * cos( dot( d, p ) + t );\n"
        "//    d = cos( dot( d, p ) + t );\n"
        "    d = (d + vec2(1.0,1.0))*0.5;\n"
        "    return d;\n"
        "}\n"
        "\n"
        "vec3 combine( vec2 p )\n"
        "{\n"
        "    vec2 sum = vec2( 0.0 );\n"
        "    vec2 rdir = vec2( cos( ra ), sin( ra ) );\n"
        "    vec2 gdir = vec2( cos( ga ), sin( ga ) );\n"
        "    vec2 bdir = vec2( cos( ba ), sin( ba ) );\n"
        "    for (int i = 0; i < symmetry; ++i)\n"
        "    {\n"
        "        sum += wave( point( p ), float( i ) * PI / float( symmetry ) );\n"
        "    }\n"
        "    sum.x = mod(floor(sum.x), 2.0) == 0.0 ? fract(sum.x) : 1.0 - fract(sum.x);\n"
        "    sum.y = mod(floor(sum.y), 2.0) == 0.0 ? fract(sum.y) : 1.0 - fract(sum.y);\n"
        "    sum = 2*sum - vec2(1.0,1.0);\n"
        "    return vec3( dot( rdir, sum ), dot( gdir, sum ), dot( bdir, sum ) );\n"
        "}\n"
        "\n"
        "void main(void)\n"
        "{\n"
        "    float s = 0.0;\n"
        "    gl_FragColor = vec4( combine( vec2( vUV.x * xpixels, vUV.y * ypixels ) ), 1.0 );\n"
        "}"
    };
    
    GLuint vshader, fshader[NUM_PROG];
    vshader = glCreateShader(GL_VERTEX_SHADER);
    fshader[0] = glCreateShader(GL_FRAGMENT_SHADER);
    fshader[1] = glCreateShader(GL_FRAGMENT_SHADER);
    fshader[2] = glCreateShader(GL_FRAGMENT_SHADER);
    m_prog[0] = glCreateProgram();
    m_prog[1] = glCreateProgram();
    m_prog[2] = glCreateProgram();
    glShaderSource(vshader, 1, &vsText, NULL);
    glShaderSource(fshader[0], 1, &fsText[0], NULL);
    glShaderSource(fshader[1], 1, &fsText[1], NULL);
    glShaderSource(fshader[2], 1, &fsText[2], NULL);
    [ self compileAndCheckProg:m_prog[0] vshader:vshader fshader:fshader[0] ];
    [ self compileAndCheckProg:m_prog[1] vshader:vshader fshader:fshader[1] ];
    [ self compileAndCheckProg:m_prog[2] vshader:vshader fshader:fshader[2] ];
    
    for(int i=0; i<NUM_PROG; ++i) {
        uniformLoc[i][0] = glGetUniformLocation(m_prog[i], "timer");
        uniformLoc[i][1] = glGetUniformLocation(m_prog[i], "xpixels");
        uniformLoc[i][2] = glGetUniformLocation(m_prog[i], "ypixels");
        uniformLoc[i][3] = glGetUniformLocation(m_prog[i], "scale");
        uniformLoc[i][4] = glGetUniformLocation(m_prog[i], "tscale");
        uniformLoc[i][5] = glGetUniformLocation(m_prog[i], "symmetry");
        uniformLoc[i][6] = glGetUniformLocation(m_prog[i], "clut");
        attribLoc[i][0]  = glGetAttribLocation(m_prog[i], "aPosition");    
        attribLoc[i][1]  = glGetAttribLocation(m_prog[i], "aUV");
        /*[ self checkForGLErrors: "attrib aUV" ];*/
    }
    
}

- (void)setUpOpenGL { 
    [[glView openGLContext] makeCurrentContext];
    /*GLboolean okay =*/ [self checkOpenGL];
    [self setUpShaders];
    glClearColor( 0.5f, 0.2f, 0.5f, 0.0f );
    timer = 0.0f;
	m_cur_clut = 0;
    m_cur_prog_index = 0;
}

- (void)checkForGLErrors:(const char *)s {
    int errors = 0 ;
    
    while ( true )
    {
        GLenum x = glGetError() ;
        
        if ( x == GL_NO_ERROR )
            return ; //errors ;
        
        fprintf( stderr, "%s: OpenGL error: %s [%08x]\n", s ? s : "", gluErrorString ( x ), errors++ ) ;
        errors++ ;
    }
}

- (void)setFrameSize:(NSSize)newSize { 
    [super setFrameSize:newSize]; 
    [glView setFrameSize:newSize]; 
    [[glView openGLContext] makeCurrentContext]; 
    glViewport( 0, 0, (GLsizei)newSize.width, (GLsizei)newSize.height ); 
    [[glView openGLContext] update]; 
    m_size = newSize;
}
    
- (void)startAnimation
{
    [super startAnimation];
}

- (void)stopAnimation
{
    [super stopAnimation];
}

- (void)drawRect:(NSRect)rect
{
    [super drawRect:rect];
    [[glView openGLContext] makeCurrentContext];
    
    glUseProgram(m_prog[m_cur_prog_index]);
    
    glClear(GL_COLOR_BUFFER_BIT);
    glLoadIdentity();
    GLfloat squareVertices[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f, 
        -1.0f,  1.0f, 
         1.0f,  1.0f 
	};
	float ds = sin(timer/tscale/30);
	float dt = cos(timer/tscale/30);
	GLfloat squareUV[] = {
        0.0f+ds, 0.0f+dt,
		1.0f+ds, 0.0f+dt,
		0.0f+ds, 1.0f+dt,
		1.0f+ds, 1.0f+dt,
	};
#define RGBX(r,g,b) (r/255.0f), (g/255.0f), (b/255.0f), 0.0f
	GLfloat clut[] = {
		0.0f, 0.0f, 0.0f, 0.0f, // CLUT 0 - ice water
		0.0f, 0.0f, 1.0f, 0.0f,
		0.0f, 1.0f, 1.0f, 0.0f,
		0.0f, 1.0f, 1.0f, 0.0f,
		1.0f, 1.0f, 1.0f, 0.0f,
        
		RGBX(138,170,178),      // CLUT 1 - campfire on kuler.adobe.com
		RGBX(76,76,75),
		RGBX(53,53,54),
		RGBX(105,47,29),
		RGBX(237,94,17),
		
		RGBX(255,192,108),      // CLUT 2 - sweet dreams on kuler.adobe.com
		RGBX(240,155,99),
		RGBX(235,112,79),
		RGBX(227,50,38),
		RGBX(201,0,18),
		
		RGBX(37,56,59),         // CLUT 3 - aquarium on kuler.adobe.com
		RGBX(42,93,97),
		RGBX(100,131,135),
		RGBX(184,182,130),
		RGBX(219,219,172),
		
		RGBX(58,117,78),        // CLUT 4 - feelin fine on kuler.adobe.com
		RGBX(175,207,93),
		RGBX(255,232,135),
		RGBX(194,138,79),
		RGBX(145,70,56),
		
		RGBX(0,0,0),            // CLUT 5 - grey
		RGBX(64,64,64),
		RGBX(128,128,128),
		RGBX(192,192,192),
		RGBX(255,255,255),

		RGBX(0,0,0),            // CLUT 6 - Ed's Scheme (These are ignored)
		RGBX(0,0,0),
		RGBX(0,0,0),
		RGBX(0,0,0),
		RGBX(0,0,0),
        
		RGBX(0,0,0),            // CLUT 7 - Riff (These are ignored)
		RGBX(0,0,0),
		RGBX(0,0,0),
		RGBX(0,0,0),
		RGBX(0,0,0)
	};
    glUniform1f(uniformLoc[m_cur_prog_index][0],timer);
    glUniform1f(uniformLoc[m_cur_prog_index][1],m_size.width);
    glUniform1f(uniformLoc[m_cur_prog_index][2],m_size.height);
    glUniform1f(uniformLoc[m_cur_prog_index][3],scale);
    glUniform1f(uniformLoc[m_cur_prog_index][4],tscale);
    glUniform1i(uniformLoc[m_cur_prog_index][5],symmetry);
    glUniform4fv(uniformLoc[m_cur_prog_index][6], 5, clut+(m_cur_clut*5*sizeof(float))); // FIXME 5-size of color table
    
    glVertexAttribPointer(attribLoc[m_cur_prog_index][0], 2, GL_FLOAT, FALSE, 0, squareVertices);
    glVertexAttribPointer(attribLoc[m_cur_prog_index][1], 2, GL_FLOAT, FALSE, 0, squareUV);
    glEnableVertexAttribArray(attribLoc[m_cur_prog_index][0]);
    glEnableVertexAttribArray(attribLoc[m_cur_prog_index][1]);    
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    /*[ self checkForGLErrors: "glDrawArrays" ];*/    
    glFlush(); 
}

- (void)animateOneFrame
{
    ScreenSaverDefaults *defaults;
    defaults = [ScreenSaverDefaults defaultsForModuleWithName:MyModuleName];
    scale = [defaults floatForKey:@"Scale"];
    tscale = [defaults floatForKey:@"Rate"];
    symmetry = [defaults integerForKey:@"Symmetry"];
	m_cur_clut = [defaults integerForKey:@"Color"];
    
    if (symmetry < 1) {
        symmetry = 1;
    } else if (symmetry > 99) {
        symmetry = 99;
    }

    if(scale < 8.0) {
        scale = 64.0;
    }
    if (tscale < 8.0) {
        tscale = 128.0;
    }
	if(m_cur_clut < 0) {
		m_cur_clut = 0;
	} else if (m_cur_clut > 7) {  // FIXME
		m_cur_clut = 7;
	}
    
    if (m_cur_clut < 6) {
        m_cur_prog_index = 0;
    } else {
        m_cur_prog_index = m_cur_clut - 5;  // 6->1, 7->2 
    }

    timer += 1.0f;
    if (timer > 10000000.0f) {
        timer = 0.0f;
    }
    [self setNeedsDisplay:YES];
}

- (BOOL)hasConfigureSheet
{
    return YES;
}

- (NSWindow*)configureSheet
{
    ScreenSaverDefaults *defaults; 
    defaults = [ScreenSaverDefaults defaultsForModuleWithName:MyModuleName]; 
    
    if (!configSheet) { 
        if (![NSBundle loadNibNamed:@"QuasiCrystalConfigure" owner:self]) { 
            NSLog( @"Failed to load configure sheet." ); 
            NSBeep(); 
        } 
    } 
    
    [scaleOption setFloatValue:[defaults floatForKey:@"Scale"]]; 
    [rateOption setFloatValue:[defaults floatForKey:@"Rate"]]; 
    [colorOption selectItemAtIndex:[defaults integerForKey:@"Color"]]; 
    [symmetryOption setIntegerValue:[defaults integerForKey:@"Symmetry"]];

    return configSheet;
}

- (IBAction)cancelClick:(id)sender 
{ 
    [[NSApplication sharedApplication] endSheet:configSheet]; 
}

- (IBAction)okClick: (id)sender 
{ 
    ScreenSaverDefaults *defaults; 
    defaults = [ScreenSaverDefaults defaultsForModuleWithName:MyModuleName]; 
    // Update our defaults 
	NSLog( @"scale    = %0.3f", [scaleOption floatValue] ); 
	NSLog( @"rate     = %0.3f", [rateOption floatValue] ); 
	NSLog( @"color    = %d", [[colorOption selectedItem] tag] );
	NSLog( @"symmetry = %d", [symmetryOption integerValue] ); 
    [defaults setInteger:[symmetryOption integerValue] forKey:@"Symmetry"];
    [defaults setFloat:[scaleOption floatValue] forKey:@"Scale"]; 
    [defaults setFloat:[rateOption floatValue] forKey:@"Rate"]; 
    [defaults setInteger:[[colorOption selectedItem] tag] forKey:@"Color"]; 	
    // Save the settings to disk 
    [defaults synchronize]; 
    // Close the sheet 
    [[NSApplication sharedApplication] endSheet:configSheet]; 
}
    
@end

