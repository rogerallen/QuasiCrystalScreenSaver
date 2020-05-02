//
//  QuasiCrystalScreenSaverView.h
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

#import <ScreenSaver/ScreenSaver.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import "MyOpenGLView.h"

#define NUM_PROG 3

@interface GmailRallen_QuasiCrystalScreenSaverView : ScreenSaverView 
{
    MyOpenGLView *glView; 

    NSSize  m_size;
    GLfloat timer;
    GLfloat scale;
    GLfloat tscale;
    GLint   symmetry;
	int     m_cur_clut;
    
    GLuint  m_prog[NUM_PROG];
    int     m_cur_prog_index;
    GLint   uniformLoc[NUM_PROG][8];
    GLint   attribLoc[NUM_PROG][8];
    
    IBOutlet id configSheet; 
    IBOutlet id symmetryOption; 
    IBOutlet id scaleOption; 
    IBOutlet id rateOption; 
	IBOutlet id colorOption;
    
}
- (void)setUpOpenGL;
- (void)checkForGLErrors:(const char *)s;
- (IBAction)cancelClick:(id)sender;
- (IBAction)okClick:(id)sender;
@end
